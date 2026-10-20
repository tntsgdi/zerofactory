extends SceneTree
# VALIDATE SHIP: the static checks (scripts/ship_validator.gd), then three
# dynamic ones on the real game — a save / load round trip, a minute of the
# ship left alone, and a bot walking every safe-removal procedure in the
# ship file through the game's own actions.
# tools/run_test.sh tests/validate_ship.gd --fixed-fps 60 -- <id|all> [break=pipe:<line>|ctrl:<id>|joint:<n>]
# A broken run is expected to FAIL and to name what is broken.

const Snap = preload("res://tests/snap_util.gd")
const M := 48.0
var ids: Array = []
var breaks: Array = []
var game
var bot := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
var results := {}            # ship id -> {check: [problems]}
var queue: Array = []        # pending dynamic jobs: [ship id, kind, arg]
var job: Array = []
var job_t := 0
var step_i := 0
var step_t := 0.0
var job_bad: Array = []
var job_state := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("break="):
			breaks.append(a.substr(6))
		elif a == "all":
			ids = ["gr7", "ts1", "e07a", "e07b", "e07c", "e07d"]
		else:
			ids.append(a)
	if ids.is_empty():
		ids = ["gr7", "ts1"]
	SaveGame.path = "user://zp_validate_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	for id in ids:
		var d: Dictionary = Ship.load_data(id).duplicate(true)
		for b in breaks:
			_break(d, b)
		Ship.override(id, d)
		results[id] = ShipValidator.run(d)
		results[id]["save"] = []
		results[id]["standstill"] = []
		results[id]["procedures"] = []
		queue.append([id, "save", ""])
		queue.append([id, "standstill", ""])
		for k in d.get("procedures", {}):
			queue.append([id, "proc", k])


# break the data on purpose, the way a careless edit would
func _break(d: Dictionary, b: String) -> void:
	var kind := b.split(":")[0]
	var what := b.substr(kind.length() + 1)
	match kind:
		"pipe":
			for l in d.lines:
				if l.id == what:
					l.b = "NO-SUCH-PIECE"
		"ctrl":
			d.ctrls = d.ctrls.filter(func(c): return c.id != what)
		"joint":
			d.joints.remove_at(int(what))
	print("broken on purpose: ", b)


func _spawn(id: String, load_it: bool) -> void:
	if game != null:
		game.queue_free()
	SaveGame.load_requested = load_it
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	scene.ship_id = id
	root.add_child(scene)
	game = scene
	Engine.time_scale = 1.0


func _process(_dt: float) -> bool:
	if job.is_empty():
		if queue.is_empty():
			_report()
			return true
		job = queue.pop_front()
		job_t = 0
		step_i = 0
		step_t = 0.0
		job_bad = []
		job_state = {}
		_spawn(job[0], false)
		return false
	job_t += 1
	var done := false
	match job[1]:
		"save":
			done = _job_save()
		"standstill":
			done = _job_standstill()
		"proc":
			done = _job_proc()
	if done:
		var key: String = "procedures" if job[1] == "proc" else job[1]
		for b in job_bad:
			results[job[0]][key].append(("%s: " % job[2] if job[2] != "" else "") + b)
		job = []
		Engine.time_scale = 1.0
	return false


# ---------------------------------------------------------------- save round trip

func _job_save() -> bool:
	if job_t == 30:
		SaveGame.save(game)
		var before := Snap.snap(game)
		_spawn(job[0], true)
		var after := Snap.snap(game)
		job_bad.append_array(Snap.diff(before, after))
		if game.ship_id != job[0]:
			job_bad.append("loaded as ship %s" % game.ship_id)
		for ext in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.path + ext))
		return true
	return false


# ---------------------------------------------------------------- left alone

func _job_standstill() -> bool:
	var s = game.sys
	if job_t == 2:
		job_state.p = {}
		for n in game.world.rooms:
			job_state.p[n] = s.P(n)
		job_state.bus = s.bus_live
		job_state.pieces = game.world.pieces.size()
	if job_t == 2 + 60 * 20:
		var w = game.world
		if not w.bodies.is_empty():
			job_bad.append("%d pieces broke loose on their own" % w.bodies.size())
		for n in w.rooms:
			var p0: float = job_state.p[n]
			if p0 > 1.0 and absf(s.P(n) - p0) > p0 * 0.02:
				job_bad.append("room %s went from %.1f to %.1f kPa untouched" % [n, p0, s.P(n)])
		if s.bus_live != job_state.bus:
			job_bad.append("the bus changed state untouched")
		if not game.incidents.is_empty():
			job_bad.append("incidents with nobody touching it: %s" % str(game.incidents))
		if w.pieces.size() != job_state.pieces:
			job_bad.append("pieces changed untouched")
		return true
	return false


