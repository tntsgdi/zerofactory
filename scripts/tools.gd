class_name Tools
extends Node2D
# The five tools of R-02. Every tool works at the cursor, within 4 m of the
# drone, on what can actually be seen (never inside a room nobody has opened).
#   1 measure   2 laser   3 magnetic grapple   4 wrench   5 gas/fluid hose

const RANGE := 4.0 * 48.0          # the laser and the grapple
const REACH := {1: 6.0 * 48.0, 4: 6.0 * 48.0}   # measuring and the wrench reach further
const GRAB_MAX_T := 3.0
const EMPTY_SPEED := 2600.0
const K_TETHER := 34.0
const FMAX := 3.0 * 175.0

var game: Game
var world: World
var sys: Systems
var drone: Drone
var tool := 2
var pin_key := "-"           # what the pointer was on when a number key chose the tool
var hover := {}
var aim := Vector2.ZERO
var lmb := false
var lmb_pressed := false
var hose_mode := "recover"

# laser
var cutting := false
var front := Vector2.ZERO
var front_prev := Vector2.ZERO
var pending := {}          # piece id -> {"pl": PackedVector2Array, "anch": bool, "t": float}
var auth := {}
var blocked := {}          # {"piece": id, "t": time}
var in_material := false
var material_k := 0.0
var touched := {}          # piece id -> true (hazards fire once per stroke)
var cut_sound := 0.0

# grapple
var held_body = null
var held_piece = null
var held_local := Vector2.ZERO
var strain := 0.0
var overweight := false
var tether_target := Vector2.ZERO
var tether_force := 0.0
var crack_t := 0.0
var stroke_cuts := 0

# wrench / measure / hose actions in progress
var job := {}              # {"kind", "t", "dur", "target", "pos"}
var latched := false       # the grapple holds on while another tool is in hand
var latch_d := Vector2.ZERO
var laser_lock := {}       # piece id -> the training interlock stopped the beam here (this stroke)
var denied_slot := 0       # a locked tool was asked for (the toolbar shakes it)
var denied_t := 9.0
var t := 0.0
var add_node: Node2D


func _init() -> void:
	z_index = 9
	z_as_relative = false
	add_node = Node2D.new()
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_node.material = m
	add_node.z_index = 10
	add_node.z_as_relative = false
	add_node.draw.connect(_draw_add)
	add_child(add_node)


# how far the tool in hand reaches
func reach(n: int = -1) -> float:
	return REACH.get(tool if n < 0 else n, RANGE)


func set_tool(n: int, force: bool = false, by_key: bool = false) -> void:
	# a number key pins its tool over the context tool until the pointer moves to something else
	if by_key:
		pin_key = _context()[1]
	# the training course opens one tool at a time
	if not force and game.tutorial != null and not game.tutorial.tool_allowed(n):
		denied_slot = n
		denied_t = 0.0
		game.sfx.play("deny")
		game.say("tool_locked", drone.global_position + Vector2(0, -44))
		return
	if n == tool:
		if n == 5:
			hose_mode = "vent" if hose_mode == "recover" else "recover"
			for id in sys.hoses:
				var c = world.ctrls[id]
				if c.medium == "gas":
					sys.hoses[id].mode = hose_mode
			game.say("hose_" + hose_mode, drone.global_position)
		return
	if cutting:
		_finish_cut()
	if held_body != null or held_piece != null:
		# the grapple can keep its hold while the wrench works (and back again)
		if (n == 4 and tool == 3) or (n == 3 and tool == 4 and latched):
			latched = true
			latch_d = tether_target - drone.global_position
		else:
			release_grab(false)
	job = {}
	tool = n
	game.sfx.play("tool")


func in_range(p: Vector2) -> bool:
	return drone.alive and drone.global_position.distance_to(p) <= reach()


func clamp_range(p: Vector2) -> Vector2:
	var d := p - drone.global_position
	return drone.global_position + d.limit_length(reach())


# The context tool (design/体验打磨定案.md §5): out of the laser, the tool in
# hand follows what the pointer is on — a bolt, lock, clamp, valve, switch or
# connector takes the wrench, a pressure port the meter, a floating piece the
# grapple. Never while a job, a cut or a hold is going on, never in the
# training course (it teaches the keys), never for a bot.
const WRENCH_CTRLS := ["valve", "switch", "remote", "stop", "socket", "discharge", "door", "hatch", "jam", "degauss", "seal"]


