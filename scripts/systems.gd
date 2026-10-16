class_name Systems
extends Node
# The ship's hidden truth: gas in every compartment, the electric network,
# propellant and coolant, temperatures. The player only ever sees readings
# (KnownState) taken with an instrument at a real test point; a reading
# records where, when and through what it was taken, and goes stale once the
# system it describes has changed.

const SPACE := 0
const ROOM_IDS := {"A": 1, "B": 2, "C": 3, "D": 4, "E": 5}
const ROOM_NAMES := ["", "A", "B", "C", "D", "E"]
const CELL := 0.1                 # metres per gas cell
const GX0 := -1.0
const GY0 := -5.0
const GW := 440
const GH := 100
const K_OPEN := 8.0               # m²/s of exchange per contact cell
const SAFE_KPA := 5.0

var game: Game
var world: World
var cell_owner := PackedByteArray()
var room_cells := {}
var time := 0.0

# gas: volumes by id -> {n, V}; pressure = n / V (kPa)
var vols := {}
var links: Array = []             # [a_id, b_id, g, pos(px), dir]
var link_sig := {}                # room -> signature of its openings
var vol_ver := {}                 # volume id -> version (bumped when its openings change)
var topology_dirty := true
var job_id := -1
var job_result = null
var job_mutex := Mutex.new()
var gas0 := 0.0
var gas_recovered := 0.0
var gas_lost := 0.0
var blown := {}                   # room -> time of last blowout
var flow_rate := {}               # room -> kPa/s (negative when draining)

# electric
var G_running := true
var KG := true
var KB := true
var bat := 0.84
var cap := 1.0
var nav_bat := 1.0
var aux := false
var discharge := false
var g_remote := false
var bus_live := true
var elec_ver := 0
var _elec_sig := ""

# fluids
var VC01 := false
var VF01 := true
var VE1 := true
var VE2 := true
var fuel := 0.35
var fuel_line := 0.04
var cool := 0.25
var cool_broken := 0.06
var loop_T := 138.0
var fuel_recovered := 0.0
var cool_recovered := 0.0
var fluid_lost := 0.0
const COOL0 := 0.31
const FUEL0 := 0.39
var leaks: Array = []             # {pos, dir, fluid, rate, src, t, body, local}
var clouds: Array = []            # {pos, r, amount, t}

# hoses: port id -> {"mode": "recover"|"vent", "t": age}
var hoses := {}
var readings := {}


func setup(g, w) -> void:
	game = g
	world = w
	cell_owner.resize(GW * GH)
	cell_owner.fill(0)
	for n in world.rooms:
		var r = world.rooms[n]
		var bb: Rect2 = r.bbox
		var id: int = ROOM_IDS[n]
		var c := 0
		var x0 := maxi(0, int((bb.position.x / Geom.M - GX0) / CELL))
		var x1 := mini(GW - 1, int((bb.end.x / Geom.M - GX0) / CELL) + 1)
		var y0 := maxi(0, int((bb.position.y / Geom.M - GY0) / CELL))
		var y1 := mini(GH - 1, int((bb.end.y / Geom.M - GY0) / CELL) + 1)
		for gy in range(y0, y1 + 1):
			for gx in range(x0, x1 + 1):
				if Geometry2D.is_point_in_polygon(_cell_px(gx, gy), r.poly):
					cell_owner[gy * GW + gx] = id
					c += 1
		room_cells[n] = c
	var start := {"A": 92.0, "B": 92.0, "C": 108.0, "D": 72.0, "E": 0.0}
	for n in start:
		var v: float = room_cells[n] * CELL * CELL
		vols[n] = {"n": start[n] * v, "V": v}
	vols["SC"] = {"n": 0.0, "V": 0.05}
	vols["T1"] = {"n": 1820.0 * 0.6, "V": 0.6}
	vols["T2"] = {"n": 1760.0 * 0.6, "V": 0.6}
	for k in vols:
		gas0 += vols[k].n
		vol_ver[k] = 0
	_compute_now()


func _cell_px(gx: int, gy: int) -> Vector2:
	return Vector2((GX0 + (gx + 0.5) * CELL) * Geom.M, (GY0 + (gy + 0.5) * CELL) * Geom.M)


func P(id: String) -> float:
	var v = vols.get(id)
	if v == null:
		return 0.0
	return v.n / v.V


# ---------------------------------------------------------------- gas topology

func _barrier_polys() -> Array:
	var out: Array = []
	for id in world.order:
		var p = world.pieces[id]
		if p.gone or p.body != null or not p.barrier:
			continue
		if p.door and p.open_t > 0.5:
			continue
		out.append(p.poly)
	return out


