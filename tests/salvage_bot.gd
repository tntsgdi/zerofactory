extends RefCounted
# A salvage bot for any contract on a known ship type: it reads the ship's
# own systems data (gas volumes and valves, power sources and their switches,
# fluid ports, the safe-removal procedures) and makes the ship safe through
# the game's own actions, then frees every piece (as the wrench would) and
# puts each body into the mouth it belongs to. Careless: everything into the
# furnace, nothing made safe. Used by the career, contract and money tests.

const M := 48.0
var g                      # the Game
var careless := false
var phase := "prep"
var t := 0
var phase_t := 0
var order: Array = []
var sent := {}
var done_ops := {}         # things already done once
var notes: Array = []      # what the bot did (and anything it had to force)
var forced := 0            # steps it could only do by cheating (a validator failure)
var timeout := 30000
var finished := false
var fast := 8.0            # time warp while it waits


func _init(game, opts: Dictionary = {}) -> void:
	g = game
	careless = opts.get("careless", false)


func _note(s: String) -> void:
	notes.append("[%d] %s" % [t, s])


func ctrl(id: String) -> Dictionary:
	var c = g.world.ctrls.get(id)
	if c == null or not g.world.ctrl_alive(c):
		return {}
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _hidden(id: String) -> bool:
	var c = g.world.ctrls.get(id)
	return c == null or g.world.room_hidden(c.hidden_room)


func _once(key: String) -> bool:
	if done_ops.has(key):
		return false
	done_ops[key] = true
	return true


# one frame of work; true once the contract has ended (or the bot gave up)
func step() -> bool:
	if finished:
		return true
	t += 1
	phase_t += 1
	if t < 3:
		return false
	match phase:
		"prep":
			if careless:
				_go_strip()
			else:
				_prep()
		"strip":
			_strip()
	if g.state == "ending":
		Engine.time_scale = 1.0
		finished = true
	elif t > timeout:
		_note("TIMEOUT in %s" % phase)
		Engine.time_scale = 1.0
		finished = true
	return finished


# ---------------------------------------------------------------- making it safe

func _prep() -> void:
	var s = g.sys
	var w = g.world
	if phase_t % 5 != 0:
		return
	# a guard over a port comes off first (it is a fixture: its fixings undone)
	for id in g.ship.get("ctrls_cfg", {}):
		var gd: String = g.ship.ctrls_cfg[id].get("blocked_by", "")
		if gd != "" and _once("guard " + gd):
			var gp = w.tag(gd)
			if gp != null:
				for j in w.joints_of(gp):
					w.kill_joint(j)
				_note("guard %s off" % gd)
			return
	# dead legs: the valve between a test port and its room opens first
	for gv in s.gas_valves:
		if not s.on(gv.ctrl) and not _hidden(gv.ctrl) and _once("valve " + gv.ctrl):
			g.do_wrench(ctrl(gv.ctrl))
			_note("open %s" % gv.ctrl)
			return
	# every gas port on something under pressure gets a hose
	for id in w.ctrls:
		var c = w.ctrls[id]
		if c.kind != "port" or s.hoses.has(id) or _hidden(id) or done_ops.has("hose " + id):
			continue
		if not w.ctrl_alive(c) or g.tools._ctrl_blocked(c) != "":
			continue
		var want := false
		if c.medium == "gas":
			want = s.P(c.target) > (1.0 if w.rooms.has(c.target) or s.vessel_cfg.get(c.target, {}).has("dead_leg") else 40.0)
		elif c.medium != "volt":
			var vk: String = s.fluid_at_port(id)
			want = vk != "" and s.fluid(vk) > 0.015
		if want:
			done_ops["hose " + id] = true
			g.do_hose(ctrl(id))
			_note("hose %s" % id)
			return
	# power: open every source switch, send remote stops, then bleed capacitors
	for tg in s.src_order:
		var src: Dictionary = s.src[tg]
		if src.has("switch") and s.on(src.switch) and not _hidden(src.switch) and _once("sw " + src.switch):
			g.do_wrench(ctrl(src.switch))
			_note("switch %s off" % src.switch)
			return
		if src.has("remote") and src.running and not _hidden(src.remote) and _once("remote " + src.remote):
			g.do_wrench(ctrl(src.remote))
			_note("remote stop %s" % src.remote)
			return
	for tg in s.iso:
		var sw: String = s.iso[tg].get("switch", "")
		if sw != "" and s.on(sw) and not _hidden(sw) and _once("iso " + sw):
			g.do_wrench(ctrl(sw))
			_note("own supply %s off" % sw)
			return
	var fed := false
	for tg in s.src_order:
		if s.src[tg].kind != "cap" and s._feeding(s.src[tg]):
			fed = true
	for tg in s.src_order:
		var src: Dictionary = s.src[tg]
		if src.kind == "cap" and src.has("discharge") and src.charge > 0.02 and not fed and not s.on(src.discharge) and not _hidden(src.discharge):
			g.do_wrench(ctrl(src.discharge))
			_note("discharge %s" % src.discharge)
			return
	# a generator that ignored its remote stop: open its room and use the local handle
	for tg in s.src_order:
		var src: Dictionary = s.src[tg]
		if src.kind != "gen" or not src.running or not src.has("local"):
			continue
		var lc = w.ctrls.get(src.local)
		if lc == null:
			continue
		if w.room_hidden(lc.hidden_room):
			if s.P(lc.hidden_room) < 5.0 and _once("open " + lc.hidden_room):
				_open_room(lc.hidden_room, src.local)
			return
		if _once("local " + src.local):
			g.do_wrench(ctrl(src.local))
			_note("local stop %s" % src.local)
			return
	# a room with things inside that need their own hose opens once it is empty
	for id in w.ctrls:
		var c = w.ctrls[id]
		if c.kind == "port" and c.hidden_room != "" and w.room_hidden(c.hidden_room) and not s.hoses.has(id):
			if s.P(c.hidden_room) < 5.0 and _once("open " + c.hidden_room):
				_open_room(c.hidden_room, "")
				return
	Engine.time_scale = fast
	if _safe() or phase_t > 60 * 60 * 6:
		if not _safe():
			_note("prep gave up: %s" % _unsafe())
			forced += 1
		Engine.time_scale = 1.0
		_note("safe at t=%.1f s sim" % s.time)
		_go_strip()


