extends SceneTree
# Roadmap 3.2 acceptance: a market of several ship types. Over 300 markets
# (reputation high enough for every type): the Heron and the Swift both come
# up, and so do the pod, the tug and the Double Hook; each type's standard
# time, value and fee follow its own file; the types differ in time and in
# what a minute of work pays; and the bigger ship is not always the better
# job (by what a minute pays, net of the fee). Every offer passed the
# contract validator (Market.make keeps only those).
# godot --headless --path . -s tests/market_types.gd

var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _initialize() -> void:
	var by := {}                 # ship -> {n, time, value, fee, per_min}
	var big_best := 0
	var markets := 0
	Market.stats = {"made": 0, "discarded": 0, "reasons": {}}
	for m in 300:
		var offers := Market.make(77000 + m, {"rep": 12, "done": 6})
		if offers.size() != 3:
			continue
		markets += 1
		var best_pm := -1e9
		var best_ship := ""
		var big_v := -1.0
		var big_ship := ""
		for o in offers:
			var s: String = o.ship
			var e: Dictionary = by.get(s, {"n": 0, "time": 0.0, "value": 0.0, "fee": 0.0, "per_min": 0.0, "full": 0})
			e.n += 1
			var pm: float = (float(o.value) - float(o.fee)) / (float(o.time) / 60.0)
			# a "fast" job is meant to be shorter than the type's standard time: not one of these
			if o.scope == "full" and int(o.stars) == 1 and o.get("goal", "") != "fast":
				e.full += 1
				e.time += float(o.time)
				e.value += float(o.value)
				e.fee += float(o.fee)
				e.per_min += pm
			by[s] = e
			if pm > best_pm:
				best_pm = pm
				best_ship = s
			var tv := float(Market.type_of(s).get("value", 0.0))
			if tv > big_v:
				big_v = tv
				big_ship = s
		if best_ship == big_ship:
			big_best += 1
	print("  %d markets, %d offers made, %d thrown away by the validator" % [markets, Market.stats.made, Market.stats.discarded])
	for s in by:
		var e: Dictionary = by[s]
		var f := maxi(1, int(e.full))
		print("    %-5s %3d offers  1-star full strips: %3d  time %5.1f min  value $%7d  fee $%6d  $%5d / min" % [s, e.n, e.full, e.time / f / 60.0, int(e.value / f), int(e.fee / f), int(e.per_min / f)])
	check(markets == 300, "every market has three offers")
	for s in ["gr7", "s09", "pod", "tug", "h22"]:
		check(by.has(s), "%s comes up on the market" % s)
	# each type's time follows its file
	var times := {}
	var pms := {}
	for s in by:
		if int(by[s].full) == 0:
			continue
		var t: float = by[s].time / by[s].full
		times[s] = t
		pms[s] = by[s].per_min / by[s].full
		var want: float = Market.base_time(s)
		check(absf(t - want) <= want * 0.06 + 60.0, "%s: a one-star strip takes its own standard time (%.1f / %.1f min)" % [s, t / 60.0, want / 60.0])
	if times.has("gr7") and times.has("s09"):
		check(times.s09 < times.gr7 * 0.8, "the Swift is a markedly shorter job than the Heron")
		check(absf(pms.s09 - pms.gr7) > pms.gr7 * 0.1, "and pays a different rate a minute ($%d vs $%d)" % [pms.s09, pms.gr7])
	# the biggest type is not the best paid per minute on average, nor in every market
	var top := ""
	for s in pms:
		if top == "" or pms[s] > pms[top]:
			top = s
	var biggest := ""
	for s in pms:
		if biggest == "" or Market.type_of(s).value > Market.type_of(biggest).value:
			biggest = s
	check(top != biggest, "the biggest ship (%s) is not the best paid minute (%s)" % [biggest, top])
	check(big_best < markets, "in %d of %d markets the biggest ship on the board was also the best job" % [big_best, markets])
	print("MARKET TYPES %s" % ("PASS" if fails == 0 else "FAIL"))
	quit(1 if fails > 0 else 0)
