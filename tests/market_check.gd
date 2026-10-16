extends SceneTree
# Roadmap 2.4: risk stars and reputation on the market. At each reputation
# level, 200 markets: the first offer is always one star with one plain trap;
# no offer is riskier than the level allows; subtle traps (rerouted line,
# second source, hidden damage) only once certified; three stars only from
# senior; every offer passed the contract validator; riskier offers pay more
# for less fee. And the career's reputation moves with the grades.
# godot --headless --path . -s tests/market_check.gd

var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _initialize() -> void:
	for rep in [0, 6, 16, 30]:
		var lv: String = Career.LEVELS[Market.level_index(rep)][0]
		var by_star := {}
		var bad: Array = []
		Market.stats = {"made": 0, "discarded": 0, "reasons": {}}
		for m in 200:
			var offers := Market.make(rep * 1000 + m, {"rep": rep, "done": 4})
			if offers.size() != 3:
				bad.append("market %d has %d offers" % [m, offers.size()])
				continue
			var first: Dictionary = offers[0]
			if int(first.stars) != 1 or first.traps.size() != 1 or Traps.TIER[first.traps[0]] != 0:
				bad.append("first offer is not low risk: %s %s" % [first.stars, first.traps])
			for o in offers:
				var st := int(o.stars)
				if st > Market.max_stars(rep):
					bad.append("%d stars at %s" % [st, lv])
				for t in o.traps:
					if Traps.TIER[t] == 1 and Market.level_index(rep) < 1:
						bad.append("subtle trap %s at %s" % [t, lv])
				# value and fee by risk: whole-ship contracts only (a part-ship job is smaller by design)
				if o.get("scope", "full") != "full":
					continue
				if not by_star.has(st):
					by_star[st] = {"n": 0, "traps": 0.0, "value": 0.0, "fee": 0.0}
				var b: Dictionary = by_star[st]
				b.n += 1
				b.traps += o.traps.size()
				b.value += float(o.value)
				b.fee += float(o.fee)
		print("%s (rep %d): %d offers drawn, %d thrown away by the validator %s" % [lv, rep, Market.stats.made, Market.stats.discarded, Market.stats.reasons])
		var keys := by_star.keys()
		keys.sort()
		for st in keys:
			var b: Dictionary = by_star[st]
			print("    %d★  %4d offers  %.1f traps  value $%d  fee $%d (%.1f%%)" % [st, b.n, b.traps / b.n, int(b.value / b.n), int(b.fee / b.n), b.fee / b.value * 100.0])
		check(bad.is_empty(), "%s: risk and traps within the level (%d problems) %s" % [lv, bad.size(), str(bad.slice(0, 3))])
		if by_star.has(1) and by_star.has(2):
			check(by_star[2].value / by_star[2].n > by_star[1].value / by_star[1].n and by_star[2].fee / by_star[2].value < by_star[1].fee / by_star[1].value, "%s: two stars pay more, for a smaller share in fees" % lv)
	# reputation follows the grades
	Career.path = "user://zp_test_market_career.json"
	Career.data = Career.fresh()
	var seen: Array = [Career.level()]
	for g in [3, 3, 2, 0, 3, 3, 3, 3, 2, 3, 3, 3]:
		Career.data.active = {"id": "x", "fee": 0.0, "fee_paid": true}
		Career.settle({"earned": 100000.0, "grade": g})
		if seen.back() != Career.level():
			seen.append(Career.level())
	check(seen == ["trainee", "certified", "senior", "chief"], "reputation climbs trainee → certified → senior → chief with good grades: %s (rep %d)" % [str(seen), int(Career.data.rep)])
	var r0 := int(Career.data.rep)
	Career.data.active = {"id": "y", "fee": 0.0, "fee_paid": true}
	Career.settle({"earned": 0.0, "grade": 0})
	check(int(Career.data.rep) == r0 - 1, "a failed contract costs a point")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Career.path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Career.path + ".bak"))
	print("MARKET %s" % ("PASS" if fails == 0 else "FAIL"))
	quit()
