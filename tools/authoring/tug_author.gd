class_name TugAuthor
# Authoring script for the work tug, the 16 m first real ship after training
# (design/ships/TUG_作业艇_设计稿.md, structure: design/ships/TUG_作业艇_结构图.png).
# Not part of the game: tools/ship_export.gd runs it and writes ships/tug.json.
# Metres, x bow (0) to stern (16), y down.
#
# A short, tall push boat: a fendered push plate at the bow, a raised wheelhouse
# over the cabin A, the engine room M behind a bulkhead door, a heavy keel bolted
# under the whole boat, an open aft deck with the winch under an A-frame, and a
# thruster pod slung under the keel. Each danger once, all mild: measure before
# opening (A has air), power off (one battery, one switch), recover a liquid
# (one fuel tank), haul a big piece (the winch).

const T := 0.3
const OUTER := [
	Vector2(0.05, 1.7), Vector2(0.05, -2.0), Vector2(0.5, -2.4), Vector2(0.95, -2.4), Vector2(1.95, -4.5),
	Vector2(5.3, -4.5), Vector2(5.55, -2.4), Vector2(12.0, -2.4), Vector2(12.0, 2.6), Vector2(1.0, 2.6),
]
# where the long edges are cut into plates (fractions along each edge)
const CUTS := {0: [0.55], 5: [0.7], 6: [0.3, 0.65], 7: [0.52], 8: [0.27, 0.55, 0.78]}
# the tags some plates carry (the accident templates name them)
const PLATE_TAGS := {6: ["TOP-1", "TOP-2", "TOP-3"], 7: ["AFT-1", "AFT-2"]}
const WH_FLOOR := -2.4            # the wheelhouse's grating floor (top)
const FLOOR := 2.3                # the inner bottom: what A and M stand on
const SEAT_SHAPE := [Vector2(0.02, 1.0), Vector2(0.98, 1.0), Vector2(0.98, 0.92), Vector2(0.6, 0.92), Vector2(0.6, 0.75), Vector2(0.78, 0.72),
	Vector2(1.0, 0.18), Vector2(1.0, 0.02), Vector2(0.86, 0.0), Vector2(0.82, 0.15), Vector2(0.6, 0.63), Vector2(0.02, 0.64),
	Vector2(0.02, 0.75), Vector2(0.38, 0.75), Vector2(0.38, 0.92), Vector2(0.02, 0.92)]

static var inner: Array = []
static var w
static var by_tag := {}


static func p(x: float, y: float) -> Vector2:
	return Vector2(x * Geom.M, y * Geom.M)


