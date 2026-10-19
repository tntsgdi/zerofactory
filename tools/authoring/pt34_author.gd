class_name Pt34Author
# Authoring script for PT-34 "Falcon", the 134 m retired patrol warship
# (design/ships/PT-34_隼鹰_设计稿.md, structure: design/ships/PT-34_结构图.png;
# the player's "super frigate", fleet expansion 2026-10-19).
# Not part of the game: tools/ship_export.gd runs it and writes ships/pt34.json.
# Metres, x bow (0) to stern (134), y down; the keel line is y = 0.
#
# A warship is not a big freighter. What it asks of you is finding the way in:
#   - a ring of armour round it all, cutting at a fifth of the speed of hull
#     plate, and fixings bolted to the inside of it that only show (to the
#     precision kit, or once a plate is off) when you look for them;
#   - two maintenance tunnels between the armour and the pressure hull, the
#     only way to much of the ship without cutting armour, reached through
#     hatches at their ends; in the upper one, the control lines of the
#     thrust-vector rams, live off the B grid, to be locked before they're cut;
#   - two power grids: the outside panel's breaker kills grid A; grid B runs
#     off the backup generator aft and a battery in the lower deck, and only
#     its own breakers inside kill it;
#   - weapon capacitors and the close-in gun's capacitor that nothing outside
#     can bleed: their discharge points are inside, by the weapons' panel;
#   - munitions that go off: 39 shells in an armoured magazine (a flood valve
#     makes them safe and worthless), five missiles in their launch cells,
#     two in the bow tubes and two reloads, six in the back launcher, two
#     decoy launchers, four drums of close-in rounds. The beam's heat cooks
#     them, a hard knock sets them off, and one sets off the next.

const TA := 0.7                  # armour
const TP := 0.4                  # pressure hull, bulkheads
const OUT := [Vector2(0.0, 1.0), Vector2(16.0, -7.0), Vector2(37.0, -7.0), Vector2(38.0, -7.6), Vector2(110.0, -7.6), Vector2(116.0, -6.4),
	Vector2(120.0, -6.4), Vector2(120.0, 7.4), Vector2(116.0, 7.4), Vector2(110.0, 8.8), Vector2(38.0, 8.8), Vector2(16.0, 6.8)]
# the pressure hull and its tunnels, from the forward bulkhead to the aft one
const X0 := 38.4
const X1 := 109.6
const TU0 := -6.9                # upper tunnel: under the armour to the pressure hull's top
const PHT := -5.5
const IN_T := -5.1               # inside: the upper deck's ceiling
const DECK_U := -1.4             # the upper deck's floor (plate to -1.1)
const DECK_L := 2.5              # the middle deck's floor (plate to 2.8)
const IN_B := 6.3                # the lower deck's floor
const PHB := 6.7
const TL1 := 8.1
const VLS := [[28.0, 29.3], [29.7, 31.0], [31.4, 32.7], [33.1, 34.4], [34.8, 36.1]]
const SEAT_SHAPE := [Vector2(0.02, 1.0), Vector2(0.98, 1.0), Vector2(0.98, 0.92), Vector2(0.6, 0.92), Vector2(0.6, 0.75), Vector2(0.78, 0.72),
	Vector2(1.0, 0.18), Vector2(1.0, 0.02), Vector2(0.86, 0.0), Vector2(0.82, 0.15), Vector2(0.6, 0.63), Vector2(0.02, 0.64),
	Vector2(0.02, 0.75), Vector2(0.38, 0.75), Vector2(0.38, 0.92), Vector2(0.02, 0.92)]

static var w
static var by_tag := {}
static var shells: Array = []


static func p(x: float, y: float) -> Vector2:
	return Vector2(x * Geom.M, y * Geom.M)


