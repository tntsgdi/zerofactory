extends SceneTree
# Roadmap 2.1 acceptance: a new career takes three contracts in a row — the
# hand-made GR-001, then two from the market — buying stock at the terminal
# in between. Half way through the second contract the game is quit and
# started again: funds, loan, stock, upgrades and the contract in progress
# (its ship, cut for cut) must all be where they were. Test files only.
# godot --headless --path . --fixed-fps 60 -s tests/career_run.gd

const Bot = preload("res://tests/salvage_bot.gd")
const Snap = preload("res://tests/snap_util.gd")
var fails := 0
var checks := 0
var finished := false


func _initialize() -> void:
	Career.path = "user://zp_test_career.json"
	SaveGame.path = "user://zp_test_career_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	_run()


func _process(_dt: float) -> bool:
	return finished


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _game() -> Node:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


# plays the contract to its end with the bot; stops early (returns false) at `stop_at` frames
func _play(game, stop_at: int = -1) -> Dictionary:
	var bot = Bot.new(game)
	var f := 0
	while not bot.step():
		f += 1
		if stop_at > 0 and f >= stop_at:
			return {"stopped": true, "bot": bot}
		await process_frame
	await _frames(5)
	return {"stopped": false, "bot": bot, "sum": bot.summary()}


# the terminal between contracts: buy what is asked, take the first offer
func _terminal(buy: Array) -> Dictionary:
	var term: Node = load("res://scenes/terminal.tscn").instantiate()
	root.add_child(term)
	await _frames(3)
	check(term.offers().size() == 3, "the market shows three offers (%d)" % term.offers().size())
	for id in buy:
		for it in term.SHOP:
			if it[0] == id:
				term.buy(it)
	var o: Dictionary = term.offers()[0].duplicate(true)
	term.take(0)
	term.queue_free()
	await _frames(2)
	return o


func _books() -> Dictionary:
	var d := Career.data
	return {"money": snappedf(float(d.money), 0.01), "loan": snappedf(float(d.loan), 0.01), "items": d.items.duplicate(), "upgrades": d.upgrades.duplicate(),
		"active": d.active.duplicate(true), "rep": int(d.rep), "done": int(d.done)}


