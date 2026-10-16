extends SceneTree
# Roadmap 2.5 acceptance: twenty contracts in a row, twice, on test files.
# Careful: the bot makes every ship safe, buys the shop's upgrades as funds
# allow (keeping a reserve for the next fee) and pays the rest off the loan —
# it should own the berth after 4–6 contracts. Careless: everything into the
# furnace, nothing bought, nothing paid early — the loan should only grow.
# Every settlement takes the installment and 2% interest; what funds can't
# cover goes back on the loan; fees are paid up front; the time bonus is +20%.
# godot --headless --path . --fixed-fps 60 -s tests/money_run.gd -- [n=20] [only=careful|careless] [paced]

const Bot = preload("res://tests/salvage_bot.gd")
const BOT := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
const UPGRADES := [["pump2", 22000.0], ["scan_kit", 24000.0], ["grapple5", 38000.0], ["arm", 65000.0]]
const RESERVE := 30000.0
var n := 20
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
	Career.path = "user://zp_test_money_career.json"
	SaveGame.path = "user://zp_test_money_save.json"
	SaveGame.allow_test = true
	_run()


func _process(_dt: float) -> bool:
	return finished


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _career(careless: bool) -> Array:
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	Career.data = {}
	Career.start_new()
	var rows: Array = []
	for i in n:
		if i > 0:
			Career.ensure_offers(Market.make)
			Career.accept(0)
		Game.contract = Career.active()
		Game.start_ship = Career.active().ship
		SaveGame.load_requested = false
		var scene: Node = load("res://scenes/main.tscn").instantiate()
		scene.bot = BOT.duplicate()
		root.add_child(scene)
		var bot = Bot.new(scene, {"careless": careless, "paced": paced})
		bot.timeout = 80000
		while not bot.step():
			await process_frame
		for k in 3:
			await process_frame
		var r: Dictionary = scene.career_result
		var bought: Array = []
		var prepaid := 0.0
		if not careless:
			for u in UPGRADES:
				if not Career.data.upgrades.has(u[0]) and float(Career.data.money) - u[1] >= RESERVE:
					Career.data.money = float(Career.data.money) - u[1]
					Career.data.upgrades[u[0]] = 1
					bought.append(u[0])
			if float(Career.data.loan) > 0.0:
				prepaid = Career.repay(maxf(0.0, float(Career.data.money) - RESERVE))
		Career.save()
		rows.append({"id": scene.job.id, "net": scene.net(), "bonus": r.get("bonus", 0.0), "inst": r.installment + r.interest, "short": r.short,
			"money": float(Career.data.money), "loan": float(Career.data.loan), "bought": bought, "prepaid": prepaid, "rate": scene.recovery_rate()})
		print("  %2d %-11s rate %5.1f%%  net %8d  bonus %6d  due %6d  short %6d  bought %-22s prepaid %7d  funds %8d  loan %8d" % [i + 1, scene.job.id, rows.back().rate * 100.0,
			rows.back().net, rows.back().bonus, rows.back().inst, rows.back().short, ",".join(bought), prepaid, rows.back().money, rows.back().loan])
		scene.queue_free()
		for k in 2:
			await process_frame
	return rows


func _run() -> void:
	if only != "careless":
		print("CAREFUL")
		var a: Array = await _career(false)
		var off := -1
		for i in a.size():
			if a[i].loan <= 0.5:
				off = i + 1
				break
		check(off >= 4 and off <= 6, "careful: the loan is paid off after contract %d (target 4–6)" % off)
		check(Career.data.get("paid_off", false) and int(Career.data.paid_off_at) == off, "the milestone is on the books")
		check(Career.data.upgrades.size() == UPGRADES.size(), "and all four first upgrades bought on the way (%s)" % str(Career.data.upgrades.keys()))
	if only != "careful":
		print("CARELESS")
		var b: Array = await _career(true)
		var up := true
		for i in range(1, b.size()):
			if b[i].loan <= b[i - 1].loan:
				up = false
		check(up and b.back().loan > b[0].loan, "careless: the loan rises every contract, %d → %d" % [b[0].loan, b.back().loan])
	print("MONEY %s" % ("PASS" if fails == 0 else "FAIL"))
	finished = true