func _compute_now() -> void:
	_apply_links(_grid_job_calc(_barrier_polys()))


func _grid_job(polys: Array) -> void:
	var r := _grid_job_calc(polys)
	job_mutex.lock()
	job_result = r
	job_mutex.unlock()


func _grid_job_calc(polys: Array) -> Array:
	var solid := PackedByteArray()
	solid.resize(GW * GH)
	solid.fill(0)
	var inv := 1.0 / (CELL * Geom.M)
	for poly in polys:
		var bb := Geom.bbox(poly)
		var x0 := maxi(0, int(bb.position.x * inv - GX0 / CELL))
		var x1 := mini(GW - 1, int(bb.end.x * inv - GX0 / CELL) + 1)
		var y0 := maxi(0, int(bb.position.y * inv - GY0 / CELL))
		var y1 := mini(GH - 1, int(bb.end.y * inv - GY0 / CELL) + 1)
		for gy in range(y0, y1 + 1):
			for gx in range(x0, x1 + 1):
				var idx := gy * GW + gx
				if solid[idx] == 0 and Geometry2D.is_point_in_polygon(_cell_px(gx, gy), poly):
					solid[idx] = 1
	var seen := PackedByteArray()
	seen.resize(GW * GH)
	seen.fill(0)
	var out: Array = []
	var stack := PackedInt32Array()
	for start in GW * GH:
		if seen[start] != 0 or solid[start] != 0 or cell_owner[start] != 0:
			continue
		var contact := {}
		var border := false
		stack.clear()
		stack.append(start)
		seen[start] = 1
		while stack.size() > 0:
			var idx := stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			var gx := idx % GW
			var gy := idx / GW
			if gx == 0 or gy == 0 or gx == GW - 1 or gy == GH - 1:
				border = true
			for d in 4:
				var nx := gx + (1 if d == 0 else (-1 if d == 1 else 0))
				var ny := gy + (1 if d == 2 else (-1 if d == 3 else 0))
				if nx < 0 or ny < 0 or nx >= GW or ny >= GH:
					continue
				var ni := ny * GW + nx
				if solid[ni] != 0:
					continue
				var o := cell_owner[ni]
				if o != 0:
					if not contact.has(o):
						contact[o] = [0, Vector2.ZERO, Vector2.ZERO]
					var cc: Array = contact[o]
					cc[0] += 1
					cc[1] += _cell_px(gx, gy)
					cc[2] += Vector2(gx - nx, gy - ny)
					continue
				if seen[ni] == 0:
					seen[ni] = 1
					stack.append(ni)
		if contact.is_empty():
			continue
		var ks := contact.keys()
		if border:
			for r in ks:
				var cc: Array = contact[r]
				out.append([ROOM_NAMES[r], "space", float(cc[0]), cc[1] / cc[0], (cc[2] as Vector2).normalized()])
		else:
			for i in ks.size():
				for k in range(i + 1, ks.size()):
					var a: Array = contact[ks[i]]
					var b: Array = contact[ks[k]]
					out.append([ROOM_NAMES[ks[i]], ROOM_NAMES[ks[k]], float(mini(a[0], b[0])), (a[1] / a[0] + b[1] / b[0]) * 0.5, Vector2.ZERO])
	return out


func _apply_links(new_links: Array) -> void:
	links = new_links
	var sig := {}
	for l in links:
		for side in [l[0], l[1]]:
			if side == "space":
				continue
			sig[side] = sig.get(side, "") + "%s:%d;" % [l[1] if side == l[0] else l[0], int(l[2])]
	for n in ROOM_NAMES:
		if n == "":
			continue
		var s: String = sig.get(n, "")
		if link_sig.get(n, "") != s:
			link_sig[n] = s
			vol_ver[n] = vol_ver.get(n, 0) + 1
	# rooms open to space, or joined to an open room, can be seen into
	for l in links:
		if l[1] == "space" and l[2] >= 1.0:
			world.reveal(l[0], l[3])
	for pass_i in 3:
		for l in links:
			if l[1] == "space":
				continue
			var ra = world.rooms.get(l[0])
			var rb = world.rooms.get(l[1])
			if ra == null or rb == null or l[2] < 3.0:
				continue
			if ra.revealed and not rb.revealed:
				world.reveal(l[1], l[3])
			elif rb.revealed and not ra.revealed:
				world.reveal(l[0], l[3])


# ---------------------------------------------------------------- step

