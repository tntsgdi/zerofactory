class_name ShipValidator
# VALIDATE SHIP, the static half: reads a ship file, builds it into a scratch
# World and checks that it can be played. Every problem names the exact item
# (piece, line, control, room) so a broken file says where it is broken.
# The dynamic half (save round trip, standing still, the bot walking each
# safe-removal procedure) lives in tests/validate_ship.gd.

const CHECKS := [
	["structure", "结构", "STRUCTURE"],
	["volumes", "容积", "VOLUMES"],
	["doors", "气密门", "AIRTIGHT DOORS"],
	["power", "电网", "POWER"],
	["lines", "管路端点", "LINE ENDS"],
	["connected", "结构连接", "CONNECTED"],
	["controls", "接口可达", "CONTROLS REACHABLE"],
	["mandatory", "强制目标", "MANDATORY ITEMS"],
	["story", "剧情物件", "STORY ITEMS"],
	["settle", "可结算", "SETTLEABLE"],
]
const CTRL_KINDS := ["port", "test", "valve", "switch", "remote", "stop", "socket", "discharge", "door", "hatch", "jam", "degauss", "probe", "seal"]
const REACH := 4.0         # metres, the tool reach of the drone
const NEAR := 0.3          # how far a fixing / control / line end may sit from its piece


# Returns {check id: Array of problem strings}; empty arrays pass.
static func run(d: Dictionary) -> Dictionary:
	var out := {}
	for c in CHECKS:
		out[c[0]] = []
	var w := World.new()
	var keys: Dictionary = Ship.build(w, d)
	w.finalize(float(d.get("value", {}).get("metal", 0.0)))
	_structure(d, w, keys, out.structure)
	_volumes(d, w, out.volumes)
	_doors(d, w, out.doors)
	_power(d, w, out.power)
	_lines(d, w, keys, out.lines)
	_connected(d, w, out.connected)
	_controls(d, w, out.controls)
	_mandatory(d, w, out.mandatory)
	_story(d, w, out.story)
	_settle(d, w, out.settle)
	w.free()
	return out


static func _m(v: Vector2) -> String:
	return "(%.2f, %.2f)" % [v.x / Geom.M, v.y / Geom.M]


static func _dist_piece(p, pos: Vector2) -> float:
	if Geometry2D.is_point_in_polygon(pos, p.poly):
		return 0.0
	return Geom.dist_to_boundary(pos, p.poly) / Geom.M


# ---------------------------------------------------------------- checks

static func _structure(d: Dictionary, w, keys: Dictionary, bad: Array) -> void:
	var seen_keys := {}
	for pd in d.get("pieces", []):
		if seen_keys.has(pd.key):
			bad.append("piece key %s used twice" % pd.key)
		seen_keys[pd.key] = true
		if pd.get("poly", []).size() < 3:
			bad.append("piece %s has fewer than 3 corners" % pd.key)
	var tags := {}
	for id in w.order:
		var p = w.pieces[id]
		var name: String = p.tag if p.tag != "" else "#%d" % p.id
		if not Geom.valid(p.poly) or Geom.area(p.poly) < 1.0:
			bad.append("piece %s is not a valid polygon" % name)
		if p.mass <= 0.0:
			bad.append("piece %s has no mass" % name)
		if p.tag != "":
			if tags.has(p.tag):
				bad.append("tag %s used by two pieces" % p.tag)
			tags[p.tag] = true
		if p.cls == "equip":
			if p.value <= 0.0:
				bad.append("equipment %s has no value" % name)
			if p.name_key == "" or not Txt.has(p.name_key):
				bad.append("equipment %s has no name text (%s)" % [name, p.name_key])
		if p.art != "" and p.art_size == Vector2.ZERO and p.art != "window":
			bad.append("piece %s has art but no art size" % name)
	for jd in d.get("joints", []):
		if not keys.has(jd.a) or (jd.b != null and not keys.has(jd.b)):
			bad.append("joint at %s joins a missing piece (%s / %s)" % [str(jd.at), jd.a, jd.b])
			continue
		var a = keys[jd.a]
		var pos := Vector2(jd.at[0], jd.at[1]) * Geom.M
		if _dist_piece(a, pos) > NEAR:
			bad.append("%s joint at %s is %.2f m off piece %s" % [jd.type, str(jd.at), _dist_piece(a, pos), jd.a])
		if not jd.type in ["weld", "bolt", "lock", "clamp", "seam", "crack", "pack"]:
			bad.append("joint at %s has unknown type %s" % [str(jd.at), jd.type])


