class_name ContractValidator
# VALIDATE CONTRACT (roadmap 2.3, extends VALIDATE SHIP to random contracts):
# a contract's ship must pass every static ship check, and on top of that
#   dismantlable — every part can be moved by some grapple the berth can
#                    buy, nothing sits inside anything else, every named item
#                    has its safe-removal procedure;
#   evidence      — each trap leaves something to measure or look at, and it
#                    is there and within reach;
#   no self-harm  — nothing on board starts an accident with nobody touching
#                    it (no fuel loose, no live supply inside explosive cargo);
#   traps land    — every trap found what it changes.
# A contract that fails is thrown away and drawn again (Market.make). The
# dynamic half — the bot takes it apart, a save round trip, the ship left
# alone — is tests/contract_validate.gd.

const MAX_GRAPPLE := 5.0      # t, the biggest grapple the shop sells


# {ok, reasons: [short id], detail: [text]}
static func check(d: Dictionary) -> Dictionary:
	var reasons: Array = []
	var detail: Array = []
	for note in d.get("variant", {}).get("notes", []):
		if str(note).begins_with("reject:"):
			reasons.append(str(note).substr(7).split(" ")[0])
			detail.append(str(note).substr(7))
	if not reasons.is_empty():
		return {"ok": false, "reasons": reasons, "detail": detail}
	var ship := ShipValidator.run(d)
	for c in ship:
		if not ship[c].is_empty():
			reasons.append("ship_" + c)
			detail.append_array(ship[c].slice(0, 3))
	_dismantlable(d, reasons, detail)
	_evidence(d, reasons, detail)
	_no_self_harm(d, reasons, detail)
	return {"ok": reasons.is_empty(), "reasons": reasons, "detail": detail}


static func _dismantlable(d: Dictionary, reasons: Array, detail: Array) -> void:
	var boxes: Array = []
	for pd in d.pieces:
		# too heavy for any grapple, unless it has marked lines to cut it into parts that are not
		if pd.get("cls", "") == "equip" and float(pd.get("mass", 0.0)) > MAX_GRAPPLE * (pd.get("segments", []).size() + 1):
			reasons.append("too_heavy")
			detail.append("%s weighs %.1f t" % [pd.key, pd.mass])
		if pd.get("cls", "") == "equip" or pd.kind == "fixture":
			boxes.append([pd.key, _poly(pd.poly)])
	# a trap's fitting never stands inside anything already there
	var added: Dictionary = Traps.fittings(d.get("variant", {}).get("traps", [])).pieces
	for i in boxes.size():
		for k in range(i + 1, boxes.size()):
			if not added.has(boxes[i][0]) and not added.has(boxes[k][0]):
				continue
			var a: PackedVector2Array = boxes[i][1]
			var b: PackedVector2Array = boxes[k][1]
			if not Geom.bbox(a).grow(-0.02).intersects(Geom.bbox(b).grow(-0.02)):
				continue
			var inter := Geometry2D.intersect_polygons(a, b)
			var area := 0.0
			for q in inter:
				area += Geom.area(q)
			if area > 0.02:
				reasons.append("overlap")
				detail.append("%s and %s overlap (%.2f m²)" % [boxes[i][0], boxes[k][0], area])


static func _evidence(d: Dictionary, reasons: Array, detail: Array) -> void:
	for t in d.get("variant", {}).get("traps", []):
		for e in Traps.evidence(d, t):
			var ok := false
			match e[0]:
				"ctrl":
					ok = Variant.ctrl(d, e[1]) != null
				"piece":
					ok = Variant.piece(d, e[1]) != null
				"line":
					ok = d.lines.any(func(l): return l.id == e[1])
			if not ok:
				reasons.append("no_evidence")
				detail.append("%s: nothing to find it by (%s %s)" % [t, e[0], e[1]])


static func _no_self_harm(d: Dictionary, reasons: Array, detail: Array) -> void:
	for s in d.get("power", {}).get("isolated", []):
		var pd = Variant.piece(d, s.piece)
		if pd != null and pd.get("hazard", "") == "explosive":
			reasons.append("self_ignition")
			detail.append("%s is explosive cargo with its own live supply" % s.piece)
	for k in d.get("fluids", {}).get("volumes", {}):
		var v: Dictionary = d.fluids.volumes[k]
		if v.get("fluid", "") == "fuel" and v.has("drip") and float(v.amount) > 0.0:
			reasons.append("self_ignition")
			detail.append("propellant %s drips with nobody touching it" % k)


static func _poly(a: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in a:
		out.append(Vector2(q[0], q[1]))
	return out
