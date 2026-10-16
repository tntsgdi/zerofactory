extends SceneTree
# Leave the training course half way and come back: same lesson, same step,
# same world. tools/run_test.sh tests/tutorial_resume.gd --fixed-fps 60

const Snap = preload("res://tests/snap_util.gd")
var game
var frame := 0
var bot := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
var before := {}
var where := []


func _initialize() -> void:
	SaveGame.train_path = "user://zp_test_resume.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_spawn(false)


func _spawn(load_it: bool) -> void:
	SaveGame.load_requested = load_it
	Game.start_ship = "ts1"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 10:
		# skip ahead to lesson 3, step "valve", with the first reading taken
		var t = game.tutorial
		t.lesson_i = 3
		t.step_i = 3
		t._enter_step()
		var w = game.world
		game.do_measure({"kind": "ctrl", "ctrl": w.ctrls["PT-02"], "pos": w.ctrl_world(w.ctrls["PT-02"])})
		game.do_wrench({"kind": "ctrl", "ctrl": w.ctrls["V-02"], "pos": w.ctrl_world(w.ctrls["V-02"])})
	if frame == 20:
		SaveGame.save(game)
		before = Snap.snap(game)
		where = [game.tutorial.lesson_i, game.tutorial.step_i]
		game.queue_free()
		_spawn(true)
		var after := Snap.snap(game)
		var bad: Array = Snap.diff(before, after)
		var now := [game.tutorial.lesson_i, game.tutorial.step_i]
		print("saved at lesson %d step %d, resumed at lesson %d step %d" % [where[0], where[1], now[0], now[1]])
		print("world: %s" % ("same" if bad.is_empty() else str(bad.slice(0, 5))))
		print("RESUME %s" % ("PASS" if bad.is_empty() and now == where else "FAIL"))
		for ext in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.train_path + ext))
		return true
	return false
