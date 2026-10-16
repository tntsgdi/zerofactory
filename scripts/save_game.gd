class_name SaveGame
# The contract in progress, cut shapes and all, as JSON in user://.
# Tests never read or write it (Game.testing). Every save first rotates the
# previous file into .bak so a bad write can never cost the player a ship.

const PATH := "user://zeropower_save.json"
const BEST := "user://zeropower_best.json"
const VERSION := 1

static var load_requested := false
static var path := PATH          # tests point this at their own file
static var allow_test := false


static func exists() -> bool:
	return FileAccess.file_exists(path)


static func _v2(v: Vector2) -> Array:
	return [v.x, v.y]


static func _p2(a) -> Vector2:
	return Vector2(a[0], a[1])


static func _poly(p: PackedVector2Array) -> Array:
	var out: Array = []
	for q in p:
		out.append(q.x)
		out.append(q.y)
	return out


static func _unpoly(a: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, a.size() - 1, 2):
		out.append(Vector2(a[i], a[i + 1]))
	return out


static func _xf(t: Transform2D) -> Array:
	return [t.x.x, t.x.y, t.y.x, t.y.y, t.origin.x, t.origin.y]


static func _unxf(a: Array) -> Transform2D:
	return Transform2D(Vector2(a[0], a[1]), Vector2(a[2], a[3]), Vector2(a[4], a[5]))


static func save(g) -> void:
	if (g.testing and not allow_test) or g.ended or g.state != "play":
		return
	var w = g.world
	var s = g.sys
	var body_ids := {}
	var bodies: Array = []
	for b in w.bodies:
		if not is_instance_valid(b) or b.capture != null:
			continue
		body_ids[b] = bodies.size()
		bodies.append({"xf": _xf(b.global_transform), "v": _v2(b.linear_velocity), "w": b.angular_velocity})
	var pieces: Array = []
	for id in w.order:
		var p = w.pieces[id]
		if p.gone:
			continue
		if p.body != null and not body_ids.has(p.body):
			continue
		pieces.append({
			"id": p.id, "kind": p.kind, "tag": p.tag, "nk": p.name_key, "poly": _poly(p.poly),
			"body": body_ids.get(p.body, -1), "mass": p.mass, "den": p.density, "cls": p.cls, "val": p.value,
			"cond": p.cond, "intact": p.intact, "art": p.art, "axf": _xf(p.art_xf), "asz": _v2(p.art_size),
			"frag": p.fragile, "contam": p.contam, "cs": p.cut_speed, "room": p.room, "bar": p.barrier,
			"door": p.door, "open": p.door_open, "odir": _v2(p.open_dir), "haz": p.hazard, "temp": p.temp,
			"must": p.mandatory, "dest": p.dest, "hid": p.hidden_by,
		})
	var joints: Array = []
	for j in w.joints:
		if j.alive:
			joints.append({"id": j.id, "a": j.a, "b": j.b, "t": j.type, "p": _v2(j.pos), "tag": j.get_meta("tag", "")})
	var lines: Array = []
	for id in w.lines:
		var l = w.lines[id]
		lines.append({"id": l.id, "k": l.kind, "net": l.net, "a": l.a, "b": l.b, "pa": _v2(l.pa), "pb": _v2(l.pb), "path": _poly(l.path), "alive": l.alive, "cut": _v2(l.cut_at) if l.cut_at != Vector2.INF else null})
	var ctrls: Array = []
	for id in w.ctrls:
		var c = w.ctrls[id]
		ctrls.append({"id": c.id, "k": c.kind, "piece": c.piece, "p": _v2(c.pos), "st": c.state, "m": c.medium, "tg": c.target, "hr": c.hidden_room})
	var rooms := {}
	for n in w.rooms:
		rooms[n] = w.rooms[n].revealed
	var vols := {}
	for k in s.vols:
		vols[k] = s.vols[k].n
	var readings: Array = []
	for k in s.readings:
		var r: Dictionary = s.readings[k]
		readings.append({"key": r.key, "kind": r.kind, "at": r.at, "inst": r.inst, "t": r.t, "val": r.val, "text": r.text, "ver": r.ver, "vol": r.get("vol", "")})
	var d := {
		"version": VERSION,
		"world": {"pieces": pieces, "joints": joints, "lines": lines, "ctrls": ctrls, "rooms": rooms, "bodies": bodies,
			"next_id": w.next_id, "next_joint": w.next_joint, "metal_price": w.metal_price, "smass": w.structural_mass},
		"sys": {"vols": vols, "VC01": s.VC01, "VF01": s.VF01, "VE1": s.VE1, "VE2": s.VE2, "G": s.G_running, "KG": s.KG, "KB": s.KB,
			"bat": s.bat, "cap": s.cap, "aux": s.aux, "dis": s.discharge, "grem": s.g_remote, "fuel": s.fuel, "fline": s.fuel_line,
			"cool": s.cool, "coolb": s.cool_broken, "T": s.loop_T, "frec": s.fuel_recovered, "crec": s.cool_recovered,
			"grec": s.gas_recovered, "glost": s.gas_lost, "flost": s.fluid_lost, "time": s.time, "hoses": s.hoses, "readings": readings,
			"vol_ver": s.vol_ver},
		"game": {"ie": g.income_equip, "im": g.income_metal, "ih": g.income_hazard, "loss": g.losses, "lines": g.loss_lines,
			"bb": g.bb_ok, "gen": g.gen_ok, "time": g.playtime, "hints": g.hints_seen, "ledger": g.ledger,
			"drone": {"p": _v2(g.drone.global_position), "v": _v2(g.drone.linear_velocity), "hp": g.drone.integrity, "alive": g.drone.alive},
			"tool": g.tools.tool, "hose_mode": g.tools.hose_mode},
	}
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak"))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))


