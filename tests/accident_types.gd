extends SceneTree
# Roadmap 3.3 acceptance: the accident library across ship types. The ten
# accident templates (Traps.ALL) are placed on each type where its file has a
# slot for them (market.slots); for every type and every template it allows,
# contracts that carry it pass the contract validator (which also checks that
# the template leaves evidence a careful operator can measure or inspect, in
# reach), and two templates combine where the rules allow. The same template
# lands on different parts on different types (other evidence to find it by):
# it does something else there.
# The dynamic half (the bot takes such contracts apart, save round trip) is
# tests/contract_validate.gd -- ship=mix.
# godot --headless --path . -s tests/accident_types.gd

const SHIPS := ["gr7", "s09", "tug", "pod", "h22"]
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


# a contract on `ship` carrying exactly `traps`, drawn until one passes (or not)
func _try(ship: String, traps: Array, seed: int) -> Dictionary:
	var o := Market.offer_for(seed, {"rep": 30, "done": 6}, 1, "full", ship)
	o.traps = traps
	for k in 12:
		var d := Variant.make(Ship.load_data(ship), o)
		var v := ContractValidator.check(d)
		if v.ok:
			return {"ok": true, "d": d}
		o.variant = int(o.variant) + 1
	return {"ok": false}


# the evidence with the room (and the ship's part) each piece of it sits in
func _where(d: Dictionary, ev: Array) -> String:
	var out: Array = []
	for e in ev:
		var room := ""
		if e[0] == "piece":
			var pd = Variant.piece(d, e[1])
			room = str(pd.get("room", "")) + "@" + str(snappedf(float(Geom.centroid(_poly(pd.poly)).x), 1.0)) if pd != null else "?"
		out.append("%s %s %s" % [e[0], e[1], room])
	return ", ".join(out)


func _poly(a: Array) -> PackedVector2Array:
	var p := PackedVector2Array()
	for q in a:
		p.append(Vector2(q[0], q[1]))
	return p


func _initialize() -> void:
	check(Traps.ALL.size() == 10, "ten accident templates")
	var where := {}              # trap -> {ship: what it changed}
	var covered := {}
	for s in SHIPS:
		var allowed: Array = Traps.allowed(Ship.load_data(s))
		print("  %s: %d templates — %s" % [s, allowed.size(), ", ".join(allowed)])
		check(allowed.size() >= 3, "%s carries at least three templates" % s)
		var ok_n := 0
		for t in allowed:
			covered[t] = true
			var good := 0
			var tgt := ""
			for seed in [11, 23, 37]:
				var r := _try(s, [t], seed)
				if r.ok:
					good += 1
					# where it lands: what a careful operator finds it by on this type
					tgt = _where(r.d, Traps.evidence(r.d, t))
					var notes: Array = r.d.get("variant", {}).get("notes", [])
					if not t in notes:
						good -= 1
			if good == 3:
				ok_n += 1
			else:
				print("      %s on %s: %d / 3 contracts valid" % [t, s, good])
			var e: Dictionary = where.get(t, {})
			e[s] = tgt
			where[t] = e
		check(ok_n == allowed.size(), "%s: every template it allows makes valid contracts (%d / %d)" % [s, ok_n, allowed.size()])
		# two at once, where the rules allow
		var pairs := 0
		var pair_ok := 0
		for i in allowed.size():
			for j in range(i + 1, allowed.size()):
				pairs += 1
				if _try(s, [allowed[i], allowed[j]], 50 + i * 7 + j).ok:
					pair_ok += 1
		print("      %s: %d of %d pairs combine" % [s, pair_ok, pairs])
		check(pairs == 0 or pair_ok >= pairs * 0.6, "%s: most pairs of templates combine (%d / %d)" % [s, pair_ok, pairs])
	check(covered.size() == 10, "every template is used somewhere (%d)" % covered.size())
	# the same template, different consequences: it lands on other parts on other types
	var spread := 0
	var multi := 0
	for t in where:
		var targets := {}
		for s in where[t]:
			if where[t][s] != "":
				targets[s + ":" + where[t][s]] = true
		if where[t].size() >= 2:
			multi += 1
			if targets.size() >= 2:
				spread += 1
		print("    %-16s %s" % [t, str(where[t]).left(220)])
	check(multi >= 5 and spread >= multi - 1, "%d templates appear on several types, %d of them on different parts" % [multi, spread])
	print("ACCIDENT TYPES %s" % ("PASS" if fails == 0 else "FAIL"))
	quit(1 if fails > 0 else 0)
