class_name SaveGame
# The contract in progress, cut shapes and all, as JSON in user://.
# Tests never read or write it (Game.testing). A save is written to a .tmp
# file first and only then swapped in, the previous save moves to .bak, and
# every file carries a checksum: a torn or damaged save falls back to .bak.
# Older versions are migrated one step at a time (see migrate()).

const PATH := "user://zeropower_save.json"
const BEST := "user://zeropower_best.json"
const VERSION := 3
const MAGIC := "ZEROPRESSURE"

static var load_requested := false
static var path := PATH          # tests point this at their own file
const TRAIN_PATH := "user://zeropower_training.json"
static var train_path := TRAIN_PATH   # the training course in progress (its own file)
static var allow_test := false
static var recovered := false    # the last read() had to fall back to .bak


static func exists(file: String = "") -> bool:
	var f := path if file == "" else file
	return FileAccess.file_exists(f) or FileAccess.file_exists(f + ".bak")


static func file_for(g) -> String:
	return file_for_ship(g.ship)


# the training course and the assessment keep their own files, next to the contract's
static func file_for_ship(d: Dictionary) -> String:
	if d.get("training", false):
		return train_path
	if d.has("exam"):
		return path.get_basename() + "_exam.json"
	return path


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
	# a developer's test contract is never written over the career's contract in progress
	if g.dev_job():
		return
	var w = g.world
	var s = g.sys
	# a cut made this frame splits the body before it is written, as it would next physics step
	if w.dirty_links:
		w.relink()
	var body_ids := {}
	var bodies: Array = []
	var taken := {}
	for sw in g.dock.swallowing:
		taken[sw[0]] = Transform2D(sw[4], sw[3])
	for b in w.bodies:
		if not is_instance_valid(b) or b.pieces.is_empty():
			continue
		body_ids[b] = bodies.size()
		# a body half way down a recovery mouth goes back to where the mouth took it
		if taken.has(b):
			bodies.append({"xf": _xf(taken[b]), "v": [0.0, 0.0], "w": 0.0})
		else:
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
			"must": p.mandatory, "dest": p.dest, "hid": p.hidden_by, "seen": p.seen, "label": p.label,
			"scope": p.scope, "seg": p.get_meta("segments", []),
		})
	var joints: Array = []
	for j in w.joints:
		if j.alive:
			joints.append({"id": j.id, "a": j.a, "b": j.b, "t": j.type, "p": _v2(j.pos), "tag": j.get_meta("tag", "")})
	var lines: Array = []
	for id in w.lines:
		var l = w.lines[id]
		lines.append({"id": l.id, "k": l.kind, "net": l.net, "a": l.a, "b": l.b, "pa": _v2(l.pa), "pb": _v2(l.pb), "path": _poly(l.path), "alive": l.alive, "cut": _v2(l.cut_at) if l.cut_at != Vector2.INF else null, "label": l.label})
	var ctrls: Array = []
	for id in w.ctrls:
		var c = w.ctrls[id]
		ctrls.append({"id": c.id, "k": c.kind, "piece": c.piece, "p": _v2(c.pos), "st": c.state, "m": c.medium, "tg": c.target, "hr": c.hidden_room, "label": c.label})
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
	var leaks: Array = []
	for lk in s.leaks:
		var lp = lk.piece
		leaks.append({"pos": _v2(lk.pos), "dir": _v2(lk.dir), "fluid": lk.fluid, "rate": lk.rate, "src": lk.src, "t": lk.t,
			"piece": lp.id if lp != null and not lp.gone else -1, "local": _v2(lk.local)})
	var clouds: Array = []
	for cl in s.clouds:
		clouds.append({"pos": _v2(cl.pos), "r": cl.r, "amount": cl.amount, "t": cl.t})
	var debris: Array = []
	for db in g.dock.debris:
		debris.append({"p": _v2(db[0]), "v": _v2(db[1]), "t": db[2], "poly": _poly(db[3]), "rot": db[4], "spin": db[5], "val": db[6]})
	var src := {}
	for t in s.src:
		src[t] = {"charge": s.src[t].charge, "running": s.src[t].running}
	var iso := {}
	for t in s.iso:
		iso[t] = s.iso[t].charge
	var fluid := {}
	for k in s.fvol:
		fluid[k] = s.fvol[k].amount
	var d := {
		"version": VERSION,
		"ship": g.ship_id,
		"mech": g.mech.save_state() if g.mech != null else {},
		"munitions": g.munitions.save_state() if g.munitions != null and g.munitions.active() else {},
		"rails": g.rails.save_state() if g.rails != null and g.rails.active() else {},
		"atmos": g.atmos.save_state() if g.atmos != null and g.atmos.active() else {},
		"cold": g.coldchain.save_state() if g.coldchain != null and g.coldchain.active() else {},
		"media": g.media.save_state() if g.media != null and g.media.active() else {},
		"furnace": g.furnace.save_state() if g.furnace != null and g.furnace.active() else {},
		"drones": g.drones.save_state() if g.drones != null and g.drones.active() else {},
		"tanknet": g.tanknet.save_state() if g.tanknet != null and g.tanknet.active() else {},
		"liner": g.liner.save_state() if g.liner != null and g.liner.active() else {},
		"boxbeam": g.boxbeam.save_state() if g.boxbeam != null and g.boxbeam.active() else {},
		"sail": g.sail.save_state() if g.sail != null and g.sail.active() else {},
		"reactor": g.reactor.save_state() if g.reactor != null and g.reactor.active() else {},
		"softshell": g.softshell.save_state() if g.softshell != null and g.softshell.active() else {},
		"train": g.train.save_state() if g.train != null and g.train.active() else {},
		"flywheel": g.flywheel.save_state() if g.flywheel != null and g.flywheel.active() else {},
		"rings": g.rings.save_state() if g.rings != null and g.rings.active() else {},
		"spine": g.spine.save_state() if g.spine != null and g.spine.active() else {},
		"workday": g.workday.save_state() if g.workday != null and g.workday.active() else {},
		"drillstring": g.drillstring.save_state() if g.drillstring != null and g.drillstring.active() else {},
		"nested": g.nested.save_state() if g.nested != null and g.nested.active() else {},
		"waterball": g.waterball.save_state() if g.waterball != null and g.waterball.active() else {},
		"magnets": g.magnets.save_state() if g.magnets != null and g.magnets.active() else {},
		"optics": g.optics.save_state() if g.optics != null and g.optics.active() else {},
		"immersion": g.immersion.save_state() if g.immersion != null and g.immersion.active() else {},
		"thermal": g.thermal.save_state() if g.thermal != null and g.thermal.active() else {},
		"composite": g.composite.save_state() if g.composite != null and g.composite.active() else {},
		"dilution": g.dilution.save_state() if g.dilution != null and g.dilution.active() else {},
		"tether": g.tether.save_state() if g.tether != null and g.tether.active() else {},
		"sandwich": g.sandwich.save_state() if g.sandwich != null and g.sandwich.active() else {},
		"ice": g.ice.save_state() if g.ice != null and g.ice.active() else {},
		"bio": g.bio.save_state() if g.bio != null else {},
		"ore": g.ore.save_state() if g.ore != null else {},
		"cryo": g.cryo.save_state() if g.cryo != null else {},
		"plan": g.plan.save_state() if g.plan != null else {},
		"keepout": g.keepout.map(func(r): return [r.position.x, r.position.y, r.size.x, r.size.y]),
		"world": {"pieces": pieces, "joints": joints, "lines": lines, "ctrls": ctrls, "rooms": rooms, "bodies": bodies,
			"next_id": w.next_id, "next_joint": w.next_joint, "metal_price": w.metal_price, "smass": w.structural_mass},
		"sys": {"vols": vols, "switch": s.switch, "src": src, "iso": iso, "fluid": fluid, "frec": s.fluid_rec, "aux": s.aux,
			"remote": s.remote_sent, "T": s.loop_T, "grec": s.gas_recovered, "glost": s.gas_lost, "flost": s.fluid_lost,
			"time": s.time, "hoses": s.hoses, "readings": readings, "vol_ver": s.vol_ver, "elec_ver": s.elec_ver,
			"elec_sig": s._elec_sig, "leaks": leaks, "clouds": clouds, "blown": s.blown},
		"game": {"ie": g.income_equip, "im": g.income_metal, "ih": g.income_hazard, "loss": g.losses, "lines": g.loss_lines,
			"must": g.mandatory_ok, "incidents": g.incidents, "time": g.playtime, "hints": g.hints_seen, "ledger": g.ledger,
			"drone": {"p": _v2(g.drone.global_position), "v": _v2(g.drone.linear_velocity), "hp": g.drone.integrity, "alive": g.drone.alive},
			"tool": g.tools.tool, "hose_mode": g.tools.hose_mode, "reveals": g.reveal_count, "respawn": g.drone_respawn, "used": g.used, "verified": g.verified, "ops": g.ops,
			"debris": debris, "must_value": g.must_value, "changed": g.changed, "time_by": g.time_by},
	}
	if not g.job.is_empty():
		d.job = g.job
	if g.tutorial != null:
		d.tutorial = g.tutorial.save_state()
	if g.story != null:
		d.story = g.story.save_state()
	write_file(file_for(g), d)


