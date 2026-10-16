class_name Tutorial
extends Node
# The training course (ships/<ship>_course.json) run on top of the normal
# game. Progress is state-driven: a step is done when the world says so,
# never because time passed. Lockstep lessons open one tool at a time; goal
# lessons give one sentence and every tool. The first dangerous move of a
# lesson is stopped by the training interlock, the second is allowed to go
# wrong — and the props come back 1.5 s later. Lines queue while the player
# is busy, never repeat back to back, and expire if they wait too long.

const STUCK_1 := 20.0        # s without progress: Liang gives a direction
const STUCK_2 := 40.0        # the target flashes
const RESET_DELAY := 1.5

signal step_changed
signal finished

var game: Game
var course: Dictionary = {}
var lesson_i := 0
var step_i := 0
var flags := {}               # TUT_01_COMPLETE ... (the state markers of the course)
var step_t := 0.0
var idle_t := 0.0
var hint_level := 0
var bp_seen := false
var choice_pick := ""
var rings_done := 0
var dash_done := false
var box_t := 0.0
var assist_seen_off := false
var guard_used := {}          # lesson id -> the interlock already stopped one move
var recovered := {}           # tag -> zone it went into
var step_end_time := {}       # step id -> sim time it was completed
var reset_at := -1.0
var reset_lesson := -1
var incidents_seen := 0
var autopilot = null          # Vector2 (px) the drone flies itself to after Q
var done := false
var celebrate_t := -1.0       # the certificate stamp
var reacted := {}
var rings: Array = []         # [center px, radius px]
var long_ring: Array = []
var stop_box := Rect2()
var t := 0.0


func setup(g: Game, ship_id: String) -> void:
	game = g
	var f := FileAccess.open("res://ships/%s_course.json" % ship_id, FileAccess.READ)
	if f != null:
		course = JSON.parse_string(f.get_as_text())
	game.radio.lines = course.get("lines", {})
	for r in course.get("rings", []):
		rings.append([Vector2(r[0], r[1]) * Geom.M, float(r[2]) * Geom.M])
	var lr: Array = course.get("long_ring", [])
	if not lr.is_empty():
		long_ring = [Vector2(lr[0][0], lr[0][1]) * Geom.M, Vector2(lr[1][0], lr[1][1]) * Geom.M, float(lr[2]) * Geom.M]
	var sb: Array = course.get("stop_box", [])
	if not sb.is_empty():
		stop_box = Rect2(Vector2(sb[0], sb[1]) * Geom.M, Vector2(sb[2] - sb[0], sb[3] - sb[1]) * Geom.M)
	_enter_step()


# ---------------------------------------------------------------- course access

func lessons() -> Array:
	return course.get("lessons", [])


func lesson() -> Dictionary:
	return lessons()[lesson_i] if lesson_i < lessons().size() else {}


func step() -> Dictionary:
	var l := lesson()
	if l.is_empty() or step_i >= l.steps.size():
		return {}
	return l.steps[step_i]


func lockstep() -> bool:
	return lesson().get("mode", "goal") == "lockstep"


func tool_allowed(n: int) -> bool:
	if done:
		return true
	var st := step()
	if st.is_empty():
		return true
	# (JSON numbers arrive as floats)
	for x in st.get("tools", [1, 2, 3, 4, 5]):
		if int(x) == n:
			return true
	return false


func text(d) -> String:
	if d is Dictionary:
		return d.get("zh", "") if Txt.zh else d.get("en", "")
	return str(d)


# ---------------------------------------------------------------- radio

func say(id: String, once: bool = true) -> void:
	if id != "":
		game.radio.say(id, once)


func lines_idle() -> bool:
	return game.radio.idle()


# ---------------------------------------------------------------- frame

func _process(dt: float) -> void:
	if game == null or game.state != "play" or game.menu_open:
		return
	t += dt
	step_t += dt
	idle_t += dt
	_watch_flight(dt)
	_watch_incidents()
	_react()
	if reset_at >= 0.0 and t >= reset_at:
		reset_at = -1.0
		_reset_lesson(reset_lesson)
	if game.blueprint.on:
		bp_seen = true
	if not done:
		var st := step()
		if not st.is_empty() and _check(st.done):
			_complete_step()
		_stuck()
	if autopilot != null:
		var dp: Vector2 = game.drone.global_position
		if dp.distance_to(autopilot) < 0.4 * Geom.M or game.player_moved:
			autopilot = null