static func R(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return Geom.rect_poly(Geom.mrect(x0, y0, x1, y1))


static func _mp(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(q * Geom.M)
	return out


static func _inner_outline() -> Array:
	var n := OUTER.size()
	var out: Array = []
	for i in n:
		var a: Vector2 = OUTER[(i - 1 + n) % n]
		var b: Vector2 = OUTER[i]
		var c: Vector2 = OUTER[(i + 1) % n]
		var d1 := (b - a).normalized()
		var d2 := (c - b).normalized()
		var n1 := Vector2(-d1.y, d1.x)
		var n2 := Vector2(-d2.y, d2.x)
		var hit = Geometry2D.line_intersects_line(a + n1 * T, d1, b + n2 * T, d2)
		out.append(hit if hit != null else b + n1 * T)
	return out


static func build(world) -> void:
	w = world
	by_tag = {}
	inner = _inner_outline()
	_hull()
	_interior()
	_deck()
	_equipment()
	_lines()
	_controls()
	_rooms()


static func rooms_only(world) -> void:
	w = world
	inner = _inner_outline()
	_rooms()


static func _tagged(pc):
	if pc.tag != "":
		by_tag[pc.tag] = pc
	return pc


static func _bolt(a, b, x: float, y: float, type: String = "bolt") -> void:
	if a == null or b == null:
		push_warning("TUG joint missing a piece at %s,%s" % [x, y])
		return
	w.add_joint(a, b, type, p(x, y))


static func at(x: float, y: float, kinds: Array = []):
	return w.piece_at(p(x, y), kinds)


# ---------------------------------------------------------------- hull: plates round the outline, welded edge to edge

static func _hull() -> void:
	var S := {"density": 1.5, "barrier": true, "cut_speed": 240.0}
	var n := OUTER.size()
	var prev = null
	var first = null
	for i in n:
		var o0: Vector2 = OUTER[i]
		var o1: Vector2 = OUTER[(i + 1) % n]
		var i0: Vector2 = inner[i]
		var i1: Vector2 = inner[(i + 1) % n]
		var st: Array = [0.0]
		st.append_array(CUTS.get(i, []))
		st.append(1.0)
		for k in st.size() - 1:
			var a := o0.lerp(o1, st[k])
			var b := o0.lerp(o1, st[k + 1])
			var c := i0.lerp(i1, st[k + 1])
			var d := i0.lerp(i1, st[k])
			var opts := S.duplicate()
			var kind := "hull"
			if i == 3:
				opts["art"] = "window"                    # the windscreen
			if i == 5 and k == 0:
				kind = "hatch"                              # the entry hatch: the back of the wheelhouse
				opts["door"] = true
				opts["tag"] = "HATCH-A"
				opts["open_dir"] = Vector2(0, -1.7) * Geom.M
			if i == 0:
				opts["density"] = 2.2                       # the bow wall behind the push plate
			if PLATE_TAGS.has(i):
				opts["tag"] = PLATE_TAGS[i][k]
			var pc = _tagged(w.add_piece(kind, _mp([a, b, c, d]), opts))
			if prev != null:
				w.add_joint(prev, pc, "weld", a.lerp(d, 0.3) * Geom.M)
				w.add_joint(prev, pc, "weld", a.lerp(d, 0.7) * Geom.M)
			else:
				first = pc
			prev = pc
	w.add_joint(prev, first, "weld", OUTER[0].lerp(inner[0], 0.3) * Geom.M)
	w.add_joint(prev, first, "weld", OUTER[0].lerp(inner[0], 0.7) * Geom.M)
	# the push plate and its fender blocks on the bow
	var pp = _tagged(w.add_piece("beam", R(-0.4, -2.3, 0.05, 2.3), {"density": 1.8, "cut_speed": 160.0, "tag": "PUSH"}))
	for y in [-1.9, -0.6, 0.7, 1.9]:
		_bolt(pp, at(0.15, clampf(y, -1.95, 1.65), ["hull"]), 0.05, clampf(y, -1.95, 1.65))
	for i in 4:
		var y0 := -2.0 + i * 1.08
		var f = w.add_piece("fixture", R(-0.95, y0, -0.4, y0 + 0.9), {"density": 0.6, "cut_speed": 300.0, "cls": "metal", "dest": "metal", "art": "panel", "art_xf": Transform2D(0.0, p(-0.95, y0)), "art_size": p(0.55, 0.9), "name_key": "p_fender"})
		_bolt(f, pp, -0.4, y0 + 0.45)
	# the keel: one heavy beam under the boat, bolted up into the bottom plates
	var keel = _tagged(w.add_piece("keel", _mp([Vector2(1.2, 2.6), Vector2(15.4, 2.6), Vector2(15.0, 3.15), Vector2(1.6, 3.15)]), {"density": 1.2, "barrier": true, "cut_speed": 120.0, "tag": "KEEL"}))
	var x := 1.8
	while x < 11.8:
		_bolt(keel, at(x, 2.45, ["hull"]), x, 2.6)
		x += 1.6
	# dock clamps grip the keel
	for cl in [[3.0, 3.15, "CL-01"], [7.2, 3.15, "CL-02"]]:
		var j = w.add_joint(at(cl[0], cl[1] - 0.1, ["keel"]), null, "clamp", p(cl[0], cl[1]))
		j.set_meta("tag", cl[2])


# ---------------------------------------------------------------- inside: wheelhouse floor, ladder, the A/M bulkhead and its door

static func _interior() -> void:
	# the wheelhouse floor: two grating plates with the ladder hole between (not airtight: A is one room)
	var wl: float = inner[3].x + 0.02
	var wr: float = 5.24
	var f1 = _tagged(w.add_piece("rail", R(wl, WH_FLOOR, 4.0, WH_FLOOR + 0.15), {"density": 0.8, "cut_speed": 240.0, "tag": "WF-1", "room": "A",
		"art": "grating", "art_xf": Transform2D(0.0, p(wl, WH_FLOOR)), "art_size": p(4.0 - wl, 0.15), "name_key": "p_floor"}))
	var f2 = _tagged(w.add_piece("rail", R(4.6, WH_FLOOR, wr, WH_FLOOR + 0.15), {"density": 0.8, "cut_speed": 240.0, "tag": "WF-2", "room": "A",
		"art": "grating", "art_xf": Transform2D(0.0, p(4.6, WH_FLOOR)), "art_size": p(wr - 4.6, 0.15), "name_key": "p_floor"}))
	_bolt(f1, at(wl - 0.1, WH_FLOOR + 0.05, ["hull"]), wl, WH_FLOOR + 0.07)
	_bolt(f2, at(5.4, -2.5, ["hull"]), wr, WH_FLOOR + 0.07)
	# the ladder from the wheelhouse down into the cabin
	var lad = _tagged(w.add_piece("fixture", R(4.05, WH_FLOOR + 0.15, 4.55, FLOOR), {"density": 0.5, "cut_speed": 280.0, "tag": "LADDER", "cls": "metal", "dest": "metal", "room": "A",
		"art": "ladder", "art_xf": Transform2D(0.0, p(4.05, WH_FLOOR + 0.15)), "art_size": p(0.5, FLOOR - WH_FLOOR - 0.15), "name_key": "p_ladder"}))
	_bolt(lad, f1, 4.0, WH_FLOOR + 0.1)
	_bolt(lad, at(4.3, FLOOR + 0.15, ["hull"]), 4.3, FLOOR)
	# the bulkhead between the cabin and the engine room; the door slides up into it
	var dr = _tagged(w.add_piece("door", R(5.88, 0.3, 6.12, FLOOR), {"density": 1.0, "barrier": true, "door": true, "tag": "DR-AM", "open_dir": Vector2(0, -1.9) * Geom.M, "cut_speed": 240.0}))
	var bh = _tagged(w.add_piece("bulkhead", R(5.85, -2.1, 6.15, 0.3), {"density": 1.2, "barrier": true, "cut_speed": 260.0, "tag": "BH-AM"}))
	_bolt(bh, at(6.0, -2.25, ["hull"]), 6.0, -2.1, "weld")
	_bolt(dr, bh, 6.0, 0.3, "weld")


# ---------------------------------------------------------------- the open aft deck, the A-frame, the thruster pod

static func _deck() -> void:
	var keel = by_tag["KEEL"]
	var dk = _tagged(w.add_piece("deck", R(12.0, 2.0, 15.6, 2.6), {"density": 1.1, "cut_speed": 220.0, "tag": "DECK-T"}))
	_bolt(dk, at(11.85, 2.3, ["hull"]), 12.0, 2.3, "weld")
	for x in [12.8, 14.0, 15.2]:
		_bolt(dk, keel, x, 2.6)
	# the A-frame over the winch: two legs and a head beam with the sheave
	var lt = _tagged(w.add_piece("strut", _mp([Vector2(12.5, 2.0), Vector2(12.8, 2.0), Vector2(13.98, -3.6), Vector2(13.75, -3.6)]), {"density": 1.2, "cut_speed": 200.0, "tag": "AF-1"}))
	var rt = _tagged(w.add_piece("strut", _mp([Vector2(15.25, 2.0), Vector2(15.55, 2.0), Vector2(14.35, -3.6), Vector2(14.12, -3.6)]), {"density": 1.2, "cut_speed": 200.0, "tag": "AF-2"}))
	var hd = _tagged(w.add_piece("beam", R(13.6, -3.95, 14.5, -3.6), {"density": 1.2, "cut_speed": 200.0, "tag": "AF-H"}))
	_bolt(lt, dk, 12.65, 2.0)
	_bolt(rt, dk, 15.4, 2.0)
	_bolt(lt, hd, 13.86, -3.6, "weld")
	_bolt(rt, hd, 14.24, -3.6, "weld")
	# the thruster pod under the keel on two pylons
	var py1 = w.add_piece("strut", R(9.6, 3.15, 10.2, 3.6), {"density": 1.2, "cut_speed": 200.0})
	var py2 = w.add_piece("strut", R(13.4, 3.15, 14.0, 3.6), {"density": 1.2, "cut_speed": 200.0})
	_bolt(py1, keel, 9.9, 3.15)
	_bolt(py2, keel, 13.7, 3.15)
	var pod = _equip("POD-T", "engine_s", Rect2(8.4, 3.6, 6.8, 1.25), {"mass": 0.8, "value": 3000.0, "fragile": 0.3, "name_key": "p_pod"})
	_bolt(pod, py1, 9.9, 3.6)
	_bolt(pod, py2, 13.7, 3.6)


static func _equip(tag: String, art: String, r: Rect2, opts: Dictionary, poly = null):
	var rr := Rect2(r.position * Geom.M, r.size * Geom.M)
	var o := {"art": art, "art_xf": Transform2D(0.0, rr.position), "art_size": rr.size, "tag": tag, "cls": "equip", "dest": "equip", "cut_speed": 140.0}
	o.merge(opts, true)
	var kind := "equip" if o.get("cls", "equip") == "equip" else "fixture"
	var pc = w.add_piece(kind, poly if poly != null else Geom.rect_poly(rr), o)
	return _tagged(pc)


# two bolts down into whatever is under the piece
static func _sit(pc, r: Rect2, type: String = "bolt", n: int = 2) -> void:
	for i in n:
		var x: float = r.position.x + r.size.x * (0.2 + 0.6 * i / maxf(1.0, n - 1.0))
		var host = null
		var y := r.end.y + 0.06
		while host == null and y < r.end.y + 1.0:
			host = at(x, y, ["hull", "rail", "deck", "keel"])
			y += 0.05
		_bolt(pc, host, x, r.end.y, type)


static func _lamp(tag: String, x: float, room: String, y: float, host) -> void:
	var lp = _equip(tag, "lamp", Rect2(x - 0.28, y, 0.56, 0.16), {"cls": "metal", "dest": "metal", "mass": 0.04, "room": room, "cut_speed": 260.0, "name_key": "p_lamp"})
	_bolt(lp, host, x, y)


# ---------------------------------------------------------------- equipment

static func _equipment() -> void:
	var f1 = by_tag["WF-1"]
	var f2 = by_tag["WF-2"]
	# A, the wheelhouse: console, pilot and second seat, the nav computer
	var r := Rect2(1.72, WH_FLOOR - 0.7, 0.58, 0.7)
	var con = _equip("CON-T", "console", r, {"mass": 0.25, "value": 900.0, "fragile": 0.5, "room": "A", "name_key": "p_console"})
	_sit(con, r)
	for i in 2:
		var x0 := 2.35 + i * 0.85
		r = Rect2(x0, WH_FLOOR - 1.45, 0.72, 1.45)
		var sp := PackedVector2Array()
		for q in SEAT_SHAPE:
			sp.append(p(x0 + q.x * 0.72, r.position.y + q.y * 1.45))
		var st = _equip("SEAT-P" if i == 0 else "SEAT-C", "seat", r, {"mass": 0.1, "value": 500.0, "fragile": 0.3, "room": "A", "name_key": "p_seat_p" if i == 0 else "p_seat_c"}, sp)
		_bolt(st, f1, x0 + 0.13, WH_FLOOR)
		_bolt(st, f1, x0 + 0.59, WH_FLOOR)
		_bolt(st, f1, x0 + 0.36, WH_FLOOR, "lock")
	r = Rect2(4.62, WH_FLOOR - 0.9, 0.42, 0.9)
	var nav = _equip("NAV-T", "nav", r, {"mass": 0.25, "value": 4000.0, "fragile": 0.85, "room": "A", "name_key": "p_nav"})
	_bolt(nav, f2, 4.72, WH_FLOOR)
	_bolt(nav, f2, 4.95, WH_FLOOR)
	# A, the cabin below: the recorder, an oxygen bottle, the air unit, a locker
	r = Rect2(2.6, FLOOR - 0.62, 0.62, 0.62)
	var fdr = _equip("FDR-T", "blackbox", r, {"mass": 0.08, "value": 1500.0, "fragile": 0.2, "room": "A", "mandatory": true, "name_key": "p_blackbox"})
	_sit(fdr, r)
	r = Rect2(3.45, FLOOR - 1.55, 0.42, 1.55)
	var o2 = _equip("O2-T", "gastank", r, {"mass": 0.2, "value": 800.0, "fragile": 0.3, "room": "A", "hazard": "gas_tank", "name_key": "p_gastank"})
	_sit(o2, r)
	r = Rect2(4.65, FLOOR - 1.3, 1.1, 1.3)
	var env = _equip("ENV-T", "env", r, {"mass": 0.3, "value": 1200.0, "fragile": 0.5, "room": "A", "name_key": "p_env"})
	_sit(env, r)
	r = Rect2(1.3, FLOOR - 1.8, 1.0, 1.8)
	var lk = _equip("LOCK-T", "locker", r, {"cls": "metal", "dest": "metal", "mass": 0.2, "room": "A", "cut_speed": 260.0, "name_key": "p_locker"})
	_sit(lk, r)
	_lamp("LAMP-A", 2.4, "A", WH_FLOOR + 0.15, f1)
	# M, the engine room: engine, battery, the switchboard, the fuel tank
	r = Rect2(6.5, FLOOR - 2.7, 3.0, 2.7)
	var eng = _equip("ENG-T", "eng_core", r, {"mass": 0.9, "value": 5000.0, "fragile": 0.3, "room": "M", "name_key": "p_engt"})
	_sit(eng, r, "bolt", 3)
	var top := -2.1
	r = Rect2(9.5, top, 1.4, 1.0)
	var bat = _equip("BAT-T", "battery", r, {"mass": 0.4, "value": 2000.0, "fragile": 0.4, "room": "M", "hazard": "battery", "name_key": "p_battery"})
	_bolt(bat, at(9.8, -2.25, ["hull"]), 9.8, top)
	_bolt(bat, at(10.6, -2.25, ["hull"]), 10.6, top)
	r = Rect2(11.1, top, 0.55, 1.6)
	var swb = _equip("SWB-T", "swb", r, {"mass": 0.15, "value": 700.0, "fragile": 0.4, "room": "M", "name_key": "p_s_swb"})
	_bolt(swb, at(11.85, -1.6, ["hull"]), 11.65, -1.6)
	_bolt(swb, at(11.85, -0.8, ["hull"]), 11.65, -0.8)
	r = Rect2(9.8, FLOOR - 1.7, 1.8, 1.7)
	var ft = _equip("FT-T", "fueltank", r, {"mass": 0.3, "value": 1000.0, "fragile": 0.35, "room": "M", "hazard": "fuel_tank", "name_key": "p_fueltank"})
	_sit(ft, r, "lock")
	_lamp("LAMP-M", 8.2, "M", top, at(8.2, -2.25, ["hull"]))
	# T, the aft deck: the winch under the A-frame, two bolts and two locks
	r = Rect2(13.3, 0.4, 1.5, 1.6)
	var wn = _equip("WINCH-T", "reel", r, {"mass": 1.2, "value": 9000.0, "fragile": 0.3, "mandatory": true, "name_key": "p_winch"})
	_bolt(wn, by_tag["DECK-T"], 13.5, 2.0)
	_bolt(wn, by_tag["DECK-T"], 14.6, 2.0)
	_bolt(wn, by_tag["DECK-T"], 13.4, 2.0, "lock")
	_bolt(wn, by_tag["DECK-T"], 14.7, 2.0, "lock")
	# the outside switch panel on the roof over M: the battery switch and a test point
	r = Rect2(8.0, -2.95, 1.6, 0.55)
	var pn = _equip("PNL-T", "panel", r, {"cls": "metal", "dest": "metal", "mass": 0.08, "cut_speed": 240.0, "name_key": "p_panel"})
	_bolt(pn, at(8.3, -2.25, ["hull"]), 8.3, -2.4)
	_bolt(pn, at(9.3, -2.25, ["hull"]), 9.3, -2.4)


static func _line(id: String, kind: String, net: String, a: String, pa: Vector2, b: String, pb: Vector2, via: Array = []) -> void:
	var pts: Array = [pa]
	pts.append_array(via)
	pts.append(pb)
	w.add_line(id, kind, net, by_tag[a], pa * Geom.M, by_tag[b], pb * Geom.M, _mp(pts))


static func _lines() -> void:
	# power: the battery into the switchboard; out to the engine, the nav computer, the winch and the lamps
	_line("c1", "cable", "power", "BAT-T", Vector2(10.9, -1.6), "SWB-T", Vector2(11.1, -1.6))
	_line("c2", "cable", "power", "SWB-T", Vector2(11.2, -0.55), "ENG-T", Vector2(9.4, -0.3), [Vector2(11.2, -0.3)])
	_line("c3", "cable", "power", "SWB-T", Vector2(11.3, -2.05), "NAV-T", Vector2(4.95, -2.9), [Vector2(11.3, -1.95), Vector2(5.4, -1.95), Vector2(5.4, -2.9)])
	_line("c4", "cable", "power", "SWB-T", Vector2(11.55, -0.55), "WINCH-T", Vector2(13.4, 0.6), [Vector2(11.55, -0.1), Vector2(12.4, -0.1), Vector2(12.4, 0.6)])
	_line("c5", "cable", "power", "SWB-T", Vector2(11.4, -2.05), "LAMP-M", Vector2(8.4, -2.0), [Vector2(11.4, -2.0)])
	_line("c6", "cable", "power", "LAMP-M", Vector2(8.0, -2.0), "LAMP-A", Vector2(2.6, -2.2), [Vector2(6.3, -2.0), Vector2(6.3, -1.85), Vector2(3.4, -1.85), Vector2(3.4, -2.2)])
	# fuel: the tank to the engine, and down through the keel to the pod
	_line("p1", "pipe", "fuel", "FT-T", Vector2(9.85, 1.4), "ENG-T", Vector2(9.45, 1.4))
	_line("p2", "pipe", "fuel", "FT-T", Vector2(10.7, 2.25), "POD-T", Vector2(11.0, 3.65), [Vector2(10.7, 3.4), Vector2(11.0, 3.4)])


static func _ctrl(id: String, kind: String, piece, pos: Vector2, opts: Dictionary = {}) -> void:
	w.add_ctrl(id, kind, piece, pos * Geom.M, opts)


static func _controls() -> void:
	_ctrl("GAS-A", "port", at(3.2, -4.35, ["hull"]), Vector2(3.2, -4.6), {"medium": "gas", "target": "A"})
	_ctrl("GAS-M", "port", at(7.2, -2.25, ["hull"]), Vector2(7.2, -2.5), {"medium": "gas", "target": "M"})
	var pn = by_tag["PNL-T"]
	_ctrl("K-T", "switch", pn, Vector2(8.35, -2.68), {"target": "K-T", "state": true})
	_ctrl("E-T01", "test", pn, Vector2(8.85, -2.68), {"medium": "volt", "target": "bus"})
	_ctrl("O2-P", "port", by_tag["O2-T"], Vector2(3.66, FLOOR - 1.5), {"medium": "gas", "target": "O2", "hidden_room": "A"})
	_ctrl("FUEL-T", "port", by_tag["FT-T"], Vector2(11.2, FLOOR - 0.2), {"medium": "fuel", "target": "fuel", "hidden_room": "M"})
	for d in ["DR-AM", "HATCH-A"]:
		var dp = by_tag[d]
		var c := Geom.centroid(dp.poly) / Geom.M
		_ctrl(d, "door", dp, c, {"target": d, "state": false})


static func _rooms() -> void:
	var ip := PackedVector2Array()
	for q in inner:
		ip.append(q * Geom.M)
	var a: Array = Geometry2D.intersect_polygons(ip, R(-1.0, -5.0, 5.85, 3.0))
	var m: Array = Geometry2D.intersect_polygons(ip, R(6.15, -5.0, 13.0, 3.0))
	w.add_room("A", a[0])
	w.add_room("M", m[0])


static func meta() -> Dictionary:
	return {
		"id": "tug",
		"name": "TUG",
		"title": ["作业艇 · 16 m", "WORK TUG · 16 m"],
		"contract": "TUG-001",
		"length": 16.0,
		"value": {"total": 33700.0, "metal": 3000.0},
		"clamps": [[3.0, 3.15], [7.2, 3.15]],
		"room_names": {"A": "room_tA", "M": "room_tM"},
		"gas": {
			"rooms": {"A": 101.0, "M": 98.0},
			"vessels": {"O2": {"V": 0.03, "kpa": 1400.0, "piece": "O2-T", "burst": 200.0}},
			"valves": [],
			"value": 300.0,
		},
		"power": {
			"bus": "SWB-T",
			"sources": [{"piece": "BAT-T", "kind": "battery", "volts": 48.0, "local_volts": 48.0, "cable": "c1", "switch": "K-T", "charge": 0.9, "drain": 0.0004}],
			"isolated": [],
			"lamps": {"A": "LAMP-A", "M": "LAMP-M"},
		},
		"fluids": {
			"volumes": {
				"fuel": {"fluid": "fuel", "amount": 0.12, "piece": "FT-T", "content": 1.0, "leak": 0.1, "port": "FUEL-T", "pump": [0.12, 0.008], "hazard": 0.02},
				"fuel_line": {"fluid": "fuel", "amount": 0.01, "nets": ["fuel"], "leak": 0.05, "leak_min": 0.005},
			},
			"joins": [],
			"value": {"fuel": 300.0},
		},
		"ctrls_cfg": {
			"GAS-A": {"rate": 9.0},
			"GAS-M": {"rate": 9.0},
			"O2-P": {"rate": 0.2},
		},
		"labels": {"O2-T": "O₂", "FT-T": "FUEL", "WINCH-T": "WINCH", "ENG-T": "ENGINE"},
		"hints": {},
		# what a market contract may find changed on a tug, and where the accident templates fit
		"market": {
			"class": "WT", "name": ["作业艇", "WORK TUG"], "time": 10.0,
			"rooms": {"A": [0.25, 60.0, 101.0], "M": [0.3, 50.0, 100.0]},
			"vessels": {"O2": [0.3, 20.0, 140.0, 900.0, 1500.0]},
			"charge": {"BAT-T": [0.15, 1.0]},
			"fluids": {"fuel": [0.02, 0.14]}, "fill": {"fuel_line": "fuel"},
			"knockable": ["CON-T", "NAV-T", "ENV-T", "ENG-T", "POD-T"],
			"drift": ["ENV-T", "O2-T", "FT-T"],
			"section_x": 6.0,
			"slots": {
				"hidden_tank": {"x": [[6.6, "TOP-1"]], "y0": -1.9, "y1": -0.55, "base_y": -2.1, "room": "M"},
				"fire_system": {"x": 2.75, "y0": -2.25, "y1": -0.85, "base": ["WF-1", -2.25], "room": "A", "port": [3.15, -1.0]},
				"second_source": {"at": [9.6, -1.1], "size": [1.3, 1.7], "base": [["BAT-T", 10.0, -1.1], ["FT-T", 10.6, 0.6]], "room": "M",
					"bus": "SWB-T", "path": [[10.85, -0.6], [11.2, -0.6]], "switch_at": [9.9, -0.7], "proc": "WINCH-T", "test": "E-T01", "volts": 48.0},
				"hidden_damage": {"plates": ["TOP-1", "TOP-2", "TOP-3"]},
			},
		},
		"procedures": {
			"FDR-T": [
				{"do": "hose", "ctrl": "GAS-A"},
				{"do": "wait", "until": {"P": ["A", "<", 5.0]}, "max": 120.0},
				{"do": "operate", "ctrl": "HATCH-A"},
				{"do": "wait", "until": {"open": ["A"]}, "max": 5.0},
				{"do": "free", "piece": "FDR-T"},
				{"do": "deliver", "piece": "FDR-T", "zone": "equip"},
			],
			"WINCH-T": [
				{"do": "operate", "ctrl": "K-T"},
				{"do": "measure", "ctrl": "E-T01", "expect": ["<", 1.0]},
				{"do": "free", "piece": "WINCH-T"},
				{"do": "deliver", "piece": "WINCH-T", "zone": "equip"},
			],
		},
		"blueprint": {
			"hide": ["LAMP-A", "LAMP-M", "WF-1", "WF-2", "LADDER", "PNL-T"],
		},
	}
