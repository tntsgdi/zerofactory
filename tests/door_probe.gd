extends SceneTree
# Debugging: a hatch opened on an emptied room - does it swing open and the room reveal?
# godot --headless --path . --fixed-fps 60 -s tests/door_probe.gd -- ship port room hatch

var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_doorprobe_save.json"
	SaveGame.allow_test = true
	_run()


func _process(_dt: float) -> bool:
	return finished


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	Game.contract = {}
	Game.start_ship = a[0]
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(3)
	var c = g.world.ctrls[a[1]]
	g.do_hose({"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)})
	var n := 0
	while g.sys.P(a[2]) > 5.0 and n < 6000:
		await _frames(10)
		n += 10
	print("PROBE P %s %.1f after %d frames" % [a[2], g.sys.P(a[2]), n])
	var hc = g.world.ctrls[a[3]]
	print("PROBE ctrl kind %s target %s bus %s" % [hc.kind, hc.target, g.sys.bus_live])
	g.do_wrench({"kind": "ctrl", "ctrl": hc, "pos": g.world.ctrl_world(hc)})
	var dp = g.world.tag(str(hc.target))
	for i in 24:
		await _frames(5)
		print("PROBE f %d job %d dirty %s open_t %.2f hidden %s" % [i * 5, g.sys.job_id, g.sys.topology_dirty, dp.open_t, g.world.room_hidden(a[2])])
	for i in 2:
		await _frames(20)
		print("PROBE t %d door_open %s open_t %.2f hidden %s links %s" % [i, dp.door_open, dp.open_t, g.world.room_hidden(a[2]), g.sys.links.filter(func(l): return l[0] == a[2] or l[1] == a[2]).map(func(l): return [l[0], l[1], int(l[2])])])
	print("PROBE msgs ", g.messages.map(func(m): return m[0]))
	finished = true
