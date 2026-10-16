extends SceneTree
# Takes GR-7 apart through the game's own actions: measure, valves, switches,
# hoses, local stop; then frees every piece (as the wrench would) and puts each
# body into the mouth it belongs to. Prints the books; stills of the ending.
# tools/run_test.sh tests/full_run.gd --fixed-fps 60 -- [careless]

const Cap = preload("res://tests/cap.gd")
const M := 48.0
var game
var frame := 0
var phase := "prep"
var phase_t := 0
var careless := false
var bot := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
var order: Array = []
var sent := {}
var end_frame := -1
var log_lines: Array = []


func _initialize() -> void:
	careless = OS.get_cmdline_user_args().has("careless")
	root.add_child(preload("res://tests/test_window.gd").new())
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene


func c(id: String) -> Dictionary:
	var ct = game.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": ct, "pos": game.world.ctrl_world(ct)}


func wrench(id: String) -> void:
	game.do_wrench(c(id))


func say(s: String) -> void:
	print("[%5d] %s" % [frame, s])


func _prep() -> void:
	var s = game.sys
	match phase_t:
		1:
			game.do_measure(c("P-C01"))
			say("P-C01 closed valve reads %s" % s.readings["P-C01"].text)
			wrench("V-C01")
			for id in ["GAS-AB", "P-C01", "GAS-D"]:
				game.do_hose(c(id))
			wrench("K-G")
			wrench("K-B")
			wrench("G-STOP")
			game.do_measure(c("E-D01"))
			say("bus after remote stop + K-G/K-B open: %s (cap still on the bus)" % s.readings["E-D01"].text)
			wrench("E-D02")
			# off with the guard so the propellant port is reachable
			var guard = game.world.tag("GUARD-F")
			for j in game.world.joints_of(guard):
				game.world.kill_joint(j)
		5:
			game.do_measure(c("P-C01"))
			say("P-C01 after V-C01 open reads %s" % s.readings["P-C01"].text)
			game.do_hose(c("FUEL-F"))
			game.do_hose(c("COOL-E"))
			Engine.time_scale = 4.0
		_:
			if phase_t % 60 == 0:
				say("A %.1f B %.1f C %.1f D %.1f  cap %.2f fuel %.3f cool %.3f T %.0f bus %s" % [s.P("A"), s.P("B"), s.P("C"), s.P("D"), s.charge("CAP-01"), s.fluid("fuel"), s.fluid("cool"), s.loop_T, s.bus_live])
			if s.P("D") < 5.0 and not game.world.rooms["D"].revealed:
				# open D's roof with a real kerf to reach the local stop
				var roof = game.world.piece_at(Vector2(28.6, -3.8) * M, ["hull"])
				game.world.commit_cut(roof, PackedVector2Array([Vector2(28.2, -4.3) * M, Vector2(28.2, -3.4) * M]))
				game.world.commit_cut(roof, PackedVector2Array([Vector2(29.0, -4.3) * M, Vector2(29.0, -3.4) * M]))
				say("cut D roof")
			if game.world.rooms["D"].revealed and s.running("G-01"):
				wrench("G-LOCAL")
				say("G-01 local stop")
			var ok: bool = s.P("A") < 5.0 and s.P("C") < 5.0 and s.P("D") < 5.0 and s.charge("CAP-01") < 0.05 and s.fluid("fuel") < 0.02 and s.fluid("cool") < 0.02 and s.loop_T < 60.0 and not s.running("G-01")
			if ok or phase_t > 4000:
				Engine.time_scale = 1.0
				say("prep done (ok=%s) at t=%.1f s sim" % [ok, s.time])
				game.do_measure(c("E-D01"))
				say("bus now %s" % s.readings["E-D01"].text)
				for id in s.hoses.keys():
					game.do_hose(c(id))
				for tk in ["TK-B1", "TK-B2", "EM-A"]:
					game.world.reveal("B", game.world.rooms["B"].from)
					game.world.reveal("A", game.world.rooms["A"].from)
					game.do_hose(c(tk))
				phase = "tanks"
				phase_t = 0