func _context() -> Array:
	var pick := 15.0 / game.cam_zoom()
	var best := [0, "", INF]
	for h in [_near_ctrl(WRENCH_CTRLS, pick), _near_joint(pick * 0.9), _near_connector(pick * 0.9)]:
		if not h.is_empty() and h.d < best[2]:
			best = [4, "w%s%s" % [h.kind, h.get("label", "")] + str(h.pos.round()), h.d]
	var hm := _near_ctrl(["port", "test", "probe"], pick)
	if not hm.is_empty() and hm.d < best[2]:
		best = [1, "m%s" % hm.ctrl.id, hm.d]
	if best[0] == 0 and _visible(aim):
		var list: Array = world.pieces_at(aim)
		if not list.is_empty() and list[0].body != null:
			best = [3, "g%d" % list[0].id, 0.0]
	return best


func _context_step() -> void:
	if not Txt.context or game.bot != null or game.tutorial != null or tool == 2 or tool == 5:
		return
	if cutting or not job.is_empty() or held_body != null or held_piece != null or lmb:
		return
	var c := _context()
	if c[1] == pin_key:
		return
	pin_key = ""
	if c[0] != 0 and c[0] != tool:
		tool = c[0]


func step(dt: float) -> void:
	t += dt
	denied_t += dt
	if not drone.alive:
		if cutting:
			_finish_cut()
		release_grab(false)
		job = {}
		hover = {}
		queue_redraw()
		add_node.queue_redraw()
		return
	# a tool the training course has not opened yet does nothing
	if game.tutorial != null and not game.tutorial.tool_allowed(tool):
		hover = {}
		if cutting:
			_finish_cut()
		if lmb_pressed:
			denied_slot = tool
			denied_t = 0.0
			game.sfx.play("deny")
		queue_redraw()
		add_node.queue_redraw()
		return
	_context_step()
	hover = _find_hover()
	match tool:
		2:
			_laser(dt)
		3:
			_grab_input()
		_:
			if lmb_pressed and hover.get("ok", false) and job.is_empty():
				_start_job()
	_step_job(dt)
	queue_redraw()
	add_node.queue_redraw()


# ---------------------------------------------------------------- targeting

func _visible(p: Vector2) -> bool:
	return not world.hidden(p)


func _ctrl_blocked(c) -> String:
	if world.room_hidden(c.hidden_room):
		return "hidden"
	var guard: String = Ship.ctrl_cfg(game.ship, c.id).get("blocked_by", "")
	if guard != "":
		var g = world.tag(guard)
		if g != null and g.body == null:
			return "blocked_guard"
	return ""


func _find_hover() -> Dictionary:
	var h := {}
	var pick := 15.0 / game.cam_zoom()
	match tool:
		1:
			h = _near_ctrl(["port", "test", "discharge", "probe"], pick)
			if h.is_empty():
				h = _near_line(pick * 0.6)
			if h.is_empty():
				h = _piece_hover()
				if not h.is_empty():
					h.kind = "inspect"
		3:
			h = _piece_hover()
		4:
			h = _near_ctrl(WRENCH_CTRLS, pick)
			var hj := _near_joint(pick * 0.9)
			if not hj.is_empty() and (h.is_empty() or hj.d < h.d):
				h = hj
			var hc := _near_connector(pick * 0.9)
			if not hc.is_empty() and (h.is_empty() or hc.d < h.d):
				h = hc
		5:
			h = _near_ctrl(["port"], pick * 1.2)
			if not h.is_empty() and h.ctrl.medium == "volt":
				h = {}
		2:
			return {}
	if h.is_empty():
		return h
	h.ok = true
	h.reason = ""
	if not _visible(h.pos) and h.kind != "inspect":
		h.ok = false
		h.reason = "hidden"
	elif not in_range(h.pos):
		h.ok = false
		h.reason = "range"
	elif h.has("ctrl"):
		var b := _ctrl_blocked(h.ctrl)
		if b != "":
			h.ok = false
			h.reason = b
	elif h.has("piece") and h.piece.hidden_by >= 0:
		var cov = world.pieces.get(h.piece.hidden_by)
		if cov != null and not cov.gone and cov.body == null:
			h.ok = false
			h.reason = "covered"
	return h


