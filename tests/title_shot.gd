extends SceneTree
# Stills of the title and its save slots (one in training, one on a contract,
# one empty, then the empty one being named). Slot data is made up here: a
# test never reads the player's saves.
# tools/run_test.sh tests/title_shot.gd -- [en]

const Cap = preload("res://tests/cap.gd")
var finished := false


func _initialize() -> void:
	Txt.test_zh = not OS.get_cmdline_user_args().has("en")
	Txt.zh = Txt.test_zh
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _process(_dt: float) -> bool:
	return finished


func _frames(n: int) -> void:
	for i in n:
		Txt.zh = Txt.test_zh
		await process_frame


func _run() -> void:
	var l := "" if Txt.zh else "_en"
	var title: Control = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	Txt.zh = Txt.test_zh
	await _frames(200)
	Cap.save(root, "res://tests/out/title%s.png" % l)
	title._open_slots()
	title.slots = [
		{"company": "BERTH 07", "money": 0.0, "loan": 0.0, "done": 0, "rep": 0, "time": 640.0, "certified": false, "active": {"id": "GR-001"}},
		{"company": "Kessler & Daughters", "money": 48210.0, "loan": 12000.0, "done": 6, "rep": 9, "time": 15780.0, "certified": true, "active": {"id": "008-GR-50"}},
		{},
	]
	await _frames(90)
	Cap.save(root, "res://tests/out/title_slots%s.png" % l)
	title._enter(2)
	title.name_edit.text = "零压回收"
	await _frames(30)
	Cap.save(root, "res://tests/out/title_naming%s.png" % l)
	finished = true
