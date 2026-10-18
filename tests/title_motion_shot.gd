extends SceneTree
# Stills of the title's motion (2026-10-18): the pointer's inspection light on
# the cargo hold, the dive into the ship half way, the cards with the pointer
# on the second one (lean and sheen), and the numbers still rolling up. The
# pointer is a stand-in (pointer_override): the real mouse is never moved.
# Slot data is made up here: a test never reads the player's saves.
# tools/run_test.sh tests/title_motion_shot.gd

const Cap = preload("res://tests/cap.gd")
var finished := false


func _initialize() -> void:
	Txt.test_zh = true
	Txt.zh = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _process(_dt: float) -> bool:
	return finished


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var title: Control = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	# over GR-7's cargo hold, a little right of the middle
	title.pointer_override = Vector2(1100, 330)
	await _frames(220)
	Cap.save(root, "res://tests/out/tm_light.png")
	print("bay under the pointer: %s" % title.bay)
	title.pointer_override = Vector2(960, 700)
	title._open_slots()
	title.slots = [
		{"company": "BERTH 07", "money": 0.0, "loan": 0.0, "done": 0, "rep": 0, "time": 640.0, "certified": false, "active": {"id": "GR-001"}},
		{"company": "Kessler & Daughters", "money": 1643532.0, "loan": 0.0, "done": 9, "rep": 9, "time": 4740.0, "certified": true, "active": {"id": "011-M-14"}},
		{},
	]
	await _frames(9)
	Cap.save(root, "res://tests/out/tm_dive.png")
	await _frames(22)
	Cap.save(root, "res://tests/out/tm_roll.png")
	title.pointer_override = title._slot_rect(1).get_center() + Vector2(120, -60)
	await _frames(60)
	Cap.save(root, "res://tests/out/tm_cards.png")
	finished = true