func _near_ctrl(kinds: Array, pick: float) -> Dictionary:
	var best := {}
	var bd := pick
	for id in world.ctrls:
		var c = world.ctrls[id]
		if not c.kind in kinds or not world.ctrl_alive(c):
			continue
		if world.room_hidden(c.hidden_room):
			continue
		var p: Vector2 = world.ctrl_world(c)
		var d := p.distance_to(aim)
		if d < bd:
			bd = d
			best = {"kind": "ctrl", "ctrl": c, "pos": p, "d": d, "label": c.id}
	return best


func _near_joint(pick: float) -> Dictionary:
	var best := {}
	var bd := pick
	for j in world.joints:
		if not j.alive or not j.type in ["bolt", "lock", "clamp"]:
			continue
		var p: Vector2 = world.joint_world(j)
		var d := p.distance_to(aim)
		if d < bd:
			var pa = world.pieces.get(j.a)
			if pa != null and pa.body == null and world.room_hidden(pa.room):
				continue
			if world.joint_covered(j):
				continue
			bd = d
			best = {"kind": "joint", "joint": j, "pos": p, "d": d, "label": j.get_meta("tag", "")}
	return best


func _near_connector(pick: float) -> Dictionary:
	var best := {}
	var bd := pick
	for id in world.lines:
		var l = world.lines[id]
		if not l.alive:
			continue
		for end in 2:
			var p: Vector2 = world.line_end_world(l, end)
			var d := p.distance_to(aim)
			if d < bd and _visible(p):
				bd = d
				best = {"kind": "connector", "line": l, "end": end, "pos": p, "d": d, "label": l.id.to_upper()}
	return best


func _near_line(pick: float) -> Dictionary:
	var best := {}
	var bd := pick
	for id in world.lines:
		var l = world.lines[id]
		if not l.alive:
			continue
		var path: PackedVector2Array = world.line_path_world(l)
		var d := Geom.dist_to_polyline(aim, path)
		if d < bd and _visible(aim):
			bd = d
			best = {"kind": "line", "line": l, "pos": aim, "d": d, "label": l.id.to_upper()}
	return best


func _piece_hover() -> Dictionary:
	if not _visible(aim):
		return {}
	var list: Array = world.pieces_at(aim)
	if list.is_empty():
		return {}
	var p = list[0]
	return {"kind": "piece", "piece": p, "pos": aim, "d": 0.0, "label": p.tag}


# ---------------------------------------------------------------- jobs (measure / wrench / hose)

func _start_job() -> void:
	var dur := 0.4
	var kind := "wrench"
	match tool:
		1:
			kind = "measure"
			dur = 0.42
		5:
			kind = "hose"
			dur = 0.3
		4:
			kind = "wrench"
			match hover.kind:
				"joint":
					dur = {"bolt": 0.55, "lock": 0.45, "clamp": 0.95}.get(hover.joint.type, 0.5)
				"connector":
					dur = 0.4
				"ctrl":
					dur = {"switch": 0.22, "remote": 0.22, "valve": 0.5, "door": 0.25, "hatch": 0.3, "jam": 0.9, "stop": 0.35, "socket": 0.45, "discharge": 0.45}.get(hover.ctrl.kind, 0.35)
	job = {"kind": kind, "t": 0.0, "dur": dur, "target": hover.duplicate(), "pos": hover.pos}
	game.sfx.play("probe" if kind == "measure" else ("wrench" if kind == "wrench" else "hose"))


func _target_pos(tg: Dictionary) -> Vector2:
	match tg.kind:
		"ctrl": return world.ctrl_world(tg.ctrl)
		"joint": return world.joint_world(tg.joint)
		"connector": return world.line_end_world(tg.line, tg.end)
		"piece":
			if tg.has("local"):
				return world.frame(tg.piece) * tg.local
			return tg.pos
	return tg.pos