func _tanks() -> void:
	var s = game.sys
	Engine.time_scale = 4.0
	if s.P("T1") < 50.0 and s.P("T2") < 50.0 and s.P("T3") < 50.0 or phase_t > 2400:
		Engine.time_scale = 1.0
		for tk in ["TK-B1", "TK-B2", "EM-A"]:
			game.do_hose(c(tk))
		say("bottles %.0f / %.0f kPa" % [s.P("T1"), s.P("T2")])
		for n in game.world.rooms:
			game.world.reveal(n, game.world.rooms[n].from)
		_make_order()
		phase = "strip"
		phase_t = 0


func _make_order() -> void:
	var rank := {"equip": 0, "fixture": 1, "strut": 2, "rail": 3, "rib": 3, "beam": 4, "door": 5, "bulkhead": 5, "deck": 5, "hatch": 6, "hull": 6, "keel": 7}
	order = game.world.order.duplicate()
	order.sort_custom(func(a, b): return rank.get(game.world.pieces[a].kind, 5) < rank.get(game.world.pieces[b].kind, 5))


func _strip() -> void:
	var w = game.world
	# feed waiting bodies to the mouths, one at a time
	if phase_t % 6 == 0:
		for b in w.bodies:
			if not is_instance_valid(b) or b.capture != null or sent.has(b):
				continue
			var zone := _zone_for(b)
			sent[b] = zone
			if OS.get_cmdline_user_args().has("verbose"):
				var tags := []
				for p in b.pieces:
					tags.append("%s:%s%s" % [p.kind, p.tag, "" if p.intact else "*"])
				say("send %s %.2ft %s" % [zone, b.total_mass(), tags])
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
		var p = w.pieces[id]
		if p.gone or p.body != null:
			continue
		for j in w.joints_of(p):
			w.kill_joint(j)
		for l in w.lines_of(p):
			w.kill_line(l)
		break
	if order.is_empty() and w.bodies.is_empty() and phase_t % 60 == 0:
		var left := 0
		for id in w.order:
			if not w.pieces[id].gone:
				left += 1
		say("left %d  debris %d  swallowing %d" % [left, game.dock.debris.size(), game.dock.swallowing.size()])


func _zone_for(b) -> String:
	var hazard := false
	var equip := false
	var metal := 0.0
	var m := 0.0
	for p in b.pieces:
		m += p.mass
		var d: String = game.sys.dest_of(p)
		if d == "hazard":
			hazard = true
		elif d == "equip":
			equip = true
		else:
			metal += p.mass
	if careless:
		return "metal"
	if hazard:
		return "hazard"
	if equip and metal <= m * 0.2:
		return "equip"
	return "metal"


func _process(_dt: float) -> bool:
	frame += 1
	phase_t += 1
	if frame == 3:
		game.drone.global_position = Vector2(20, -6) * M
	match phase:
		"prep": _prep()
		"tanks": _tanks()
		"strip": _strip()
	if game.state == "ending" and end_frame < 0:
		end_frame = frame
		for l in game.ledger:
			if l[2] > 300.0:
				say("  %-28s %-7s %8.0f" % [l[0], l[1], l[2]])
		say("ENDING  rate %.1f%%  equip $%d metal $%d hazard $%d gas+fluid $%d losses $%d net $%d  bb %s gen %s  grade %d" % [game.recovery_rate() * 100.0, game.income_equip, game.income_metal, game.income_hazard, game.sys.gas_value() + game.sys.fluid_value(), game.losses, game.net(), game.mandatory_ok.get("BB-01", false), game.mandatory_ok.get("G-01", false), game.hud.grade()])
	if end_frame > 0:
		var e := frame - end_frame
		if e in [60, 160, 260, 420]:
			Cap.save(root, "res://tests/out/end_%d%s.png" % [e, "_careless" if careless else ""])
		if e > 430:
			return true
	if frame > 20000:
		say("TIMEOUT phase %s" % phase)
		return true
	return false
