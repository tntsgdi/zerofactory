class_name Systems
extends Node
# The ship's hidden truth: gas in every compartment, the electric network,
# fluids and their temperature. What exists and how it is wired comes from the
# ship file (gas / power / fluids sections); nothing here knows a ship by name.
# The player only ever sees readings (KnownState) taken with an instrument at
# a real test point; a reading records where, when and through what it was
# taken, and goes stale once the system it describes has changed.

const SPACE := 0
const CELL := 0.1                 # metres per gas cell
# the gas grid: x -1..43 m, y -5..5 m, grown (on the same cells) for a ship that reaches further
var GX0 := -1.0
var GY0 := -5.0
var GW := 440
var GH := 100
const K_OPEN := 8.0               # m²/s of exchange per contact cell
const SAFE_KPA := 5.0
# hazards that only ever go to the hazard mouth (which pays 40 % of their value)
const HAZARD_ONLY := ["explosive", "bio", "chem"]

var game: Game
var world: World
var cfg: Dictionary = {}          # the ship file
var cell_owner := PackedByteArray()
var room_cells := {}
var room_ids := {}                # room name -> grid id 1..n
var room_names: Array = [""]      # grid id -> room name
var time := 0.0

# gas: volumes by id -> {n, V}; pressure = n / V (kPa)
var vols := {}
var vessel_cfg := {}              # vessel id -> its ship-file entry
var gas_valves: Array = []        # [{ctrl, a, b, g}]
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

# switches, valves and other two-state controls: ctrl id -> on
var switch := {}
# electric
var src := {}                     # source piece tag -> its ship-file entry + live "charge" / "running"
var src_order: Array = []
var iso := {}                     # isolated source tag -> {volts, charge, switch}: a supply of its own (a reefer unit, a nav battery)
var bus_tag := ""
var bus_live := false
var powered := {}                 # piece id -> true: reached from the bus through live cables
var iso_powered := {}             # piece id -> volts of its own little network
var aux := false                  # external power plugged into the dock socket
var remote_sent := false          # a remote stop was sent (and may not have worked)
var elec_ver := 0
var _elec_sig := ""

# fluids
var fvol := {}                    # volume id -> its ship-file entry + live "amount"
var fluid0 := {}                  # fluid kind -> amount at the start
var fluid_rec := {}               # fluid kind -> amount recovered
var fluid_lost := 0.0
var loop_T := 20.0
var heat: Dictionary = {}
var leaks: Array = []             # {pos, dir, fluid, rate, src, t, piece, local}
var clouds: Array = []            # {pos, r, amount, t}

# biological contamination carried in a room's air (ship file "bio": {"rooms": {room: index}}):
# room -> amount (index × volume); it moves with the gas between rooms, goes with it to
# space, and the recovery hose's filter takes it out
var bio := {}
var bio_vented := 0.0

# hoses: port id -> {"mode": "recover"|"vent", "t": age}
var hoses := {}
var readings := {}


