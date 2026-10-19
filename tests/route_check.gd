extends SceneTree
# P.8: the terminal's route page and the header's two goals (2026-10-18).
# Checks: the ships come in the order a career meets them, each with its
# conditions; pinning from the route page and from the skill book share the two
# slots and a third pushes the oldest out; reached goals drop out and the empty
# slot shows the closest; pins survive a save; the arrows walk the map; a click
# on a header goal opens its node. Stills: route.png, route_home.png, route_en.png.
# tools/run_test.sh tests/route_check.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var fails := 0
var term


func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	Txt.test_zh = true
	Txt.zh = true
	Career.path = "user://zp_test_route_career.json"
	for ext in ["", ".bak", ".tmp", ".old"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Career.path + ext))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _career() -> void:
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.market = true
	Career.data.done = 4
	Career.data.money = 41250.0
	Career.data.loan = 36000.0
	Career.data.in_debt = true
	Career.data.rep = 7
	Career.data.seen = {"market": true}
	Career.data.upgrades = {"scan_kit": true, "net05": true, "hauler": true}
	Career.data.history = [{"id": "TUG-001", "ship": "tug"}, {"id": "S09-001", "ship": "s09"}, {"id": "GR-001", "ship": "gr7"}, {"id": "M-1", "ship": "gr7"}]
	Career.save()


func _keys(ns: Array) -> Array:
	return ns.map(func(n): return n.key)


func _run() -> void:
	_career()
	# ---------------------------------------------------------------- the model
	var ns := Route.nodes()
	var ships := ns.filter(func(n): return n.kind == "ship").map(func(n): return n.id)
	# the first eight as the career has always met them; the fleet expansion's after them, by reputation
	var later: Array = Market.POOL.filter(func(e): return int(e[2]) > 12).map(func(e): return e[0])
	check(ships.slice(0, 8) == ["tug", "s09", "gr7", "pod", "h22", "m14", "med47", "fr26"] and ships.slice(8) == later, "ships in the order a career meets them: %s" % [ships])
	var m14 := Route.find("ship:m14")
	check(not m14.done and Route.missing(m14) == "还差 1 点声望 · 要扩建船坞", "M-14 one reputation point short: %s" % Route.missing(m14))
	var med := Route.find("ship:med47")
	check(med.conds.size() == 3 and not med.conds[1].ok, "MED-47 needs reputation, the berth extension and the market")
	check(m14.conds.size() == 3 and not m14.conds[1].ok, "M-14 (58 m) needs the berth extension too")
	check(Route.find("ship:gr7").done and int(Route.find("ship:gr7").stripped) == 2, "the Heron open, stripped twice")
	check(Route.find("buy:hauler").done and not Route.find("buy:hauler2").ready and Route.missing(Route.find("buy:hauler2")) == "还差 $18,750", "second hauler: first one owned, money short")
	check(Route.find("tier:2").done and not Route.find("tier:3").done, "volume II reached, volume III not")
	var buys := ns.filter(func(n): return n.kind == "buy")
	check(buys.size() == Route.buys().size() and buys.size() <= Route.PER_ROW * 2 and buys.all(func(n): return int(n.row) <= 1), "all %d upgrades and facilities on the two money rows" % buys.size())
	# ---------------------------------------------------------------- pins
	check(Route.pins().is_empty(), "nothing pinned on a fresh career")
	var auto := Route.goals()
	check(auto.size() == 2 and not auto[0].pinned and not auto[0].ready, "two automatic goals, still to earn first: %s" % [_keys(auto)])
	check(Route.toggle("ship:m14") and Route.toggle("buy:hauler2"), "pin M-14 and the second hauler")
	check(Route.pins() == ["ship:m14", "buy:hauler2"], "two pins in order")
	check(Growth.set_goal("drive"), "skill book sets a savings goal")
	check(Route.pins() == ["buy:hauler2", "skill:drive"], "the skill goal takes a slot, the oldest pin goes: %s" % [Route.pins()])
	check(Route.toggle("skill:drive") and str(Career.data.growth_goal) == "", "unpinning the skill clears the skill book's goal")
	Route.toggle("ship:m14")
	var disk := FileAccess.get_file_as_string(Career.path)
	check(disk.contains("buy:hauler2") and disk.contains("ship:m14"), "pins saved to the career file")
	# a goal reached drops out and the slot falls back to the closest
	Career.data.rep = 8
	Career.data.upgrades.berth88 = true
	var gs := Route.goals()
	check(gs.size() == 2 and gs[0].key == "buy:hauler2" and not gs[1].pinned, "M-14 reached: it leaves the goals, an automatic one fills in: %s" % [_keys(gs)])
	Career.data.rep = 7
	Career.data.upgrades.erase("berth88")
	# ---------------------------------------------------------------- the page
	term = load("res://scenes/terminal.tscn").instantiate()
	root.add_child(term)
	await _frames(40)
	Cap.save(root, "res://tests/out/route_home.png")
	term.set_tab(5)
	var tn: Array = term.items()
	check(tn.size() == ns.size() and tn[term.sel].key == Route.pins()[0], "the route page opens on the first pin")
	for i in tn.size():
		if tn[i].key == "ship:m14":
			term.sel = i
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = KEY_UP
	term._unhandled_input(ev)
	check(int(tn[term.sel].row) == 1, "up goes to the money row above")
	ev.physical_keycode = KEY_DOWN
	term._unhandled_input(ev)
	term._unhandled_input(ev)
	check(tn[term.sel].kind == "tier", "down twice reaches the volumes")
	ev.physical_keycode = KEY_UP
	term._unhandled_input(ev)
	ev.physical_keycode = KEY_RIGHT
	term._unhandled_input(ev)
	check(tn[term.sel].kind == "ship", "back on the ships and along the line: %s" % tn[term.sel].key)
	# Enter pins the chosen ship and pushes the oldest pin out
	var chosen: String = tn[term.sel].key
	term.act()
	check(Route.pinned(chosen) and Route.pins().size() == 2, "Enter pins it: %s" % [Route.pins()])
	term.act()
	check(not Route.pinned(chosen), "Enter again unpins it")
	Route.toggle("ship:m14")
	term._route_frame = -1
	# a click on a header goal opens its node
	term.set_tab(HOME_TAB)
	term._open_goal(0)
	check(term.tab == 5 and term.items()[term.sel].key == Route.goals()[0].key, "a header goal opens its node on the route page")
	Route.toggle("ship:m14")
	Route.toggle("buy:hauler2")
	term._route_frame = -1
	term.sel = term._route_start()
	await _frames(40)
	Cap.save(root, "res://tests/out/route.png")
	var tn2: Array = term.items()
	for i in tn2.size():
		if tn2[i].key == "buy:hauler2":
			term.sel = i
	await _frames(30)
	Cap.save(root, "res://tests/out/route_buy.png")
	Txt.zh = false
	term.deal_t = 0.0
	await _frames(40)
	Cap.save(root, "res://tests/out/route_en.png")
	Txt.zh = true
	print("ROUTE %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()


const HOME_TAB := -1