func _step_job(dt: float) -> void:
	if job.is_empty():
		return
	var tg: Dictionary = job.target
	if tg.kind == "piece" and not tg.has("local"):
		tg.local = world.frame(tg.piece).affine_inverse() * tg.pos
	job.pos = _target_pos(tg)
	if not in_range(job.pos):
		game.say("out_of_range", job.pos)
		job = {}
		return
	job.t += dt
	if job.kind == "wrench" and randf() < 0.35:
		game.fx.sparks(job.pos, Vector2.from_angle(randf() * TAU), 1, Pal.ink(0.7, 1.3), 90.0, 0.2)
	if job.t >= job.dur:
		var j := job
		job = {}
		match j.kind:
			"measure": game.do_measure(j.target)
			"wrench": game.do_wrench(j.target)
			"hose": game.do_hose(j.target)


# ---------------------------------------------------------------- laser

func _speed_at(p: Vector2) -> Array:
	# [speed, pieces under the point]
	var list: Array = world.pieces_at(p)
	if list.is_empty():
		return [EMPTY_SPEED, list]
	var s := EMPTY_SPEED
	for q in list:
		s = minf(s, q.cut_speed)
	return [s, list]


func _guarded(q) -> bool:
	return q.cls == "equip" and q.intact and not auth.has(q.id)


# the training interlock stops the beam at a piece it guards (once per lesson)
func _locked(q) -> bool:
	if game.tutorial == null:
		return false
	if laser_lock.has(q.id):
		return true
	if game.tutorial.interlock(q):
		laser_lock[q.id] = true
		return true
	return false


func _laser(dt: float) -> void:
	if not lmb:
		if cutting:
			_finish_cut()
		in_material = false
		laser_lock = {}
		return
	var desired := clamp_range(aim)
	if lmb_pressed or not cutting:
		cutting = true
		pending = {}
		touched = {}
		# a second press on the same piece confirms cutting into equipment
		if not blocked.is_empty() and t - blocked.t < 4.0:
			auth[blocked.piece] = true
			blocked = {}
		var start := desired
		if world.hidden(start):
			start = _last_visible(drone.global_position, start)
		var at: Array = _speed_at(start)
		var guard_hit := false
		for q in at[1]:
			if _locked(q):
				guard_hit = true
			elif _guarded(q):
				guard_hit = true
				blocked = {"piece": q.id, "t": t}
				game.on_laser_blocked(q, start)
		if guard_hit:
			start = _last_free(drone.global_position, start)
		front = start
		front_prev = front
		for q in _speed_at(front)[1]:
			if not _guarded(q) and not laser_lock.has(q.id):
				_kerf_point(q, front)
				if not touched.has(q.id):
					touched[q.id] = true
					game.on_cut_into(q, front)
	var budget := dt
	var moved_world := PackedVector2Array([front])
	var went := 0.0
	in_material = false
	var guard := 0
	while budget > 0.0 and guard < 400:
		guard += 1
		var to := desired - front
		var dist := to.length()
		if dist < 0.5:
			break
		var stepl := minf(3.0, dist)
		var np := front + to / dist * stepl
		if world.hidden(np):
			break
		var sa: Array = _speed_at(np)
		var stop := false
		for q in sa[1]:
			if _locked(q):
				stop = true
			elif _guarded(q):
				if blocked.is_empty() or blocked.piece != q.id:
					game.on_laser_blocked(q, np)
				blocked = {"piece": q.id, "t": t}
				stop = true
		if stop:
			break
		var cost: float = stepl / sa[0]
		if cost > budget:
			stepl *= budget / cost
			np = front + to / dist * stepl
			cost = budget
		budget -= cost
		front = np
		went += stepl
		if not sa[1].is_empty():
			in_material = true
			for q in sa[1]:
				_kerf_point(q, front)
				if not touched.has(q.id):
					touched[q.id] = true
					game.on_cut_into(q, front)
		moved_world.append(front)
	material_k = Pal.damp(material_k, 1.0 if in_material else 0.0, 18.0, dt)
	# lines the beam passed over
	if moved_world.size() >= 2:
		for hit in world.cut_lines(moved_world):
			game.on_line_cut(hit[0], hit[1])
	# commit kerfs that are anchored to an edge
	for id in pending.keys():
		var pd: Dictionary = pending[id]
		pd.t += dt
		var p = world.pieces.get(id)
		if p == null or p.gone:
			pending.erase(id)
			continue
		if pd.pl.size() >= 2 and pd.anch and pd.t >= 0.05:
			_commit(id)
	# propellant in the air + a cutting beam
	var cl = sys.cloud_at(front)
	if cl != null:
		game.on_ignite(cl, front)
	front_prev = front
	if in_material:
		_cut_fx(dt, went)