# tmp first, then swap: whatever happens mid-write, either the old save or the
# new one is complete on disk
static func write_file(file: String, d: Dictionary) -> bool:
	var body := JSON.stringify(d)
	var full := ProjectSettings.globalize_path(file)
	var f := FileAccess.open(file + ".tmp", FileAccess.WRITE)
	if f == null:
		return false
	f.store_string("%s %d %s\n" % [MAGIC, VERSION, body.md5_text()])
	f.store_string(body)
	f.close()
	if FileAccess.file_exists(file):
		if FileAccess.file_exists(file + ".bak"):
			DirAccess.remove_absolute(full + ".bak")
		DirAccess.rename_absolute(full, full + ".bak")
	return DirAccess.rename_absolute(full + ".tmp", full) == OK


static func read(file: String = "") -> Dictionary:
	return _read(path if file == "" else file, true)


# the career file: the same checks and backup, but not a contract to migrate
static func read_career(file: String) -> Dictionary:
	return _read(file, false)


static func _read(f: String, contract: bool) -> Dictionary:
	recovered = false
	var d := read_file(f, contract)
	if d.is_empty() and FileAccess.file_exists(f + ".bak"):
		d = read_file(f + ".bak", contract)
		recovered = not d.is_empty()
		if recovered:
			push_warning("save damaged, loaded the backup")
	return d