func _physics_process(dt: float) -> void:
	if game == null or game.paused_sim:
		return
	time += dt
	if topology_dirty and job_id < 0:
		topology_dirty = false
		job_id = WorkerThreadPool.add_task(_grid_job.bind(_barrier_polys()))
	if job_id >= 0 and WorkerThreadPool.is_task_completed(job_id):
		WorkerThreadPool.wait_for_task_completion(job_id)
		job_id = -1
		job_mutex.lock()
		var r = job_result
		job_result = null
		job_mutex.unlock()
		if r != null:
			_apply_links(r)
	_step_gas(dt)
	_step_elec(dt)
	_step_fluids(dt)


func _step_gas(dt: float) -> void:
	var before := {}
	for n in ROOM_IDS:
		before[n] = P(n)
	var sub := 4
	var h := dt / sub
	for s in sub:
		for l in links:
			var a: String = l[0]
			var b: String = l[1]
			var pa := P(a)
			var pb := 0.0 if b == "space" else P(b)
			if absf(pa - pb) < 0.001:
				continue
			var g: float = l[2] * K_OPEN
			var dn := g * (pa - pb) * h
			dn = _limit(dn, a, b)
			vols[a].n -= dn
			if b == "space":
				gas_lost += maxf(dn, 0.0)
			else:
				vols[b].n += dn
		if VC01:
			var dn2 := 20.0 * (P("C") - P("SC")) * h
			dn2 = _limit(dn2, "C", "SC")
			vols["C"].n -= dn2
			vols["SC"].n += dn2
		for port_id in hoses:
			var c = world.ctrls.get(port_id)
			if c == null or c.medium != "gas":
				continue
			var v: String = c.target
			var k := 0.2 if v.begins_with("T") else (6.0 if v == "D" else 9.0)
			if v == "SC":
				k = 3.0
			var hose: Dictionary = hoses[port_id]
			if hose.mode == "vent":
				k *= 3.0
			var take: float = minf(vols[v].n, k * P(v) * h)
			vols[v].n -= take
			if hose.mode == "vent":
				gas_lost += take
			else:
				gas_recovered += take
	for n in ROOM_IDS:
		vols[n].n = maxf(0.0, vols[n].n)
		var rate: float = (P(n) - before[n]) / maxf(dt, 1e-4)
		flow_rate[n] = rate
		if rate < -22.0 and before[n] > 25.0 and time - blown.get(n, -99.0) > 4.0:
			blown[n] = time
			var worst = null
			for l in links:
				if l[0] == n and l[1] == "space" and (worst == null or l[2] > worst[2]):
					worst = l
			if worst != null and game != null:
				game.on_blowout(n, worst[3], worst[4], before[n])
	# jets for the fx
	if game != null:
		for l in links:
			if l[1] != "space":
				continue
			var p := P(l[0])
			if p > 1.5:
				game.on_jet(l[0], l[3], l[4], p, l[2])


func _limit(dn: float, a: String, b: String) -> float:
	# never push more than it takes to equalise
	var va: float = vols[a].V
	if b == "space":
		return clampf(dn, 0.0, vols[a].n)
	var vb: float = vols[b].V
	var eq := (P(a) - P(b)) / (1.0 / va + 1.0 / vb)
	if eq >= 0.0:
		return clampf(dn, 0.0, eq * 0.95)
	return clampf(dn, eq * 0.95, 0.0)


func _step_elec(dt: float) -> void:
	var c1 := _alive("c1")
	var c2 := _alive("c2")
	var c3 := _alive("c3")
	var src_g := G_running and KG and c1 and _piece_ok("G-01")
	var src_b := KB and bat > 0.01 and c2 and _piece_ok("B-01")
	var src_c := cap > 0.02 and c3 and _piece_ok("CAP-01")
	bus_live = (src_g or src_b or src_c) and _piece_ok("SWB")
	if discharge:
		if src_g or src_b:
			discharge = false
			if game != null:
				game.on_discharge_refused()
		elif c3:
			cap = maxf(0.0, cap - cap * dt / 0.9 - dt * 0.02)
	if src_b and not src_g:
		bat = maxf(0.0, bat - dt * 0.0004)
	var lit := {}
	lit["D"] = bus_live and _alive("c5") and _piece_ok("LAMP-D")
	var c6 := bus_live and _alive("c6")
	lit["C"] = c6 and _piece_ok("LAMP-C")
	var c7 := c6 and _alive("c7") and _piece_ok("LAMP-C")
	lit["B"] = c7 and _piece_ok("LAMP-B")
	lit["A"] = c7 and _alive("c8") and _piece_ok("LAMP-B") and _piece_ok("LAMP-A")
	lit["E"] = false
	var redraw := false
	for n in lit:
		if world.rooms[n].lit != lit[n]:
			world.rooms[n].lit = lit[n]
			redraw = true
	if redraw:
		world.light_layer.queue_redraw()
	var sig := "%s%s%s%s%s%d%d%s%s" % [G_running, KG, KB, bus_live, aux, int(cap * 20), int(bat * 50), c1, c3]
	if sig != _elec_sig:
		_elec_sig = sig
		elec_ver += 1