func _kerf_point(q, wp: Vector2) -> void:
	var lp: Vector2 = world.frame(q).affine_inverse() * wp - world.door_offset(q)
	if not pending.has(q.id):
		var near_edge: bool = Geom.dist_to_boundary(lp, q.poly) <= World.KERF + 1.5 or not Geometry2D.is_point_in_polygon(lp, q.poly)
		pending[q.id] = {"pl": PackedVector2Array([lp]), "anch": near_edge, "t": 0.0}
		return
	var pd: Dictionary = pending[q.id]
	var pl: PackedVector2Array = pd.pl
	if pl[pl.size() - 1].distance_to(lp) >= 1.5:
		pl.append(lp)
		pd.pl = pl
	if not pd.anch and Geom.dist_to_boundary(lp, q.poly) <= World.KERF + 1.0:
		pd.anch = true


func _commit(id: int) -> void:
	var pd: Dictionary = pending[id]
	var p = world.pieces.get(id)
	pending.erase(id)
	if p == null or p.gone:
		return
	var pl: PackedVector2Array = pd.pl
	var res: Dictionary = world.commit_cut(p, pl)
	game.on_kerf(p, res)
	stroke_cuts += 1
	# keep cutting from where the front is now, on whatever holds that point
	if not res.gone:
		var last := pl[pl.size() - 1]
		for q in [p] + res.new:
			if not q.gone and (Geometry2D.is_point_in_polygon(last, q.poly) or Geom.dist_to_boundary(last, q.poly) < 6.0):
				pending[q.id] = {"pl": PackedVector2Array([last]), "anch": true, "t": 0.0}
				break


func _finish_cut() -> void:
	cutting = false
	# one stroke that went through something is one cutting decision
	if stroke_cuts > 0 or not pending.is_empty():
		game.log_op("cut")
	stroke_cuts = 0
	for id in pending.keys():
		if pending.has(id) and pending[id].pl.size() >= 1:
			_commit(id)
	pending = {}
	auth = {}
	touched = {}
	in_material = false


func _last_visible(a: Vector2, b: Vector2) -> Vector2:
	var lo := 0.0
	var hi := 1.0
	for i in 12:
		var m := (lo + hi) * 0.5
		if world.hidden(a.lerp(b, m)):
			hi = m
		else:
			lo = m
	return a.lerp(b, lo)


func _last_free(a: Vector2, b: Vector2) -> Vector2:
	var lo := 0.0
	var hi := 1.0
	for i in 12:
		var m := (lo + hi) * 0.5
		var guarded := false
		for q in world.pieces_at(a.lerp(b, m)):
			if _guarded(q):
				guarded = true
		if guarded:
			hi = m
		else:
			lo = m
	return a.lerp(b, lo)


func _cut_fx(dt: float, went: float) -> void:
	var fx = game.fx
	var mv := (front - front_prev)
	var away := -mv.normalized() if mv.length() > 0.5 else (front - drone.global_position).normalized()
	var n := 3 + int(went * 0.2)
	fx.sparks(front, away.rotated(randf_range(-0.6, 0.6)), n, Pal.heat(1.0, 3.4), 460.0, 0.38, 0.9)
	fx.sparks(front, Vector2.from_angle(randf() * TAU), 2, Color(2.4, 2.1, 1.8, 1.0), 260.0, 0.2)
	for i in 2:
		if randf() < 0.7:
			fx.molten(front, away * randf_range(60, 200) + Vector2.from_angle(randf() * TAU) * 50.0, 2.0)
	if randf() < 0.25:
		fx.puff(front, away * 40.0, 0.7, 3.0, 12.0, Pal.ink(0.06))


# ---------------------------------------------------------------- grapple