static func _volumes(d: Dictionary, w, bad: Array) -> void:
	var gas: Dictionary = d.get("gas", {})
	var start: Dictionary = gas.get("rooms", {})
	var sys := Systems.new()
	sys.world = w
	sys.cfg = d
	for n in w.rooms:
		if not start.has(n):
			bad.append("room %s has no starting pressure" % n)
	for n in start:
		if not w.rooms.has(n):
			bad.append("starting pressure given for missing room %s" % n)
	# build the gas grid the game uses and see what each room touches
	sys.setup(null, w, d)
	for n in w.rooms:
		if sys.room_cells.get(n, 0) <= 0:
			bad.append("room %s lies outside the gas grid" % n)
	for l in sys.links:
		if l[1] == "space" and float(start.get(l[0], 0.0)) > 1.0:
			bad.append("room %s starts at %.0f kPa but is open to space (%.0f cells at %s)" % [l[0], start[l[0]], l[2], _m(l[3])])
	var vessels: Dictionary = gas.get("vessels", {})
	for k in vessels:
		var v: Dictionary = vessels[k]
		if float(v.get("V", 0.0)) <= 0.0:
			bad.append("vessel %s has no volume" % k)
		if v.has("piece") and w.tag(v.piece) == null:
			bad.append("vessel %s sits in missing piece %s" % [k, v.piece])
		if v.has("dead_leg") and not w.ctrls.has(v.dead_leg):
			bad.append("dead leg %s names missing valve %s" % [k, v.dead_leg])
	for gv in gas.get("valves", []):
		if not w.ctrls.has(gv.ctrl):
			bad.append("gas valve %s does not exist as a control" % gv.ctrl)
		elif w.ctrls[gv.ctrl].kind != "valve":
			bad.append("gas valve %s is a %s, not a valve" % [gv.ctrl, w.ctrls[gv.ctrl].kind])
		for side in [gv.a, gv.b]:
			if not w.rooms.has(side) and not vessels.has(side):
				bad.append("gas valve %s joins unknown volume %s" % [gv.ctrl, side])
	sys.free()


static func _doors(d: Dictionary, w, bad: Array) -> void:
	var opened_by := {}
	for id in w.ctrls:
		var c = w.ctrls[id]
		if c.kind == "door":
			opened_by[c.target] = id
	for k in d.get("ctrls_cfg", {}):
		for t in d.ctrls_cfg[k].get("doors", []):
			opened_by[t] = k
	for id in w.order:
		var p = w.pieces[id]
		if not p.door:
			continue
		var name: String = p.tag if p.tag != "" else "#%d" % p.id
		if not p.barrier:
			bad.append("door %s does not hold gas (no barrier)" % name)
		if p.tag == "" or not opened_by.has(p.tag):
			bad.append("door %s has no control that opens it" % name)
		if w.joints_of(p).is_empty():
			bad.append("door %s is not fixed to anything" % name)
	for id in w.ctrls:
		var c = w.ctrls[id]
		if c.kind == "door" and w.tag(c.target) == null:
			bad.append("door control %s opens missing door %s" % [id, c.target])


