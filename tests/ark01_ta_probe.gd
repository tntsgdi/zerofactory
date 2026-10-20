extends SceneTree
# Why does a lower transfer airlock not vent with its hatches open? (ARK-01 debugging)

var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_ark01ta_save.json"
	SaveGame.allow_test = true
	_run()


func _process(_dt: float) -> bool:
	return finished


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	Game.contract = {}
	Game.start_ship = "ark01"
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(3)
	var s = g.sys
	for r in ["TIU", "TIL", "TPU", "TPL"]:
		var cells := 0
		var free := 0
		for i in s.GW * s.GH:
			if s.cell_owner[i] == s.room_names.find(r):
				cells += 1
		print("ROOM %s V %.2f owner-cells %d" % [r, s.vols[r].V, cells])
	for t in ["HT-TIU", "HT-TIU2", "HT-TIL", "HT-TIL2"]:
		var p = g.world.tag(t)
		p.door_open = true
		p.open_t = 1.0
	s.topology_dirty = true
	await _frames(120)
	while s.job_id >= 0 or s.topology_dirty:
		await process_frame
	await _frames(10)
	for l in s.links:
		if l[0] in ["TIU", "TIL"] or l[1] in ["TIU", "TIL"]:
			print("LINK ", l.slice(0, 3))
	print("P TIU %.1f TIL %.1f INDL %.1f L7 %.1f INDU %.1f" % [s.P("TIU"), s.P("TIL"), s.P("INDL"), s.P("L7"), s.P("INDU")])
	finished = true