func setup(g, w, ship: Dictionary) -> void:
	game = g
	world = w
	cfg = ship
	var gas: Dictionary = cfg.get("gas", {})
	room_ids = {}
	room_names = [""]
	_fit_grid(ship)
	for n in world.rooms:
		room_names.append(n)
		room_ids[n] = room_names.size() - 1
	cell_owner.resize(GW * GH)
	cell_owner.fill(0)
	for n in world.rooms:
		var r = world.rooms[n]
		var bb: Rect2 = r.bbox
		var id: int = room_ids[n]
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
	var start: Dictionary = gas.get("rooms", {})
	for n in world.rooms:
		var v: float = room_cells[n] * CELL * CELL
		vols[n] = {"n": float(start.get(n, 0.0)) * v, "V": v}
	vessel_cfg = gas.get("vessels", {})
	for k in vessel_cfg:
		var vc: Dictionary = vessel_cfg[k]
		vols[k] = {"n": float(vc.kpa) * float(vc.V), "V": float(vc.V)}
	gas_valves = gas.get("valves", [])
	for k in vols:
		gas0 += vols[k].n
		vol_ver[k] = 0
	bio = {}
	var b0: Dictionary = cfg.get("bio", {}).get("rooms", {})
	for n in b0:
		if vols.has(n):
			bio[n] = float(b0[n]) * vols[n].V
	# every control with two states starts as the ship file says
	for id in world.ctrls:
		var c = world.ctrls[id]
		if c.kind in ["valve", "switch", "discharge", "socket"]:
			switch[id] = c.state
	var pw: Dictionary = cfg.get("power", {})
	bus_tag = pw.get("bus", "")
	for s in pw.get("sources", []):
		var e: Dictionary = s.duplicate()
		e.charge = float(s.get("charge", 1.0))
		e.running = bool(s.get("running", false))
		src[s.piece] = e
		src_order.append(s.piece)
	for s in pw.get("isolated", []):
		iso[s.piece] = {"volts": float(s.volts), "charge": float(s.get("charge", 1.0)), "switch": s.get("switch", "")}
	var fl: Dictionary = cfg.get("fluids", {})
	for k in fl.get("volumes", {}):
		var e: Dictionary = fl.volumes[k].duplicate()
		e.amount = float(e.amount)
		fvol[k] = e
		fluid0[e.fluid] = fluid0.get(e.fluid, 0.0) + e.amount
		fluid_rec[e.fluid] = 0.0
	heat = fl.get("heat", {})
	loop_T = _heat_target() if not heat.is_empty() else 20.0
	_compute_now()
	_step_elec(0.0)


# a longer or taller ship than the standard grid holds: whole metres more, same cells
func _fit_grid(ship: Dictionary) -> void:
	var x1 := -INF
	var y0 := INF
	var y1 := -INF
	for pd in ship.get("pieces", []):
		for q in pd.get("poly", []):
			x1 = maxf(x1, q[0])
			y0 = minf(y0, q[1])
			y1 = maxf(y1, q[1])
	if x1 == -INF:
		return
	if x1 + 1.0 > GX0 + GW * CELL:
		GW = ceili((ceilf(x1) + 1.0 - GX0) / CELL)
	if y0 - 1.0 < GY0 or y1 + 1.0 > GY0 + GH * CELL:
		var top := minf(GY0, floorf(y0) - 1.0)
		var bot := maxf(GY0 + GH * CELL, ceilf(y1) + 1.0)
		GY0 = top
		GH = roundi((bot - top) / CELL)


func _cell_px(gx: int, gy: int) -> Vector2:
	return Vector2((GX0 + (gx + 0.5) * CELL) * Geom.M, (GY0 + (gy + 0.5) * CELL) * Geom.M)


func P(id: String) -> float:
	var v = vols.get(id)
	if v == null:
		return 0.0
	return v.n / v.V


func on(ctrl_id: String) -> bool:
	return switch.get(ctrl_id, false)


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
				out.append([room_names[r], "space", float(cc[0]), cc[1] / cc[0], (cc[2] as Vector2).normalized()])
		else:
			for i in ks.size():
				for k in range(i + 1, ks.size()):
					var a: Array = contact[ks[i]]
					var b: Array = contact[ks[k]]
					out.append([room_names[ks[i]], room_names[ks[k]], float(mini(a[0], b[0])), (a[1] / a[0] + b[1] / b[0]) * 0.5, Vector2.ZERO])
	return out


func _apply_links(new_links: Array) -> void:
	links = new_links
	var sig := {}
	for l in links:
		for side in [l[0], l[1]]:
			if side == "space":
				continue
			sig[side] = sig.get(side, "") + "%s:%d;" % [l[1] if side == l[0] else l[0], int(l[2])]
	for n in room_names:
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


func _exit_tree() -> void:
	if job_id >= 0:
		WorkerThreadPool.wait_for_task_completion(job_id)
		job_id = -1