static func _power(d: Dictionary, w, bad: Array) -> void:
	var pw: Dictionary = d.get("power", {})
	if pw.is_empty():
		return
	var bus = w.tag(pw.get("bus", ""))
	if bus == null:
		bad.append("bus %s does not exist" % pw.get("bus", ""))
		return
	var reach := {}
	var stack: Array = [bus.id]
	reach[bus.id] = true
	while not stack.is_empty():
		var id = stack.pop_back()
		for lid in w.lines:
			var l = w.lines[lid]
			if l.kind != "cable":
				continue
			var other := -1
			if l.a == id:
				other = l.b
			elif l.b == id:
				other = l.a
			if other >= 0 and not reach.has(other):
				reach[other] = true
				stack.append(other)
	for s in pw.get("sources", []):
		var sp = w.tag(s.piece)
		if sp == null:
			bad.append("source %s does not exist" % s.piece)
			continue
		if not s.kind in ["gen", "battery", "cap"]:
			bad.append("source %s has unknown kind %s" % [s.piece, s.kind])
		var l = w.lines.get(s.get("cable", ""))
		if l == null:
			bad.append("source %s feeds through missing cable %s" % [s.piece, s.get("cable", "")])
		elif l.kind != "cable":
			bad.append("source %s feeds through %s, which is a pipe" % [s.piece, l.id])
		elif not ((l.a == sp.id and l.b == bus.id) or (l.b == sp.id and l.a == bus.id)):
			bad.append("cable %s does not run from %s to the bus %s" % [l.id, s.piece, bus.tag])
		for k in ["switch", "remote", "local", "discharge"]:
			if s.has(k) and not w.ctrls.has(s[k]):
				bad.append("source %s: %s control %s does not exist" % [s.piece, k, s[k]])
		if s.has("switch") and w.ctrls.has(s.switch) and w.ctrls[s.switch].kind != "switch":
			bad.append("source %s: %s is not a switch" % [s.piece, s.switch])
		if s.has("discharge") and w.ctrls.has(s.discharge) and w.ctrls[s.discharge].kind != "discharge":
			bad.append("source %s: %s is not a discharge plug" % [s.piece, s.discharge])
	for s in pw.get("isolated", []):
		if w.tag(s.piece) == null:
			bad.append("isolated source %s does not exist" % s.piece)
	var lamps: Dictionary = pw.get("lamps", {})
	for n in lamps:
		var lp = w.tag(lamps[n])
		if lp == null:
			bad.append("lamp %s does not exist" % lamps[n])
		elif not reach.has(lp.id):
			bad.append("lamp %s has no cable back to the bus" % lamps[n])
		if n != "" and not w.rooms.has(n):
			bad.append("lamp %s lights missing room %s" % [lamps[n], n])
	for id in w.ctrls:
		var c = w.ctrls[id]
		if c.kind == "test" and not c.medium in ["volt", "bio"]:
			bad.append("test point %s does not read volts" % id)


static func _lines(d: Dictionary, w, keys: Dictionary, bad: Array) -> void:
	var nets := {"power": true, "nav": true, "gas": true, "none": true}
	for k in d.get("fluids", {}).get("volumes", {}):
		for n in d.fluids.volumes[k].get("nets", []):
			nets[n] = true
	for ld in d.get("lines", []):
		if not keys.has(ld.a) or not keys.has(ld.b):
			bad.append("line %s: end %s is a missing piece" % [ld.id, ld.a if not keys.has(ld.a) else ld.b])
	var used := {}
	for id in w.lines:
		var l = w.lines[id]
		used[l.net] = true
		var pa = w.pieces.get(l.a)
		var pb = w.pieces.get(l.b)
		if pa != null and _dist_piece(pa, l.pa) > NEAR:
			bad.append("line %s: end A is %.2f m from %s" % [id, _dist_piece(pa, l.pa), pa.tag])
		if pb != null and _dist_piece(pb, l.pb) > NEAR:
			bad.append("line %s: end B is %.2f m from %s" % [id, _dist_piece(pb, l.pb), pb.tag])
		if l.path.size() < 2 or l.path[0].distance_to(l.pa) > 2.0 or l.path[l.path.size() - 1].distance_to(l.pb) > 2.0:
			bad.append("line %s: its route does not start and end at its ends" % id)
		if not l.kind in ["cable", "pipe"]:
			bad.append("line %s has unknown kind %s" % [id, l.kind])
		elif l.kind == "pipe" and not nets.has(l.net):
			bad.append("pipe %s carries %s, which no fluid volume holds" % [id, l.net])
		elif l.kind == "cable" and not l.net in ["power", "nav"]:
			bad.append("cable %s is on unknown network %s" % [id, l.net])
	for k in d.get("fluids", {}).get("volumes", {}):
		var v: Dictionary = d.fluids.volumes[k]
		for n in v.get("nets", []):
			if not used.has(n):
				bad.append("fluid %s: no pipe carries its net %s" % [k, n])
		if v.has("piece") and w.tag(v.piece) == null:
			bad.append("fluid %s is held by missing piece %s" % [k, v.piece])
		if v.has("port") and not w.ctrls.has(v.port):
			bad.append("fluid %s drains through missing port %s" % [k, v.port])
	for jn in d.get("fluids", {}).get("joins", []):
		for vv in jn.get("valves", []):
			if not w.ctrls.has(vv):
				bad.append("fluid join %s-%s: valve %s does not exist" % [jn.a, jn.b, vv])


