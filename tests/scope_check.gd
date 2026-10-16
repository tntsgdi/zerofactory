extends SceneTree
# Short contracts on part of a ship (Variant._scope): "aft", "rescue", "hold".
# For each, a few market draws: the scope's value is a fraction of the ship's,
# the validator still passes it, and the salvage bot plays it to the end —
# the contract closes by itself when the scope is in (or the hold's clock
# runs out), nothing outside the scope is paid, and it takes a fraction of a
# full contract's time.
# godot --headless --path . --fixed-fps 60 -s tests/scope_check.gd -- [n=2] [only=aft]

const Bot = preload("res://tests/salvage_bot.gd")
const BOT := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
var n := 2
var only := ""
var paced := false
var fails := 0
var finished := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("n="):
			n = int(a.substr(2))
		elif a == "paced":
			paced = true
		elif a.begins_with("only="):
			only = a.substr(5)
	SaveGame.path = "user://zp_test_scope_save.json"
	SaveGame.allow_test = true
	Career.path = "user://zp_test_scope_career.json"
	_run()


func _process(_dt: float) -> bool:
	return finished


func _check(ok: bool, what: String) -> void:
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _run() -> void:
	var full: float = float(Variant.make(Ship.load_data("gr7"), {"id": "x", "variant": 1, "traps": [], "stars": 1}).value.total)
	var career := Career.fresh()
	career.done = 3
	for kind in ["aft", "rescue", "hold"]:
		if only != "" and kind != only:
			continue
		print("SCOPE %s" % kind)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(kind)
		var got := 0
		var tries := 0
		var why := {}
		while got < n and tries < 60:
			tries += 1
			var o := Market.offer(rng, career, 1)
			o.scope = kind
			o.time = Market.SHORT_TIME[kind]
			var d := Variant.make(Ship.load_data("gr7"), o)
			o.erase("_ship")
			var v := ContractValidator.check(d)
			if not v.ok:
				for r in v.reasons:
					why[r] = why.get(r, 0) + 1
				continue
			got += 1
			var inside := 0
			var must: Array = []
			for pd in d.pieces:
				if pd.get("scope", true):
					inside += 1
				if pd.get("mandatory", false):
					must.append(pd.get("tag", ""))
			var tv: float = float(d.value.total)
			print("  %s  traps %s  %d pieces in scope  value $%d (%.0f%% of a full ship)  must %s" % [o.id, str(o.traps), inside, int(tv), tv / full * 100.0, str(must)])
			_check(tv < full * 0.75 and tv > 0.0, "scope value is part of the ship's")
			if kind != "aft":
				_check(tv <= full * 0.4, "a short job is worth about a third of a ship at most")
			if kind == "rescue":
				_check(must.size() == 3, "three pieces named, all required")
			Game.contract = o
			SaveGame.load_requested = false
			var scene: Node = load("res://scenes/main.tscn").instantiate()
			scene.bot = BOT.duplicate()
			root.add_child(scene)
			var bot = Bot.new(scene, {"paced": paced})
			bot.timeout = 60000
			var frames := 0
			while not bot.step():
				frames += 1
				await process_frame
			for k in 3:
				await process_frame
			var outside := 0
			for id in scene.world.order:
				var p = scene.world.pieces[id]
				if not p.gone and not p.scope:
					outside += 1
			print("    played: %s  rate %.1f%%  net $%d  %d s on the clock  %d pieces outside the scope left  incidents %d" % [scene.state, scene.recovery_rate() * 100.0, int(scene.net()), int(scene.playtime), outside, scene.incidents.size()])
			_check(scene.state == "ending", "the contract closed")
			_check(scene.recovery_rate() <= 1.05, "nothing outside the scope was paid")
			if kind != "hold":
				_check(scene.all_mandatory_ok(), "what it asks for was delivered")
			else:
				_check(scene.playtime <= Variant.HOLD_LIMIT + 1.0, "stopped at the time limit")
			scene.queue_free()
			for k in 2:
				await process_frame
		_check(got == n, "%d of %d drawn passed the validator (%d tries; rejected %s)" % [got, n, tries, str(why)])
	print("SCOPE %s" % ("PASS" if fails == 0 else "FAIL"))
	finished = true