func _run() -> void:
	print("CAREER: new career")
	Career.data = {}
	Career.start_new()
	check(Career.exists(), "the career file is written")
	check(Career.active().get("id", "") == "TUG-001", "the first contract is the work tug")
	# ---- the opening: the work tug, then S-09; after each the market is open with
	# the next opening contract pinned on it (player 2026-10-17), taken from there
	for want in [["TUG-001", "tug", "S09-001"], ["S09-001", "s09", Career.FIRST]]:
		check(Career.active().get("id", "") == want[0] and Career.active().ship == want[1], "%s is next, on %s" % [want[0], want[1]])
		Game.start_ship = Career.active().ship
		Game.contract = Career.active()
		var go = _game()
		await _frames(2)
		check(go.job.get("id", "") == want[0] and go.fee == 0.0 and Txt.hint_tier == "standard", "%s: no fee, the one standard hint level" % want[0])
		var ro: Dictionary = await _play(go)
		print("  %s: " % want[0], ro.sum)
		check(ro.sum.ended and ro.sum.incidents == 0 and Career.data.market and Career.active().is_empty() and Career.story_job().get("id", "") == want[2],
			"%s taken apart safely; the market open with %s pinned" % [want[0], want[2]])
		go.queue_free()
		await _frames(2)
		var term: Node = load("res://scenes/terminal.tscn").instantiate()
		root.add_child(term)
		await _frames(3)
		var shown: Array = term.offers()
		check(shown.size() == 3 and shown[0].get("story_card", false) and shown[0].id == want[2] and not shown[1].get("story_card", false),
			"the market: %s pinned first, then two offers to choose from (%d cards)" % [want[2], shown.size()])
		term.take(0)
		term.queue_free()
		await _frames(2)
	check(Career.active().get("id", "") == Career.FIRST and Career.active().has("kit"), "then GR-001, taken from its pinned card")
	var money_open := float(Career.data.money)
	check(money_open > 50000.0 and float(Career.data.loan) == 0.0, "the opening pays: funds %d, no debt" % money_open)
	# ---- contract 3: GR-001
	Game.start_ship = Career.active().ship
	Game.contract = Career.active()
	var g1 = _game()
	await _frames(2)
	check(g1.job.get("id", "") == "GR-001" and g1.ship.has("story"), "GR-001 is the hand-made Heron with its story")
	var r1: Dictionary = await _play(g1)
	print("  GR-001: ", r1.sum)
	check(r1.sum.ended and r1.sum.incidents == 0, "GR-001 taken apart safely")
	var cr: Dictionary = g1.career_result
	check(not cr.is_empty() and not cr.prepaid and int(Career.data.done) == 3 and Career.data.market and Career.story_job().is_empty(), "GR-001 settled with the career; the opening is through, nothing pinned")
	var expect_money: float = money_open + r1.sum.net + cr.bonus - cr.installment - cr.interest
	check(absf(float(Career.data.money) - expect_money) < 1.0, "funds = net %d + bonuses %d − installment %d − interest %d = %d (%d)" % [r1.sum.net, cr.bonus, cr.installment, cr.interest, expect_money, Career.data.money])
	check(float(Career.data.loan) == 0.0 and cr.installment == 0.0 and cr.interest == 0.0, "no debt from a clean first contract: loan %d" % Career.data.loan)
	g1.queue_free()
	await _frames(2)
	# ---- contract 2, quit half way
	var money_before := float(Career.data.money)
	var o2: Dictionary = await _terminal(["repair", "ring"])
	check(Career.data.items.get("repair", 0) == 1 and Career.data.items.get("ring", 0) == 1, "two items in stock")
	check(absf(float(Career.data.money) - (money_before - 3000.0 - 9000.0 - float(o2.fee))) < 1.0, "items and the contract fee paid from funds")
	check(Career.active().get("id", "") == o2.id and Career.active().get("fee_paid", false), "contract %s in progress, fee paid" % o2.id)
	var g2 = _game()
	await _frames(2)
	check(g2.job.get("id", "") == o2.id and not g2.ship.has("story") and g2.fee == float(o2.fee), "the game plays the offer's contract at its fee")
	var half: Dictionary = await _play(g2, 300)
	SaveGame.save(g2)
	var before := Snap.snap(g2)
	var books := _books()
	g2.queue_free()
	await _frames(2)
	print("CAREER: quit and start again")
	Career.data = {}
	Ship.clear_cache()
	Career.load_or_new()
	var after := _books()
	for k in books:
		var same := JSON.stringify(books[k], "", true) == JSON.stringify(after[k], "", true)
		check(same, "%s where it was: %s" % [k, JSON.stringify(after[k], "", true).left(90)])
	Game.contract = Career.active()
	Game.start_ship = Career.active().ship
	SaveGame.load_requested = true
	var g2b = _game()
	await _frames(2)
	var diff: Array = Snap.diff(before, Snap.snap(g2b))
	check(diff.is_empty(), "the contract in progress comes back as it was (%d differences %s)" % [diff.size(), str(diff.slice(0, 4))])
	for dd in diff.slice(0, 6):
		print("      ", dd)
	var r2: Dictionary = await _play(g2b)
	print("  %s: " % o2.id, r2.sum)
	check(r2.sum.ended and int(Career.data.done) == 4 and g2b.career_result.prepaid, "contract 4 settled (fee prepaid)")
	g2b.queue_free()
	await _frames(2)
	# ---- contract 3
	var o3: Dictionary = await _terminal([])
	var g3 = _game()
	await _frames(2)
	var r3: Dictionary = await _play(g3)
	print("  %s: " % o3.id, r3.sum)
	check(r3.sum.ended and int(Career.data.done) == 5 and Career.data.history.size() == 5, "five contracts on the books")
	check(Career.data.items.get("repair", 0) == 1, "stock carried through")
	g3.queue_free()
	await _frames(2)
	Career.data = {}
	Career.load_or_new()
	check(int(Career.data.done) == 5 and Career.active().is_empty() and not SaveGame.exists(), "after the fifth: on disk, nothing in progress")
	print("CAREER %s  (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	finished = true