static func read() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY or int(d.get("version", 0)) != VERSION:
		return {}
	return d


# Rebuild the world, systems and books from a save. Returns false if unusable.
static func apply(g, d: Dictionary) -> bool:
	var w = g.world
	var wd: Dictionary = d.world
	for pd in wd.pieces:
		var p := Model.Piece.new()
		p.id = int(pd.id)
		p.kind = pd.kind
		p.tag = pd.tag
		p.name_key = pd.nk
		p.poly = _unpoly(pd.poly)
		p.mass = pd.mass
		p.density = pd.den
		p.cls = pd.cls
		p.value = pd.val
		p.cond = pd.cond
		p.intact = pd.intact
		p.art = pd.art
		p.art_xf = _unxf(pd.axf)
		p.art_size = _p2(pd.asz)
		p.fragile = pd.frag
		p.contam = pd.contam
		p.cut_speed = pd.cs
		p.room = pd.room
		p.barrier = pd.bar
		p.door = pd.door
		p.door_open = pd.open
		p.open_t = 1.0 if p.door_open else 0.0
		p.open_dir = _p2(pd.odir)
		p.hazard = pd.haz
		p.temp = pd.temp
		p.mandatory = pd.must
		p.dest = pd.dest
		p.hidden_by = int(pd.hid)
		p.set_meta("body", int(pd.body))
		w.pieces[p.id] = p
		w.order.append(p.id)
	for jd in wd.joints:
		var j := Model.Joint.new()
		j.id = int(jd.id)
		j.a = int(jd.a)
		j.b = int(jd.b)
		j.type = jd.t
		j.pos = _p2(jd.p)
		if jd.tag != "":
			j.set_meta("tag", jd.tag)
		w.joints.append(j)
	for ld in wd.lines:
		var l := Model.Line.new()
		l.id = ld.id
		l.kind = ld.k
		l.net = ld.net
		l.a = int(ld.a)
		l.b = int(ld.b)
		l.pa = _p2(ld.pa)
		l.pb = _p2(ld.pb)
		l.path = _unpoly(ld.path)
		l.alive = ld.alive and w.pieces.has(l.a) and w.pieces.has(l.b)
		l.cut_at = _p2(ld.cut) if ld.cut != null else Vector2.INF
		w.lines[l.id] = l
	for cd in wd.ctrls:
		var c := Model.Ctrl.new()
		c.id = cd.id
		c.kind = cd.k
		c.piece = int(cd.piece)
		c.pos = _p2(cd.p)
		c.state = cd.st
		c.medium = cd.m
		c.target = cd.tg
		c.hidden_room = cd.hr
		w.ctrls[c.id] = c
	w.next_id = int(wd.next_id)
	w.next_joint = int(wd.next_joint)
	# pieces of drifting bodies were saved body-local: put them back in world space
	for id in w.order:
		var p = w.pieces[id]
		var bi: int = p.get_meta("body", -1)
		if bi < 0:
			continue
		var xf := _unxf(wd.bodies[bi].xf)
		p.poly = xf * p.poly
		p.art_xf = xf * p.art_xf
		p.open_dir = xf.basis_xform(p.open_dir)
		for j in w.joints:
			if j.a == p.id:
				j.pos = xf * j.pos
		for lid in w.lines:
			var l = w.lines[lid]
			if l.a == p.id:
				l.pa = xf * l.pa
			if l.b == p.id:
				l.pb = xf * l.pb
		for cid in w.ctrls:
			var c = w.ctrls[cid]
			if c.piece == p.id:
				c.pos = xf * c.pos
	return true