# ---------------------------------------------------------------- safe-removal procedures

func _ctrl_target(id: String) -> Dictionary:
	var c = game.world.ctrls.get(id)
	if c == null:
		return {}
	return {"kind": "ctrl", "ctrl": c, "pos": game.world.ctrl_world(c)}


func _cond_ok(until: Dictionary) -> bool:
	var s = game.sys
	for k in until:
		var a: Array = until[k]
		var v := 0.0
		var op: String
		var lim
		match k:
			"P":
				v = s.P(a[0])
				op = a[1]
				lim = a[2]
			"charge":
				v = s.charge(a[0])
				op = a[1]
				lim = a[2]
			"fluid":
				v = s.fluid(a[0])
				op = a[1]
				lim = a[2]
			"T":
				v = s.loop_T
				op = a[0]
				lim = a[1]
			"stage":
				v = game.dilution.stage_temp(a[0]) if game.dilution != null else 0.0
				op = a[1]
				lim = a[2]
			"zone":
				v = game.thermal.zone_temp(a[0]) if game.thermal != null else 0.0
				op = a[1]
				lim = a[2]
			"mod":
				# a module's own reading: [module, its method, op, limit]
				var m = game.get(str(a[0]))
				v = float(m.call(str(a[1]))) if m != null else 0.0
				op = a[2]
				lim = a[3]
			"open":
				if game.world.room_hidden(a[0]):
					return false
				continue
		if (op == "<" and v >= lim) or (op == ">" and v <= lim):
			return false
	return true