static func _connected(d: Dictionary, w, bad: Array) -> void:
	var parent := {}
	for id in w.pieces:
		parent[id] = id
	parent[Model.ANCHOR] = Model.ANCHOR
	var find := func(x):
		while parent[x] != x:
			x = parent[x]
		return x
	var clamps := 0
	for j in w.joints:
		if j.b == Model.ANCHOR:
			clamps += 1
			var near := false
			for c in d.get("clamps", []):
				if absf(j.pos.x / Geom.M - float(c[0])) < 0.3:
					near = true
			if not near:
				bad.append("clamp joint at %s has no dock clamp under it" % _m(j.pos))
		var ra = find.call(j.a)
		var rb = find.call(j.b)
		if ra != rb:
			parent[ra] = rb
	for lid in w.lines:
		var l = w.lines[lid]
		var ra = find.call(l.a)
		var rb = find.call(l.b)
		if ra != rb:
			parent[ra] = rb
	if clamps == 0:
		bad.append("nothing is clamped to the dock")
	var root = find.call(Model.ANCHOR)
	for id in w.order:
		if find.call(id) != root:
			var p = w.pieces[id]
			bad.append("piece %s floats free at the start" % (p.tag if p.tag != "" else "#%d %s at %s" % [p.id, p.kind, _m(Geom.centroid(p.poly))]))


static func _controls(d: Dictionary, w, bad: Array) -> void:
	var gas: Dictionary = d.get("gas", {})
	var fl: Dictionary = d.get("fluids", {})
	for id in w.ctrls:
		var c = w.ctrls[id]
		if not c.kind in CTRL_KINDS:
			bad.append("control %s has unknown kind %s" % [id, c.kind])
		var p = w.pieces.get(c.piece)
		if p == null:
			bad.append("control %s is not on any piece" % id)
			continue
		var pos: Vector2 = w.ctrl_world(c)
		if _dist_piece(p, pos) > NEAR:
			bad.append("control %s is %.2f m off its piece %s" % [id, _dist_piece(p, pos), p.tag])
		var room: String = w.room_at(pos)
		if room != "" and c.hidden_room != room:
			bad.append("control %s is inside room %s but not marked as hidden there" % [id, room])
		if c.kind == "port":
			match c.medium:
				"gas":
					if not w.rooms.has(c.target) and not gas.get("vessels", {}).has(c.target):
						bad.append("gas port %s reads missing volume %s" % [id, c.target])
				"volt", "":
					bad.append("port %s has no medium" % id)
				_:
					var has_vol := false
					for k in fl.get("volumes", {}):
						if fl.volumes[k].get("port", "") == id:
							has_vol = true
					if not has_vol:
						bad.append("%s port %s drains no fluid volume" % [c.medium, id])
		if c.kind == "jam":
			var used := false
			for k in d.get("ctrls_cfg", {}):
				if d.ctrls_cfg[k].get("jam", "") == id:
					used = true
			if not used:
				bad.append("jam %s blocks nothing" % id)
		if not _reachable(w, pos, c.hidden_room):
			bad.append("control %s at %s cannot be reached by the drone" % [id, _m(pos)])
	for k in d.get("ctrls_cfg", {}):
		if not w.ctrls.has(k):
			bad.append("settings given for missing control %s" % k)
			continue
		var cc: Dictionary = d.ctrls_cfg[k]
		if cc.has("blocked_by") and w.tag(cc.blocked_by) == null:
			bad.append("control %s is blocked by missing piece %s" % [k, cc.blocked_by])
		if cc.has("target") and w.tag(cc.target) == null:
			bad.append("control %s acts on missing piece %s" % [k, cc.target])
		for t in cc.get("doors", []):
			if w.tag(t) == null:
				bad.append("control %s opens missing door %s" % [k, t])
		if cc.has("jam") and not w.ctrls.has(cc.jam):
			bad.append("control %s waits for missing jam %s" % [k, cc.jam])
		if cc.has("cable") and not w.lines.has(cc.cable):
			bad.append("control %s is powered through missing cable %s" % [k, cc.cable])


