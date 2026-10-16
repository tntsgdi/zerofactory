extends SceneTree
# Contracts on part of a ship (Variant._scope, design/体验打磨定案.md §4):
# "section" (only the aft section; outside it, taking or cutting a piece is a
# breach) and "rescue" (three named pieces, a fixed fee each, whole at the
# equipment mouth). For each, a few market draws: the validator passes it,
# the salvage bot plays it to the end and the contract closes by itself.
# Fast bot (takes everything): a section contract charges the breaches. Paced
# bot (paced): it keeps to the section, so nothing is charged.
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
	for kind in ["section", "rescue"]:
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
			var o := Market.offer(rng, career, 1, {}, kind)
			var d: Dictionary = o._ship
			o.erase("_ship")
			var v := ContractValidator.check(d)
			if not v.ok:
				for r in v.reasons:
					why[r] = why.get(r, 0) + 1
				continue
			got += 1
			var must: Array = []
			for pd in d.pieces:
				if pd.get("mandatory", false):
					must.append(pd.get("tag", ""))
			var tv: float = float(d.value.total)
			print("  %s  traps %s  value $%d (%.0f%% of a full ship)  fee $%d  must %s" % [o.id, str(o.traps), int(tv), tv / full * 100.0, int(o.fee), str(must)])
			_check(tv < full * 0.75 and tv > 0.0, "the scope is part of the ship")
			if kind == "rescue":
				var pay := 0.0
				for tg in d.scope.pay:
					pay += float(d.scope.pay[tg])
				_check(must.size() == 3 and absf(pay - tv) < 1.0, "three pieces named, each with its fee ($%d in all)" % int(pay))
				_check(float(o.fee) <= tv * 0.06, "a rescue's fee is low ($%d)" % int(o.fee))
			Game.contract = o
			SaveGame.load_requested = false
			var scene: Node = load("res://scenes/main.tscn").instantiate()
			scene.bot = BOT.duplicate()
			root.add_child(scene)
			var bot = Bot.new(scene, {"paced": paced})
			bot.timeout = 60000
			while not bot.step():
				await process_frame
			for k in 3:
				await process_frame
			var breaches := 0.0
			for ln in scene.loss_lines:
				if str(ln[0]).begins_with("loss_breach"):
					breaches += float(ln[1])
			print("    played: %s  rate %.1f%%  earned $%d  breaches $%d  net $%d  %d s on the clock  incidents %d" % [scene.state, scene.recovery_rate() * 100.0, int(scene.earned()), int(breaches), int(scene.net()), int(scene.playtime), scene.incidents.size()])
			_check(scene.state == "ending", "the contract closed by itself")
			_check(scene.all_mandatory_ok(), "what it asks for was delivered")
			_check(scene.earned() <= tv + 1.0, "nothing outside the scope was paid")
			if kind == "section":
				if paced:
					_check(breaches == 0.0, "kept to the section: no breach charged")
				else:
					_check(breaches > 0.0, "taking pieces from outside the section is charged ($%d)" % int(breaches))
			scene.queue_free()
			for k in 2:
				await process_frame
		_check(got == n, "%d of %d drawn passed the validator (%d tries; rejected %s)" % [got, n, tries, str(why)])
	print("SCOPE %s" % ("PASS" if fails == 0 else "FAIL"))
	finished = true