# opens a room the way the ship's procedure does it (its cuts), or by force
func _open_room(room: String, for_ctrl: String) -> void:
	var w = g.world
	for k in g.ship.get("procedures", {}):
		var steps: Array = g.ship.procedures[k]
		var cuts: Array = []
		var uses := false
		for st in steps:
			if st.do == "cut":
				cuts.append(st)
			if st.do == "wait" and st.until.has("open") and st.until.open[0] == room:
				uses = true
		if uses and not cuts.is_empty():
			for st in cuts:
				var at := Vector2(st.at[0], st.at[1]) * M
				var p = w.piece_at(at)
				if p == null:
					continue
				var pl := PackedVector2Array()
				for q in st.kerf:
					pl.append(Vector2(q[0], q[1]) * M)
				g.cut_kerf(p, pl)
			_note("cut open %s (%s)" % [room, k])
			return
	w.reveal(room, w.rooms[room].from)
	_note("opened %s" % room)


func _unsafe() -> Array:
	var s = g.sys
	var out: Array = []
	for n in g.world.rooms:
		if s.P(n) > 5.0:
			out.append("room %s %.0f kPa" % [n, s.P(n)])
	for k in s.vessel_cfg:
		if s.P(k) > 50.0 and not s.vessel_cfg[k].has("dead_leg"):
			out.append("vessel %s %.0f kPa" % [k, s.P(k)])
	for tg in s.src_order:
		var src: Dictionary = s.src[tg]
		if src.kind == "cap" and src.charge > 0.05:
			out.append("cap %s" % tg)
		if src.kind == "gen" and src.running:
			out.append("gen %s" % tg)
	for tg in s.iso:
		if s.iso[tg].get("switch", "") != "" and s.on(s.iso[tg].switch) and s.iso[tg].charge > 0.0:
			out.append("own supply %s" % tg)
	for k in s.fvol:
		if s.fvol[k].amount > 0.02:
			out.append("fluid %s %.3f" % [k, s.fvol[k].amount])
	if not s.heat.is_empty() and s.loop_T > 60.0:
		out.append("loop %.0f C" % s.loop_T)
	if s.bus_live:
		out.append("bus live")
	return out


func _safe() -> bool:
	return _unsafe().is_empty()


func _go_strip() -> void:
	var s = g.sys
	for id in s.hoses.keys():
		g.do_hose(ctrl(id))
	for n in g.world.rooms:
		g.world.reveal(n, g.world.rooms[n].from)
	var rank := {"equip": 0, "fixture": 1, "strut": 2, "rail": 3, "rib": 3, "beam": 4, "door": 5, "bulkhead": 5, "deck": 5, "hatch": 6, "hull": 6, "keel": 7}
	order = g.world.order.duplicate()
	order.sort_custom(func(a, b): return rank.get(g.world.pieces[a].kind, 5) < rank.get(g.world.pieces[b].kind, 5))
	phase = "strip"
	phase_t = 0
	Engine.time_scale = 1.0


# ---------------------------------------------------------------- taking it apart

func _strip() -> void:
	var w = g.world
	if phase_t % 6 == 0:
		for b in w.bodies:
			if not is_instance_valid(b) or b.capture != null or sent.has(b):
				continue
			var zone := zone_for(b)
			sent[b] = zone
			var mouth: Vector2 = Dock.zpos(zone)
			var com_off: Vector2 = b.global_transform.basis_xform(b.center_of_mass)
			b.global_position = mouth - com_off
			b.linear_velocity = Vector2.ZERO
			b.angular_velocity = 0.0
			b.reset_physics_interpolation()
			break
	if phase_t % 4 != 0:
		return
	while not order.is_empty():
		var id = order.pop_front()
		var p = w.pieces.get(id)
		if p == null or p.gone or p.body != null:
			continue
		for j in w.joints_of(p):
			w.kill_joint(j)
		for l in w.lines_of(p):
			w.kill_line(l)
		break
	if order.is_empty() and w.bodies.is_empty() and phase_t % 120 == 0:
		# anything left over (split off by a cut) comes away too
		for id in w.order:
			var p = w.pieces[id]
			if not p.gone and p.body == null:
				order.append(id)


func zone_for(b) -> String:
	if careless:
		return "metal"
	var hazard := false
	var equip := false
	var metal := 0.0
	var m := 0.0
	for p in b.pieces:
		m += p.mass
		var d: String = g.sys.dest_of(p)
		if d == "hazard":
			hazard = true
		elif d == "equip":
			equip = true
		else:
			metal += p.mass
	if hazard:
		return "hazard"
	if equip and metal <= m * 0.2:
		return "equip"
	return "metal"


func summary() -> Dictionary:
	return {"rate": g.recovery_rate(), "net": g.net(), "earned": g.earned(), "losses": g.losses, "grade": g.hud.grade(),
		"incidents": g.incidents.size(), "time": g.playtime, "ended": g.state == "ending", "forced": forced}