func _grab_input() -> void:
	if latched:
		# back on the grapple after the wrench: the hold stays until the next click
		if lmb_pressed:
			latched = false
		return
	if lmb_pressed and held_body == null and held_piece == null:
		if hover.get("ok", false) and hover.kind == "piece":
			var p = hover.piece
			held_piece = p
			held_body = p.body
			held_local = world.frame(p).affine_inverse() * aim
			strain = 0.0
			game.sfx.play("grab")
			game.on_grab(p)
		elif not hover.is_empty():
			game.say(hover.reason if hover.reason != "" else "nothing", aim)
	if not lmb and (held_body != null or held_piece != null):
		release_grab(true)


func release_grab(thrown: bool) -> void:
	if held_body == null and held_piece == null:
		return
	if thrown and held_body != null and is_instance_valid(held_body) and held_body.linear_velocity.length() > 140.0:
		game.sfx.play("throw")
	elif held_body != null or held_piece != null:
		game.sfx.play("release")
	if held_body != null and is_instance_valid(held_body):
		held_body.tethered = false
		held_body.set_meta("hauled", true)
	held_body = null
	held_piece = null
	latched = false
	strain = 0.0
	overweight = false
	tether_force = 0.0


func grab_point() -> Vector2:
	if held_piece == null or held_piece.gone:
		return drone.global_position
	return world.frame(held_piece) * held_local


func physics_step(dt: float) -> void:
	if held_piece == null:
		return
	if held_piece.gone or not drone.alive:
		release_grab(false)
		return
	if held_piece.body != held_body:
		held_body = held_piece.body
	var d: Vector2 = aim - drone.global_position if not latched else latch_d
	var reach := clampf(d.length(), 1.4 * 48.0, 3.4 * 48.0)
	tether_target = drone.global_position + d.normalized() * reach
	var g := grab_point()
	if g.distance_to(drone.global_position) > RANGE * 1.35:
		game.say("tether_snap", g)
		release_grab(false)
		return
	if held_body != null and is_instance_valid(held_body):
		held_body.tethered = true
		var m: float = held_body.total_mass()
		overweight = m > game.grab_max() + 0.001
		if overweight:
			strain = minf(1.0, strain + dt * 2.0)
			tether_force = 1.0
			return
		strain = maxf(0.0, strain - dt * 2.0)
		# hauling on a cracked piece of structure: the crack gives way
		if tether_force > 0.25:
			crack_t += dt
			if crack_t > 0.5:
				crack_t = 0.0
				for j in world.joints:
					if j.alive and j.type == "crack" and held_body.pieces.any(func(q): return q.id == j.a or q.id == j.b):
						game.on_snap(j)
						break
		var r: Vector2 = g - held_body.global_transform * held_body.center_of_mass
		var vg: Vector2 = held_body.linear_velocity + Vector2(-r.y, r.x) * held_body.angular_velocity
		var c := 2.0 * 0.85 * sqrt(K_TETHER * m)
		var f: Vector2 = (tether_target - g) * K_TETHER - (vg - drone.linear_velocity) * c
		f = f.limit_length(FMAX)
		tether_force = f.length() / FMAX
		held_body.apply_force(f, g - held_body.global_position)
		drone.external -= f.limit_length(Drone.ACCEL * drone.mass * 0.7)
	else:
		# still fixed to the ship: the beam pulls, the fixings decide
		var m2: float = world.group_mass(held_piece)
		overweight = m2 > game.grab_max() + 0.001
		var pull := clampf((tether_target - g).length() / (1.2 * 48.0), 0.0, 1.0)
		tether_force = pull
		var fixed := 0
		var weak: Array = []
		for j in world.joints_of(held_piece):
			if j.type in ["bolt", "weld", "clamp", "seam", "crack"]:
				fixed += 1
			else:
				weak.append(j)
		var lines_held: Array = world.lines_of(held_piece)
		drone.external -= (tether_target - g).normalized() * FMAX * 0.35 * pull
		if overweight or fixed > 0:
			strain = minf(1.0, strain + dt * 1.5 * pull)
			return
		strain += dt * pull / 1.3
		if strain >= 1.0:
			strain = 0.0
			game.on_tear(held_piece, weak, lines_held, g)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if not drone.alive:
		return
	var z: float = game.cam_zoom()
	var lw := 1.3 / z
	# the reach of the tools, faint, brighter when something is out of reach
	var out: bool = (not hover.is_empty() and hover.get("reason", "") == "range") or (tool == 2 and lmb and aim.distance_to(drone.global_position) > reach())
	var ra := 0.16 if out else 0.05
	_dashed_circle(drone.global_position, reach(), Pal.ink(ra), lw)
	# hover target
	if not hover.is_empty() and hover.kind != "piece" and hover.kind != "inspect":
		var c := Pal.ink(0.9) if hover.ok else Pal.ink(0.35)
		var rr := 9.0 / z + 2.0 * sin(t * 6.0) / z
		draw_arc(hover.pos, rr, 0.0, TAU, 24, c, lw * 1.2, true)
		draw_arc(hover.pos, rr + 5.0 / z, -0.6 + t * 2.0, 0.6 + t * 2.0, 10, c, lw, true)
	elif not hover.is_empty() and (hover.kind == "piece" or hover.kind == "inspect"):
		var poly: PackedVector2Array = world.world_poly(hover.piece)
		var cl := poly.duplicate()
		cl.append(poly[0])
		draw_polyline(cl, Pal.ink(0.75 if hover.ok else 0.3), lw * 1.6, true)
	# job progress
	if not job.is_empty():
		var k: float = job.t / job.dur
		var pp: Vector2 = job.pos
		draw_arc(pp, 14.0 / z, -PI / 2, -PI / 2 + TAU * k, 30, Pal.ink(0.95), 2.4 / z, true)
		if job.kind == "wrench":
			for i in 6:
				var a := t * 9.0 + TAU * i / 6.0
				draw_line(pp + Vector2.from_angle(a) * 5.0 / z, pp + Vector2.from_angle(a) * 9.0 / z, Pal.ink(0.8), 1.6 / z)
		elif job.kind == "measure":
			var from := drone.muzzle()
			var tip := from.lerp(pp, Pal.ease_out(k * 1.6))
			_dashed_line(from, tip, Pal.ink(0.7), lw)
			draw_circle(tip, 2.5 / z, Pal.ink(1.0))
	# cursor
	_cursor(z)
	# blocked laser hint ring
	if tool == 2 and not blocked.is_empty() and t - blocked.t < 4.0:
		var bp = world.pieces.get(blocked.piece)
		if bp != null and not bp.gone:
			var poly2: PackedVector2Array = world.world_poly(bp)
			var cl2 := poly2.duplicate()
			cl2.append(poly2[0])
			var pulse := 0.5 + 0.5 * sin(t * 10.0)
			draw_polyline(cl2, Pal.heat(0.5 + 0.4 * pulse, 1.3), lw * 2.0, true)


