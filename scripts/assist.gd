class_name Assist
extends Node
# The hint tiers on a real contract. All three run the same simulation; they
# only differ in what Liang says on the radio:
#   guided    a known danger in what you are about to do gets a concrete check
#   standard  only that some system is still unresolved, never how to resolve it
#   hardcore  nothing: instruments, readings and real alarms only
# Plus recall cards (guided, standard): the first time a real ship shows a
# problem the training course taught, a card says which lesson, once, and
# folds into the notes. Nothing here changes the ship or the books.

const REPEAT := 25.0          # s before the same warning may come back
const CARD_T := 3.0

var game: Game
var t := 0.0
var _scan := 0.0
var said := {}                # rule key -> time said
var cards: Array = []         # [lesson, subject key, t]
var notes: Array = []         # [lesson, subject key]
var recalled := {}
var history: Array = []       # [t, tier, kind, key]: every hint that went out (tests read it)
var _adj := {}                # piece id -> rooms beside it


func tier() -> String:
	return Txt.hint_tier


func _process(dt: float) -> void:
	if game == null or game.state != "play":
		return
	t += dt
	for c in cards:
		c[2] += dt
	var keep: Array = []
	for c in cards:
		if c[2] < CARD_T:
			keep.append(c)
		elif not notes.any(func(n): return n[1] == c[1]):
			notes.append([c[0], c[1]])
	cards = keep
	_scan += dt
	if _scan >= 0.2:
		_scan = 0.0
		_rules()


# ---------------------------------------------------------------- saying things

func _warn(key: String, guided: String, standard: String) -> void:
	var tr := tier()
	if tr == "hardcore":
		return
	if t - said.get(key, -1e9) < REPEAT:
		return
	said[key] = t
	var text := guided if tr == "guided" else standard
	if text == "":
		return
	history.append([t, tr, "warn", key])
	game.radio.say_text("as:" + key + ":" + tr, "liang", text, text, false)


func _recall(lesson: int, subject: String, line: String) -> void:
	if tier() == "hardcore" or recalled.has(subject):
		return
	# who skipped the course has no lesson to be reminded of
	if str(Career.data.get("cert_kind", Txt.cert_kind)) == "skipped":
		return
	recalled[subject] = true
	cards.append([lesson, subject, 0.0])
	history.append([t, tier(), "recall", subject])
	if line != "":
		game.radio.say_text("rc:" + subject, "liang", Txt.t(line), Txt.t(line))


func _f(key: String, args: Array = []) -> String:
	var s := Txt.t(key)
	return s % args if not args.is_empty() else s


# ---------------------------------------------------------------- what is the player about to do

func _rules() -> void:
	var tl = game.tools
	var w = game.world
	var s = game.sys
	if not game.drone.alive:
		return
	var tool: int = tl.tool
	var hv: Dictionary = tl.hover
	# the piece the action lands on
	var target = null
	var joint_target = null
	if tool == 2:
		var at: Vector2 = tl.front if tl.cutting else tl.aim
		var list: Array = w.pieces_at(at)
		if not list.is_empty() and tl.in_range(at):
			target = list[0]
	elif tool == 4 and not hv.is_empty() and hv.get("ok", false):
		match hv.kind:
			"joint":
				joint_target = hv.joint
				target = w.pieces.get(hv.joint.a)
			"connector":
				target = w.pieces.get(hv.line.a if hv.end == 0 else hv.line.b)
	# 1. a wall of a room that still holds gas
	if target != null and target.body == null and (target.barrier or joint_target != null):
		var walls: Array = [target]
		if joint_target != null and joint_target.b != Model.ANCHOR:
			var other = w.pieces.get(joint_target.b)
			if other != null and other.barrier:
				walls.append(other)
		for wall in walls:
			if not wall.barrier:
				continue
			for room in _rooms_beside(wall):
				if s.P(room) <= Systems.SAFE_KPA:
					continue
				_pressure_warning(room)
	# 2. live equipment
	if target != null and target.cls == "equip" and target.intact:
		var v: float = s.piece_volts(target)
		if hv.get("kind", "") == "connector" and hv.line.kind == "cable":
			v = maxf(v, game._cut_cable_volts(hv.line))
		if v > 30.0:
			var name: String = target.tag if target.tag != "" else Txt.piece_name(target)
			_warn("volts:" + name, _f("as_v_g", [name]), _f("as_v_s"))
	# 3. pipes that are full or hot
	if tool == 4 and hv.get("kind", "") == "connector" and hv.line.kind == "pipe":
		var l = hv.line
		var vk: String = s.fluid_of_net(l.net)
		if vk != "" and s.fluid(vk) > 0.02:
			var port: String = s.fvol[vk].get("port", "")
			_warn("full:" + l.id, _f("as_f_g", [port]) if port != "" else _f("as_f_g_np"), _f("as_f_s", [l.id.to_upper()]))
		elif s.line_temp(l) > 60.0:
			_warn("hot:" + l.id, _f("as_t_g"), _f("as_t_s"))
	# 4. pulling at something still fixed
	var hp = tl.held_piece
	if hp != null and hp.body == null and tl.strain > 0.3:
		var fixed := 0
		for j in w.joints_of(hp):
			fixed += 1
		var nl: int = w.lines_of(hp).size()
		if fixed + nl > 0:
			var nm: String = hp.tag if hp.tag != "" else Txt.piece_name(hp)
			_warn("tied:" + nm, _f("as_c_g"), _f("as_c_s", [nm]))
		_recall(2, "rc_s_tied", "rc_pull")
	# 5. something dangerous on its way into the furnace
	if hp != null and hp.body != null and is_instance_valid(hp.body):
		var near_furnace: bool = (hp.body.global_transform * hp.body.center_of_mass).distance_to(Dock.zpos("metal")) < 6.0 * Geom.M
		if near_furnace:
			for q in hp.body.pieces:
				if s.dest_of(q) == "hazard":
					var nq: String = q.tag if q.tag != "" else Txt.piece_name(q)
					_warn("haz:" + nq, _f("as_h_g", [nq]), _f("as_h_s", [nq]))
	# 6. the laser near propellant in the air
	if tool == 2 and tl.lmb:
		var at2: Vector2 = tl.front if tl.cutting else tl.aim
		for cl in s.clouds:
			if cl.pos.distance_to(at2) < cl.r + 2.0 * Geom.M:
				_warn("cloud", _f("as_cl_g"), _f("as_cl_s"))
	# 7. the first gas port (guided only): what does it actually read?
	if tool == 1 and hv.get("kind", "") == "ctrl" and hv.ctrl.kind == "port" and hv.ctrl.medium == "gas":
		if tier() == "guided" and not said.has("port"):
			said["port"] = t
			history.append([t, "guided", "warn", "port"])
			game.radio.say_text("as:port", "liang", _f("as_port_g"), _f("as_port_g"))
	# recall: the bent guard in front of a port
	if hv.get("reason", "") == "blocked_guard":
		_recall(4, "rc_s_guard", "rc_guard")
	if tl.overweight and hp != null:
		_recall(8, "rc_s_heavy", "rc_heavy")