func _step_gas(dt: float) -> void:
	var before := {}
	for n in room_ids:
		before[n] = P(n)
	# never more than 1/240 s a substep, whatever the time warp (a warped step lets
	# a small vessel run dry inside one substep)
	var sub := maxi(4, ceili(dt * 240.0 - 0.001))
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
			if not bio.is_empty():
				_carry_bio(a, b, dn)
			vols[a].n -= dn
			if b == "space":
				gas_lost += maxf(dn, 0.0)
			else:
				vols[b].n += dn
		for gv in gas_valves:
			if not on(gv.ctrl):
				continue
			var dn2: float = float(gv.g) * (P(gv.a) - P(gv.b)) * h
			dn2 = _limit(dn2, gv.a, gv.b)
			vols[gv.a].n -= dn2
			vols[gv.b].n += dn2
		for port_id in hoses:
			var c = world.ctrls.get(port_id)
			if c == null or c.medium != "gas" or not vols.has(c.target):
				continue
			var v: String = c.target
			var k := port_rate(port_id) * pump_k()
			var hose: Dictionary = hoses[port_id]
			if hose.mode == "vent":
				k *= 3.0
			var take: float = minf(vols[v].n, k * P(v) * h)
			if bio.get(v, 0.0) > 0.0 and vols[v].n > 1e-9:
				var out: float = bio[v] * take / vols[v].n
				bio[v] -= out
				if hose.mode == "vent":
					bio_vented += out
			vols[v].n -= take
			if hose.mode == "vent":
				gas_lost += take
			else:
				gas_recovered += take
	for n in room_ids:
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


# the contamination a flow of dn (a to b; negative: b to a) carries with it
func _carry_bio(a: String, b: String, dn: float) -> void:
	var src := a if dn > 0.0 else b
	var dst := b if dn > 0.0 else a
	if src == "space" or bio.get(src, 0.0) <= 0.0 or vols[src].n <= 1e-9:
		return
	var moved: float = minf(bio[src], bio[src] * absf(dn) / vols[src].n)
	bio[src] -= moved
	if dst == "space":
		bio_vented += moved
	else:
		bio[dst] = bio.get(dst, 0.0) + moved


# how contaminated a room's air is (1 = an isolation room as its patient left it)
func bio_index(room: String) -> float:
	if not vols.has(room) or vols[room].V <= 0.0:
		return 0.0
	return bio.get(room, 0.0) / vols[room].V


# something spilt into a room's air
func bio_add(room: String, index: float) -> void:
	if vols.has(room):
		bio[room] = bio.get(room, 0.0) + index * vols[room].V


# the high-flow recovery pump draws gas and fluid twice as fast
func pump_k() -> float:
	return 2.0 if game != null and game.has_upgrade("pump2") else 1.0


# how fast a gas port's hose draws (m² of the volume per second)
func port_rate(port_id: String) -> float:
	var cc := Ship.ctrl_cfg(cfg, port_id)
	if cc.has("rate"):
		return float(cc.rate)
	var c = world.ctrls.get(port_id)
	if c != null and vessel_cfg.has(c.target):
		return 0.2
	return 9.0


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


# ---------------------------------------------------------------- electric

func _piece_ok(t: String) -> bool:
	var p = world.tag(t)
	return p != null and not p.gone


func _alive(id: String) -> bool:
	var l = world.lines.get(id)
	return l != null and l.alive


# does this source hold energy and stand ready to feed (switch closed)?
func _energized(s: Dictionary) -> bool:
	if s.has("switch") and not on(s.switch):
		return false
	match s.kind:
		"gen":
			return s.running
		"battery":
			return s.charge > 0.01
		"cap":
			return s.charge > 0.02
	return false


func _feeding(s: Dictionary) -> bool:
	return _energized(s) and _alive(s.cable) and _piece_ok(s.piece)