func _alive(id: String) -> bool:
	var l = world.lines.get(id)
	return l != null and l.alive


func _piece_ok(t: String) -> bool:
	var p = world.tag(t)
	return p != null and not p.gone and (p.cls != "equip" or p.intact)


func _step_fluids(dt: float) -> void:
	# coolant temperature follows the generator
	var tgt := 138.0 if G_running else 20.0
	loop_T = Pal.damp(loop_T, tgt, 1.0 / (8.0 if G_running else 13.0), dt)
	for t in ["CP-E", "RAD", "ENG-F"]:
		var p = world.tag(t)
		if p != null:
			p.temp = loop_T if t != "ENG-F" else lerpf(20.0, loop_T, 0.5)
	var gp = world.tag("G-01")
	if gp != null:
		gp.temp = loop_T + (12.0 if G_running else 0.0)
	# valves join the broken segment to the loop
	var joined := VE1 or VE2
	if joined:
		var tot := cool + cool_broken
		cool = tot * 0.25 / 0.31
		cool_broken = tot - cool
	# the crack drips slowly
	var drip := minf(cool_broken, dt * 0.0016)
	cool_broken -= drip
	fluid_lost += drip
	if VF01:
		var tot2 := fuel + fuel_line
		fuel_line = minf(0.04, tot2)
		fuel = tot2 - fuel_line
	for port_id in hoses:
		var c = world.ctrls.get(port_id)
		if c == null:
			continue
		if c.medium == "fuel":
			var take := minf(fuel, (0.12 * fuel + 0.008) * dt)
			fuel -= take
			fuel_recovered += take
			if VF01:
				var t2 := minf(fuel_line, 0.02 * dt)
				fuel_line -= t2
				fuel_recovered += t2
		elif c.medium == "coolant":
			var take := minf(cool, (0.22 * cool + 0.006) * dt)
			cool -= take
			cool_recovered += take
	# leaks drain what they are attached to
	for lk in leaks:
		lk.t += dt
		var take := 0.0
		match lk.src:
			"fuel_tank":
				take = minf(fuel, dt * 0.1)
				fuel -= take
			"fuel_line":
				take = minf(fuel_line, dt * 0.05)
				fuel_line -= take
				if VF01:
					var t3 := minf(fuel, dt * 0.06)
					fuel -= t3
					take += t3
			"cool":
				take = minf(cool, dt * 0.2)
				cool -= take
			"cool_broken":
				take = minf(cool_broken, dt * 0.2)
				cool_broken -= take
		lk.rate = take / maxf(dt, 1e-4)
		fluid_lost += take
		if lk.fluid == "fuel" and take > 0.0:
			_feed_cloud(game.leak_pos(lk), take)
	leaks = leaks.filter(func(lk): return lk.rate > 0.0005 or lk.t < 0.3)
	for cl in clouds:
		cl.t += dt
		cl.amount = maxf(0.0, cl.amount - dt * 0.004)
		cl.r = clampf(Geom.M * (1.2 + sqrt(cl.amount) * 9.0), Geom.M * 1.0, Geom.M * 3.6)
	clouds = clouds.filter(func(cl): return cl.amount > 0.002)


func _feed_cloud(pos: Vector2, amt: float) -> void:
	for cl in clouds:
		if cl.pos.distance_to(pos) < Geom.M * 2.0:
			cl.amount += amt
			return
	clouds.append({"pos": pos, "r": Geom.M, "amount": amt, "t": 0.0})


func cloud_at(pos: Vector2):
	for cl in clouds:
		if cl.pos.distance_to(pos) < cl.r:
			return cl
	return null


# ---------------------------------------------------------------- queries

func line_live(l) -> bool:
	if not l.alive or l.kind != "cable":
		return false
	match l.id:
		"c1": return bus_live or (G_running and KG)
		"c2": return bus_live or (KB and bat > 0.01)
		"c3": return bus_live or cap > 0.02
		"cn": return nav_bat > 0.0
		"c7": return bus_live and _alive("c6")
		"c8": return bus_live and _alive("c6") and _alive("c7")
	return bus_live


func line_volts(l) -> float:
	if not line_live(l):
		return 0.0
	if l.id == "cn":
		return 24.0
	if l.id == "c3" and not bus_live:
		return 380.0 * cap
	if l.id == "c2" and not bus_live:
		return 52.0
	return bus_volts()