# A checked, migrated save, or {} when the file is missing or damaged.
static func read_file(file: String, contract: bool = true) -> Dictionary:
	if not FileAccess.file_exists(file):
		return {}
	var f := FileAccess.open(file, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	var body := text
	if text.begins_with(MAGIC):
		var nl := text.find("\n")
		if nl < 0:
			return {}
		var head := text.substr(0, nl).split(" ")
		body = text.substr(nl + 1)
		if head.size() != 3 or body.md5_text() != head[2]:
			return {}
	var d = JSON.parse_string(body)
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	return migrate(d) if contract else d


# Bring an older save up to VERSION one step at a time; {} if it comes from the
# future or is not a save at all.
static func migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 0))
	if v < 1 or v > VERSION or not d.has("world") or not d.has("sys") or not d.has("game"):
		return {}
	while v < VERSION:
		match v:
			1:
				# v2 added accidents in progress, electric state and debris in flight
				d.sys.merge({"nav_bat": 1.0, "elec_ver": 0, "elec_sig": "", "leaks": [], "clouds": [], "blown": {}})
				d.game.merge({"reveals": 0, "respawn": -1.0, "debris": []})
			2:
				# v3: ships are data. Every v1/v2 save is GR-7; its named fields become
				# the generic switch / source / fluid tables of the ship file.
				var sd: Dictionary = d.sys
				d.ship = "gr7"
				d.sys = {"vols": sd.get("vols", {}),
					"switch": {"V-C01": sd.get("VC01", false), "V-F01": sd.get("VF01", true), "V-E1": sd.get("VE1", true), "V-E2": sd.get("VE2", true), "K-G": sd.get("KG", true), "K-B": sd.get("KB", true),
						"E-D02": sd.get("dis", false), "PWR-EXT": sd.get("aux", false)},
					"src": {"G-01": {"charge": 1.0, "running": sd.get("G", true)}, "B-01": {"charge": sd.get("bat", 0.84), "running": false},
						"CAP-01": {"charge": sd.get("cap", 1.0), "running": false}},
					"iso": {"NAV-01": sd.get("nav_bat", 1.0)},
					"fluid": {"cool": sd.get("cool", 0.25), "cool_broken": sd.get("coolb", 0.06), "fuel": sd.get("fuel", 0.35), "fuel_line": sd.get("fline", 0.04)},
					"frec": {"fuel": sd.get("frec", 0.0), "coolant": sd.get("crec", 0.0)}, "aux": sd.get("aux", false), "remote": sd.get("grem", false), "T": sd.get("T", 138.0),
					"grec": sd.get("grec", 0.0), "glost": sd.get("glost", 0.0), "flost": sd.get("flost", 0.0), "time": sd.get("time", 0.0), "hoses": sd.get("hoses", {}),
					"readings": sd.get("readings", []), "vol_ver": sd.get("vol_ver", {}), "elec_ver": sd.get("elec_ver", 0), "elec_sig": "",
					"leaks": sd.get("leaks", []), "clouds": sd.get("clouds", []), "blown": sd.get("blown", {})}
				var leak_names := {"fuel_tank": "fuel", "fuel_line": "fuel_line", "cool": "cool", "cool_broken": "cool_broken"}
				for lk in d.sys.leaks:
					lk.src = leak_names.get(lk.src, lk.src)
				var gd: Dictionary = d.game
				gd.must = {"BB-01": gd.get("bb", false), "G-01": gd.get("gen", false)}
		v += 1
	d.version = VERSION
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
		p.scope = pd.get("scope", true)
		if not pd.get("seg", []).is_empty():
			p.set_meta("segments", pd.seg)
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
		p.seen = pd.get("seen", false)
		p.label = pd.get("label", "")
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
		l.label = ld.get("label", "")
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
		c.label = cd.get("label", "")
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
	for k in sd.switch:
		s.switch[k] = sd.switch[k]
	for t in sd.src:
		if s.src.has(t):
			s.src[t].charge = sd.src[t].charge
			s.src[t].running = sd.src[t].running
	for t in sd.iso:
		if s.iso.has(t):
			s.iso[t].charge = sd.iso[t]
	for k in sd.fluid:
		if s.fvol.has(k):
			s.fvol[k].amount = sd.fluid[k]
	for f in sd.frec:
		s.fluid_rec[f] = sd.frec[f]
	s.aux = sd.aux
	s.remote_sent = sd.remote
	s.loop_T = sd.T
	s.gas_recovered = sd.grec
	s.gas_lost = sd.glost
	s.fluid_lost = sd.flost
	s.time = sd.time
	for k in sd.vol_ver:
		s.vol_ver[k] = int(sd.vol_ver[k])
	s.elec_ver = int(sd.elec_ver)
	s._elec_sig = sd.elec_sig
	for k in sd.blown:
		s.blown[k] = sd.blown[k]
	for ld in sd.leaks:
		var lp = w.pieces.get(int(ld.piece))
		if lp != null and lp.gone:
			lp = null
		s.leaks.append({"pos": _p2(ld.pos), "dir": _p2(ld.dir), "fluid": ld.fluid, "rate": ld.rate, "src": ld.src, "t": ld.t, "piece": lp, "local": _p2(ld.local)})
	for cl in sd.clouds:
		s.clouds.append({"pos": _p2(cl.pos), "r": cl.r, "amount": cl.amount, "t": cl.t})
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
	for k in gd.must:
		g.mandatory_ok[k] = gd.must[k]
	g.must_value = gd.get("must_value", {})
	g.changed = gd.get("changed", {})
	g.time_by = gd.get("time_by", {})
	g.incidents = gd.get("incidents", [])
	g.playtime = gd.time
	g.hints_seen = gd.hints
	g.ledger = gd.ledger
	g.tools.tool = int(gd.tool)
	g.tools.hose_mode = gd.hose_mode
	g.reveal_count = int(gd.reveals)
	g.drone_respawn = gd.respawn
	for k in gd.get("used", {}):
		g.used[k] = int(gd.used[k])
	for k in gd.get("ops", {}):
		g.ops[k] = int(gd.ops[k])
	for k in gd.get("verified", {}):
		g.verified[k] = gd.verified[k]
	for db in gd.debris:
		g.dock.debris.append([_p2(db.p), _p2(db.v), db.t, _unpoly(db.poly), db.rot, db.spin, db.val, []])
	var dr: Dictionary = gd.drone
	g.drone.global_position = _p2(dr.p)
	g.drone.linear_velocity = _p2(dr.v)
	g.drone.integrity = dr.hp
	g.drone.alive = dr.alive
	g.drone.reset_physics_interpolation()
	w.redraw_all()
	w.back_layer.queue_redraw()
	w.cover_layer.queue_redraw()


# the contract is over: keep the files for reference, but never offer them as "continue"
static func clear(file: String = "") -> void:
	var f := path if file == "" else file
	for ext in ["", ".bak"]:
		if FileAccess.file_exists(f + ext):
			var full := ProjectSettings.globalize_path(f + ext)
			if FileAccess.file_exists(f + ext + ".done"):
				DirAccess.remove_absolute(full + ".done")
			DirAccess.rename_absolute(full, full + ".done")


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
