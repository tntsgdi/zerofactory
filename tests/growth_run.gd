extends SceneTree
# Roadmap 2.9 acceptance: the operation log over a career. The paced bot
# (every operation and haul taking its time) plays contracts 1, 5 and 10 of
# a new career — GR-001, then the market; the ones between are played fast
# to move the career on — buying the first upgrades as funds
# allow, and every action it takes is counted as repetitive hand work or an
# engineering decision (the recovery arm's hauls are the machine's). The
# tutorial's share comes from tests/tutorial_bot.gd (run it first; it writes
# tests/out/oplog_tutorial.json). Prints the curve for the tutorial and
# contracts 1, 5 and 10; contract 10's share of repetitive work must be
# clearly (5 points or more) below contract 1's.
# godot --headless --path . --fixed-fps 60 -s tests/growth_run.gd -- [n=10]

const Bot = preload("res://tests/salvage_bot.gd")
const BOT := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
const UPGRADES := [["arm", 65000.0], ["grapple5", 38000.0], ["pump2", 22000.0], ["scan_kit", 24000.0]]
const RESERVE := 30000.0
# DECISIONS.md, growth targets: share of repetitive hand work
const TARGET := {"tutorial": 0.85, "early": 0.75, "middle": 0.5, "late": 0.3, "end": 0.2}
var n := 10
var fails := 0
var finished := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("n="):
			n = int(a.substr(2))
	Career.path = "user://zp_test_growth_career.json"
	SaveGame.path = "user://zp_test_growth_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	_run()


func _process(_dt: float) -> bool:
	return finished


func _run() -> void:
	Career.data = {}
	Career.start_new()
	var shares: Array = []
	for i in n:
		if i > 0 and Career.active().is_empty():
			# the contracts the careful player takes: the safest offer that pays best
			Career.ensure_offers(Market.make)
			var best := 0
			for k in Career.data.offers.size():
				if float(Career.data.offers[k].value) - float(Career.data.offers[k].fee) > float(Career.data.offers[best].value) - float(Career.data.offers[best].fee):
					best = k
			Career.accept(best)
		Game.contract = Career.active()
		Game.start_ship = Career.active().ship
		SaveGame.load_requested = false
		var scene: Node = load("res://scenes/main.tscn").instantiate()
		scene.bot = BOT.duplicate()
		root.add_child(scene)
		# only the contracts on the curve are played at a player's pace; the rest move the career on
		var paced: bool = i in [0, 4, 9]
		var bot = Bot.new(scene, {"paced": paced})
		bot.timeout = 80000
		while not bot.step():
			await process_frame
		for k in 3:
			await process_frame
		var sh: Dictionary = Game.op_share(scene.ops)
		shares.append(sh)
		if not paced:
			print("  contract %2d %-11s (played fast to move the career on)" % [i + 1, scene.job.get("id", "")])
		else:
			print("  contract %2d %-11s kit %-30s %4d hand-work  %3d decisions  %3d machine → %4.1f%% repetitive   (%d s, rate %.1f%%)" % [i + 1, scene.job.get("id", ""), ",".join(scene.job.get("kit", {}).keys()), sh.manual, sh.decision, sh.machine, sh.share * 100.0, int(scene.playtime), scene.recovery_rate() * 100.0])
		scene.queue_free()
		for k in 2:
			await process_frame
		for u in UPGRADES:
			if not Career.data.upgrades.has(u[0]) and float(Career.data.money) - u[1] >= RESERVE:
				Career.data.money = float(Career.data.money) - u[1]
				Career.data.upgrades[u[0]] = 1
				var desk: Dictionary = Career.data.get("desk", {})
				desk["buy"] = int(desk.get("buy", 0)) + 1
				Career.data.desk = desk
		if float(Career.data.loan) > 0.0:
			Career.repay(maxf(0.0, float(Career.data.money) - RESERVE))
		Career.save()
	# the curve
	var tut := {}
	var tf := ProjectSettings.globalize_path("res://tests/out/oplog_tutorial.json")
	if FileAccess.file_exists(tf):
		tut = JSON.parse_string(FileAccess.get_file_as_string(tf)).get("share", {})
	print("GROWTH CURVE — share of repetitive hand work (target: tutorial 85%%, early 75%%)")
	if not tut.is_empty():
		print("  tutorial       %4.1f%%  %s" % [float(tut.share) * 100.0, _bar(float(tut.share))])
	else:
		print("  tutorial       (run tests/tutorial_bot.gd first)")
	for i in [0, 4, 9]:
		if i < shares.size():
			print("  contract %-4d  %4.1f%%  %s" % [i + 1, shares[i].share * 100.0, _bar(shares[i].share)])
	var ok: bool = shares.size() >= 10 and shares[9].share <= shares[0].share - 0.05
	print("  [%s] contract 10 (%.1f%%) is clearly below contract 1 (%.1f%%)" % ["PASS" if ok else "FAIL", shares.back().share * 100.0, shares[0].share * 100.0])
	if not ok:
		fails += 1
	print("GROWTH %s" % ("PASS" if fails == 0 else "FAIL"))
	finished = true


func _bar(x: float) -> String:
	return "█".repeat(int(round(x * 40.0))) + "·".repeat(40 - int(round(x * 40.0)))