func bus_volts() -> float:
	if not bus_live:
		return 0.0
	if G_running and KG and _alive("c1"):
		return 400.0
	if KB and bat > 0.01 and _alive("c2"):
		return 396.0
	return 380.0 * cap


# Is cutting into this piece going to arc? Returns volts (0 = dead).
func piece_volts(p) -> float:
	if p.cls != "equip" or not p.intact:
		return 0.0
	match p.tag:
		"G-01": return 400.0 if G_running else 0.0
		"B-01": return 52.0 if bat > 0.01 else 0.0
		"CAP-01": return 380.0 * cap if cap > 0.02 else 0.0
		"SWB": return bus_volts()
		"C-03": return bus_volts() if _alive("c4") else 0.0
		"NAV-01", "CON-A": return 24.0 if _alive("cn") or p.tag == "NAV-01" else 0.0
	return 0.0


func line_fluid(l) -> float:
	match l.net:
		"coolant": return cool
		"coolant_broken": return cool_broken
		"fuel": return fuel_line
		"gas": return 0.0
	return 0.0


func line_temp(l) -> float:
	if l.net in ["coolant", "coolant_broken"]:
		return loop_T
	return 20.0


func content_mass(p) -> float:
	if p.tag == "T-F01" and p.intact:
		return fuel * 2.6
	return 0.0


# where a piece pays most right now (hazardous contents go to the hazard bay)
func dest_of(p) -> String:
	if p.cls != "equip":
		return "metal"
	if not p.intact:
		return "metal"
	match p.hazard:
		"fuel_tank":
			if fuel > 0.02:
				return "hazard"
		"gas_tank":
			if P("T1" if p.tag == "TK-B1" else "T2") > 200.0:
				return "hazard"
		"cap":
			if cap > 0.05:
				return "hazard"
	return "equip"


func tank_vol(p) -> String:
	return "T1" if p.tag == "TK-B1" else "T2"


# ---------------------------------------------------------------- actions

func set_switch(id: String, on: bool) -> void:
	match id:
		"K-G": KG = on
		"K-B": KB = on
		"V-C01": VC01 = on
		"V-F01": VF01 = on
		"V-E1": VE1 = on
		"V-E2": VE2 = on
	if id.begins_with("V-C"):
		vol_ver["SC"] = vol_ver.get("SC", 0) + 1
		vol_ver["C"] = vol_ver.get("C", 0) + 1


func gas_value() -> float:
	return gas_recovered / maxf(gas0, 1.0) * 1200.0


func fluid_value() -> float:
	return fuel_recovered / FUEL0 * 900.0 + cool_recovered / COOL0 * 400.0


# ---------------------------------------------------------------- readings

func measure(key: String, kind: String, at_text: String, inst: String, extra: Dictionary = {}) -> Dictionary:
	var r := {"key": key, "kind": kind, "at": at_text, "inst": inst, "t": time, "val": 0.0, "text": "", "ver": 0, "vk": ""}
	r.merge(extra, true)
	readings[key] = r
	refresh_reading(r, true)
	return r


func refresh_reading(r: Dictionary, take: bool) -> void:
	var cur := _current(r)
	if take:
		r.val = cur[0]
		r.text = cur[1]
		r.ver = cur[2]
		r.vk = cur[3]


# [value, text, version, version-key]
func _current(r: Dictionary) -> Array:
	var key: String = r.key
	match r.kind:
		"pressure":
			var v: String = r.get("vol", "")
			var pv := P(v) + (randf_range(-0.3, 0.3) if P(v) > 1.0 else 0.0)
			return [pv, "%.1f kPa" % maxf(0.0, pv), vol_ver.get(v, 0), "gas"]
		"volts":
			var vv: float = r.get("volts_fn").call()
			return [vv, "%d V" % int(round(vv)), elec_ver, "elec"]
		"fluid":
			var fv: float = r.get("fluid_fn").call()
			return [fv, "%d %%" % int(round(fv * 100.0)), 0, "fluid"]
		"temp":
			var tv: float = r.get("temp_fn").call()
			return [tv, "%d °C" % int(round(tv)), 0, "temp"]
	return [0.0, "", 0, ""]


func stale(r: Dictionary) -> bool:
	var cur := _current(r)
	match r.kind:
		"pressure":
			return cur[2] != r.ver or absf(cur[0] - r.val) > maxf(2.0, absf(r.val) * 0.04)
		"volts":
			return cur[2] != r.ver
		"fluid":
			return absf(cur[0] - r.val) > 0.02
		"temp":
			return absf(cur[0] - r.val) > 8.0
	return false