func _watch_flight(dt: float) -> void:
	var d = game.drone
	if not d.alive:
		return
	var p: Vector2 = d.global_position
	if rings_done < rings.size():
		var r: Array = rings[rings_done]
		if p.distance_to(r[0]) < r[1] * 0.75:
			game.fx.burst_ring(r[0], r[1])
			game.sfx.play("ring")
			rings_done += 1
			idle_t = 0.0
	if not dash_done and not long_ring.is_empty() and rings_done >= rings.size():
		var dist := Geom.dist_to_segment(p, long_ring[0], long_ring[1])
		if dist < long_ring[2] * 0.8 and d.dashing and p.x > lerpf(long_ring[0].x, long_ring[1].x, 0.6):
			dash_done = true
			game.fx.burst_ring((long_ring[0] + long_ring[1]) * 0.5, long_ring[2])
			game.sfx.play("ring")
			idle_t = 0.0
	if stop_box.size != Vector2.ZERO and stop_box.has_point(p) and d.linear_velocity.length() < 14.0:
		box_t += dt
	else:
		box_t = 0.0
	if not d.assist:
		assist_seen_off = true


# ---------------------------------------------------------------- predicates

func _piece(tag: String):
	return game.world.tag(tag)


# every piece that is, or was cut from, the tagged one
func _pieces_of(tag: String) -> Array:
	var out: Array = []
	for id in game.world.order:
		var p = game.world.pieces[id]
		if p.gone:
			continue
		if p.tag == tag or p.get_meta("origin", "") == tag:
			out.append(p)
	return out


func _cmp(v: float, op: String, lim: float) -> bool:
	match op:
		"<": return v < lim
		"<=": return v <= lim
		">": return v > lim
		">=": return v >= lim
	return is_equal_approx(v, lim)


func _check(pred: Dictionary) -> bool:
	var s = game.sys
	for k in pred:
		var a = pred[k]
		var ok := true
		match k:
			"all":
				for q in a:
					if not _check(q):
						ok = false
			"any":
				ok = false
				for q in a:
					if _check(q):
						ok = true
			"lines_done":
				ok = lines_idle()
			"rings":
				ok = rings_done >= int(a)
			"dash_ring":
				ok = dash_done
			"stop_box":
				ok = box_t >= 1.0
			"assist_cycle":
				ok = assist_seen_off and game.drone.assist
			"inspected":
				var p = _piece(a)
				ok = p != null and s.readings.has("P:%d" % p.id)
			"blueprint":
				ok = bp_seen
			"choice":
				ok = choice_pick != ""
			"reading":
				var r = s.readings.get(a[0])
				ok = r != null and (a.size() < 3 or _cmp(float(r.val), a[1], float(a[2])))
			"reading_after":
				var r2 = s.readings.get(a[0])
				ok = r2 != null and float(r2.t) > float(step_end_time.get(a[1], 1e9))
			"switch":
				ok = s.on(a[0]) == bool(a[1])
			"hose":
				ok = s.hoses.has(a)
			"P":
				ok = _cmp(s.P(a[0]), a[1], float(a[2]))
			"charge":
				ok = _cmp(s.charge(a[0]), a[1], float(a[2]))
			"fluid":
				ok = _cmp(s.fluid(a[0]), a[1], float(a[2]))
			"joints_left":
				var p2 = _piece(a[0])
				ok = p2 != null and _cmp(game.world.joints_of(p2).size(), a[1], float(a[2]))
			"held":
				var p3 = _piece(a)
				ok = p3 != null and game.tools.held_piece == p3
			"free":
				var p4 = _piece(a)
				ok = p4 == null or p4.body != null
			"recovered":
				ok = recovered.has(a[0]) and (a[1] == "any" or recovered[a[0]] == a[1]) and _pieces_of(a[0]).is_empty()
			"all_recovered":
				for tg in a:
					for q in _pieces_of(tg):
						# a sliver left welded to the rig goes with the rig
						if q.body != null or q.mass >= 0.15:
							ok = false
			_:
				push_warning("course: unknown predicate %s" % k)
				ok = false
		if not ok:
			return false
	return true