func _step_elec(dt: float) -> void:
	var feeding := {}
	for t in src_order:
		feeding[t] = _feeding(src[t])
	bus_live = feeding.values().has(true) and _piece_ok(bus_tag)
	for t in src_order:
		var s: Dictionary = src[t]
		if s.kind == "cap" and s.has("discharge") and on(s.discharge):
			# a capacitor can only be bled while nothing else holds the bus up
			var fed := false
			for o in src_order:
				if o != t and feeding[o]:
					fed = true
			if fed:
				switch[s.discharge] = false
				var dc = world.ctrls.get(s.discharge)
				if dc != null:
					dc.state = false
				if game != null:
					game.on_discharge_refused(s.discharge)
			elif _alive(s.cable):
				s.charge = maxf(0.0, s.charge - s.charge * dt / 0.9 - dt * 0.02)
		if s.kind == "battery" and feeding[t]:
			var gen_on := false
			for o in src_order:
				if src[o].kind == "gen" and feeding[o]:
					gen_on = true
			if not gen_on:
				s.charge = maxf(0.0, s.charge - dt * float(s.get("drain", 0.0)))
	# what the bus reaches, through live cables and whole pieces
	powered = {}
	if bus_live:
		var bus = world.tag(bus_tag)
		_flood(bus.id, powered, {})
	iso_powered = {}
	for t in iso:
		var p = world.tag(t)
		if p == null or p.gone or not iso_live(t):
			continue
		var seen := {}
		_flood(p.id, seen, {})
		for id in seen:
			iso_powered[id] = iso[t].volts
	# rooms whose lamp is on
	var redraw := false
	var lamps: Dictionary = cfg.get("power", {}).get("lamps", {})
	for n in world.rooms:
		var lp = world.tag(lamps.get(n, ""))
		var lit: bool = bus_live and lp != null and powered.has(lp.id)
		if world.rooms[n].lit != lit:
			world.rooms[n].lit = lit
			redraw = true
	for n in lamps:
		if world.rooms.has(n):
			continue
		var lp2 = world.tag(lamps[n])
		var lit2: bool = bus_live and lp2 != null and powered.has(lp2.id)
		if lp2 != null and lp2.get_meta("lit", false) != lit2:
			lp2.set_meta("lit", lit2)
			redraw = true
	if redraw:
		world.light_layer.queue_redraw()
	var sig := "%s%s%s" % [bus_live, aux, powered.size()]
	for t in src_order:
		sig += "%s%d" % [src[t].running, int(src[t].charge * (20 if src[t].kind == "cap" else 50))]
	for t in src_order:
		sig += "%s%s" % [_alive(src[t].cable), on(src[t].get("switch", ""))]
	for t in iso:
		sig += "i%s" % iso_live(t)
	if sig != _elec_sig:
		_elec_sig = sig
		elec_ver += 1


# all pieces reachable from piece id through live power cables
func _flood(start: int, seen: Dictionary, _unused: Dictionary) -> void:
	var stack: Array = [start]
	seen[start] = true
	while not stack.is_empty():
		var id = stack.pop_back()
		for lid in world.lines:
			var l = world.lines[lid]
			if not l.alive or l.kind != "cable":
				continue
			var other := -1
			if l.a == id:
				other = l.b
			elif l.b == id:
				other = l.a
			if other < 0 or seen.has(other):
				continue
			var q = world.pieces.get(other)
			if q == null or q.gone:
				continue
			seen[other] = true
			stack.append(other)


func source_of_cable(l) -> String:
	for t in src_order:
		if src[t].cable == l.id:
			return t
	return ""


func line_live(l) -> bool:
	if not l.alive or l.kind != "cable":
		return false
	var st := source_of_cable(l)
	if st != "":
		return bus_live or _energized(src[st])
	if iso_powered.has(l.a) or iso_powered.has(l.b):
		return true
	return bus_live and (powered.has(l.a) or powered.has(l.b))


