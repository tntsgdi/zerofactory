extends SceneTree
# Roadmap 2.2 acceptance: 1000 random Herons from the market's own generator.
# (1) At least four different kinds of dismantling problem turn up (read from
# each ship file's data, Variant.problems). (2) Every part, fixing end, line
# and control keeps the factory's name and meaning; anything that is not in
# the factory file is a trap fitting with its fixed name. (3) The hull is the
# factory hull: every structural piece has the factory's shape. (4) The same
# contract builds the same ship twice.
# godot --headless --path . -s tests/variant_check.gd -- [n=1000]

var fails := 0


func _initialize() -> void:
	var n := 1000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("n="):
			n = int(a.substr(2))
	var base: Dictionary = Ship.load_data("gr7")
	var bpieces := {}
	for pd in base.pieces:
		bpieces[pd.key] = pd
	var bctrls := {}
	for c in base.ctrls:
		bctrls[c.id] = c
	var blines := {}
	for l in base.lines:
		blines[l.id] = l
	var counts := {}
	var trap_counts := {}
	var bad: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var t0 := Time.get_ticks_msec()
	for i in n:
		var stars := rng.randi_range(1, 3)
		var o := Market.offer_for(rng.randi(), {"rep": 30, "done": 5}, stars)
		var d := Variant.make(base, o)
		for t in o.traps:
			trap_counts[t] = trap_counts.get(t, 0) + 1
		for p in Variant.problems(d):
			counts[p] = counts.get(p, 0) + 1
		var fit := Traps.fittings(o.traps)
		# names: every piece is a factory piece or a fitting of this contract's traps
		for pd in d.pieces:
			var b = bpieces.get(pd.key)
			if b == null:
				if not fit.pieces.has(pd.key):
					bad.append("%s: piece %s is in neither the factory file nor a trap fitting" % [o.id, pd.key])
				continue
			for k in ["kind", "tag", "name_key", "room", "cls"]:
				if str(pd.get(k, "")) != str(b.get(k, "")):
					bad.append("%s: piece %s changed its %s (%s -> %s)" % [o.id, pd.key, k, b.get(k, ""), pd.get(k, "")])
			if pd.get("cls", "metal") != "equip" and not fit.reshaped.has(pd.key) and JSON.stringify(pd.poly) != JSON.stringify(b.poly):
				bad.append("%s: structure %s changed shape" % [o.id, pd.key])
		for c in d.ctrls:
			var b = bctrls.get(c.id)
			if b == null:
				if not fit.ctrls.has(c.id):
					bad.append("%s: control %s is not the factory's" % [o.id, c.id])
			elif c.kind != b.kind or c.piece != b.piece or str(c.get("target", "")) != str(b.get("target", "")):
				bad.append("%s: control %s changed what it is" % [o.id, c.id])
		for l in d.lines:
			var b = blines.get(l.id)
			if b == null:
				if not fit.lines.has(l.id):
					bad.append("%s: line %s is not the factory's" % [o.id, l.id])
			elif l.a != b.a or l.b != b.b or l.net != b.net:
				bad.append("%s: line %s joins something else" % [o.id, l.id])
		# a container missing from the hold takes nothing else with it
		for key in bpieces:
			if Variant.piece(d, key) == null and not key in Variant.CONTAINERS and not fit.reshaped.has(key):
				bad.append("%s: factory piece %s is missing" % [o.id, key])
		if i % 50 == 0:
			var again := Variant.make(base, o)
			if JSON.stringify(again, "", true) != JSON.stringify(d, "", true):
				bad.append("%s: the same contract built a different ship" % o.id)
	print("VARIANTS: %d Herons in %.1f s" % [n, (Time.get_ticks_msec() - t0) / 1000.0])
	var keys := counts.keys()
	keys.sort_custom(func(a, b): return counts[a] > counts[b])
	for k in keys:
		print("  %-22s %4d  (%.0f%%)" % [k, counts[k], counts[k] * 100.0 / n])
	print("  traps: ", trap_counts)
	var kinds := keys.size()
	print("  [%s] %d kinds of dismantling problem (need 4)" % ["PASS" if kinds >= 4 else "FAIL", kinds])
	if kinds < 4:
		fails += 1
	print("  [%s] names and hull as the factory built them (%d problems)" % ["PASS" if bad.is_empty() else "FAIL", bad.size()])
	for b in bad.slice(0, 12):
		print("      ", b)
	if not bad.is_empty():
		fails += 1
	print("VARIANT %s" % ("PASS" if fails == 0 else "FAIL"))
	quit()