# After rooms exist and the world is finalised: bodies, room state, systems, books.
static func apply_late(g, d: Dictionary) -> void:
	var w = g.world
	var wd: Dictionary = d.world
	w.metal_price = wd.metal_price
	w.structural_mass = wd.smass
	for n in wd.rooms:
		if w.rooms.has(n) and wd.rooms[n]:
			w.rooms[n].revealed = true
			w.rooms[n].reveal_t = 1.0
	# finalize() already set the unanchored groups drifting; give them their motion back
	for b in w.bodies:
		if b.pieces.is_empty():
			continue
		var bi: int = b.pieces[0].get_meta("body", -1)
		if bi >= 0 and bi < wd.bodies.size():
			b.linear_velocity = _p2(wd.bodies[bi].v)
			b.angular_velocity = wd.bodies[bi].w
	var s = g.sys
	var sd: Dictionary = d.sys
	for k in sd.vols:
		if s.vols.has(k):
			s.vols[k].n = sd.vols[k]
	s.VC01 = sd.VC01
	s.VF01 = sd.VF01
	s.VE1 = sd.VE1
	s.VE2 = sd.VE2
	s.G_running = sd.G
	s.KG = sd.KG
	s.KB = sd.KB
	s.bat = sd.bat
	s.cap = sd.cap
	s.aux = sd.aux
	s.discharge = sd.dis
	s.g_remote = sd.grem
	s.fuel = sd.fuel
	s.fuel_line = sd.fline
	s.cool = sd.cool
	s.cool_broken = sd.coolb
	s.loop_T = sd.T
	s.fuel_recovered = sd.frec
	s.cool_recovered = sd.crec
	s.gas_recovered = sd.grec
	s.gas_lost = sd.glost
	s.fluid_lost = sd.flost
	s.time = sd.time
	for k in sd.vol_ver:
		s.vol_ver[k] = int(sd.vol_ver[k])
	s.topology_dirty = true
	for port in sd.hoses:
		if w.ctrls.has(port) and w.ctrl_alive(w.ctrls[port]):
			s.hoses[port] = {"mode": sd.hoses[port].mode, "t": 1.0}
			g.dock.hose_attach(port, w.ctrl_world(w.ctrls[port]))
	for rd in sd.readings:
		g.restore_reading(rd)
	var gd: Dictionary = d.game
	g.income_equip = gd.ie
	g.income_metal = gd.im
	g.income_hazard = gd.ih
	g.losses = gd.loss
	g.loss_lines = gd.lines
	g.bb_ok = gd.bb
	g.gen_ok = gd.gen
	g.playtime = gd.time
	g.hints_seen = gd.hints
	g.ledger = gd.ledger
	g.tools.tool = int(gd.tool)
	g.tools.hose_mode = gd.hose_mode
	var dr: Dictionary = gd.drone
	g.drone.global_position = _p2(dr.p)
	g.drone.linear_velocity = _p2(dr.v)
	g.drone.integrity = dr.hp
	g.drone.reset_physics_interpolation()
	w.redraw_all()
	w.back_layer.queue_redraw()
	w.cover_layer.queue_redraw()


static func clear() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(PATH + ".done"))


static func best() -> Dictionary:
	if not FileAccess.file_exists(BEST):
		return {}
	var f := FileAccess.open(BEST, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f != null else null
	return d if typeof(d) == TYPE_DICTIONARY else {}


static func record_best(rate: float, net: float, secs: float, grade: int) -> Dictionary:
	var b := best()
	var out := {"rate": maxf(rate, b.get("rate", 0.0)), "net": maxf(net, b.get("net", -INF)), "grade": maxi(grade, int(b.get("grade", 0)))}
	var t0: float = b.get("time", INF)
	out["time"] = minf(secs, t0) if grade > 0 else t0
	var f := FileAccess.open(BEST, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(out))
	return out