func line_volts(l) -> float:
	if not line_live(l):
		return 0.0
	if iso_powered.has(l.a) or iso_powered.has(l.b):
		return iso_powered.get(l.a, iso_powered.get(l.b, 0.0))
	var st := source_of_cable(l)
	if st != "" and not bus_live:
		return _local_volts(src[st])
	return bus_volts()


func _local_volts(s: Dictionary) -> float:
	match s.kind:
		"gen":
			return s.volts if s.running else 0.0
		"battery":
			return s.get("local_volts", s.volts) if s.charge > 0.01 else 0.0
		"cap":
			return s.volts * s.charge if s.charge > 0.02 else 0.0
	return 0.0


func bus_volts() -> float:
	if not bus_live:
		return 0.0
	for t in src_order:
		var s: Dictionary = src[t]
		if _feeding(s):
			return s.volts * (s.charge if s.kind == "cap" else 1.0)
	return 0.0


# Is cutting into this piece going to arc? Returns volts (0 = dead).
func piece_volts(p) -> float:
	if p.cls != "equip" or not p.intact:
		return 0.0
	if src.has(p.tag):
		return _local_volts(src[p.tag])
	if iso.has(p.tag):
		return iso[p.tag].volts if iso_live(p.tag) else 0.0
	if iso_powered.has(p.id):
		return iso_powered[p.id]
	if p.tag == bus_tag or powered.has(p.id):
		return bus_volts()
	return 0.0


# is this piece part of an electric network at all (worth a volt reading)?
func electric_piece(p) -> bool:
	if p.cls != "equip":
		return false
	if src.has(p.tag) or iso.has(p.tag) or p.tag == bus_tag:
		return true
	for l in world.lines_of(p):
		if l.kind == "cable":
			return true
	return false


# an isolated supply holds charge and its own switch (if it has one) is closed
func iso_live(tag: String) -> bool:
	var s: Dictionary = iso.get(tag, {})
	return not s.is_empty() and s.charge > 0.0 and (s.get("switch", "") == "" or on(s.switch))


func running(tag: String) -> bool:
	return src.has(tag) and src[tag].running


func any_running() -> bool:
	for t in src_order:
		if src[t].kind == "gen" and src[t].running:
			return true
	return false


func stop_source(tag: String) -> void:
	if src.has(tag):
		src[tag].running = false


func drain_source(tag: String) -> void:
	if src.has(tag):
		src[tag].charge = 0.0
		src[tag].running = false
	if iso.has(tag):
		iso[tag].charge = 0.0


func charge(tag: String) -> float:
	return src[tag].charge if src.has(tag) else 0.0


# the capacitor a discharge control bleeds
func discharge_source(ctrl_id: String) -> String:
	for t in src_order:
		if src[t].get("discharge", "") == ctrl_id:
			return t
	return ""


# ---------------------------------------------------------------- fluids

func _heat_target() -> float:
	return float(heat.hot) if running(heat.get("source", "")) else float(heat.cold)