# ---------------------------------------------------------------- steps

func _enter_step() -> void:
	step_t = 0.0
	idle_t = 0.0
	hint_level = 0
	bp_seen = false
	choice_pick = ""
	var st := step()
	if st.is_empty():
		return
	for id in st.get("in", []):
		say(id)
	# whatever tool is in hand must be one the step allows
	var tools: Array = st.get("tools", [])
	if not tools.is_empty() and not tool_allowed(game.tools.tool):
		game.tools.set_tool(int(tools[0]), true)
	step_changed.emit()


func _complete_step() -> void:
	var st := step()
	for id in st.get("out", []):
		say(id)
	if st.has("flag"):
		flags[st.flag] = true
	step_end_time[st.id] = game.sys.time
	game.sfx.play("step_done")
	step_i += 1
	if step_i >= lesson().steps.size():
		flags[lesson().done_flag] = true
		lesson_i += 1
		step_i = 0
		if lesson_i >= lessons().size():
			_finish()
			return
	_enter_step()
	if game.state == "play":
		SaveGame.save(game)


func pick(which: String) -> void:
	var st := step()
	if not st.has("choice") or choice_pick != "":
		return
	choice_pick = which
	say(st.choice.get(which + "_line", ""))
	flags["TUT_03_CHOICE_" + which.to_upper()] = true


func choice_open() -> bool:
	return step().has("choice") and choice_pick == "" and lines_idle()


func _finish() -> void:
	done = true
	celebrate_t = 0.0
	_retract_rig()
	say(course.get("exam_offer", ""))
	finished.emit()
	Txt.certified = true
	if Txt.cert_kind != "full":
		Txt.cert_kind = "full"
	Txt.save_settings(game.testing)
	Career.certify()


# the training rig goes away once there is nothing left to learn on it
# (with whatever slivers are still welded to it)
func _retract_rig() -> void:
	for id in game.world.order.duplicate():
		var p = game.world.pieces[id]
		if not p.gone and p.body == null:
			var c: Vector2 = game.world.frame(p) * Geom.centroid(p.poly)
			game.fx.holo(c, Geom.bbox(p.poly).size.length() * 0.5)
			game.world.remove_piece(p)
	for i in game.dock.clamps.size():
		game.dock.clamp_t[i] = 1.0


# ---------------------------------------------------------------- help when stuck

func _stuck() -> void:
	if not lines_idle() or not game.hints_on:
		return
	var st := step()
	if hint_level == 0 and idle_t > STUCK_1:
		hint_level = 1
		if st.has("hint"):
			say(st.hint)
	elif hint_level == 1 and idle_t > STUCK_2:
		hint_level = 2


# Q: the third level, only on request. Lockstep: the drone flies itself to where
# the target can be seen; goal lessons only say there is still something left.
func request_hint() -> void:
	var st := step()
	if st.is_empty():
		return
	hint_level = maxi(hint_level, 2)
	flags["HINTS"] = int(flags.get("HINTS", 0)) + 1
	if lockstep() and st.has("auto"):
		autopilot = Vector2(st.auto[0], st.auto[1]) * Geom.M
	elif st.has("hint"):
		game.radio.forget(st.hint)
		say(st.hint)


func progress() -> void:
	idle_t = 0.0


# where the step wants the player to look (px), or INF
func target_pos() -> Vector2:
	var tg: Dictionary = step().get("target", {})
	var w = game.world
	if tg.has("piece"):
		var ps := _pieces_of(tg.piece)
		if not ps.is_empty():
			return w.frame(ps[0]) * Geom.centroid(ps[0].poly)
	if tg.has("ctrl"):
		var c = w.ctrls.get(tg.ctrl)
		if c != null:
			return w.ctrl_world(c)
	if tg.has("zone"):
		return Dock.zpos(tg.zone)
	if tg.has("ring"):
		var i := mini(int(tg.ring), rings.size())
		if rings_done < rings.size():
			return rings[rings_done][0]
		if not long_ring.is_empty():
			return (long_ring[0] + long_ring[1]) * 0.5
	if tg.has("box"):
		return stop_box.get_center()
	return Vector2.INF


