extends SceneTree
# Developer "auto sort": free every piece (F3), switch auto sort on, and the
# loose pieces fly to their own mouths — whole equipment to the equipment bay,
# keels, decks and scrap to the furnace. Test files only.
# godot --headless --path . --fixed-fps 60 -s tests/dev_sort_check.gd

var frame := 0
var g
var dev
var fails := 0
var loose0 := 0
var dev_was := false


func _initialize() -> void:
	Txt.zh = true
	dev_was = Txt.dev
	Career.path = "user://zp_test_devsort_career.json"
	SaveGame.path = "user://zp_test_devsort_save.json"
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	Career.data = {}
	Career.start_new()
	Career.save()
	Game.contract = Career.sign_active()
	Game.start_ship = Game.contract.ship
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2(-30, -30) * 48.0, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _loose() -> Array:
	return g.world.bodies.filter(func(b): return is_instance_valid(b) and b.capture == null and not b.pieces.is_empty())


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 30:
		Txt.dev = true
		for n in g.get_children():
			if n is DevPanel:
				dev = n
		DevPanel.god = true
		dev.run(2)
		dev.run(3)
	elif frame == 40:
		loose0 = _loose().size()
		dev.run(12)
		check(DevPanel.sort_on, "auto sort on")
	elif frame > 40 and (frame % 600 == 0 or frame == 3640):
		var l := _loose()
		var ghosts := l.filter(func(b): return b.has_meta("sort_layer")).size()
		var skip := l.filter(func(b): return b.get_meta("sort_skip", false)).size()
		print("t=%ds loose %d (on the way %d, turned away %d) rate %.1f%%" % [(frame - 40) / 60, l.size(), ghosts, skip, g.recovery_rate() * 100.0])
		if frame == 3640:
			check(loose0 > 10, "F3 freed the ship (%d loose bodies)" % loose0)
			check(l.size() <= loose0 * 0.1, "nearly everything went in by itself (%d of %d left)" % [l.size(), loose0])
			dev.run(12)
			check(not DevPanel.sort_on and _loose().all(func(b): return not b.has_meta("sort_layer")), "off again: nothing left ghosted")
			Txt.dev = dev_was
			DevPanel.god = false
			print("DEVSORT %s" % ("PASS" if fails == 0 else "FAIL"))
			return true
	return false