# is there open space within tool reach of the point (or the room it opens into)?
static func _reachable(w, pos: Vector2, hidden_room: String) -> bool:
	for ring in [0.7, 1.5, 2.5, 3.5]:
		for i in 24:
			var q: Vector2 = pos + Vector2.from_angle(TAU * i / 24.0) * ring * Geom.M
			var room: String = w.room_at(q)
			if room != "" and room != hidden_room:
				continue
			var blocked := false
			for id in w.order:
				var p = w.pieces[id]
				if Geom.bbox(p.poly).grow(2.0).has_point(q) and Geometry2D.is_point_in_polygon(q, p.poly):
					blocked = true
					break
			if not blocked:
				return true
	return false


# every inspectable sits on a real piece in the room it claims; the recorder exists
static func _story(d: Dictionary, w, bad: Array) -> void:
	var st: Dictionary = d.get("story", {})
	var ids := {}
	for it in st.get("inspect", []):
		if ids.has(it.id):
			bad.append("story item %s listed twice" % it.id)
		ids[it.id] = true
		var p = w.tag(it.get("piece", ""))
		if p == null:
			bad.append("story item %s sits on missing piece %s" % [it.id, it.get("piece", "")])
		elif it.has("room") and p.room != it.room:
			bad.append("story item %s: %s is in room %s, not %s" % [it.id, p.tag, p.room, it.room])
		for f in ["title", "text"]:
			if it.get(f, []).size() != 2:
				bad.append("story item %s needs %s in both languages" % [it.id, f])
	var rc: Dictionary = st.get("recorder", {})
	if not rc.is_empty():
		var bb = w.tag(rc.get("piece", ""))
		if bb == null:
			bad.append("story recorder %s is missing" % rc.get("piece", ""))
		elif not bb.mandatory:
			bad.append("story recorder %s is not a contract item" % bb.tag)


static func _mandatory(d: Dictionary, w, bad: Array) -> void:
	var procs: Dictionary = d.get("procedures", {})
	for id in w.order:
		var p = w.pieces[id]
		if not p.mandatory:
			continue
		if p.cls != "equip" or p.value <= 0.0:
			bad.append("mandatory %s is not valuable equipment" % p.tag)
		# a rescue contract's named pieces, and the ones a valuable-equipment order names, are
		# plain equipment (never a hazard): no procedure needed
		if not procs.has(p.tag) and not ((d.has("scope") or d.has("variant")) and p.hazard == ""):
			bad.append("mandatory %s has no safe-removal procedure" % p.tag)
	for k in procs:
		for step in procs[k]:
			for f in ["ctrl"]:
				if step.has(f) and not w.ctrls.has(step[f]):
					bad.append("procedure %s uses missing control %s" % [k, step[f]])
			if step.has("piece") and w.tag(step.piece) == null:
				bad.append("procedure %s handles missing piece %s" % [k, step.piece])


static func _settle(d: Dictionary, w, bad: Array) -> void:
	var v: Dictionary = d.get("value", {})
	var total := float(v.get("total", 0.0))
	if total <= 0.0:
		bad.append("contract value is not set")
		return
	var sum := float(v.get("metal", 0.0)) + float(d.get("gas", {}).get("value", 0.0))
	sum += float(d.get("ore", {}).get("fines", 0.0)) * float(d.get("ore", {}).get("price", 0.0))
	for f in d.get("fluids", {}).get("value", {}):
		sum += float(d.fluids.value[f])
	for id in w.order:
		var p = w.pieces[id]
		if p.cls == "equip":
			# explosives only ever go to the hazard mouth, which pays 40 %
			sum += p.value * (0.4 if p.hazard in Systems.HAZARD_ONLY else 1.0)
	# part of a ship: only what is inside the scope is paid, gas and fluids not at all
	if d.has("scope"):
		sum = 0.0
		if d.scope.kind == "rescue":
			for tg in d.scope.get("pay", {}):
				sum += float(d.scope.pay[tg])
		else:
			for id in w.order:
				var p = w.pieces[id]
				if p.scope:
					sum += p.value if p.cls == "equip" else p.mass * w.metal_price
	if absf(sum - total) > total * 0.05:
		bad.append("parts add up to $%d but the contract is worth $%d" % [int(sum), int(total)])
	if w.structural_mass <= 0.0:
		bad.append("no metal to scrap")