func _step_fluids(dt: float) -> void:
	if not heat.is_empty():
		var hot := running(heat.source)
		loop_T = Pal.damp(loop_T, _heat_target(), 1.0 / float(heat.tau_on if hot else heat.tau_off), dt)
		var hp: Dictionary = heat.get("pieces", {})
		for t in hp:
			var p = world.tag(t)
			if p != null:
				p.temp = lerpf(20.0, loop_T, float(hp[t]))
		var sp = world.tag(heat.source)
		if sp != null:
			sp.temp = loop_T + (float(heat.get("source_extra", 0.0)) if hot else 0.0)
	var joins: Array = cfg.get("fluids", {}).get("joins", [])
	var joined := {}
	for jn in joins:
		var open := false
		for v in jn.valves:
			if on(v):
				open = true
		if not open:
			continue
		joined[jn.b] = jn
		var a: Dictionary = fvol[jn.a]
		var b: Dictionary = fvol[jn.b]
		match jn.mode:
			"share":
				var tot: float = a.amount + b.amount
				a.amount = tot * float(jn.share)
				b.amount = tot - a.amount
			"fill":
				var tot2: float = a.amount + b.amount
				b.amount = minf(float(jn.cap), tot2)
				a.amount = tot2 - b.amount
	# a cracked volume drips on its own
	for k in fvol:
		var v: Dictionary = fvol[k]
		if v.has("drip"):
			var drip := minf(v.amount, dt * float(v.drip))
			v.amount -= drip
			fluid_lost += drip
	for port_id in hoses:
		var c = world.ctrls.get(port_id)
		if c == null or c.medium in ["gas", "volt", ""]:
			continue
		var vk := fluid_at_port(port_id)
		if vk == "":
			continue
		var v: Dictionary = fvol[vk]
		var pump: Array = v.get("pump", [0.1, 0.005])
		var take := minf(v.amount, (float(pump[0]) * v.amount + float(pump[1])) * dt * pump_k())
		v.amount -= take
		fluid_rec[v.fluid] += take
		# a pump on the tank also draws the line it feeds through an open valve
		for jn in joins:
			if jn.a == vk and joined.has(jn.b) and jn.has("pump_through"):
				var b: Dictionary = fvol[jn.b]
				var t2 := minf(b.amount, float(jn.pump_through) * dt * pump_k())
				b.amount -= t2
				fluid_rec[b.fluid] += t2
	# leaks drain what they are attached to
	for lk in leaks:
		lk.t += dt
		var take := 0.0
		var v = fvol.get(lk.src)
		if v != null:
			take = minf(v.amount, dt * float(v.get("leak", 0.1)))
			v.amount -= take
			# a line that leaks keeps being fed through an open valve
			if joined.has(lk.src) and joined[lk.src].has("leak_through"):
				var a2: Dictionary = fvol[joined[lk.src].a]
				var t3 := minf(a2.amount, dt * float(joined[lk.src].leak_through))
				a2.amount -= t3
				take += t3
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


func fluid(id: String) -> float:
	return fvol[id].amount if fvol.has(id) else 0.0


# the fluid volume a port draws from
func fluid_at_port(port_id: String) -> String:
	for k in fvol:
		if fvol[k].get("port", "") == port_id:
			return k
	return ""


# the fluid volume a piece holds (a tank), or ""
func fluid_in_piece(p) -> String:
	for k in fvol:
		if fvol[k].get("piece", "") == p.tag and p.tag != "":
			return k
	return ""


# the fluid volume running through a pipe of this net, or ""
func fluid_of_net(net: String) -> String:
	for k in fvol:
		if net in fvol[k].get("nets", []):
			return k
	return ""


# what is left in the volume, counting the source it is fed from through an open valve
func fluid_behind(vk: String) -> float:
	var amt := fluid(vk)
	for jn in cfg.get("fluids", {}).get("joins", []):
		if jn.b == vk and jn.has("leak_through"):
			for v in jn.valves:
				if on(v) and fluid(jn.a) > 0.02:
					return maxf(amt, fluid(jn.a))
	return amt


# reading of a fluid port: amount relative to its full level
func port_level(port_id: String) -> float:
	var vk := fluid_at_port(port_id)
	if vk == "":
		return 0.0
	return fvol[vk].amount / float(fvol[vk].get("full", 1.0))


func set_fluid(id: String, amount: float) -> void:
	if fvol.has(id):
		fvol[id].amount = amount


func is_heat_port(port_id: String) -> bool:
	return port_id in heat.get("ports", [])


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

func line_fluid(l) -> float:
	var vk := fluid_of_net(l.net)
	return fluid(vk) if vk != "" else 0.0


func line_temp(l) -> float:
	if l.net in heat.get("nets", []):
		return loop_T
	return 20.0


func content_mass(p) -> float:
	if not p.intact:
		return 0.0
	var vk := fluid_in_piece(p)
	if vk == "":
		return 0.0
	return fvol[vk].amount * float(fvol[vk].get("content", 0.0))