func _cursor(z: float) -> void:
	var c := aim
	var s := 1.0 / z
	var col := Pal.ink(0.9)
	match tool:
		1:
			var d := PackedVector2Array([c + Vector2(0, -7) * s, c + Vector2(7, 0) * s, c + Vector2(0, 7) * s, c + Vector2(-7, 0) * s, c + Vector2(0, -7) * s])
			draw_polyline(d, col, 1.4 * s, true)
		2:
			for a in 4:
				var dir := Vector2.from_angle(a * PI / 2.0)
				draw_line(c + dir * 5.0 * s, c + dir * 11.0 * s, col, 1.4 * s, true)
		3:
			draw_arc(c, 9.0 * s, 0.4, PI - 0.4, 14, col, 1.6 * s, true)
			draw_arc(c, 9.0 * s, PI + 0.4, TAU - 0.4, 14, col, 1.6 * s, true)
		4:
			draw_arc(c, 6.0 * s, 0.0, TAU, 16, col, 1.4 * s, true)
			for i in 6:
				var a := TAU * i / 6.0
				draw_line(c + Vector2.from_angle(a) * 6.0 * s, c + Vector2.from_angle(a) * 9.5 * s, col, 1.6 * s)
		5:
			draw_arc(c, 8.0 * s, 0.0, TAU, 20, col, 1.4 * s, true)
			draw_arc(c, 4.0 * s, 0.0, TAU, 12, col, 1.0 * s, true)


