extends RefCounted
# Snapshot of everything a save must carry, and the differences between two
# snapshots. Used by tests/save_fuzz.gd and VALIDATE SHIP.

const M := 48.0


static func snap(game) -> Dictionary:
	var w = game.world
	var s = game.sys
	var out := {}
	var pieces := {}
	var taken := {}
	for sw in game.dock.swallowing:
		taken[sw[0]] = Transform2D(sw[4], sw[3])
	for id in w.order:
		var p = w.pieces[id]
		if p.gone:
			continue
		# a body going down a recovery mouth is saved where the mouth took it
		var c: Vector2 = taken[p.body] * Geom.centroid(p.poly) if taken.has(p.body) else p.center_world()
		pieces[id] = {"kind": p.kind, "tag": p.tag, "cls": p.cls, "intact": p.intact, "open": p.door_open, "haz": p.hazard,
			"dest": p.dest, "free": p.body != null, "v": p.body.linear_velocity.length() if p.body != null and is_instance_valid(p.body) else 0.0, "n": p.poly.size(), "area": Geom.area(p.poly), "c": c,
			"mass": p.mass, "cond": p.cond, "temp": p.temp, "contam": p.contam, "seen": p.seen, "val": p.value}
	out.pieces = pieces
	var joints := {}
	for j in w.joints:
		if j.alive:
			joints[j.id] = [j.a, j.b, j.type]
	out.joints = joints
	var lines := {}
	for id in w.lines:
		var l = w.lines[id]
		lines[id] = [l.alive, l.a, l.b]
	out.lines = lines
	var ctrls := {}
	for id in w.ctrls:
		var c = w.ctrls[id]
		ctrls[id] = [c.state, c.piece]
	out.ctrls = ctrls
	var rooms := {}
	for n in w.rooms:
		rooms[n] = w.rooms[n].revealed
	out.rooms = rooms
	var vols := {}
	for k in s.vols:
		vols[k] = s.vols[k].n
	out.vols = vols
	out.flags = [s.switch.duplicate(), s.aux, s.remote_sent]
	out.nums = {"T": s.loop_T, "grec": s.gas_recovered, "glost": s.gas_lost, "flost": s.fluid_lost}
	for t in s.src:
		out.nums["charge " + t] = s.src[t].charge
		out.flags.append(s.src[t].running)
	for t in s.iso:
		out.nums["iso " + t] = s.iso[t].charge
	for k in s.fvol:
		out.nums["fluid " + k] = s.fvol[k].amount
	for f in s.fluid_rec:
		out.nums["rec " + f] = s.fluid_rec[f]
	var hoses := {}
	for k in s.hoses:
		hoses[k] = s.hoses[k].mode
	out.hoses = hoses
	var readings := {}
	for k in s.readings:
		readings[k] = [s.readings[k].text, s.readings[k].kind]
	out.readings = readings
	var lk := []
	for l in s.links:
		lk.append("%s-%s:%d" % [l[0], l[1], int(l[2])])
	lk.sort()
	out.links = lk
	out.leaks = s.leaks.size()
	out.clouds = s.clouds.size()
	out.blown = s.blown.keys()
	out.books = {"ie": game.income_equip, "im": game.income_metal, "ih": game.income_hazard, "loss": game.losses, "lines": game.loss_lines.size(),
		"must": game.mandatory_ok.duplicate(), "ledger": game.ledger.size(), "hp": game.drone.integrity, "alive": game.drone.alive,
		"tool": game.tools.tool, "mode": game.tools.hose_mode, "reveals": game.reveal_count}
	out.debris = game.dock.debris.size() + game.dock.swallowing.size()
	return out


static func _near(a: float, b: float, rel: float, absol: float) -> bool:
	return absf(a - b) <= maxf(absol, absf(a) * rel)


# list of mismatches between two snapshots (empty = the same)
static func diff(a: Dictionary, b: Dictionary) -> Array:
	var bad: Array = []
	for id in a.pieces:
		if not b.pieces.has(id):
			# swallowed or burnt in the frames between save and check is not a save error
			continue
		var pa: Dictionary = a.pieces[id]
		var pb: Dictionary = b.pieces[id]
		for k in ["kind", "tag", "cls", "intact", "open", "haz", "dest", "free", "n", "contam", "seen"]:
			if pa[k] != pb[k]:
				bad.append("piece %d %s %s != %s" % [id, k, pa[k], pb[k]])
		if not _near(pa.area, pb.area, 0.01, 2.0):
			bad.append("piece %d area %.0f != %.0f" % [id, pa.area, pb.area])
		if not _near(pa.mass, pb.mass, 0.01, 0.001):
			bad.append("piece %d mass" % id)
		if not _near(pa.val, pb.val, 0.001, 0.5) or not _near(pa.cond, pb.cond, 0.001, 0.002):
			bad.append("piece %d value/cond" % id)
		# a body moving fast when saved has gone on moving for the frames between save and check
		var tol: float = 30.0 + float(pa.get("v", 0.0)) * 0.12 if pa.free else 2.0
		if (pa.c as Vector2).distance_to(pb.c) > tol:
			bad.append("piece %d moved %.1f px" % [id, (pa.c as Vector2).distance_to(pb.c)])
		if not _near(pa.temp, pb.temp, 0.05, 3.0):
			bad.append("piece %d temp %.1f != %.1f" % [id, pa.temp, pb.temp])
	for id in b.pieces:
		if not a.pieces.has(id):
			bad.append("piece %d appeared" % id)
	if a.joints != b.joints:
		bad.append("joints differ (%d vs %d)" % [a.joints.size(), b.joints.size()])
	# a fresh cut-off may reach the debris net in the frames between save and check (it is then gone from the pieces)
	if int(b.debris) < int(a.debris) or int(b.debris) - int(a.debris) > 2:
		bad.append("debris differ: %d vs %d" % [int(a.debris), int(b.debris)])
	for k in ["lines", "ctrls", "rooms", "flags", "hoses", "leaks", "clouds"]:
		if a[k] != b[k]:
			bad.append("%s differ: %s vs %s" % [k, a[k], b[k]])
	if a.blown.size() != b.blown.size():
		bad.append("blown differ")
	for k in a.vols:
		if not _near(a.vols[k], b.vols[k], 0.04, 1.0):
			bad.append("gas %s %.1f != %.1f" % [k, a.vols[k], b.vols[k]])
	for k in a.nums:
		if not _near(a.nums[k], b.nums[k], 0.03, 0.02 if k != "T" else 2.0):
			bad.append("%s %.3f != %.3f" % [k, a.nums[k], b.nums[k]])
	if a.readings.keys() != b.readings.keys():
		bad.append("reading keys differ")
	for k in a.books:
		var va = a.books[k]
		var vb = b.books[k]
		if typeof(va) == TYPE_FLOAT:
			if not _near(va, vb, 0.001, 0.5):
				bad.append("book %s %s != %s" % [k, va, vb])
		elif va != vb:
			bad.append("book %s %s != %s" % [k, va, vb])
	return bad