static func R(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return Geom.rect_poly(Geom.mrect(minf(x0, x1), minf(y0, y1), maxf(x0, x1), maxf(y0, y1)))


static func _mp(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(q * Geom.M)
	return out


static func _inner(outer: Array, t: float) -> Array:
	var n := outer.size()
	var out: Array = []
	for i in n:
		var a: Vector2 = outer[(i - 1 + n) % n]
		var b: Vector2 = outer[i]
		var c: Vector2 = outer[(i + 1) % n]
		var d1 := (b - a).normalized()
		var d2 := (c - b).normalized()
		var n1 := Vector2(-d1.y, d1.x)
		var n2 := Vector2(-d2.y, d2.x)
		var hit = Geometry2D.line_intersects_line(a + n1 * t, d1, b + n2 * t, d2)
		out.append(hit if hit != null else b + n1 * t)
	return out


static func _tagged(pc):
	if pc != null and pc.tag != "":
		by_tag[pc.tag] = pc
	return pc


static func _bolt(a, b, x: float, y: float, type: String = "bolt", tag: String = "") -> void:
	if a == null or b == null:
		push_warning("PT34 joint missing a piece at %s,%s" % [x, y])
		return
	var j = w.add_joint(a, b, type, p(x, y))
	if tag != "":
		j.set_meta("tag", tag)


static func at(x: float, y: float, kinds: Array = []):
	return w.piece_at(p(x, y), kinds)


static func _equip(tag: String, art: String, r: Rect2, opts: Dictionary, poly = null):
	var rr := Rect2(r.position * Geom.M, r.size * Geom.M)
	var o := {"art": art, "art_xf": Transform2D(0.0, rr.position), "art_size": rr.size, "tag": tag, "cls": "equip", "dest": "equip", "cut_speed": 140.0}
	o.merge(opts, true)
	var kind := "equip" if o.get("cls", "equip") == "equip" else "fixture"
	return _tagged(w.add_piece(kind, poly if poly != null else Geom.rect_poly(rr), o))


static func _plate(tag: String, r: PackedVector2Array, opts: Dictionary, kind: String = "hull"):
	var o := {"density": 1.4, "barrier": true, "cut_speed": 220.0, "tag": tag}
	o.merge(opts, true)
	if o.get("art", "") != "" and o.art != "window" and not o.has("art_size"):
		var bb := Geom.bbox(r)
		o.art_xf = Transform2D(0.0, bb.position)
		o.art_size = bb.size
	return _tagged(w.add_piece(kind, r, o))


static func _rect(x0: float, y0: float, x1: float, y1: float) -> Rect2:
	return Rect2(minf(x0, x1), minf(y0, y1), absf(x1 - x0), absf(y1 - y0))


# ---------------------------------------------------------------- build

static func build(world) -> void:
	w = world
	by_tag = {}
	shells = []
	_armour()
	_inner_hull()
	_bridge()
	_forward()
	_magazine()
	_under_bridge()
	_central()
	_reactor()
	_stern()
	_outside()
	_lines()
	_controls()
	_rooms()


static func rooms_only(world) -> void:
	w = world
	_rooms()


# ---------------------------------------------------------------- the armour ring

# The armour: a ring of thick plates round the outline, each welded to the
# next; specials make hatches of some of them. Every plate is tagged AR<edge>-<k>.
static func _armour() -> void:
	var splits := {
		0: [0.5],
		1: [0.381, 0.5714, 0.6333, 0.6524, 0.7143, 0.7333, 0.7952, 0.8143, 0.8762, 0.8952, 0.9571],
		3: [0.01389, 0.03611, 0.1111, 0.1944, 0.2778, 0.3611, 0.4444, 0.5278, 0.6111, 0.6944, 0.7778, 0.8611, 0.9444],
		6: [0.5],
		9: [0.02778, 0.04861, 0.0833, 0.1667, 0.25, 0.3333, 0.4167, 0.5, 0.5833, 0.6667, 0.75, 0.8333, 0.9167],
		10: [0.5],
		11: [0.5],
	}
	var specials := {
		"3:1": {"kind": "hatch", "door": true, "tag": "HT-U", "open_dir": Vector2(1.7, 0) * Geom.M, "art": "", "cut_speed": 120.0},
		"9:1": {"kind": "hatch", "door": true, "tag": "HT-L", "open_dir": Vector2(-1.6, 0) * Geom.M, "art": "", "cut_speed": 120.0},
	}
	for i in VLS.size():
		specials["1:%d" % (2 + i * 2)] = {"kind": "hatch", "door": true, "tag": "VH-%d" % (i + 1), "open_dir": Vector2(0, -1.4) * Geom.M, "art": "", "cut_speed": 120.0}
	var base := {"density": 2.6, "barrier": true, "cut_speed": 44.0, "art": "armor", "name_key": "p_armor"}
	var outer: Array = OUT
	var inner := _inner(outer, TA)
	var n := outer.size()
	var prev = null
	var first = null
	for i in n:
		var o0: Vector2 = outer[i]
		var o1: Vector2 = outer[(i + 1) % n]
		var i0: Vector2 = inner[i]
		var i1: Vector2 = inner[(i + 1) % n]
		var st: Array = [0.0]
		st.append_array(splits.get(i, []))
		st.append(1.0)
		for k in st.size() - 1:
			var a := o0.lerp(o1, st[k])
			var b := o0.lerp(o1, st[k + 1])
			var c := i0.lerp(i1, st[k + 1])
			var d := i0.lerp(i1, st[k])
			var opts: Dictionary = base.duplicate()
			opts.tag = "AR%d-%d" % [i, k]
			var kind := "hull"
			var sp: Dictionary = specials.get("%d:%d" % [i, k], {})
			if not sp.is_empty():
				kind = sp.get("kind", "hull")
				opts.merge(sp, true)
				opts.erase("kind")
				opts.erase("name_key")
			var q := _mp([a, b, c, d])
			if opts.get("art", "") != "":
				var bb := Geom.bbox(q)
				opts.art_xf = Transform2D(0.0, bb.position)
				opts.art_size = bb.size
			var pc = _tagged(w.add_piece(kind, q, opts))
			if prev != null:
				w.add_joint(prev, pc, "weld", a.lerp(d, 0.3) * Geom.M)
				w.add_joint(prev, pc, "weld", a.lerp(d, 0.7) * Geom.M)
			else:
				first = pc
			prev = pc
	w.add_joint(prev, first, "weld", outer[0].lerp(inner[0], 0.3) * Geom.M)
	w.add_joint(prev, first, "weld", outer[0].lerp(inner[0], 0.7) * Geom.M)
	# clamped to the berth along the keel
	var ci := 0
	for cl in [[20.0, 7.16], [48.0, 8.8], [80.0, 8.8], [102.0, 8.8]]:
		ci += 1
		var j = w.add_joint(at(cl[0], cl[1] - 0.2, ["hull"]), null, "clamp", p(cl[0], cl[1]))
		j.set_meta("tag", "CL-%02d" % ci)


# ---------------------------------------------------------------- pressure hull, tunnels, decks, bulkheads

static func _inner_hull() -> void:
	var S := {"density": 1.4, "barrier": true, "cut_speed": 220.0}
	# forward bulkhead (the weapons bay W forward of it), a door on the middle deck
	var fbt = _plate("FB-T", R(38.0, TU0, X0, -0.8), S)
	var fbb = _plate("FB-B", R(38.0, 2.2, X0, TL1), S)
	var drw = _plate("DR-W", R(38.0, -0.8, X0, 2.2), {"density": 1.2, "door": true, "open_dir": Vector2(0, -2.0) * Geom.M, "cut_speed": 200.0}, "door")
	_bolt(fbt, at(38.2, TU0 - 0.2, ["hull"]), 38.2, TU0, "weld")
	_bolt(fbb, at(38.2, TL1 + 0.2, ["hull"]), 38.2, TL1, "weld")
	_bolt(drw, fbt, 38.2, -0.8, "weld")
	_bolt(drw, fbb, 38.2, 2.2, "weld")
	# aft bulkhead: the stern beyond it is open to space, a door through it from the auxiliary room
	var abt = _plate("AB-T", R(X1, TU0, 110.0, 0.0), S)
	var abb = _plate("AB-B", R(X1, 2.5, 110.0, TL1), S)
	var drs = _plate("DR-ST", R(X1, 0.0, 110.0, 2.5), {"density": 1.2, "door": true, "open_dir": Vector2(0, -2.0) * Geom.M, "cut_speed": 200.0}, "door")
	_bolt(abt, at(109.8, TU0 - 0.2, ["hull"]), 109.8, TU0, "weld")
	_bolt(abb, at(109.8, TL1 + 0.2, ["hull"]), 109.8, TL1, "weld")
	_bolt(drs, abt, 109.8, 0.0, "weld")
	_bolt(drs, abb, 109.8, 2.5, "weld")
	# the pressure hull's top and bottom (the tunnels outside them), with the tunnels' hatches into the rooms
	var top := [[X0, 50.0, "PHT-1"], [50.0, 51.6, "DR-TU1"], [51.6, 56.0, "PHT-2"], [56.0, 88.0, "PHT-3"], [88.0, 89.6, "DR-TU2"], [89.6, 96.0, "PHT-4"], [96.0, 103.0, "PHT-5"], [103.0, 104.6, "DR-TU3"], [104.6, X1, "PHT-6"]]
	var bot := [[X0, 56.0, "PHB-1"], [56.0, 90.0, "PHB-2"], [90.0, 91.6, "DR-TL1"], [91.6, 100.0, "PHB-3"], [100.0, 101.6, "DR-TL2"], [101.6, X1, "PHB-4"]]
	for row in [[top, PHT, IN_T, Vector2(1.5, 0)], [bot, IN_B, PHB, Vector2(1.5, 0)]]:
		var prev = null
		for seg in row[0]:
			var tg: String = seg[2]
			var door: bool = tg.begins_with("DR-")
			var pc = _plate(tg, R(seg[0], row[1], seg[1], row[2]), S.merged({"density": 1.2, "door": true, "open_dir": row[3] * Geom.M, "cut_speed": 200.0}) if door else S, "hatch" if door else "hull")
			if prev != null:
				_bolt(prev, pc, seg[0], (row[1] + row[2]) * 0.5, "weld")
			prev = pc
	# the ends of the pressure hull weld to the bulkheads
	_bolt(by_tag["PHT-1"], fbt, X0, (PHT + IN_T) * 0.5, "weld")
	_bolt(by_tag["PHB-1"], fbb, X0, (IN_B + PHB) * 0.5, "weld")
	_bolt(by_tag["PHT-6"], abt, X1, (PHT + IN_T) * 0.5, "weld")
	_bolt(by_tag["PHB-4"], abb, X1, (IN_B + PHB) * 0.5, "weld")
	# frames across the tunnels hold the pressure hull off the armour
	for fx in [46.0, 62.0, 78.0, 94.0, 98.5]:
		var ft = _plate("", R(fx, TU0, fx + 0.3, PHT), {"density": 1.0, "barrier": false, "cut_speed": 200.0}, "rib")
		_bolt(ft, at(fx + 0.15, TU0 - 0.2, ["hull"]), fx + 0.15, TU0, "weld")
		_bolt(ft, at(fx + 0.15, PHT + 0.2, ["hull"]), fx + 0.15, PHT, "weld")
		var fb = _plate("", R(fx, PHB, fx + 0.3, TL1), {"density": 1.0, "barrier": false, "cut_speed": 200.0}, "rib")
		_bolt(fb, at(fx + 0.15, PHB - 0.2, ["hull"]), fx + 0.15, PHB, "weld")
		_bolt(fb, at(fx + 0.15, TL1 + 0.2, ["hull"]), fx + 0.15, TL1, "weld")
	# the two decks, forward and central lengths
	for d in [["DKU-1", X0, 56.0, DECK_U], ["DKU-2", 56.4, 96.0, DECK_U], ["DKL-1", X0, 56.0, DECK_L], ["DKL-2", 56.4, 96.0, DECK_L]]:
		var dk = _plate(d[0], R(d[1], d[3], d[2], d[3] + 0.3), {"density": 1.1, "barrier": true, "cut_speed": 220.0}, "deck")
		if d[1] == X0:
			_bolt(dk, at(d[1] - 0.15, d[3] + 0.15, ["hull", "door", "bulkhead"]), d[1], d[3] + 0.15, "weld")
	# transverse bulkheads at 56 and 96, a door on each deck; and between the reactor and the auxiliary room
	for bx in [56.0, 96.0]:
		var parts := [[IN_T, -4.0, ""], [-4.0, DECK_U, "door"], [DECK_U, 0.0, ""], [0.0, DECK_L, "door"], [DECK_L, 3.8, ""], [3.8, IN_B, "door"]]
		var prev2 = null
		var k := 0
		for q in parts:
			var tg2 := ""
			var isd: bool = q[2] == "door"
			if isd:
				k += 1
				tg2 = "D%d-%d" % [int(bx), k]
			var pc2 = _plate(tg2, R(bx, q[0], bx + 0.4, q[1]), {"density": 1.2, "door": true, "open_dir": Vector2(0, -1.6 if k != 3 else 1.6) * Geom.M, "cut_speed": 200.0} if isd else S, "door" if isd else "bulkhead")
			if prev2 != null:
				_bolt(prev2, pc2, bx + 0.2, q[0], "weld")
			else:
				_bolt(pc2, at(bx + 0.2, IN_T - 0.2, ["hull"]), bx + 0.2, IN_T, "weld")
			prev2 = pc2
		_bolt(prev2, at(bx + 0.2, IN_B + 0.2, ["hull"]), bx + 0.2, IN_B, "weld")
	for dk1 in ["DKU-1", "DKL-1"]:
		var yy: float = (DECK_U if dk1 == "DKU-1" else DECK_L) + 0.15
		_bolt(by_tag[dk1], at(56.2, yy, ["bulkhead"]), 56.0, yy, "weld")
	for dk2 in ["DKU-2", "DKL-2"]:
		var dd = by_tag[dk2]
		_bolt(dd, at(56.2, (DECK_U if dk2 == "DKU-2" else DECK_L) + 0.15, ["bulkhead"]), 56.4, (DECK_U if dk2 == "DKU-2" else DECK_L) + 0.15, "weld")
		_bolt(dd, at(96.2, (DECK_U if dk2 == "DKU-2" else DECK_L) + 0.15, ["bulkhead"]), 96.0, (DECK_U if dk2 == "DKU-2" else DECK_L) + 0.15, "weld")
	var rx1 = _plate("", R(105.6, IN_T, 106.0, 0.0), S, "bulkhead")
	var drx = _plate("DR-RX", R(105.6, 0.0, 106.0, DECK_L), {"density": 1.2, "door": true, "open_dir": Vector2(0, -1.8) * Geom.M, "cut_speed": 200.0}, "door")
	var rx2 = _plate("", R(105.6, DECK_L, 106.0, IN_B), S, "bulkhead")
	_bolt(rx1, at(105.8, IN_T - 0.2, ["hull"]), 105.8, IN_T, "weld")
	_bolt(rx2, at(105.8, IN_B + 0.2, ["hull"]), 105.8, IN_B, "weld")
	_bolt(drx, rx1, 105.8, 0.0, "weld")
	_bolt(drx, rx2, 105.8, DECK_L, "weld")


# ---------------------------------------------------------------- the bridge on top

static func _bridge() -> void:
	var S := {"density": 1.2, "barrier": true, "cut_speed": 150.0}
	var bf = _plate("BR-F", _mp([Vector2(41.0, -7.6), Vector2(43.0, -11.8), Vector2(43.45, -11.4), Vector2(41.55, -7.6)]), S.merged({"art": "window"}))
	var r1 = _plate("BR-R1", R(43.0, -11.8, 46.6, -11.4), S)
	var hb = _plate("HATCH-BR", R(46.6, -11.8, 48.4, -11.4), {"density": 1.0, "door": true, "open_dir": Vector2(1.6, 0) * Geom.M, "cut_speed": 150.0}, "hatch")
	var r2 = _plate("BR-R2", R(48.4, -11.8, 54.0, -11.4), S)
	var ba = _plate("BR-A", _mp([Vector2(54.0, -11.8), Vector2(56.0, -7.6), Vector2(55.45, -7.6), Vector2(53.55, -11.4)]), S)
	_bolt(bf, at(41.3, -7.4, ["hull"]), 41.3, -7.6, "weld")
	_bolt(ba, at(55.7, -7.4, ["hull"]), 55.7, -7.6, "weld")
	_bolt(r1, bf, 43.1, -11.6, "weld")
	_bolt(hb, r1, 46.6, -11.6, "weld")
	_bolt(hb, r2, 48.4, -11.6, "weld")
	_bolt(r2, ba, 53.9, -11.6, "weld")
	var flo := -7.6
	for i in 3:
		var sx := 43.8 + i * 2.6
		var r := Rect2(sx, flo - 1.6, 0.8, 1.6)
		var sp := PackedVector2Array()
		for q in SEAT_SHAPE:
			sp.append(p(r.position.x + q.x * r.size.x, r.position.y + q.y * r.size.y))
		var seat = _equip("SEAT-T%d" % (i + 1), "seat", r, {"mass": 0.15, "value": 2000.0, "fragile": 0.3, "room": "BR", "name_key": "p_seat_t"}, sp)
		_bolt(seat, at(sx + 0.2, flo + 0.2, ["hull"]), sx + 0.2, flo)
		_bolt(seat, at(sx + 0.6, flo + 0.2, ["hull"]), sx + 0.6, flo, "lock")
	var cr = _equip("CRYPTO", "cabinet", _rect(51.0, flo - 1.4, 52.2, flo), {"mass": 0.4, "value": 22000.0, "fragile": 0.5, "room": "BR", "mandatory": true, "name_key": "p_crypto"})
	_bolt(cr, at(51.3, flo + 0.2, ["hull"]), 51.3, flo)
	_bolt(cr, at(51.9, flo + 0.2, ["hull"]), 51.9, flo, "lock")
	var fcs = _equip("FCS", "console", _rect(52.4, flo - 2.0, 54.2, flo), {"mass": 0.6, "value": 24000.0, "fragile": 0.5, "room": "BR", "mandatory": true, "name_key": "p_fcs"})
	_bolt(fcs, at(52.8, flo + 0.2, ["hull"]), 52.8, flo)
	_bolt(fcs, at(53.8, flo + 0.2, ["hull"]), 53.8, flo)
	var lb = _equip("LAMP-BR", "lamp", _rect(44.8, -11.4, 45.36, -11.24), {"cls": "metal", "dest": "metal", "mass": 0.04, "room": "BR", "cut_speed": 260.0, "name_key": "p_lamp"})
	_bolt(lb, r1, 45.08, -11.4)
	var mast = _equip("MAST", "", _rect(50.5, -14.8, 51.1, -11.8), {"cls": "metal", "dest": "metal", "mass": 0.3, "cut_speed": 180.0, "name_key": "p_mast"})
	_bolt(mast, r2, 50.8, -11.8, "weld")
	var rd = _equip("RADAR", "radar", _rect(49.0, -15.4, 52.6, -14.8), {"mass": 0.5, "value": 9000.0, "fragile": 0.6, "name_key": "p_radar"},
		_mp([Vector2(49.0, -15.4), Vector2(52.6, -15.4), Vector2(52.0, -14.8), Vector2(49.6, -14.8)]))
	_bolt(rd, mast, 50.8, -14.8)


# ---------------------------------------------------------------- the forward weapons bay W

static func _forward() -> void:
	var deck := -6.3                 # under the forward deck's armour
	# the gun: the mount under the deck, the turret on it, the barrel out of the turret
	var mt = _equip("GUN-MT", "gun_mount", _rect(18.0, deck, 23.0, -4.6), {"mass": 3.0, "value": 12000.0, "fragile": 0.3, "room": "W", "name_key": "p_gun_mount"})
	_bolt(mt, at(18.6, deck - 0.2, ["hull"]), 18.6, deck)
	_bolt(mt, at(22.4, deck - 0.2, ["hull"]), 22.4, deck)
	var tu = _equip("TURRET", "turret", _rect(17.5, -9.2, 24.0, -7.0), {"mass": 6.5, "value": 28000.0, "fragile": 0.25, "cut_speed": 60.0, "name_key": "p_turret"},
		_mp([Vector2(17.5, -7.0), Vector2(18.5, -8.8), Vector2(22.5, -9.2), Vector2(24.0, -8.4), Vector2(24.0, -7.0)]))
	# 6.5 t: the crane lifts it whole, a grapple takes it in two halves along its marked line
	tu.set_meta("segments", [[21.0, -9.3, 21.0, -6.95]])
	_bolt(tu, at(19.0, -6.8, ["hull"]), 19.0, -7.0)
	_bolt(tu, at(23.2, -6.8, ["hull"]), 23.2, -7.0)
	# a third fixing, to the plate under it, sits under the next plate's edge: nothing to see
	# until that plate is off (the precision kit tells it is there)
	_bolt(tu, at(23.9, -6.85, ["hull"]), 24.08, -6.95, "bolt", "HF-1")
	var gb = _equip("GUN-B", "barrel", _rect(7.0, -8.5, 18.7, -8.0), {"mass": 1.5, "value": 6000.0, "fragile": 0.2, "cut_speed": 70.0, "name_key": "p_gun_barrel"})
	_bolt(gb, tu, 18.45, -8.25)
	# the ammunition hoist from the magazine up to the mount, the weapons' cooling beside it
	var ho = _equip("HOIST", "", _rect(26.2, deck, 27.2, 2.4), {"mass": 1.2, "value": 6000.0, "fragile": 0.35, "room": "W", "name_key": "p_hoist"})
	_bolt(ho, at(26.7, deck - 0.2, ["hull"]), 26.7, deck)
	var wc = _equip("WCOOL", "radiator", _rect(22.0, -1.2, 26.2, 0.0), {"mass": 0.8, "value": 6000.0, "fragile": 0.4, "room": "W", "name_key": "p_wcool"})
	_bolt(wc, ho, 26.2, -0.6)
	var lw = _equip("LAMP-W", "lamp", _rect(24.7, deck, 25.26, deck + 0.16), {"cls": "metal", "dest": "metal", "mass": 0.04, "room": "W", "cut_speed": 260.0, "name_key": "p_lamp"})
	_bolt(lw, at(24.98, deck - 0.2, ["hull"]), 24.98, deck)
	# five launch cells under the forward deck's hatches, a missile standing in each
	for i in VLS.size():
		var x0: float = VLS[i][0]
		var x1: float = VLS[i][1]
		var wl = _plate("", R(x0 - 0.15, deck, x0, 1.6), {"density": 1.0, "barrier": false, "cut_speed": 180.0}, "rib")
		var wr = _plate("", R(x1, deck, x1 + 0.15, 1.6), {"density": 1.0, "barrier": false, "cut_speed": 180.0}, "rib")
		var bs = _equip("VLS-%d" % (i + 1), "", _rect(x0 - 0.15, 1.6, x1 + 0.15, 1.9), {"mass": 0.5, "value": 4000.0, "fragile": 0.3, "room": "W", "name_key": "p_vls"})
		_bolt(wl, at(x0 - 0.075, -6.85, ["hull"]), x0 - 0.075, deck, "weld")
		_bolt(wr, at(x1 + 0.075, -6.85, ["hull"]), x1 + 0.075, deck, "weld")
		_bolt(bs, wl, x0 - 0.075, 1.6)
		_bolt(bs, wr, x1 + 0.075, 1.6)
		var ms = _equip("MSL-%d" % (i + 1), "missile", _rect(x0 + 0.2, -6.0, x1 - 0.2, 1.5), {"mass": 1.2, "value": 4000.0, "fragile": 0.2, "room": "W", "hazard": "explosive", "dest": "hazard", "name_key": "p_missile"})
		_bolt(ms, bs, (x0 + x1) * 0.5, 1.5, "lock")
	# the bow tubes: two rails each, a missile between them; a frame aft holds them
	var tf = _plate("", R(21.0, 0.2, 21.4, 6.5), {"density": 1.2, "barrier": false, "cut_speed": 180.0}, "rib")
	_bolt(tf, at(21.2, 6.75, ["hull"]), 21.2, 6.6, "weld")
	for t in 2:
		var y0 := 0.3 + t * 1.6
		var ra = _plate("", R(9.0, y0, 21.0, y0 + 0.15), {"density": 1.0, "barrier": false, "cut_speed": 180.0}, "rail")
		var rb = _plate("", R(9.0, y0 + 1.05, 21.0, y0 + 1.2), {"density": 1.0, "barrier": false, "cut_speed": 180.0}, "rail")
		_bolt(ra, tf, 21.0, y0 + 0.075, "weld")
		_bolt(rb, tf, 21.0, y0 + 1.125, "weld")
		var tm = _equip("TUBE-%d" % (t + 1), "missile", _rect(9.5, y0 + 0.2, 20.5, y0 + 1.0), {"mass": 0.9, "value": 3500.0, "fragile": 0.2, "room": "W", "hazard": "explosive", "dest": "hazard", "name_key": "p_torpedo"})
		_bolt(tm, rb, 15.0, y0 + 1.05, "lock")
	# the reload rack under the tubes
	var shelf = _plate("", R(13.0, 4.4, 21.0, 4.55), {"density": 1.0, "barrier": false, "cut_speed": 180.0}, "rail")
	_bolt(shelf, tf, 21.0, 4.475, "weld")
	for r2 in 2:
		var rx := 13.2 + r2 * 3.8
		var rl = _equip("RELOAD-%d" % (r2 + 1), "missile", _rect(rx, 3.55, rx + 3.4, 4.35), {"mass": 0.9, "value": 3500.0, "fragile": 0.2, "room": "W", "hazard": "explosive", "dest": "hazard", "name_key": "p_torpedo"})
		_bolt(rl, shelf, rx + 1.7, 4.4, "lock")


# ---------------------------------------------------------------- the magazine (inside W)

static func _magazine() -> void:
	var A := {"density": 2.2, "barrier": true, "cut_speed": 60.0, "art": "armor", "name_key": "p_mag_wall"}
	var t1 = _plate("MAG-T1", R(26.0, 2.4, 30.0, 2.8), A)
	var hd = _plate("DR-MAG", R(30.0, 2.4, 32.0, 2.8), {"density": 1.6, "door": true, "open_dir": Vector2(2.1, 0) * Geom.M, "cut_speed": 70.0}, "hatch")
	var t2 = _plate("MAG-T2", R(32.0, 2.4, 36.0, 2.8), A)
	# its walls stand on the armour (the magazine's own floor is the armour)
	var lw = _plate("MAG-L", R(26.0, 2.8, 26.4, 7.05), A)
	var rw = _plate("MAG-R", R(35.6, 2.8, 36.0, 7.9), A)
	var bt = _plate("MAG-B", R(26.4, 6.2, 35.6, 6.6), {"density": 1.4, "barrier": false, "cut_speed": 120.0}, "rib")
	_bolt(t1, hd, 30.0, 2.6, "weld")
	_bolt(hd, t2, 32.0, 2.6, "weld")
	_bolt(t1, lw, 26.2, 2.8, "weld")
	_bolt(t2, rw, 35.8, 2.8, "weld")
	_bolt(lw, bt, 26.4, 6.4, "weld")
	_bolt(rw, bt, 35.6, 6.4, "weld")
	_bolt(lw, at(26.2, 7.3, ["hull"]), 26.2, 7.02, "weld")
	_bolt(rw, at(35.8, 8.15, ["hull"]), 35.8, 7.88, "weld")
	# the box stands on two struts off the armour
	for sx in [30.6, 33.6]:
		var su = _plate("", R(sx, 6.6, sx + 0.3, 7.85), {"density": 1.0, "barrier": false, "cut_speed": 200.0}, "strut")
		_bolt(su, bt, sx + 0.15, 6.6, "weld")
		_bolt(su, at(sx + 0.15, 8.05, ["hull"]), sx + 0.15, 7.85, "weld")
	_bolt(t1, by_tag["HOIST"], 26.7, 2.4)
	# three rows of thirteen rounds: two shelves and the floor, a rack lock under each round
	var s1 = _plate("", R(26.4, 3.85, 35.6, 3.97), {"density": 1.0, "barrier": false, "cut_speed": 180.0}, "rail")
	var s2 = _plate("", R(26.4, 5.0, 35.6, 5.12), {"density": 1.0, "barrier": false, "cut_speed": 180.0}, "rail")
	for s in [s1, s2]:
		var sy: float = Geom.bbox(s.poly).position.y / Geom.M
		_bolt(s, lw, 26.4, sy + 0.06, "weld")
		_bolt(s, rw, 35.6, sy + 0.06, "weld")
	var rows := [[s1, 3.85], [s2, 5.0], [bt, 6.2]]
	for ri in rows.size():
		var base = rows[ri][0]
		var by: float = rows[ri][1]
		for i in 13:
			var sx := 26.6 + i * 0.7
			var tg := "SH-%d%02d" % [ri + 1, i + 1]
			var sh = _equip(tg, "shell", _rect(sx, by - 0.92, sx + 0.4, by), {"mass": 0.04, "value": 150.0, "fragile": 0.15, "room": "MAG", "hazard": "explosive", "dest": "hazard", "name_key": "p_shell"})
			_bolt(sh, base, sx + 0.2, by, "lock")
			shells.append(tg)


# ---------------------------------------------------------------- under the bridge: CIC, armoury, damage control

static func _under_bridge() -> void:
	var fu := DECK_U                 # the CIC's floor
	var fm := DECK_L                 # the armoury's floor
	var fl := IN_B                   # damage control's floor
	for i in 3:
		var sx := 42.0 + i * 2.6
		var r := Rect2(sx, fu - 1.6, 0.8, 1.6)
		var sp := PackedVector2Array()
		for q in SEAT_SHAPE:
			sp.append(p(r.position.x + q.x * r.size.x, r.position.y + q.y * r.size.y))
		var seat = _equip("CIC-%d" % (i + 1), "seat", r, {"mass": 0.4, "value": 2200.0, "fragile": 0.3, "room": "CIC", "name_key": "p_cic_seat"}, sp)
		_bolt(seat, by_tag["DKU-1"], sx + 0.2, fu)
		_bolt(seat, by_tag["DKU-1"], sx + 0.6, fu, "lock")
	var cc = _equip("CIC-C", "console", _rect(39.4, fu - 1.5, 41.0, fu), {"mass": 0.4, "value": 5000.0, "fragile": 0.5, "room": "CIC", "name_key": "p_cic"})
	_bolt(cc, by_tag["DKU-1"], 40.2, fu)
	var cr = _equip("CIC-R", "nav_rack", _rect(51.0, -4.6, 53.0, fu), {"mass": 0.4, "value": 9000.0, "fragile": 0.5, "room": "CIC", "name_key": "p_cic_rack"})
	_bolt(cr, by_tag["DKU-1"], 51.5, fu)
	_bolt(cr, by_tag["DKU-1"], 52.5, fu)
	_lamp("LAMP-CIC", 46.0, IN_T, "CIC", by_tag["PHT-1"])
	for i in 4:
		var ax := 40.0 + i * 1.6
		var ar = _equip("ARMORY-%d" % (i + 1), "locker", _rect(ax, fm - 1.8, ax + 1.2, fm), {"mass": 0.3, "value": 3000.0, "fragile": 0.3, "room": "ARM", "name_key": "p_armory"})
		_bolt(ar, by_tag["DKL-1"], ax + 0.3, fm, "lock")
		_bolt(ar, by_tag["DKL-1"], ax + 0.9, fm)
	var cm = _equip("COMMS", "console", _rect(52.0, fm - 1.5, 54.6, fm), {"mass": 0.4, "value": 7000.0, "fragile": 0.5, "room": "ARM", "name_key": "p_comms"})
	_bolt(cm, by_tag["DKL-1"], 52.6, fm)
	_bolt(cm, by_tag["DKL-1"], 54.0, fm)
	_lamp("LAMP-ARM", 47.0, DECK_U + 0.3, "ARM", by_tag["DKU-1"])
	for i in 2:
		var fx := 40.0 + i * 1.6
		var ft = _equip("FOAM-%d" % (i + 1), "gastank", _rect(fx, fl - 2.3, fx + 1.2, fl), {"mass": 0.4, "value": 1500.0, "fragile": 0.3, "room": "DCR", "hazard": "gas_tank", "name_key": "p_foam"})
		_bolt(ft, by_tag["PHB-1"], fx + 0.6, fl, "lock")
	for i in 2:
		var ox := 43.6 + i * 1.0
		var o2 = _equip("O2-%d" % (i + 1), "gastank", _rect(ox, fl - 2.1, ox + 0.6, fl), {"mass": 0.08, "value": 600.0, "fragile": 0.3, "room": "DCR", "hazard": "gas_tank", "name_key": "p_o2bottle"})
		_bolt(o2, by_tag["PHB-1"], ox + 0.3, fl, "lock")
	var dp = _equip("DCP", "pump", _rect(46.4, fl - 1.0, 47.6, fl), {"mass": 0.6, "value": 1500.0, "fragile": 0.4, "room": "DCR", "name_key": "p_dc_pump"})
	_bolt(dp, by_tag["PHB-1"], 47.0, fl)
	var dl = _equip("DCL", "locker", _rect(48.4, fl - 1.7, 49.6, fl), {"mass": 0.3, "value": 1500.0, "fragile": 0.3, "room": "DCR", "name_key": "p_dc_locker"})
	_bolt(dl, by_tag["PHB-1"], 49.0, fl, "lock")
	_lamp("LAMP-DCR", 52.0, DECK_L + 0.3, "DCR", by_tag["DKL-1"])


static func _lamp(tag: String, x: float, y: float, room: String, on) -> void:
	var l = _equip(tag, "lamp", _rect(x - 0.28, y, x + 0.28, y + 0.16), {"cls": "metal", "dest": "metal", "mass": 0.04, "room": room, "cut_speed": 260.0, "name_key": "p_lamp"})
	_bolt(l, on, x, y)


# ---------------------------------------------------------------- the central hull: three decks

static func _central() -> void:
	var fu := DECK_U
	var fm := DECK_L
	var fl := IN_B
	var dku = by_tag["DKU-2"]
	var dkl = by_tag["DKL-2"]
	var phb = by_tag["PHB-2"]
	# upper deck: distribution A and its battery, the sensor racks, eighteen berths, lockers
	var da = _equip("DIST-A", "swb", _rect(57.0, -4.6, 58.6, fu), {"mass": 1.0, "value": 10000.0, "fragile": 0.4, "room": "UP", "name_key": "p_dist_a"})
	_bolt(da, dku, 57.4, fu)
	_bolt(da, dku, 58.2, fu)
	var ba = _equip("BAT-A", "battery", _rect(59.0, fu - 1.2, 60.4, fu), {"mass": 0.8, "value": 5000.0, "fragile": 0.4, "room": "UP", "hazard": "battery", "name_key": "p_battery"})
	_bolt(ba, dku, 59.7, fu)
	for i in 4:
		var sx := 61.6 + i * 1.4
		var se = _equip("SENS-%d" % (i + 1), "nav_rack", _rect(sx, -4.0, sx + 1.1, fu), {"mass": 0.4, "value": 8000.0, "fragile": 0.5, "room": "UP", "name_key": "p_sens"})
		_bolt(se, dku, sx + 0.55, fu)
	var posts: Array = []
	for i in 7:
		var px := 68.6 + i * 2.35
		var po = _plate("", R(px, IN_T, px + 0.15, fu), {"density": 0.8, "barrier": false, "cut_speed": 200.0}, "strut")
		_bolt(po, by_tag["PHT-3"], px + 0.075, IN_T, "weld")
		_bolt(po, dku, px + 0.075, fu, "weld")
		posts.append(po)
	var bn := 0
	for s in 6:
		var bx := 68.75 + s * 2.35
		for tier in 3:
			bn += 1
			var by := -4.6 + tier * 1.15
			var bk = _equip("BERTH-%02d" % bn, "bunk", _rect(bx, by, bx + 2.2, by + 0.45), {"mass": 0.15, "value": 500.0, "fragile": 0.3, "room": "UP", "name_key": "p_bunk"})
			_bolt(bk, posts[s], bx, by + 0.22)
			_bolt(bk, posts[s + 1], bx + 2.2, by + 0.22)
	for i in 4:
		var lx := 85.4 + i * 1.0
		var lk = _equip("LOCKER-%d" % (i + 1), "locker", _rect(lx, fu - 2.0, lx + 0.8, fu), {"mass": 0.12, "value": 400.0, "fragile": 0.3, "room": "UP", "name_key": "p_locker"})
		_bolt(lk, dku, lx + 0.4, fu, "lock")
	_lamp("LAMP-UP", 76.0, IN_T, "UP", by_tag["PHT-3"])
	# middle deck: the main computer, electronic warfare, the mess and galley, the sick bay, the weapons' capacitors
	for i in 4:
		var cx := 57.4 + i * 1.3
		var cp = _equip("CPU-%d" % (i + 1), "nav_rack", _rect(cx, -0.6, cx + 1.1, fm), {"mass": 0.4, "value": 8000.0, "fragile": 0.5, "room": "MID", "name_key": "p_cpu"})
		_bolt(cp, dkl, cx + 0.55, fm)
	var r := Rect2(63.4, fm - 1.6, 0.8, 1.6)
	var sp := PackedVector2Array()
	for q in SEAT_SHAPE:
		sp.append(p(r.position.x + q.x * r.size.x, r.position.y + q.y * r.size.y))
	var ew = _equip("EW", "seat", r, {"mass": 0.3, "value": 8000.0, "fragile": 0.4, "room": "MID", "name_key": "p_ew"}, sp)
	_bolt(ew, dkl, 63.6, fm)
	_bolt(ew, dkl, 64.0, fm, "lock")
	var ms = _equip("MESS", "", _rect(66.0, fm - 0.9, 69.0, fm), {"cls": "metal", "dest": "metal", "mass": 0.3, "cut_speed": 200.0, "room": "MID", "name_key": "p_table"})
	_bolt(ms, dkl, 66.4, fm)
	_bolt(ms, dkl, 68.6, fm)
	var gl = _equip("GALLEY", "cabinet", _rect(69.5, fm - 2.0, 72.0, fm), {"mass": 0.6, "value": 3500.0, "fragile": 0.4, "room": "MID", "name_key": "p_galley"})
	_bolt(gl, dkl, 70.0, fm)
	_bolt(gl, dkl, 71.5, fm)
	var bd = _equip("SICKBED", "bed", _rect(74.0, fm - 0.9, 76.4, fm), {"mass": 0.3, "value": 4000.0, "fragile": 0.5, "room": "MID", "name_key": "p_bed"})
	_bolt(bd, dkl, 74.4, fm)
	_bolt(bd, dkl, 76.0, fm)
	var mc = _equip("MEDCAB", "locker", _rect(76.8, fm - 2.0, 77.8, fm), {"mass": 0.2, "value": 2500.0, "fragile": 0.4, "room": "MID", "hazard": "chem", "dest": "hazard", "name_key": "p_pharmacy"})
	_bolt(mc, dkl, 77.3, fm, "lock")
	for i in 2:
		var wx := 84.0 + i * 1.8
		var wcp = _equip("WCAP-%d" % (i + 1), "cap", _rect(wx, fm - 2.2, wx + 1.4, fm), {"mass": 0.6, "value": 7000.0, "fragile": 0.4, "room": "MID", "hazard": "battery", "name_key": "p_wcap"})
		_bolt(wcp, dkl, wx + 0.7, fm)
	var wd = _equip("WDIST", "swb", _rect(88.2, -0.6, 90.2, fm), {"mass": 0.5, "value": 6000.0, "fragile": 0.4, "room": "MID", "name_key": "p_wdist"})
	_bolt(wd, dkl, 88.7, fm)
	_bolt(wd, dkl, 89.7, fm)
	_lamp("LAMP-MID", 80.0, DECK_U + 0.3, "MID", dku)
	# lower deck: distribution B and its battery, fresh water, the close-in gun's drums and capacitor, stores
	var db = _equip("DIST-B", "swb", _rect(57.0, 3.6, 58.6, fl), {"mass": 1.0, "value": 10000.0, "fragile": 0.4, "room": "LOW", "name_key": "p_dist_b"})
	_bolt(db, phb, 57.4, fl)
	_bolt(db, phb, 58.2, fl)
	var bb = _equip("BAT-B", "battery", _rect(59.0, fl - 1.3, 60.6, fl), {"mass": 1.0, "value": 6000.0, "fragile": 0.4, "room": "LOW", "hazard": "battery", "name_key": "p_battery"})
	_bolt(bb, phb, 59.8, fl)
	for i in 2:
		var hx := 62.0 + i * 1.8
		var wt = _equip("H2O-%d" % (i + 1), "water", _rect(hx, fl - 2.7, hx + 1.4, fl), {"mass": 0.9, "value": 1500.0, "fragile": 0.35, "room": "LOW", "name_key": "p_water_tank"})
		_bolt(wt, phb, hx + 0.4, fl, "lock")
		_bolt(wt, phb, hx + 1.0, fl, "lock")
	for i in 4:
		var dx := 67.0 + i * 0.95
		var dr = _equip("DRUM-%d" % (i + 1), "drum", _rect(dx, fl - 0.8, dx + 0.7, fl), {"mass": 0.4, "value": 600.0, "fragile": 0.2, "room": "LOW", "hazard": "explosive", "dest": "hazard", "name_key": "p_drum"})
		_bolt(dr, phb, dx + 0.35, fl, "lock")
	var cc2 = _equip("CCAP", "cap", _rect(71.2, fl - 1.5, 72.4, fl), {"mass": 0.4, "value": 4000.0, "fragile": 0.4, "room": "LOW", "hazard": "battery", "name_key": "p_ccap"})
	_bolt(cc2, phb, 71.8, fl)
	for i in 3:
		var stx := 75.0 + i * 1.6
		var st = _equip("STORE-%d" % (i + 1), "cargo", _rect(stx, fl - 1.7, stx + 1.4, fl), {"mass": 1.0, "value": 2000.0, "fragile": 0.3, "room": "LOW", "name_key": "p_stores"})
		_bolt(st, phb, stx + 0.7, fl, "lock")
	_lamp("LAMP-LOW", 70.0, DECK_L + 0.3, "LOW", dkl)


# ---------------------------------------------------------------- the reactor and the auxiliary room

static func _reactor() -> void:
	var SH := {"density": 2.4, "barrier": false, "cut_speed": 50.0, "art": "armor", "name_key": "p_shield"}
	var st = _plate("SH-T", R(97.0, -4.1, 105.0, -3.6), SH, "plate")
	var sb = _plate("SH-B", R(97.0, 5.0, 105.0, 5.5), SH, "plate")
	var sl = _plate("SH-L", R(97.0, -3.6, 97.5, 5.0), SH, "plate")
	var sr = _plate("SH-R", R(104.5, -3.6, 105.0, 5.0), SH, "plate")
	_bolt(st, sl, 97.25, -3.6, "weld")
	_bolt(st, sr, 104.75, -3.6, "weld")
	_bolt(sb, sl, 97.25, 5.0, "weld")
	_bolt(sb, sr, 104.75, 5.0, "weld")
	# the shield stands on struts off the pressure hull
	for sx in [98.0, 104.0]:
		var su = _plate("", R(sx, 5.5, sx + 0.3, IN_B), {"density": 1.0, "barrier": false, "cut_speed": 200.0}, "strut")
		_bolt(su, sb, sx + 0.15, 5.5, "weld")
		_bolt(su, at(sx + 0.15, IN_B + 0.2, ["hull"]), sx + 0.15, IN_B, "weld")
	var re = _equip("REACT", "reactor", _rect(97.5, -3.6, 104.5, 5.0), {"mass": 12.0, "value": 120000.0, "fragile": 0.2, "room": "RX", "cut_speed": 60.0, "name_key": "p_reactor"})
	# 12 t: the crane lifts it whole, a grapple only in thirds along its marked lines
	re.set_meta("segments", [[99.83, -3.55, 99.83, 4.95], [102.17, -3.55, 102.17, 4.95]])
	_bolt(re, sb, 99.0, 5.0)
	_bolt(re, sb, 103.0, 5.0)
	_bolt(re, st, 101.0, -3.6)
	var cr = _equip("CRD", "cabinet", _rect(99.5, IN_T, 102.5, -4.1), {"mass": 1.0, "value": 9000.0, "fragile": 0.4, "room": "RX", "name_key": "p_crd"})
	_bolt(cr, at(101.0, IN_T - 0.2, ["hull"]), 101.0, IN_T)
	_bolt(cr, st, 101.0, -4.1)
	_lamp("LAMP-RX", 98.5, IN_T, "RX", at(98.5, IN_T - 0.2, ["hull"]))
	# auxiliary: the backup generator, its panel, a pump
	var gn = _equip("GEN-B", "gen", _rect(106.4, IN_B - 2.4, 109.2, IN_B), {"mass": 2.0, "value": 12000.0, "fragile": 0.35, "room": "AUX", "hazard": "gen", "name_key": "p_backup_gen"})
	_bolt(gn, at(107.0, IN_B + 0.2, ["hull"]), 107.0, IN_B)
	_bolt(gn, at(108.6, IN_B + 0.2, ["hull"]), 108.6, IN_B)
	var pa = _equip("PNL-AUX", "panel", _rect(106.0, -1.2, 107.6, -0.6), {"cls": "metal", "dest": "metal", "mass": 0.05, "room": "AUX", "cut_speed": 240.0, "name_key": "p_panel"})
	_bolt(pa, at(105.8, -0.9, ["bulkhead"]), 106.0, -0.9)
	var pu = _equip("PUMP-B", "pump", _rect(107.6, -4.4, 109.2, -3.2), {"mass": 0.4, "value": 2000.0, "fragile": 0.4, "room": "AUX", "name_key": "p_pump"})
	_bolt(pu, at(109.8, -3.8, ["hull"]), 109.2, -3.8)
	_lamp("LAMP-AUX", 107.8, IN_T, "AUX", at(107.8, IN_T - 0.2, ["hull"]))


# ---------------------------------------------------------------- the stern: propellant inside the armour, engines on the tail beams

static func _stern() -> void:
	var stw_t = at(119.7, -3.0, ["hull"])
	var stw_b = at(119.7, 3.0, ["hull"])
	for i in 2:
		var y0 := -5.4 if i == 0 else 0.9
		var y1 := -0.9 if i == 0 else 5.4
		var pt = _equip("PROP-%d" % (i + 1), "fueltank", _rect(110.0, y0, 119.3, y1), {"mass": 1.8, "value": 3000.0, "fragile": 0.3, "room": "ST", "hazard": "fuel_tank", "name_key": "p_fueltank"})
		_bolt(pt, by_tag["AB-T" if i == 0 else "AB-B"], 110.0, (y0 + y1) * 0.5)
		_bolt(pt, stw_t if i == 0 else stw_b, 119.3, (y0 + y1) * 0.5)
	var B := {"density": 2.0, "barrier": false, "cut_speed": 110.0, "name_key": "p_tail_beam"}
	var tbu = _plate("TB-U", R(120.0, -6.4, 133.0, -5.6), B, "beam")
	var tbl = _plate("TB-L", R(120.0, 6.6, 133.0, 7.4), B, "beam")
	_bolt(tbu, stw_t, 120.0, -6.0, "weld")
	_bolt(tbu, stw_t, 120.0, -5.7, "weld")
	_bolt(tbl, stw_b, 120.0, 7.0, "weld")
	_bolt(tbl, stw_b, 120.0, 6.7, "weld")
	for i in 2:
		var sg := -1.0 if i == 0 else 1.0
		var y0 := -4.6 if i == 0 else 1.0
		var e = _equip("ENG-%d" % (i + 1), "eng_core", _rect(120.0, y0, 127.0, y0 + 3.6), {"mass": 4.0, "value": 20000.0, "fragile": 0.3, "name_key": "p_engine_big"})
		_bolt(e, stw_t if i == 0 else stw_b, 120.0, y0 + 1.0, "weld")
		_bolt(e, stw_t if i == 0 else stw_b, 120.0, y0 + 2.6)
		var nz = _equip("NOZ-%d" % (i + 1), "nozzle", _rect(127.0, y0 - 0.6, 134.0, y0 + 4.2), {"cls": "metal", "dest": "metal", "mass": 0.8, "cut_speed": 160.0, "name_key": "p_nozzle"},
			_mp([Vector2(127.0, y0 + 0.4), Vector2(134.0, y0 - 0.6), Vector2(134.0, y0 + 4.2), Vector2(127.0, y0 + 3.2)]))
		_bolt(nz, e, 127.0, y0 + 1.2)
		_bolt(nz, e, 127.0, y0 + 2.4)
		# the thrust-vector ram between the beam and the engine
		var ry0 := -5.6 if i == 0 else 4.6
		var ry1 := -4.6 if i == 0 else 6.6
		var tv = _equip("TVC-%d" % (i + 1), "", _rect(124.0, ry0, 125.0, ry1), {"mass": 1.4, "value": 9000.0, "fragile": 0.35, "name_key": "p_tvc"})
		_bolt(tv, tbu if i == 0 else tbl, 124.5, -5.6 if i == 0 else 6.6)
		_bolt(tv, e, 124.5, -4.6 if i == 0 else 4.6)


# ---------------------------------------------------------------- outside: the back launcher, the decoys, the close-in gun, the outside panel

static func _outside() -> void:
	var dtop := -7.6
	var bx0 := 82.0
	var base = _equip("BOX-L", "launcher", _rect(bx0, dtop - 0.35, 92.0, dtop), {"mass": 2.0, "value": 15000.0, "fragile": 0.3, "name_key": "p_launcher"})
	_bolt(base, at(83.0, dtop + 0.2, ["hull"]), 83.0, dtop)
	_bolt(base, at(91.0, dtop + 0.2, ["hull"]), 91.0, dtop)
	var walls: Array = []
	for i in 7:
		var wx := bx0 + 0.2 + i * 1.6
		var wl = _plate("", R(wx, dtop - 2.6, wx + 0.15, dtop - 0.35), {"density": 1.0, "barrier": false, "cut_speed": 180.0}, "rib")
		_bolt(wl, base, wx + 0.075, dtop - 0.35, "weld")
		walls.append(wl)
	for i in 6:
		var mx := bx0 + 0.45 + i * 1.6
		var ms = _equip("BOXM-%d" % (i + 1), "missile", _rect(mx, dtop - 2.5, mx + 1.1, dtop - 0.4), {"mass": 0.5, "value": 2500.0, "fragile": 0.2, "hazard": "explosive", "dest": "hazard", "name_key": "p_missile"})
		_bolt(ms, base, mx + 0.55, dtop - 0.35, "lock")
	for d in [["DECOY-1", 62.0], ["DECOY-2", 100.0]]:
		var dx: float = d[1]
		var dc = _equip(d[0], "decoy", _rect(dx, dtop - 0.9, dx + 1.2, dtop), {"mass": 0.3, "value": 2000.0, "fragile": 0.3, "hazard": "explosive", "dest": "hazard", "name_key": "p_decoy"})
		_bolt(dc, at(dx + 0.6, dtop + 0.2, ["hull"]), dx + 0.6, dtop)
	# the close-in gun under the belly
	var bot := 8.8
	var cw = _equip("CIWS", "ciws", _rect(66.0, bot, 70.0, bot + 1.8), {"mass": 1.5, "value": 12000.0, "fragile": 0.3, "cut_speed": 90.0, "name_key": "p_ciws"},
		_mp([Vector2(66.0, bot), Vector2(70.0, bot), Vector2(69.4, bot + 1.8), Vector2(66.6, bot + 1.8)]))
	_bolt(cw, at(66.8, bot - 0.2, ["hull"]), 66.8, bot)
	_bolt(cw, at(69.2, bot - 0.2, ["hull"]), 69.2, bot)
	_bolt(cw, at(68.2, bot - 0.15, ["hull"]), 67.92, bot - 0.05, "bolt", "HF-2")
	var cb = _equip("CIWS-B", "barrel", _rect(59.6, bot + 1.0, 66.4, bot + 1.3), {"mass": 0.3, "value": 1500.0, "fragile": 0.2, "cut_speed": 90.0, "name_key": "p_gun_barrel"})
	_bolt(cb, cw, 66.3, bot + 1.15)
	# the outside panel, on the belly forward: grid A's breaker, a bus test point, a shore socket
	var px = _equip("PNL-X", "panel", _rect(42.0, bot, 46.4, bot + 0.6), {"cls": "metal", "dest": "metal", "mass": 0.1, "cut_speed": 240.0, "name_key": "p_panel"})
	_bolt(px, at(42.6, bot - 0.2, ["hull"]), 42.6, bot)
	_bolt(px, at(45.8, bot - 0.2, ["hull"]), 45.8, bot)


# ---------------------------------------------------------------- lines

static func _line(id: String, kind: String, net: String, a: String, pa: Vector2, b: String, pb: Vector2, via: Array = []) -> void:
	var pts: Array = [pa]
	pts.append_array(via)
	pts.append(pb)
	w.add_line(id, kind, net, by_tag[a], pa * Geom.M, by_tag[b], pb * Geom.M, _mp(pts))


static func _lines() -> void:
	var cu := -4.9                   # cable run under the upper deck's ceiling
	var cm := -0.9
	var cl := 3.0
	# grid A: the battery into distribution A, out to the sensors, the computers, the bridge and the lamps
	_line("a1", "cable", "power", "BAT-A", Vector2(59.7, -2.6), "DIST-A", Vector2(58.4, -3.0), [Vector2(59.7, -3.0)])
	_line("a2", "cable", "power", "DIST-A", Vector2(58.4, -4.4), "SENS-1", Vector2(62.1, -4.0), [Vector2(58.8, cu), Vector2(62.1, cu)])
	_line("a3", "cable", "power", "SENS-1", Vector2(62.5, -4.0), "SENS-2", Vector2(63.5, -4.0), [Vector2(62.5, cu), Vector2(63.5, cu)])
	_line("a4", "cable", "power", "SENS-2", Vector2(63.9, -4.0), "SENS-3", Vector2(64.9, -4.0), [Vector2(63.9, cu), Vector2(64.9, cu)])
	_line("a5", "cable", "power", "SENS-3", Vector2(65.3, -4.0), "SENS-4", Vector2(66.3, -4.0), [Vector2(65.3, cu), Vector2(66.3, cu)])
	_line("a6", "cable", "power", "DIST-A", Vector2(57.6, -1.6), "CPU-1", Vector2(57.9, -0.6), [Vector2(57.6, -1.0), Vector2(57.9, -1.0)])
	_line("a7", "cable", "power", "CPU-1", Vector2(58.3, -0.6), "CPU-2", Vector2(59.2, -0.6), [Vector2(58.3, cm), Vector2(59.2, cm)])
	_line("a8", "cable", "power", "CPU-2", Vector2(59.6, -0.6), "CPU-3", Vector2(60.5, -0.6), [Vector2(59.6, cm), Vector2(60.5, cm)])
	_line("a9", "cable", "power", "CPU-3", Vector2(60.9, -0.6), "CPU-4", Vector2(61.8, -0.6), [Vector2(60.9, cm), Vector2(61.8, cm)])
	_line("a10", "cable", "power", "DIST-A", Vector2(57.2, -4.4), "LAMP-UP", Vector2(76.0, IN_T + 0.08), [Vector2(57.2, cu - 0.05), Vector2(76.0, cu - 0.05)])
	_line("a11", "cable", "power", "DIST-A", Vector2(57.1, -4.2), "LAMP-CIC", Vector2(46.0, IN_T + 0.08), [Vector2(56.9, -4.7), Vector2(46.0, -4.7)])
	_line("a12", "cable", "power", "LAMP-CIC", Vector2(45.9, IN_T + 0.08), "CIC-C", Vector2(40.2, -2.9), [Vector2(40.2, -4.8)])
	_line("a13", "cable", "power", "LAMP-CIC", Vector2(46.1, IN_T + 0.08), "CIC-R", Vector2(52.0, -4.6), [Vector2(52.0, -4.85)])
	# up to the bridge: through the deck armour by the mast
	_line("a14", "cable", "power", "CIC-R", Vector2(52.6, -4.6), "FCS", Vector2(53.3, -9.6), [Vector2(52.6, -5.0), Vector2(53.3, -5.0)])
	_line("a15", "cable", "power", "FCS", Vector2(52.6, -9.4), "CRYPTO", Vector2(51.6, -9.0), [Vector2(52.6, -9.9), Vector2(51.6, -9.9)])
	_line("a16", "cable", "power", "FCS", Vector2(53.0, -9.6), "LAMP-BR", Vector2(45.08, -11.24), [Vector2(53.0, -11.0), Vector2(45.08, -11.0)])
	_line("a17", "cable", "power", "LAMP-BR", Vector2(45.3, -11.24), "RADAR", Vector2(50.8, -14.9), [Vector2(50.4, -11.0), Vector2(50.4, -14.9)])
	_line("a18", "cable", "power", "DIST-A", Vector2(57.5, -1.6), "LAMP-MID", Vector2(80.0, DECK_U + 0.38), [Vector2(57.5, -1.0), Vector2(80.0, -1.0)])
	_line("a19", "cable", "power", "LAMP-MID", Vector2(79.9, DECK_U + 0.38), "LAMP-ARM", Vector2(47.0, DECK_U + 0.38), [Vector2(56.2, -0.95), Vector2(47.0, -0.95)])
	_line("a20", "cable", "power", "LAMP-ARM", Vector2(46.8, DECK_U + 0.38), "COMMS", Vector2(53.3, 1.0), [Vector2(53.3, -0.9)])
	_line("a21", "cable", "power", "LAMP-ARM", Vector2(47.2, DECK_U + 0.38), "LAMP-W", Vector2(24.98, -6.14), [Vector2(38.2, -0.9), Vector2(30.0, -0.9), Vector2(25.0, -5.8)])
	_line("a23", "cable", "power", "LAMP-W", Vector2(25.1, -6.14), "HOIST", Vector2(26.4, -4.0), [Vector2(25.6, -4.0)])
	_line("a24", "cable", "power", "DIST-A", Vector2(58.0, -4.6), "LAMP-RX", Vector2(98.5, IN_T + 0.08), [Vector2(58.0, -5.0), Vector2(98.5, -5.0)])
	_line("a25", "cable", "power", "LAMP-RX", Vector2(98.6, IN_T + 0.08), "CRD", Vector2(100.0, -4.2), [Vector2(100.0, -5.0)])
	_line("a26", "cable", "power", "LAMP-RX", Vector2(98.7, IN_T + 0.08), "LAMP-AUX", Vector2(107.8, IN_T + 0.08), [Vector2(105.8, -4.95), Vector2(107.8, -4.95)])
	_line("a27", "cable", "power", "DIST-A", Vector2(57.3, -1.6), "LAMP-DCR", Vector2(52.0, DECK_L + 0.38), [Vector2(56.6, 2.9), Vector2(52.0, 2.9)])
	_line("a28", "cable", "power", "LAMP-DCR", Vector2(51.9, DECK_L + 0.38), "DCP", Vector2(47.0, 5.3), [Vector2(47.0, 2.95)])
	# grid B: the backup generator (aft, along the lower tunnel) and its battery into distribution B
	_line("b1", "cable", "power", "GEN-B", Vector2(106.6, 4.2), "DIST-B", Vector2(58.4, 4.0), [Vector2(106.2, 4.2), Vector2(106.2, 7.4), Vector2(58.8, 7.4), Vector2(58.4, 6.0)])
	_line("b2", "cable", "power", "BAT-B", Vector2(59.4, 5.0), "DIST-B", Vector2(58.5, 4.6), [Vector2(59.4, 4.6)])
	_line("b3", "cable", "power", "DIST-B", Vector2(57.4, 3.6), "LAMP-LOW", Vector2(70.0, DECK_L + 0.38), [Vector2(57.4, 3.1), Vector2(70.0, 3.1)])
	_line("b4", "cable", "power", "LAMP-LOW", Vector2(70.1, DECK_L + 0.38), "STORE-1", Vector2(75.7, 4.6), [Vector2(75.7, 3.1)])
	_line("b5", "cable", "power", "DIST-B", Vector2(57.2, 3.6), "PUMP-B", Vector2(108.4, -3.2), [Vector2(57.2, 3.05), Vector2(95.8, 3.05), Vector2(106.2, -3.0), Vector2(108.4, -3.0)])
	# the thrust-vector rams' control lines, off grid B, up through the upper tunnel and out to the stern
	_line("ct1", "cable", "power", "DIST-B", Vector2(58.2, 3.6), "TVC-1", Vector2(124.5, -5.2), [Vector2(58.2, 3.2), Vector2(59.0, -6.2), Vector2(109.4, -6.2), Vector2(116.0, -6.0), Vector2(124.5, -6.0)])
	_line("ct2", "cable", "power", "DIST-B", Vector2(58.0, 3.6), "TVC-2", Vector2(124.5, 5.2), [Vector2(58.0, 3.25), Vector2(58.8, -6.3), Vector2(109.4, -6.3), Vector2(118.0, -6.3), Vector2(122.0, 6.2), Vector2(124.5, 6.2)])
	# the weapons: two capacitors into the weapons' panel, out to the gun mount and the launch cells
	_line("w1", "cable", "power", "WCAP-1", Vector2(84.7, 0.3), "WDIST", Vector2(88.4, -0.3), [Vector2(84.7, -0.3)])
	_line("w2", "cable", "power", "WCAP-2", Vector2(86.5, 0.3), "WDIST", Vector2(88.4, 0.0), [Vector2(86.5, 0.0)])
	_line("w3", "cable", "power", "WDIST", Vector2(89.0, -0.6), "GUN-MT", Vector2(22.0, -4.6), [Vector2(89.0, -0.95), Vector2(38.2, -0.85), Vector2(22.0, -0.85)])
	_line("w4", "cable", "power", "GUN-MT", Vector2(20.0, -4.6), "VLS-1", Vector2(28.3, 1.6), [Vector2(20.0, 1.8), Vector2(28.3, 1.8)])
	# the close-in gun's own capacitor, out through the belly
	_line("cw1", "cable", "power", "CCAP", Vector2(71.8, 4.8), "CIWS", Vector2(68.0, 9.2), [Vector2(71.8, 7.2), Vector2(68.0, 7.2)])
	# water to the damage-control pump; propellant to the engines
	_line("h1", "pipe", "water", "H2O-1", Vector2(62.7, 3.6), "DCP", Vector2(47.4, 5.4), [Vector2(62.7, 3.2), Vector2(47.4, 3.2)])
	_line("h2", "pipe", "water", "H2O-2", Vector2(64.5, 3.6), "H2O-1", Vector2(63.0, 3.6), [Vector2(64.5, 3.3), Vector2(63.0, 3.3)])
	_line("f1", "pipe", "fuel", "PROP-1", Vector2(119.2, -3.0), "ENG-1", Vector2(120.1, -2.8))
	_line("f2", "pipe", "fuel", "PROP-2", Vector2(119.2, 3.0), "ENG-2", Vector2(120.1, 2.8))


# ---------------------------------------------------------------- controls

static func _ctrl(id: String, kind: String, piece, pos: Vector2, opts: Dictionary = {}) -> void:
	w.add_ctrl(id, kind, piece, pos * Geom.M, opts)


static func _controls() -> void:
	# outside: a gas port through the armour for every pressurised room
	for g in [["G-W", 25.0, -7.15, "W"], ["G-CIC", 38.6, -7.75, "CIC"], ["G-UP", 66.0, -7.75, "UP"], ["G-RX", 98.0, -7.75, "RX"], ["G-AUX", 109.0, -7.75, "AUX"],
			["G-ARM", 48.0, 8.95, "ARM"], ["G-DCR", 53.0, 8.95, "DCR"], ["G-MID", 72.0, 8.95, "MID"], ["G-LOW", 76.0, 8.95, "LOW"]]:
		var gy: float = g[2]
		_ctrl(g[0], "port", at(g[1], gy + (0.4 if gy < 0.0 else -0.4), ["hull"]), Vector2(g[1], gy), {"medium": "gas", "target": g[3]})
	_ctrl("G-BR", "port", by_tag["BR-R1"], Vector2(44.2, -12.0), {"medium": "gas", "target": "BR"})
	# the outside panel: grid A's breaker, a test point on bus A, the shore socket
	var px = by_tag["PNL-X"]
	_ctrl("K-A", "switch", px, Vector2(42.8, 9.6), {"target": "K-A", "state": true})
	_ctrl("E-A", "test", px, Vector2(43.8, 9.6), {"medium": "volt", "target": "bus"})
	_ctrl("AUX-P", "socket", px, Vector2(45.6, 9.6), {"target": "aux", "state": false})
	# hatches (manual) and doors (powered)
	for h in [["HT-U", ""], ["HT-L", ""], ["HATCH-BR", ""], ["DR-MAG", "W"], ["DR-TU1", "TU"], ["DR-TU2", "TU"], ["DR-TU3", "TU"], ["DR-TL1", "TL"], ["DR-TL2", "TL"]]:
		var hp = by_tag[h[0]]
		_ctrl(h[0], "door", hp, Geom.centroid(hp.poly) / Geom.M, {"target": h[0], "state": false, "hidden_room": h[1]})
	for i in VLS.size():
		var vh = by_tag["VH-%d" % (i + 1)]
		_ctrl("VH-%d" % (i + 1), "door", vh, Geom.centroid(vh.poly) / Geom.M, {"target": "VH-%d" % (i + 1), "state": false})
	for d in [["DR-W", "W"], ["D56-1", "CIC"], ["D56-2", "ARM"], ["D56-3", "DCR"], ["D96-1", "UP"], ["D96-2", "MID"], ["D96-3", "LOW"], ["DR-RX", "RX"], ["DR-ST", "AUX"]]:
		var dp = by_tag[d[0]]
		_ctrl(d[0], "door", dp, Geom.centroid(dp.poly) / Geom.M, {"target": d[0], "state": false, "hidden_room": d[1]})
	# inside: grid B's own breakers and a test point on it; the backup generator's stop
	var db = by_tag["DIST-B"]
	_ctrl("K-BB", "switch", db, Vector2(57.6, 4.2), {"target": "K-BB", "state": true, "hidden_room": "LOW"})
	_ctrl("E-B", "test", db, Vector2(58.3, 4.2), {"medium": "volt", "target": "DIST-B", "hidden_room": "LOW"})
	_ctrl("K-GB", "switch", by_tag["PNL-AUX"], Vector2(106.5, -0.9), {"target": "K-GB", "state": true, "hidden_room": "AUX"})
	_ctrl("E-GB", "test", by_tag["PNL-AUX"], Vector2(107.2, -0.9), {"medium": "volt", "target": "GEN-B", "hidden_room": "AUX"})
	# the weapons' panel: the capacitors' discharge points (nothing outside reaches them), test points
	var wd = by_tag["WDIST"]
	_ctrl("WD-1", "discharge", wd, Vector2(88.6, 0.2), {"target": "WCAP-1", "state": false, "hidden_room": "MID"})
	_ctrl("WD-2", "discharge", wd, Vector2(89.4, 0.2), {"target": "WCAP-2", "state": false, "hidden_room": "MID"})
	_ctrl("E-W1", "test", by_tag["WCAP-1"], Vector2(84.7, 0.9), {"medium": "volt", "target": "WCAP-1", "hidden_room": "MID"})
	_ctrl("E-W2", "test", by_tag["WCAP-2"], Vector2(86.5, 0.9), {"medium": "volt", "target": "WCAP-2", "hidden_room": "MID"})
	_ctrl("CD-1", "discharge", by_tag["CCAP"], Vector2(71.8, 5.2), {"target": "CCAP", "state": false, "hidden_room": "LOW"})
	_ctrl("E-CC", "test", by_tag["CCAP"], Vector2(71.8, 5.8), {"medium": "volt", "target": "CCAP", "hidden_room": "LOW"})
	# the rams' locks, in the upper tunnel by the aft bulkhead
	_ctrl("LK-T1", "switch", by_tag["PHT-6"], Vector2(106.4, -5.65), {"target": "LK-T1", "state": false, "hidden_room": "TU"})
	_ctrl("LK-T2", "switch", by_tag["PHT-6"], Vector2(107.6, -5.65), {"target": "LK-T2", "state": false, "hidden_room": "TU"})
	# the magazine: its flood valve and a heat test point, both on its top in the bay; its own gas port
	_ctrl("FLV", "valve", by_tag["MAG-T1"], Vector2(28.0, 2.3), {"target": "FLV", "state": false, "hidden_room": "W"})
	_ctrl("MT-H", "probe", by_tag["MAG-T2"], Vector2(34.0, 2.3), {"medium": "heat", "target": "MAG", "hidden_room": "W"})
	_ctrl("G-MAG", "port", by_tag["MAG-T2"], Vector2(33.0, 2.3), {"medium": "gas", "target": "MAG", "hidden_room": "W"})
	# fluids: the water tanks, the propellant tanks (in the open stern), the damage-control bottles
	_ctrl("WP-1", "port", by_tag["H2O-1"], Vector2(62.7, 4.2), {"medium": "coolant", "target": "h2o1", "hidden_room": "LOW"})
	_ctrl("WP-2", "port", by_tag["H2O-2"], Vector2(64.5, 4.2), {"medium": "coolant", "target": "h2o2", "hidden_room": "LOW"})
	_ctrl("PP-1", "port", by_tag["PROP-1"], Vector2(114.8, -0.95), {"medium": "fuel", "target": "prop1", "hidden_room": "ST"})
	_ctrl("PP-2", "port", by_tag["PROP-2"], Vector2(114.8, 0.95), {"medium": "fuel", "target": "prop2", "hidden_room": "ST"})
	for i in 2:
		var o = by_tag["O2-%d" % (i + 1)]
		_ctrl("O2P-%d" % (i + 1), "port", o, Geom.centroid(o.poly) / Geom.M - Vector2(0, 0.6), {"medium": "gas", "target": "O2-%d" % (i + 1), "hidden_room": "DCR"})
		var f = by_tag["FOAM-%d" % (i + 1)]
		_ctrl("FP-%d" % (i + 1), "port", f, Geom.centroid(f.poly) / Geom.M - Vector2(0, 0.6), {"medium": "gas", "target": "FOAM-%d" % (i + 1), "hidden_room": "DCR"})


# ---------------------------------------------------------------- rooms

static func _rooms() -> void:
	var inner := _inner(OUT, TA)
	# the weapons bay: the armour's inside forward of the bulkhead, less the magazine
	var a10: Vector2 = inner[10]
	var a11: Vector2 = inner[11]
	var yb := func(x: float) -> float: return a11.y + (x - a11.x) / (a10.x - a11.x) * (a10.y - a11.y)
	w.add_room("W", _mp([inner[0], inner[1], inner[2], Vector2(38.0, -6.9), Vector2(38.0, 8.1), Vector2(36.0, yb.call(36.0)), Vector2(36.0, 2.4),
		Vector2(26.0, 2.4), Vector2(26.0, yb.call(26.0)), inner[11]]))
	w.add_room("MAG", _mp([Vector2(26.4, 2.8), Vector2(35.6, 2.8), Vector2(35.6, yb.call(35.6)), Vector2(26.4, yb.call(26.4))]))
	w.add_room("BR", _mp([Vector2(41.55, -7.6), Vector2(43.45, -11.4), Vector2(53.55, -11.4), Vector2(55.45, -7.6)]))
	w.add_room("CIC", R(X0, IN_T, 56.0, DECK_U))
	w.add_room("ARM", R(X0, DECK_U + 0.3, 56.0, DECK_L))
	w.add_room("DCR", R(X0, DECK_L + 0.3, 56.0, IN_B))
	w.add_room("UP", R(56.4, IN_T, 96.0, DECK_U))
	w.add_room("MID", R(56.4, DECK_U + 0.3, 96.0, DECK_L))
	w.add_room("LOW", R(56.4, DECK_L + 0.3, 96.0, IN_B))
	w.add_room("RX", R(96.4, IN_T, 105.6, IN_B))
	w.add_room("AUX", R(106.0, IN_T, X1, IN_B))
	w.add_room("TU", R(X0, TU0, X1, PHT))
	w.add_room("TL", R(X0, PHB, X1, TL1))
	var st := PackedVector2Array()
	for q in [Vector2(110.0, inner[4].y), inner[5], inner[6], inner[7], inner[8], Vector2(110.0, inner[9].y)]:
		st.append(q * Geom.M)
	w.add_room("ST", st)


static func meta() -> Dictionary:
	var rooms := {"W": 101.0, "MAG": 101.0, "BR": 101.0, "CIC": 101.0, "ARM": 101.0, "DCR": 101.0, "UP": 101.0, "MID": 101.0, "LOW": 101.0, "RX": 101.0, "AUX": 101.0, "TU": 0.0, "TL": 0.0, "ST": 0.0}
	var vessels := {
		"O2-1": {"V": 0.012, "kpa": 1500.0, "piece": "O2-1", "burst": 200.0}, "O2-2": {"V": 0.012, "kpa": 1500.0, "piece": "O2-2", "burst": 200.0},
		"FOAM-1": {"V": 0.05, "kpa": 1200.0, "piece": "FOAM-1", "burst": 180.0}, "FOAM-2": {"V": 0.05, "kpa": 1200.0, "piece": "FOAM-2", "burst": 180.0},
	}
	var cfg := {"G-W": {"rate": 12.0}, "G-BR": {"rate": 8.0}, "G-CIC": {"rate": 10.0}, "G-UP": {"rate": 12.0}, "G-RX": {"rate": 10.0}, "G-AUX": {"rate": 8.0},
		"G-ARM": {"rate": 10.0}, "G-DCR": {"rate": 10.0}, "G-MID": {"rate": 12.0}, "G-LOW": {"rate": 12.0}, "G-MAG": {"rate": 4.0},
		"O2P-1": {"rate": 0.25}, "O2P-2": {"rate": 0.25}, "FP-1": {"rate": 0.3}, "FP-2": {"rate": 0.3}}
	var labels := {"MAG-T1": "MAG", "PROP-1": "MMH", "PROP-2": "MMH", "H2O-1": "H₂O", "H2O-2": "H₂O", "O2-1": "O₂", "O2-2": "O₂", "FOAM-1": "FOAM", "FOAM-2": "FOAM",
		 "DIST-A": "DIST A", "DIST-B": "DIST B", "WCAP-1": "WCAP", "WCAP-2": "WCAP", "CCAP": "CIWS CAP", "CRYPTO": "CRYPTO", "FCS": "FCS"}
	var room_names := {"W": "room_ptW", "MAG": "room_ptMAG", "BR": "room_ptBR", "CIC": "room_ptCIC", "ARM": "room_ptARM", "DCR": "room_ptDCR", "UP": "room_ptUP", "MID": "room_ptMID",
		"LOW": "room_ptLOW", "RX": "room_ptRX", "AUX": "room_ptAUX", "TU": "room_ptTU", "TL": "room_ptTL", "ST": "room_ptST"}
	var plates: Array = []
	for k in [2, 4, 6, 8, 10, 12]:
		plates.append("AR3-%d" % k)
	return {
		"id": "pt34",
		"name": "PT-34 FALCON",
		"title": ["PT-34「隼鹰」退役巡逻舰 · 134 m", "PT-34 FALCON · RETIRED PATROL SHIP · 134 m"],
		"contract": "PT-34",
		"length": 134.0,
		"value": {"total": 650000.0, "metal": 62000.0},
		"clamps": [[20.0, 7.16], [48.0, 8.8], [80.0, 8.8], [102.0, 8.8]],
		"room_names": room_names,
		"gas": {"rooms": rooms, "vessels": vessels, "valves": [], "value": 2400.0},
		"power": {
			"bus": "DIST-A",
			"sources": [
				{"piece": "BAT-A", "kind": "battery", "volts": 440.0, "local_volts": 48.0, "cable": "a1", "switch": "K-A", "charge": 0.9, "drain": 0.0003},
			],
			# grid B: nothing outside reaches its breakers
			"isolated": [
				{"piece": "GEN-B", "volts": 440.0, "charge": 1.0, "switch": "K-GB"},
				{"piece": "BAT-B", "volts": 440.0, "charge": 0.9, "switch": "K-BB"},
				{"piece": "WCAP-1", "kind": "cap", "volts": 900.0, "charge": 1.0, "discharge": "WD-1"},
				{"piece": "WCAP-2", "kind": "cap", "volts": 900.0, "charge": 1.0, "discharge": "WD-2"},
				{"piece": "CCAP", "kind": "cap", "volts": 600.0, "charge": 1.0, "discharge": "CD-1"},
			],
			"lamps": {"W": "LAMP-W", "BR": "LAMP-BR", "CIC": "LAMP-CIC", "ARM": "LAMP-ARM", "DCR": "LAMP-DCR", "UP": "LAMP-UP", "MID": "LAMP-MID", "RX": "LAMP-RX", "AUX": "LAMP-AUX"},
		},
		"fluids": {"volumes": {
			"h2o1": {"fluid": "coolant", "amount": 0.4, "piece": "H2O-1", "content": 1.0, "leak": 0.1, "port": "WP-1", "pump": [0.12, 0.008]},
			"h2o2": {"fluid": "coolant", "amount": 0.4, "piece": "H2O-2", "content": 1.0, "leak": 0.1, "port": "WP-2", "pump": [0.12, 0.008]},
			"h2o_line": {"fluid": "coolant", "amount": 0.02, "nets": ["water"], "leak": 0.05, "leak_min": 0.004},
			"prop1": {"fluid": "fuel", "amount": 1.2, "piece": "PROP-1", "content": 0.6, "leak": 0.15, "port": "PP-1", "pump": [0.2, 0.01], "hazard": 0.04},
			"prop2": {"fluid": "fuel", "amount": 1.2, "piece": "PROP-2", "content": 0.6, "leak": 0.15, "port": "PP-2", "pump": [0.2, 0.01], "hazard": 0.04},
			"prop_line": {"fluid": "fuel", "amount": 0.02, "nets": ["fuel"], "leak": 0.05, "leak_min": 0.004},
		}, "joins": [], "value": {"coolant": 600.0, "fuel": 4000.0}},
		"munitions": {"cook": {"r": 1.6, "rate": 28.0, "at": 120.0}, "chain": 3.0, "knock": 340.0, "flood": {"FLV": "MAG"}},
		"actuators": {
			"ct1": {"lock": "LK-T1", "piece": "TVC-1", "hits": "TB-U", "push": [0.0, -240.0]},
			"ct2": {"lock": "LK-T2", "piece": "TVC-2", "hits": "TB-L", "push": [0.0, 240.0]},
		},
		"ctrls_cfg": cfg,
		"labels": labels,
		"hints": {},
		"market": {
			"class": "PT", "name": ["隼鹰级巡逻舰", "FALCON-CLASS PATROL SHIP"], "time": 90.0,
			"rooms": {"W": [0.2, 40.0, 101.0], "BR": [0.2, 40.0, 101.0], "CIC": [0.2, 40.0, 101.0], "UP": [0.2, 40.0, 101.0], "MID": [0.2, 40.0, 101.0], "LOW": [0.2, 40.0, 101.0], "RX": [0.25, 0.0, 101.0]},
			"charge": {"BAT-A": [0.2, 1.0]},
			"fluids": {"h2o1": [0.1, 0.4], "h2o2": [0.1, 0.4], "prop1": [0.2, 1.2], "prop2": [0.2, 1.2]}, "fill": {"h2o_line": "h2o1", "prop_line": "prop1"},
			"knockable": ["CIC-C", "CIC-R", "COMMS", "SENS-1", "SENS-2", "CPU-1", "CPU-2", "GALLEY"],
			"drift": ["STORE-1", "STORE-2", "LOCKER-1", "LOCKER-2"],
			"section_x": 96.0,
			"slots": {
				"hidden_damage": {"plates": plates},
			},
			"mechanisms": true,
		},
		"procedures": {
			"CRYPTO": [
				{"do": "hose", "ctrl": "G-BR"},
				{"do": "wait", "until": {"P": ["BR", "<", 5.0]}, "max": 150.0},
				{"do": "operate", "ctrl": "HATCH-BR"},
				{"do": "wait", "until": {"open": ["BR"]}, "max": 5.0},
				{"do": "operate", "ctrl": "K-A"},
				{"do": "measure", "ctrl": "E-A", "expect": ["<", 1.0]},
				{"do": "free", "piece": "CRYPTO"},
				{"do": "deliver", "piece": "CRYPTO", "zone": "equip"},
			],
			"FCS": [
				{"do": "hose", "ctrl": "G-BR"},
				{"do": "wait", "until": {"P": ["BR", "<", 5.0]}, "max": 150.0},
				{"do": "operate", "ctrl": "HATCH-BR"},
				{"do": "wait", "until": {"open": ["BR"]}, "max": 5.0},
				{"do": "operate", "ctrl": "K-A"},
				{"do": "measure", "ctrl": "E-A", "expect": ["<", 1.0]},
				{"do": "free", "piece": "FCS"},
				{"do": "deliver", "piece": "FCS", "zone": "equip"},
			],
		},
	}