# the gas vessel a piece is (a bottle), or ""
func tank_vol(p) -> String:
	for k in vessel_cfg:
		if vessel_cfg[k].get("piece", "") == p.tag and p.tag != "":
			return k
	return ""


# would cutting into this piece burst a pressure vessel?
func bursts(p) -> bool:
	var v := tank_vol(p)
	return v != "" and P(v) > float(vessel_cfg[v].get("burst", 200.0))


# the dead-leg vessel behind a port is cut off by its valve
func dead_leg_closed(c) -> bool:
	var vc = vessel_cfg.get(c.target)
	return vc != null and vc.has("dead_leg") and not on(vc.dead_leg)


# where a piece pays most right now (hazardous contents go to the hazard bay)
func dest_of(p) -> String:
	if p.cls != "equip":
		return "metal"
	if not p.intact:
		return "metal"
	if p.hazard in Systems.HAZARD_ONLY:
		return "hazard"
	var fv := fluid_in_piece(p)
	if fv != "" and fvol[fv].amount > float(fvol[fv].get("hazard", 0.02)):
		return "hazard"
	if bursts(p):
		return "hazard"
	if src.has(p.tag) and src[p.tag].kind == "cap" and src[p.tag].charge > 0.05:
		return "hazard"
	return "equip"


# ---------------------------------------------------------------- actions

func set_switch(id: String, state: bool) -> void:
	switch[id] = state
	for gv in gas_valves:
		if gv.ctrl == id:
			vol_ver[gv.a] = vol_ver.get(gv.a, 0) + 1
			vol_ver[gv.b] = vol_ver.get(gv.b, 0) + 1


func gas_value() -> float:
	return gas_recovered / maxf(gas0, 1.0) * float(cfg.get("gas", {}).get("value", 0.0))


func fluid_value() -> float:
	var v := 0.0
	var vals: Dictionary = cfg.get("fluids", {}).get("value", {})
	for f in fluid_rec:
		if fluid0.get(f, 0.0) > 0.0:
			v += fluid_rec[f] / fluid0[f] * float(vals.get(f, 0.0))
	return v


# ---------------------------------------------------------------- readings

func measure(key: String, kind: String, at_text: String, inst: String, extra: Dictionary = {}) -> Dictionary:
	var r := {"key": key, "kind": kind, "at": at_text, "inst": inst, "t": time, "val": 0.0, "text": "", "ver": 0, "vk": ""}
	r.merge(extra, true)
	readings[key] = r
	refresh_reading(r, true)
	if game != null and game.assist != null:
		game.assist.on_measure(key, r)
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
	match r.kind:
		"pressure":
			var v: String = r.get("vol", "")
			var pv := P(v) + (randf_range(-0.3, 0.3) if P(v) > 1.0 else 0.0)
			return [pv, "%.1f kPa(a)" % maxf(0.0, pv), vol_ver.get(v, 0), "gas"]
		"volts":
			var vv: float = r.get("volts_fn").call()
			return [vv, "%d V" % int(round(vv)), elec_ver, "elec"]
		"fluid":
			var fv: float = r.get("fluid_fn").call()
			return [fv, "%d %%" % int(round(fv * 100.0)), 0, "fluid"]
		"temp":
			var tv: float = r.get("temp_fn").call()
			return [tv, "%d °C" % int(round(tv)), 0, "temp"]
		"field":
			var fv2: float = r.get("field_fn").call()
			return [fv2, "%d mT" % int(round(fv2)), 0, "field"]
		"bio":
			var bv: float = bio_index(r.get("room", ""))
			return [bv, "%.2f" % bv, 0, "bio"]
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
		"field":
			return absf(cur[0] - r.val) > 2.0
		"bio":
			return absf(cur[0] - r.val) > maxf(0.05, absf(r.val) * 0.25)
	return false