func _job_proc() -> bool:
	if job_t < 3:
		return false
	var steps: Array = game.ship.procedures[job[2]]
	if step_i >= steps.size():
		# the procedure is over: nothing may have gone wrong on the way
		if not game.incidents.is_empty():
			job_bad.append("incidents on the safe path: %s" % str(game.incidents))
		if game.losses > 0.0:
			job_bad.append("losses on the safe path: $%d" % int(game.losses))
		return true
	var st: Dictionary = steps[step_i]
	var label := "step %d %s" % [step_i + 1, st.do]
	step_t += 1.0 / 60.0 * Engine.time_scale
	var w = game.world
	match st.do:
		"measure", "operate", "hose":
			var tg := _ctrl_target(st.ctrl)
			if tg.is_empty():
				job_bad.append("%s: no control %s" % [label, st.ctrl])
				return true
			if w.room_hidden(tg.ctrl.hidden_room):
				job_bad.append("%s: %s is still hidden in room %s" % [label, st.ctrl, tg.ctrl.hidden_room])
				return true
			match st.do:
				"measure":
					game.do_measure(tg)
					if st.has("expect"):
						var r: Dictionary = game.sys.readings[st.ctrl]
						var ok: bool = r.val < st.expect[1] if st.expect[0] == "<" else r.val > st.expect[1]
						if not ok:
							job_bad.append("%s: %s reads %s, expected %s %s" % [label, st.ctrl, r.text, st.expect[0], st.expect[1]])
				"operate":
					game.do_wrench(tg)
				"hose":
					game.do_hose(tg)
			_next()
		"wait":
			Engine.time_scale = 4.0
			# a room opens once the gas grid's worker has redone the topology: that runs in
			# real time, so its wait doesn't count against the step while it is pending
			# (else a busy machine fails a correct procedure)
			if st.until.has("open") and (game.sys.job_id >= 0 or game.sys.topology_dirty):
				step_t -= 1.0 / 60.0 * Engine.time_scale
			if _cond_ok(st.until):
				_next()
			elif step_t > float(st.get("max", 60.0)):
				job_bad.append("%s: %s not reached after %d s" % [label, str(st.until), int(st.max)])
				return true
		"cut":
			var at := Vector2(st.at[0], st.at[1]) * M
			var p = w.piece_at(at)
			if p == null:
				job_bad.append("%s: nothing to cut at %s" % [label, str(st.at)])
				return true
			var pl := PackedVector2Array()
			for q in st.kerf:
				pl.append(Vector2(q[0], q[1]) * M)
			game.on_kerf(p, w.commit_cut(p, pl))
			_next()
		"free":
			Engine.time_scale = 1.0
			var p = w.tag(st.piece)
			if p == null or p.gone:
				job_bad.append("%s: %s is gone" % [label, st.piece])
				return true
			if p.body != null:
				_next()
				return false
			if step_t > 1.5:
				var left := []
				for j in w.joints_of(p):
					left.append(j.type)
				for l in w.lines_of(p):
					left.append(l.id)
				job_bad.append("%s: %s will not come free (still held by %s)" % [label, st.piece, ", ".join(left)])
				return true
			# undo one fixing per frame, the way the wrench would
			for j in w.joints_of(p):
				if j.type in ["bolt", "lock", "clamp"]:
					game.do_wrench({"kind": "joint", "joint": j, "pos": w.joint_world(j)})
					return false
				job_bad.append("%s: %s is welded (%s) — a safe path must not need the laser here" % [label, st.piece, j.type])
				return true
			for l in w.lines_of(p):
				var end := 0 if l.a == p.id else 1
				game.do_wrench({"kind": "connector", "line": l, "end": end, "pos": w.line_end_world(l, end)})
				if l.alive:
					job_bad.append("%s: connector %s refused (%s)" % [label, l.id, str(game.messages.back()[0]) if not game.messages.is_empty() else "?"])
					return true
				return false
		"deliver":
			Engine.time_scale = 1.0
			if not job_state.has("piece_" + st.piece):
				job_state["piece_" + st.piece] = w.tag(st.piece)
			var p = job_state["piece_" + st.piece]
			if p == null:
				job_bad.append("%s: %s is missing" % [label, st.piece])
				return true
			if p.gone:
				# it went in: check where, and that it went in whole
				var hit := false
				for l in game.ledger:
					if l[1] == st.zone and (l[0].find(st.piece) >= 0 or st.zone == "metal"):
						hit = true
				if not hit:
					job_bad.append("%s: %s did not arrive in the %s mouth" % [label, st.piece, st.zone])
				if st.zone == "equip" and not job_state.get("intact_" + st.piece, false):
					job_bad.append("%s: %s was not intact" % [label, st.piece])
				_next()
				return false
			if p.body == null:
				job_bad.append("%s: %s is not free" % [label, st.piece])
				return true
			var b = p.body
			if not job_state.has("sent_" + st.piece):
				job_state["sent_" + st.piece] = true
				job_state["intact_" + st.piece] = p.intact and p.cond > 0.95
				var mouth: Vector2 = Dock.zpos(st.zone)
				b.global_position = mouth - b.global_transform.basis_xform(b.center_of_mass)
				b.linear_velocity = Vector2.ZERO
				b.angular_velocity = 0.0
				b.reset_physics_interpolation()
			elif step_t > 6.0:
				job_bad.append("%s: %s sat at the %s mouth and was not taken (%s)" % [label, st.piece, st.zone, game.messages.back()[0] if not game.messages.is_empty() else "no message"])
				return true
		_:
			job_bad.append("%s: unknown step" % label)
			return true
	return false


func _next() -> void:
	step_i += 1
	step_t = 0.0


# ---------------------------------------------------------------- report

func _report() -> void:
	var all_ok := true
	for id in ids:
		print("VALIDATE SHIP %s" % id)
		var r: Dictionary = results[id]
		var rows: Array = ShipValidator.CHECKS.duplicate()
		rows.append(["save", "存档一致", "SAVE ROUND TRIP"])
		rows.append(["standstill", "初始静置", "LEFT ALONE"])
		rows.append(["procedures", "安全路径", "SAFE PATHS"])
		var ok := true
		for c in rows:
			var bad: Array = r[c[0]]
			print("  [%s] %s %s" % ["PASS" if bad.is_empty() else "FAIL", c[1], c[2]] + ("" if bad.is_empty() else "  (%d)" % bad.size()))
			for b in bad.slice(0, 200 if OS.get_cmdline_user_args().has("full") else 8):
				print("         - ", b)
			if not bad.is_empty():
				ok = false
		print("VALIDATE SHIP %s: %s" % [id, "PASS" if ok else "FAIL"])
		all_ok = all_ok and ok
	print("VALIDATE %s" % ("PASS" if all_ok else "FAIL"))