# ---------------------------------------------------------------- interlock & resets

# Called before a wrench job or a laser touch lands. True = stopped.
func interlock(p) -> bool:
	if p == null or done:
		return false
	var g: Dictionary = lesson().get("guard", {})
	if g.is_empty() or guard_used.get(lesson().id, false):
		return false
	var hit := false
	for tg in g.get("pieces", []):
		if p.tag == tg or p.get_meta("origin", "") == tg:
			hit = true
	if not hit or g.get("until", {}).is_empty() or _check(g.until):
		return false
	guard_used[lesson().id] = true
	for id in g.get("lock", []):
		say(id)
	game.incident("interlock", p.tag)
	game.say("interlock", game.world.frame(p) * Geom.centroid(p.poly))
	game.sfx.play("deny")
	game.hud.white_flash(0.08)
	return true


func _watch_incidents() -> void:
	var inc: Array = game.incidents
	while incidents_seen < inc.size():
		var e: Array = inc[incidents_seen]
		incidents_seen += 1
		var g: Dictionary = lesson().get("guard", {})
		if e[1] in g.get("accident", []) and reset_at < 0.0:
			reset_at = t + RESET_DELAY
			reset_lesson = lesson_i
			say(g.get("say", ""), false)


func _reset_lesson(li: int) -> void:
	if li < 0 or li >= lessons().size():
		return
	var g: Dictionary = lessons()[li].get("guard", {})
	reset_props(g.get("reset", []), g.get("restore", {}))


# Rebuild these pieces (and anything cut from them) from the ship file, as they
# were at the start, with their fixings, lines and controls; then put the named
# system state back.
func reset_props(keys: Array, restore: Dictionary = {}) -> void:
	var w = game.world
	var s = game.sys
	var d: Dictionary = game.ship
	if game.tools.held_piece != null:
		game.tools.release_grab(false)
	for k in keys:
		for p in _pieces_of(k):
			w.remove_piece(p)
	var made := {}
	for pd in d.get("pieces", []):
		if pd.key in keys:
			var one: Dictionary = d.duplicate()
			one.pieces = [pd]
			one.joints = []
			one.lines = []
			one.ctrls = []
			one.rooms = []
			var by_key: Dictionary = Ship.build(w, one)
			made[pd.key] = by_key[pd.key]
	var find := func(key):
		if made.has(key):
			return made[key]
		var q = w.tag(key)
		return q if q != null and not q.gone else null
	for jd in d.get("joints", []):
		if not (jd.a in made or (jd.b != null and jd.b in made)):
			continue
		var a = find.call(jd.a)
		var b = find.call(jd.b) if jd.b != null else null
		if a == null or (jd.b != null and b == null) or a.body != null or (b != null and b.body != null):
			continue
		w.add_joint(a, b, jd.type, Vector2(jd.at[0], jd.at[1]) * Geom.M)
	for ld in d.get("lines", []):
		if not (ld.a in made or ld.b in made):
			continue
		var a2 = find.call(ld.a)
		var b2 = find.call(ld.b)
		if a2 == null or b2 == null:
			continue
		w.lines.erase(ld.id)
		w.add_line(ld.id, ld.kind, ld.net, a2, Vector2(ld.pa[0], ld.pa[1]) * Geom.M, b2, Vector2(ld.pb[0], ld.pb[1]) * Geom.M, Ship._poly(ld.path))
	for cd in d.get("ctrls", []):
		if cd.piece != null and made.has(cd.piece) and w.ctrls.has(cd.id):
			w.ctrls[cd.id].piece = made[cd.piece].id
			w.ctrls[cd.id].pos = Vector2(cd.at[0], cd.at[1]) * Geom.M
	for k in made:
		var p = made[k]
		w.rebuild_cols(p)
		game.fx.holo(Geom.centroid(p.poly), Geom.bbox(p.poly).size.length() * 0.5)
	# the openings are worked out again right now, before any gas is put back
	if not made.is_empty():
		s._compute_now()
	# whatever a rebuilt piece holds comes back with it (a tank that went
	# into the furnace was emptied there)
	var vols: Dictionary = d.get("fluids", {}).get("volumes", {})
	for fk in vols:
		if vols[fk].get("piece", "") in keys:
			s.set_fluid(fk, float(vols[fk].get("amount", 0.0)))
	# system state
	var gas: Dictionary = d.get("gas", {})
	for v in restore.get("gas", []):
		if s.vols.has(v):
			var kpa := float(gas.get("rooms", {}).get(v, gas.get("vessels", {}).get(v, {}).get("kpa", 0.0)))
			s.vols[v].n = kpa * s.vols[v].V
			s.vol_ver[v] = s.vol_ver.get(v, 0) + 1
	for cid in restore.get("ctrls", []):
		var c = w.ctrls.get(cid)
		for cd in d.get("ctrls", []):
			if cd.id == cid and c != null:
				c.state = cd.get("state", false)
				s.set_switch(cid, c.state)
	for hid in restore.get("hoses", []):
		if s.hoses.has(hid):
			s.hoses.erase(hid)
			game.dock.hose_detach(hid)
	for rid in restore.get("readings", []):
		s.readings.erase(rid)
	if restore.get("power", false):
		for sp in d.get("power", {}).get("sources", []):
			if s.src.has(sp.piece):
				s.src[sp.piece].charge = float(sp.get("charge", 1.0))
				s.src[sp.piece].running = bool(sp.get("running", false))
	w.dirty_links = true
	w.redraw_all(true)
	s.topology_dirty = true
	game.sfx.play("holo")
	# the lesson's interlock is armed again for the next try
	guard_used.erase(lessons()[reset_lesson if reset_lesson >= 0 else lesson_i].id)