func _dashed_circle(c: Vector2, r: float, col: Color, w: float) -> void:
	var n := 72
	var segs := PackedVector2Array()
	for i in range(0, n, 2):
		var a0 := TAU * i / n + t * 0.05
		segs.append(c + Vector2.from_angle(a0) * r)
		segs.append(c + Vector2.from_angle(a0 + TAU / n) * r)
	draw_multiline(segs, col, w)


func _dashed_line(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var l := a.distance_to(b)
	var n := int(l / 8.0)
	for i in n:
		if i % 2 == 0:
			draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), col, w)


func _draw_add() -> void:
	if not drone.alive:
		return
	var tex: Texture2D = game.fx.glow_tex
	var z: float = game.cam_zoom()
	if tool == 2 and cutting:
		var m := drone.muzzle()
		var k := material_k
		var flick := 0.85 + 0.15 * sin(t * 90.0)
		add_node.draw_line(m, front, Pal.heat(0.22 + 0.25 * k, 1.5), (4.0 + 3.0 * k) * flick, true)
		add_node.draw_line(m, front, Color(2.0, 1.7, 1.4, 0.75 + 0.2 * k), 1.4, true)
		# light runs down the beam
		var bl := m.distance_to(front)
		var bd := (front - m) / maxf(bl, 1.0)
		for i in 4:
			var u := fposmod(t * 3.2 + i * 0.25, 1.0)
			var pp := m + bd * bl * u
			add_node.draw_line(pp, pp + bd * minf(18.0, bl * 0.2), Color(2.2, 1.9, 1.6, 0.8), 1.8, true)
		# the surface glows hot around the cut
		add_node.draw_texture_rect(tex, Rect2(front - Vector2(70, 70), Vector2(140, 140)), false, Pal.heat(0.22 * k, 1.8))
		var r := (16.0 + 26.0 * k) * flick
		add_node.draw_texture_rect(tex, Rect2(front - Vector2(r, r), Vector2(r, r) * 2.0), false, Pal.heat(0.6 * (0.3 + k), 2.2))
		add_node.draw_texture_rect(tex, Rect2(front - Vector2(6, 6), Vector2(12, 12)), false, Color(2.0, 1.8, 1.6, 0.9))
		add_node.draw_texture_rect(tex, Rect2(m - Vector2(10, 10), Vector2(20, 20)), false, Pal.heat(0.6, 2.0))
	# pending kerfs glow as grooves before they go through
	for id in pending:
		var p = world.pieces.get(id)
		if p == null or p.gone:
			continue
		var pl: PackedVector2Array = world.frame(p) * (pending[id].pl as PackedVector2Array)
		if pl.size() >= 2:
			add_node.draw_polyline(pl, Pal.heat(0.85, 2.4), World.KERF * 1.6, true)
	# the magnetic tether
	if held_piece != null and not held_piece.gone:
		var a := drone.muzzle()
		var b := grab_point()
		var tension: float = maxf(strain, tether_force * 0.6)
		var col := Pal.ink(0.55, 1.4).lerp(Pal.heat(0.9, 2.0), clampf(strain + (0.5 if overweight else 0.0), 0.0, 1.0))
		# the 5 t grapple pulls with five strands of beam, the stock one with three
		var strands := 5 if game.has_upgrade("grapple5") else 3
		for i in strands:
			var off := (i - (strands - 1) * 0.5) * 4.0 / z
			var nrm := (b - a).normalized().orthogonal()
			var wob := sin(t * (30.0 + i * 7.0)) * (2.0 + 6.0 * tension) / z
			var mid := (a + b) * 0.5 + nrm * (off + wob)
			var pts := PackedVector2Array()
			for s in 13:
				var u := s / 12.0
				pts.append(a.lerp(mid, u).lerp(mid.lerp(b, u), u) + nrm * off * (1.0 - absf(u - 0.5) * 2.0))
			add_node.draw_polyline(pts, Color(col.r, col.g, col.b, col.a * (0.9 - i * 0.2)), 1.4, true)
		add_node.draw_texture_rect(tex, Rect2(b - Vector2(14, 14), Vector2(28, 28)), false, Color(col.r, col.g, col.b, 0.6))
