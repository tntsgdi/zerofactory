extends SceneTree
# P.5 (player 2026-10-17): "the equipment mouth is too far away". The
# equipment bay runs on a ceiling rail from the start: the mouth key (M) slides
# it to over the drone, within the rail's ends; with the furnace rail bought
# the furnace mouth comes along too. A second equipment bay keeps clear of the
# first. Each contract starts with the bays back at home.
# tools/run_test.sh tests/equip_rail.gd --fixed-fps 60
const M := 48.0
const BOT := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
var done := false
var fails := 0


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _process(_dt: float) -> bool:
	return done


func frames(n: int) -> void:
	for i in n:
		await process_frame


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func press_m(g: Node) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_M
	ev.physical_keycode = KEY_M
	ev.pressed = true
	g._unhandled_input(ev)


func _run() -> void:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = BOT.duplicate()
	root.add_child(g)
	await frames(8)
	g.tutorial = null
	g.drone.alive = true
	g.drone.spawn_t = 3.0
	var home: float = Dock.zpos("equip").x / M
	check(is_equal_approx(home, 14.0), "the equipment bay starts at home (%.1f m)" % home)
	var furnace0: float = Dock.metal_x
	g.drone.global_position = Vector2(22.0, -4.0) * M
	g.drone.reset_physics_interpolation()
	press_m(g)
	await frames(150)
	var x: float = Dock.zpos("equip").x / M
	check(absf(x - 22.0) < 0.1, "M slides it to over the drone (%.1f m)" % x)
	check(is_equal_approx(Dock.metal_x, furnace0), "without the furnace rail the furnace stays put")
	# past the rail's end it stops at the end
	g.drone.global_position = Vector2(-6.0, -4.0) * M
	press_m(g)
	await frames(240)
	x = Dock.zpos("equip").x / M
	check(absf(x - Dock.EQUIP_RAIL_X0) < 0.1, "it stops at the rail's near end (%.1f m)" % x)
	# whole equipment delivered at the moved mouth is still taken
	check(g.dock.zone_state.has("equip") and Dock.nearest("equip", Vector2(Dock.EQUIP_RAIL_X0, -8.0) * M) == "equip", "the moved bay is still the one things go to")
	# a second bay keeps clear of the first
	Dock.add_port2()
	Dock.equip_x["equip2"] = 30.0
	Dock.equip_x["equip"] = 20.0
	g.dock.equip_goal = Dock.equip_x.duplicate()
	# asked for 26 m: the second bay (nearer) comes, but stops 7 m short of the first
	g.dock.move_equip(26.0)
	var gap: float = absf(g.dock.equip_goal.equip2 - g.dock.equip_goal.equip)
	check(absf(gap - Dock.EQUIP_GAP) < 0.01 and is_equal_approx(g.dock.equip_goal.equip, 20.0), "two bays stay %.0f m apart (gap %.1f m)" % [Dock.EQUIP_GAP, gap])
	Dock.ZONES.erase("equip2")
	Dock.equip_x.erase("equip2")
	g.dock.equip_goal.erase("equip2")
	# with the furnace rail bought, both come
	g.bot.kit = {"mouth_rail": 1}
	g.drone.global_position = Vector2(30.0, -4.0) * M
	press_m(g)
	await frames(300)
	check(absf(Dock.metal_x - 30.0) < 0.2 and absf(Dock.zpos("equip").x / M - minf(30.0, Dock.equip_rail_x1())) < 0.2, "with the furnace rail both mouths come (furnace %.1f m, bay %.1f m)" % [Dock.metal_x, Dock.zpos("equip").x / M])
	# a new contract puts it back home
	g.dock.set_ship(g.ship)
	check(is_equal_approx(Dock.zpos("equip").x / M, 14.0), "each contract starts with the bay at home")
	print("EQUIP_RAIL %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	done = true