func _pressure_warning(room: String) -> void:
	var s = game.sys
	var rname: String = game.room_name(room)
	# does the player already know this room is full?
	var known := false
	for k in s.readings:
		var r: Dictionary = s.readings[k]
		if r.kind == "pressure" and r.get("vol", "") == room and float(r.val) > Systems.SAFE_KPA and not s.stale(r):
			known = true
	var g := ""
	if known:
		g = _f("as_p_g_known", [rname, int(round(s.P(room)))])
	else:
		var direct := ""
		var leg := []
		for id in game.world.ctrls:
			var c = game.world.ctrls[id]
			if c.kind != "port" or c.medium != "gas":
				continue
			if c.target == room:
				direct = id
			for gv in s.gas_valves:
				if c.target == gv.b and gv.a == room or c.target == gv.a and gv.b == room:
					leg = [id, gv.ctrl]
		if direct != "":
			g = _f("as_p_g", [rname, direct])
		elif not leg.is_empty():
			g = _f("as_p_g_dl", [rname, leg[0], leg[1]])
		else:
			g = _f("as_p_g_none", [rname])
	_warn("p:" + room, g, _f("as_p_s"))


# rooms on either side of a wall piece (sampled just off its middle)
func _rooms_beside(p) -> Array:
	if _adj.has(p.id):
		return _adj[p.id]
	var w = game.world
	var out: Array = []
	var c: Vector2 = w.frame(p) * Geom.centroid(p.poly)
	var bb: Rect2 = Geom.bbox(p.poly)
	var reach: float = maxf(bb.size.x, bb.size.y) * 0.5 + 0.35 * Geom.M
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		for k in [0.35 * Geom.M, reach]:
			var r: String = w.room_at(c + dir * k)
			if r != "" and not r in out:
				out.append(r)
	_adj[p.id] = out
	return out


# ---------------------------------------------------------------- the game tells us things

func on_measure(key: String, r: Dictionary) -> void:
	var c = r.get("ctrl")
	if c != null and c.medium == "gas" and game.sys.dead_leg_closed(c):
		_recall(4, "rc_s_path", "rc_v02")
	if r.kind == "volts" and c != null and c.kind == "test" and float(r.val) > 30.0:
		_recall(5, "rc_s_backup", "rc_volts")
	if r.kind == "temp" and float(r.val) > 60.0:
		_recall(7, "rc_s_hot", "rc_hot")


func on_incident(kind: String) -> void:
	if kind == "blowout":
		_recall(4, "rc_s_blow", "rc_blow")


func on_reveal(room: String) -> void:
	var s = game.sys
	for v in s.vessel_cfg:
		var vc: Dictionary = s.vessel_cfg[v]
		var p = game.world.tag(vc.get("piece", ""))
		if p != null and p.room == room and s.bursts(p):
			_recall(4, "rc_s_tank", "rc_tank")