# ---------------------------------------------------------------- reactions

func on_recovered(b, zone: String) -> void:
	for p in b.pieces:
		var tg: String = p.tag if p.tag != "" else p.get_meta("origin", "")
		if tg != "":
			recovered[tg] = zone
	idle_t = 0.0


func _react() -> void:
	var tl = game.tools
	var hp = tl.held_piece
	# lesson 2: the last bolt came out with nothing holding the plate
	if lesson().get("id", "") == "TUT_02" and not reacted.has("drift"):
		var p = _piece("P-001")
		if p != null and p.body != null and tl.held_piece != p:
			reacted.drift = true
			say("T02_drift")
	# lesson 5: pulling at a pump that is still connected
	if lesson().get("id", "") == "TUT_05" and hp != null and hp.tag == "CP-T" and hp.body == null and tl.strain > 0.5:
		say("T05_pull")
	if lesson().get("id", "") == "TUT_05" and not reacted.has("cut"):
		var pump = _piece("CP-T")
		if pump != null and not pump.intact:
			reacted.cut = true
			say("T05_cut")
	if lesson().get("id", "") == "TUT_05" and recovered.has("CP-T") and not reacted.has("pump_ok"):
		reacted.pump_ok = true
		if recovered["CP-T"] == "equip":
			say("T05_done_l")
	# lesson 6: the beam is too heavy for the grapple
	if lesson().get("id", "") == "TUT_06" and tl.overweight and hp != null:
		say("T06_heavy1")
		say("T06_heavy2")


# ---------------------------------------------------------------- save

func save_state() -> Dictionary:
	return {"lesson": lesson_i, "step": step_i, "flags": flags, "guard": guard_used, "recovered": recovered, "said": game.radio.said,
		"rings": rings_done, "dash": dash_done, "assist": assist_seen_off, "done": done, "ends": step_end_time}


func load_state(d: Dictionary) -> void:
	lesson_i = int(d.get("lesson", 0))
	step_i = int(d.get("step", 0))
	flags = d.get("flags", {})
	guard_used = d.get("guard", {})
	recovered = d.get("recovered", {})
	game.radio.said = d.get("said", {})
	rings_done = int(d.get("rings", 0))
	dash_done = d.get("dash", false)
	assist_seen_off = d.get("assist", false)
	done = d.get("done", false)
	step_end_time = d.get("ends", {})
	incidents_seen = game.incidents.size()
	# the lines of the step being resumed are said again
	var st := step()
	for id in st.get("in", []):
		game.radio.forget(id)
	_enter_step()
