class_name Tw64Author
# Authoring script for TW-64 "Bedrock", a 70 m salvage tug and workshop (R2 fleet,
# design/ships/全新舰队_R2_2026-10-18/TW-64_磐石.md; lengths as drawn, heights at
# 0.6 of the drawing, player 2026-10-19). Not part of the game:
# tools/ship_export.gd runs it and writes ships/tw64.json.
# Metres, x bow (0) to the nozzles (70), y down.
#
# A blunt hull with a towing jaw cut into its bow, the bridge raised on the roof, a
# three-jointed service arm folded on the roof aft, and two engines slung outboard
# behind the stern, one high, one low. Inside: the jaw machinery forward, the
# workshop, the hydraulics and winch room, the battery bay under the deck, the
# hydraulic power unit aft.
# What it asks of you, in the order the loads run:
#   the winch still holds the tow line taut: its brake pins out first (a tension
#   gauge on its frame reads it), or its axle comes out with the drum whipping;
#   the jaw's pads still grip the last tow's towing eye on that line: with the
#   winch brake on, the jaw's pins in or its accumulator charged, a pad's pivot
#   taken out springs it;
#   the arm's cylinder holds the arm folded on its own accumulator: vent it and
#   pull each joint's lock pin before its pivot comes out;
#   the two engine pods weigh all aft, one above, one below: set the hull support
#   (a switch on the stern) or take both off together, or the hull twists under
#   the one left.

const K = preload("res://tools/authoring/kit.gd")
const T := 0.45
const OUT := [Vector2(0.0, -5.4), Vector2(7.0, -7.8), Vector2(17.0, -7.8), Vector2(21.0, -10.8), Vector2(38.0, -10.8), Vector2(45.0, -7.8),
	Vector2(53.0, -5.4), Vector2(53.0, 6.0), Vector2(46.0, 9.0), Vector2(19.0, 9.0), Vector2(13.0, 6.0), Vector2(0.0, 4.8),
	Vector2(0.0, 2.4), Vector2(10.0, 2.4), Vector2(12.0, 0.0), Vector2(10.0, -2.4), Vector2(0.0, -2.4)]
const BH1 := 15.6                # jaw machinery | workshop (to 16.0)
const BH2 := 31.6                # workshop | hydraulics (to 32.0)
const BH3 := 48.0                # hydraulics | aft (to 48.4)
const DECK := 4.2                # the main deck (plate to 4.5); the battery bay under it
const BELLY := 8.55

static var w
static var by_tag := {}


static func build(world) -> void:
	K.begin(world, "TW64")
	w = world
	by_tag = K.by_tag
	_hull()
	_inside()
	_bridge()
	_jaw()
	_workshop()
	_hydraulics()
	_aft()
	_arm()
	_pods()
	_lines()
	_controls()
	_rooms()


static func rooms_only(world) -> void:
	K.begin(world, "TW64")
	w = world
	_rooms()


# where the inside of edge i (corner i to i + 1) runs at x
static func _iy(i: int, x: float) -> float:
	var inn := K.inner(OUT, T)
	var a: Vector2 = inn[i]
	var b: Vector2 = inn[(i + 1) % inn.size()]
	return a.y + (x - a.x) / (b.x - a.x) * (b.y - a.y)


# ---------------------------------------------------------------- the hull

static func _hull() -> void:
	K.ring(OUT, T, {
		1: [0.5],
		3: [0.15, 0.3, 0.5, 0.7, 0.85],
		4: [0.5],
		6: [0.25, 0.5, 0.75],
		8: [0.15, 0.3, 0.45, 0.6, 0.75, 0.9],
		16: [0.5],
	}, {
		"4:0": {"kind": "hatch", "door": true, "tag": "HT-H", "open_dir": Vector2(-1.2, -0.5) * Geom.M, "cut_speed": 190.0},
		"8:4": {"kind": "hatch", "door": true, "tag": "HT-L", "open_dir": Vector2(-1.6, 0) * Geom.M, "cut_speed": 190.0},
		"16:0": {"kind": "hatch", "door": true, "tag": "HT-F", "open_dir": Vector2(0, -1.4) * Geom.M, "cut_speed": 190.0},
	}, {"density": 1.8, "barrier": true, "cut_speed": 190.0, "name_key": "p_hull_heavy"}, "HL")
	K.clamp(1, 22.0, 9.0, 8.8)
	K.clamp(2, 34.0, 9.0, 8.8)
	K.clamp(3, 44.0, 9.0, 8.8)


# ---------------------------------------------------------------- bulkheads and the deck

static func _inside() -> void:
	var S := {"density": 1.3, "barrier": true, "cut_speed": 210.0}
	var D := {"density": 1.1, "door": true, "cut_speed": 200.0}
	# BH1, the jaw machinery forward of it; its door on the deck
	var top1 := _iy(1, BH1 + 0.2)
	var b1t = K.plate("BH1-T", K.R(BH1, top1 - 0.1, BH1 + 0.4, 1.4), S, "bulkhead")
	var d1 = K.plate("DR-F", K.R(BH1, 1.4, BH1 + 0.4, DECK), D.merged({"open_dir": Vector2(0, -2.8) * Geom.M}), "door")
	var b1b = K.plate("BH1-B", K.R(BH1, DECK, BH1 + 0.4, _iy(9, BH1 + 0.2) + 0.1), S, "bulkhead")
	K.bolt(b1t, K.at(BH1 + 0.2, top1 - 0.25, ["hull"]), BH1 + 0.2, top1, "weld")
	K.bolt(b1b, K.at(BH1 + 0.2, _iy(9, BH1 + 0.2) + 0.25, ["hull"]), BH1 + 0.2, _iy(9, BH1 + 0.2), "weld")
	K.bolt(d1, b1t, BH1 + 0.2, 1.4, "weld")
	K.bolt(d1, b1b, BH1 + 0.2, DECK, "weld")
	# the main deck from BH1 to BH3, the battery bay under it
	var dk = K.plate("DECK", K.R(BH1 + 0.4, DECK, BH3, DECK + 0.3), {"density": 1.2, "barrier": true, "cut_speed": 210.0}, "deck")
	K.bolt(dk, b1b, BH1 + 0.4, DECK + 0.15, "weld")
	# BH2: workshop | hydraulics, down to the deck
	var b2t = K.plate("BH2-T", K.R(BH2, -10.4, BH2 + 0.4, 1.4), S, "bulkhead")
	var d2 = K.plate("DR-WH", K.R(BH2, 1.4, BH2 + 0.4, DECK), D.merged({"open_dir": Vector2(0, -2.8) * Geom.M}), "door")
	K.bolt(b2t, K.at(BH2 + 0.2, -10.6, ["hull"]), BH2 + 0.2, -10.35, "weld")
	K.bolt(d2, b2t, BH2 + 0.2, 1.4, "weld")
	K.bolt(d2, dk, BH2 + 0.2, DECK, "weld")
	# BH3: hydraulics | aft, the whole height
	var top3 := _iy(5, BH3 + 0.2)
	var b3t = K.plate("BH3-T", K.R(BH3, top3 - 0.1, BH3 + 0.4, 1.4), S, "bulkhead")
	var d3 = K.plate("DR-HA", K.R(BH3, 1.4, BH3 + 0.4, DECK), D.merged({"open_dir": Vector2(0, -2.8) * Geom.M}), "door")
	var b3b = K.plate("BH3-B", K.R(BH3, DECK, BH3 + 0.4, _iy(7, BH3 + 0.2) + 0.1), S, "bulkhead")
	K.bolt(b3t, K.at(BH3 + 0.2, top3 - 0.25, ["hull"]), BH3 + 0.2, top3, "weld")
	K.bolt(b3b, K.at(BH3 + 0.2, _iy(7, BH3 + 0.2) + 0.25, ["hull"]), BH3 + 0.2, _iy(7, BH3 + 0.2), "weld")
	K.bolt(d3, b3t, BH3 + 0.2, 1.4, "weld")
	K.bolt(d3, b3b, BH3 + 0.2, DECK, "weld")
	K.bolt(dk, b3b, BH3, DECK + 0.15, "weld")


# ---------------------------------------------------------------- the bridge on the roof

static func _bridge() -> void:
	var S := {"density": 1.2, "barrier": true, "cut_speed": 170.0}
	var bf = K.plate("BR-F", K.mp([Vector2(22.0, -10.8), Vector2(23.6, -13.8), Vector2(24.1, -13.4), Vector2(22.55, -10.8)]), S.merged({"art": "window"}))
	var br = K.plate("BR-R1", K.R(23.6, -13.8, 26.4, -13.4), S)
	var hb = K.plate("HATCH-BR", K.R(26.4, -13.8, 28.2, -13.4), {"density": 1.0, "door": true, "open_dir": Vector2(1.6, 0) * Geom.M, "cut_speed": 170.0}, "hatch")
	var br2 = K.plate("BR-R2", K.R(28.2, -13.8, 31.6, -13.4), S)
	K.bolt(hb, br, 26.4, -13.6, "weld")
	K.bolt(hb, br2, 28.2, -13.6, "weld")
	var ba = K.plate("BR-A", K.mp([Vector2(31.6, -13.8), Vector2(34.0, -10.8), Vector2(33.45, -10.8), Vector2(31.2, -13.4)]), S)
	K.bolt(bf, K.at(22.3, -10.6, ["hull"]), 22.3, -10.8, "weld")
	K.bolt(ba, K.at(33.7, -10.6, ["hull"]), 33.7, -10.8, "weld")
	K.bolt(br, bf, 23.8, -13.6, "weld")
	K.bolt(br2, ba, 31.5, -13.6, "weld")
	var fl := -10.8
	for i in 2:
		var sx := 25.0 + i * 2.6
		var st = K.seat("SEAT-%d" % (i + 1), Rect2(sx, fl - 1.5, 0.8, 1.5), {"room": "B", "name_key": "p_seat_pilot"})
		K.bolt(st, K.at(sx + 0.2, fl + 0.2, ["hull"]), sx + 0.2, fl)
		K.bolt(st, K.at(sx + 0.6, fl + 0.2, ["hull"]), sx + 0.6, fl, "lock")
	var cn = K.equip("HELM", "console", K.rect(29.6, fl - 1.4, 31.6, fl), {"mass": 0.3, "value": 5000.0, "fragile": 0.5, "room": "B", "name_key": "p_helm"})
	K.bolt(cn, K.at(30.0, fl + 0.2, ["hull"]), 30.0, fl)
	K.bolt(cn, K.at(31.2, fl + 0.2, ["hull"]), 31.2, fl)
	var lg = K.equip("TOWLOG", "cabinet", K.rect(23.2, fl - 1.3, 24.4, fl), {"mass": 0.08, "value": 6000.0, "fragile": 0.4, "room": "B", "mandatory": true, "name_key": "p_towlog"})
	K.bolt(lg, K.at(23.5, fl + 0.2, ["hull"]), 23.5, fl)
	K.bolt(lg, K.at(24.1, fl + 0.2, ["hull"]), 24.1, fl, "lock")
	K.lamp("LAMP-B", 25.0, -13.4, "B", br)


# ---------------------------------------------------------------- the towing jaw

static func _jaw() -> void:
	# the pads hang under the throat's lips on their pivots, a locking pin at the mouth
	var pu = K.equip("JAW-U", "", K.rect(1.0, -2.4, 9.6, -1.6), {"cls": "equip", "mass": 0.9, "value": 4500.0, "fragile": 0.2, "cut_speed": 110.0, "room": "", "name_key": "p_jaw_pad"})
	var pl = K.equip("JAW-L", "", K.rect(1.0, 1.6, 9.6, 2.4), {"cls": "equip", "mass": 0.9, "value": 4500.0, "fragile": 0.2, "cut_speed": 110.0, "room": "", "name_key": "p_jaw_pad"})
	K.bolt(pu, K.at(9.2, -2.6, ["hull"]), 9.2, -2.4, "bolt", "JP-U")
	K.bolt(pu, K.at(2.0, -2.6, ["hull"]), 2.0, -2.4, "lock", "JL-U")
	K.bolt(pl, K.at(9.2, 2.6, ["hull"]), 9.2, 2.4, "bolt", "JP-L")
	K.bolt(pl, K.at(2.0, 2.6, ["hull"]), 2.0, 2.4, "lock", "JL-L")
	# the last tow's towing eye, still gripped between them
	var tw = K.equip("TOW", "", K.rect(0.6, -1.6, 11.4, 1.6), {"cls": "equip", "mass": 1.4, "value": 3500.0, "fragile": 0.15, "cut_speed": 90.0, "name_key": "p_tow_eye"},
		K.mp([Vector2(0.6, -1.6), Vector2(9.0, -1.6), Vector2(11.4, 0.0), Vector2(9.0, 1.6), Vector2(0.6, 1.6)]))
	K.bolt(tw, pu, 4.0, -1.6, "lock")
	K.bolt(tw, pl, 4.0, 1.6, "lock")
	# the pads' rams in the lips, their accumulator behind the throat
	var ru = K.equip("JR-U", "", K.rect(3.0, -4.7, 8.6, -3.5), {"mass": 0.4, "value": 2500.0, "fragile": 0.3, "room": "F", "name_key": "p_ram"})
	K.bolt(ru, K.at(5.8, -2.7, ["hull"]), 5.8, -3.5)
	var rl = K.equip("JR-L", "", K.rect(3.0, 3.0, 8.6, 3.8), {"mass": 0.3, "value": 2500.0, "fragile": 0.3, "room": "F", "name_key": "p_ram"})
	K.bolt(rl, K.at(5.8, 2.6, ["hull"]), 5.8, 3.0)
	var ac = K.equip("ACC-J", "gastank", K.rect(14.2, -5.4, 15.6, -1.6), {"mass": 0.3, "value": 1800.0, "fragile": 0.3, "room": "F", "hazard": "gas_tank", "name_key": "p_accumulator"})
	K.bolt(ac, by_tag["BH1-T"], BH1, -4.0)
	K.bolt(ac, by_tag["BH1-T"], BH1, -2.4, "lock")
	K.lamp("LAMP-F", 11.4, _iy(1, 11.4), "F", K.at(11.4, _iy(1, 11.4) - 0.2, ["hull"]))


# ---------------------------------------------------------------- the workshop

static func _workshop() -> void:
	var fl := DECK
	var dk = by_tag["DECK"]
	var rk = K.equip("PARTS", "nav_rack", K.rect(17.0, fl - 4.6, 20.4, fl), {"mass": 0.8, "value": 6000.0, "fragile": 0.35, "room": "W", "name_key": "p_parts_rack"})
	K.bolt(rk, dk, 17.6, fl)
	K.bolt(rk, dk, 19.8, fl)
	var wb = K.equip("BENCH", "cabinet", K.rect(21.2, fl - 1.6, 25.6, fl), {"mass": 0.6, "value": 3500.0, "fragile": 0.3, "room": "W", "name_key": "p_workbench"})
	K.bolt(wb, dk, 21.8, fl)
	K.bolt(wb, dk, 25.0, fl)
	var lt = K.equip("LATHE", "pump", K.rect(26.2, fl - 2.0, 29.0, fl), {"mass": 1.2, "value": 7000.0, "fragile": 0.35, "room": "W", "name_key": "p_lathe"})
	K.bolt(lt, dk, 26.8, fl)
	K.bolt(lt, dk, 28.4, fl)
	var cn = K.equip("W-CON", "console", K.rect(24.0, -4.4, 27.6, -3.0), {"mass": 0.25, "value": 3000.0, "fragile": 0.5, "room": "W", "name_key": "p_shop_console"})
	# the console on its own stand off the deck
	var stn = K.plate("", K.R(25.6, -3.0, 26.0, fl), {"density": 0.8, "barrier": false, "cut_speed": 200.0}, "strut")
	K.bolt(stn, dk, 25.8, fl, "weld")
	K.bolt(cn, stn, 25.8, -3.0)
	for i in 2:
		var gx := 29.6 + i * 0.9
		var gb = K.equip("WELD-%d" % (i + 1), "gastank", K.rect(gx, fl - 1.9, gx + 0.6, fl), {"mass": 0.07, "value": 400.0, "fragile": 0.3, "room": "W", "hazard": "gas_tank", "name_key": "p_weld_gas"})
		K.bolt(gb, dk, gx + 0.3, fl, "lock")
	K.lamp("LAMP-W", 23.0, -10.35, "W", K.at(23.0, -10.55, ["hull"]))


# ---------------------------------------------------------------- the hydraulics and winch room

static func _hydraulics() -> void:
	var fl := DECK
	var dk = by_tag["DECK"]
	var tk = K.equip("HYD", "water", K.rect(32.6, fl - 2.6, 37.6, fl), {"mass": 0.9, "value": 2500.0, "fragile": 0.3, "room": "H", "name_key": "p_hyd_tank"})
	K.bolt(tk, dk, 33.4, fl, "lock")
	K.bolt(tk, dk, 36.8, fl, "lock")
	var pm = K.equip("PUMP-H", "pump", K.rect(32.0, -6.4, 35.2, -3.6), {"mass": 0.7, "value": 5000.0, "fragile": 0.35, "room": "H", "name_key": "p_hyd_pump"})
	K.bolt(pm, by_tag["BH2-T"], BH2 + 0.4, -5.6)
	K.bolt(pm, by_tag["BH2-T"], BH2 + 0.4, -4.2)
	# the winch: its frame on the deck, the drum on its axle, two brake pins
	var fr = K.equip("W-FRAME", "", K.rect(38.8, -1.0, 45.2, fl), {"cls": "metal", "dest": "metal", "mass": 1.0, "cut_speed": 150.0, "name_key": "p_winch_frame"},
		K.mp([Vector2(38.8, fl), Vector2(45.2, fl), Vector2(44.2, -1.0), Vector2(39.8, -1.0)]))
	K.bolt(fr, dk, 39.6, fl, "weld")
	K.bolt(fr, dk, 44.4, fl, "weld")
	var c := Vector2(42.0, -2.6)
	var dr := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		dr.append(K.p(c.x + cos(a) * 2.3, c.y + sin(a) * 2.3))
	var wd = K.equip("WINCH", "drum", K.rect(39.7, -4.9, 44.3, -0.3), {"mass": 2.2, "value": 12000.0, "fragile": 0.25, "cut_speed": 100.0, "room": "H", "name_key": "p_winch"}, dr)
	K.bolt(wd, fr, 42.0, -0.6, "bolt", "WD-AX")
	K.bolt(wd, fr, 40.4, -0.85, "lock", "WB-1")
	K.bolt(wd, fr, 43.6, -0.85, "lock", "WB-2")
	# the arm's accumulator by the aft bulkhead
	var ac = K.equip("ACC-A", "gastank", K.rect(46.2, -5.6, 47.8, -0.4), {"mass": 0.35, "value": 2200.0, "fragile": 0.3, "room": "H", "hazard": "gas_tank", "name_key": "p_accumulator"})
	K.bolt(ac, by_tag["BH3-T"], BH3, -4.6)
	K.bolt(ac, by_tag["BH3-T"], BH3, -1.4, "lock")
	var sw = K.equip("SWB", "swb", K.rect(32.0, -9.8, 33.8, -7.2), {"mass": 0.6, "value": 5000.0, "fragile": 0.4, "room": "H", "name_key": "p_swb"})
	K.bolt(sw, by_tag["BH2-T"], BH2 + 0.4, -9.0)
	K.bolt(sw, by_tag["BH2-T"], BH2 + 0.4, -7.8)
	K.lamp("LAMP-H", 36.6, -10.35, "H", K.at(36.6, -10.55, ["hull"]))
	# the battery bay under the deck
	var bt = K.equip("BAT", "battery", K.rect(22.0, 6.0, 35.0, BELLY), {"mass": 2.4, "value": 9000.0, "fragile": 0.35, "room": "L", "hazard": "battery", "name_key": "p_battery"})
	K.bolt(bt, K.at(23.0, 8.75, ["hull"]), 23.0, BELLY)
	K.bolt(bt, K.at(34.0, 8.75, ["hull"]), 34.0, BELLY)
	K.lamp("LAMP-L", 40.0, DECK + 0.3, "L", by_tag["DECK"])


# ---------------------------------------------------------------- aft: the hydraulic power unit

static func _aft() -> void:
	var hp = K.equip("HPU", "gen", K.rect(48.4, 1.2, 52.2, _iy(7, 49.0) - 0.05), {"mass": 1.1, "value": 6000.0, "fragile": 0.35, "room": "A", "name_key": "p_hpu"})
	K.bolt(hp, by_tag["BH3-B"], BH3 + 0.4, 4.6)
	K.bolt(hp, by_tag["BH3-T"], BH3 + 0.4, 1.4)
	K.lamp("LAMP-A", 50.2, _iy(5, 50.2), "A", K.at(50.2, _iy(5, 50.2) - 0.2, ["hull"]))
	# the hull support on the stern: set, it carries the hull while the pods come off
	var sp = K.equip("SUP-P", "panel", K.rect(53.0, -1.4, 53.5, 1.4), {"cls": "metal", "dest": "metal", "mass": 0.08, "cut_speed": 220.0, "name_key": "p_support"})
	K.bolt(sp, K.at(52.8, -1.0, ["hull"]), 53.0, -1.0)
	K.bolt(sp, K.at(52.8, 1.0, ["hull"]), 53.0, 1.0)


# ---------------------------------------------------------------- the folded service arm on the roof

static func _bar(a: Vector2, b: Vector2, t: float) -> PackedVector2Array:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x) * t * 0.5
	return K.mp([a + n, b + n, b - n, a - n])


static func _arm() -> void:
	var roof := -10.8
	var bs = K.equip("ARM-B", "", K.rect(35.0, roof - 1.4, 38.4, roof), {"cls": "equip", "mass": 0.9, "value": 4000.0, "fragile": 0.25, "cut_speed": 120.0, "name_key": "p_arm_base"})
	K.bolt(bs, K.at(35.6, roof + 0.2, ["hull"]), 35.6, roof)
	K.bolt(bs, K.at(37.8, roof + 0.2, ["hull"]), 37.8, roof)
	var p1 := Vector2(36.8, -11.9)
	var p2 := Vector2(46.0, -15.6)
	var p3 := Vector2(55.0, -13.8)
	var a1 = K.equip("ARM-1", "", K.rect(36.3, -16.1, 46.5, -11.4), {"cls": "equip", "mass": 1.1, "value": 5500.0, "fragile": 0.25, "cut_speed": 120.0, "name_key": "p_arm_seg"}, _bar(p1, p2, 0.9))
	var a2 = K.equip("ARM-2", "", K.rect(45.5, -16.1, 55.5, -13.3), {"cls": "equip", "mass": 0.9, "value": 5000.0, "fragile": 0.25, "cut_speed": 120.0, "name_key": "p_arm_seg"}, _bar(p2, p3, 0.8))
	var cl = K.equip("CLAW", "", K.rect(54.6, -14.8, 58.2, -12.8), {"cls": "equip", "mass": 0.4, "value": 4500.0, "fragile": 0.3, "cut_speed": 120.0, "name_key": "p_claw"},
		K.mp([Vector2(54.6, -14.6), Vector2(57.4, -14.8), Vector2(58.2, -13.8), Vector2(57.4, -12.8), Vector2(54.6, -13.0)]))
	K.bolt(a1, bs, p1.x, p1.y, "bolt", "AP-1")
	K.bolt(a1, bs, 37.5, -12.15, "lock", "AL-1")
	K.bolt(a2, a1, p2.x, p2.y, "bolt", "AP-2")
	K.bolt(a2, a1, 45.75, -15.35, "lock", "AL-2")
	K.bolt(cl, a2, p3.x, p3.y, "bolt", "AP-3")
	K.bolt(cl, a2, 54.4, -14.0, "lock", "AL-3")
	# the folding cylinder from the base to the first segment
	var cy = K.equip("CYL-A", "", K.rect(38.0, -13.6, 42.6, -11.0), {"mass": 0.25, "value": 2500.0, "fragile": 0.3, "cut_speed": 130.0, "name_key": "p_arm_cyl"}, _bar(Vector2(38.2, -11.2), Vector2(42.4, -13.3), 0.35))
	K.bolt(cy, bs, 38.3, -11.25)
	K.bolt(cy, a1, 42.3, -13.3)


# ---------------------------------------------------------------- the two engine pods behind the stern

static func _pods() -> void:
	for sg in [-1.0, 1.0]:
		var n := "U" if sg < 0.0 else "L"
		var sx := 49.0
		# a strut out of the hull's aft shoulder, a beam back to the pod
		var hull_y := _iy(5 if sg < 0.0 else 7, sx + 0.3)
		var st = K.plate("STR-" + n, K.R(sx, hull_y, sx + 0.6, sg * 9.4), {"density": 2.0, "barrier": false, "cut_speed": 120.0, "name_key": "p_pylon"}, "beam")
		K.bolt(st, K.at(sx + 0.3, hull_y + sg * 0.25, ["hull"]), sx + 0.3, hull_y, "weld")
		var bm = K.plate("PYL-" + n, K.R(sx, sg * 9.4, 54.4, sg * 10.2), {"density": 2.0, "barrier": false, "cut_speed": 120.0, "name_key": "p_pylon"}, "beam")
		K.bolt(bm, st, sx + 0.3, sg * 9.4, "weld")
		# and a tie from the stern's corner to the beam's end
		var tie_y := 5.4 if sg < 0.0 else 6.0
		var ti = K.plate("TIE-" + n, _bar(Vector2(52.75, sg * (tie_y - 0.3)), Vector2(54.0, sg * 9.5), 0.4), {"density": 1.6, "barrier": false, "cut_speed": 130.0, "name_key": "p_pylon"}, "strut")
		K.bolt(ti, K.at(52.75, sg * (tie_y - 0.35), ["hull"]), 52.75, sg * (tie_y - 0.3), "weld")
		K.bolt(ti, bm, 54.0, sg * 9.6, "weld")
		var en = K.equip("ENG-" + n, "eng_core", K.rect(54.4, sg * 11.4, 65.0, sg * 5.6), {"mass": 4.2, "value": 22000.0, "fragile": 0.3, "name_key": "p_engine_pod"})
		K.bolt(en, bm, 54.4, sg * 9.8)
		K.bolt(en, bm, 54.4, sg * 9.5)
		var nz = K.equip("NOZ-" + n, "nozzle", K.rect(65.0, minf(sg * 12.0, sg * 5.0), 70.0, maxf(sg * 12.0, sg * 5.0)), {"cls": "metal", "dest": "metal", "mass": 0.7, "cut_speed": 160.0, "name_key": "p_nozzle"},
			K.mp([Vector2(65.0, sg * 6.4), Vector2(70.0, sg * 5.0), Vector2(70.0, sg * 12.0), Vector2(65.0, sg * 10.6)]))
		K.bolt(nz, en, 65.0, sg * 7.6)
		K.bolt(nz, en, 65.0, sg * 9.4)


# ---------------------------------------------------------------- lines

static func _lines() -> void:
	# the battery up through the deck to the switchboard; out to the loads
	K.line("p1", "cable", "power", "BAT", Vector2(34.6, 6.0), "SWB", Vector2(33.4, -7.2), [Vector2(34.6, 5.0), Vector2(32.3, 5.0), Vector2(32.3, -6.9), Vector2(33.4, -6.9)])
	K.line("p2", "cable", "power", "SWB", Vector2(33.8, -8.4), "LAMP-H", Vector2(36.6, -10.19), [Vector2(36.6, -8.4)])
	K.line("p3", "cable", "power", "SWB", Vector2(33.0, -9.8), "LAMP-W", Vector2(23.0, -10.19), [Vector2(33.0, -10.1), Vector2(23.0, -10.1)])
	K.line("p4", "cable", "power", "LAMP-W", Vector2(22.9, -10.19), "W-CON", Vector2(24.4, -4.4), [Vector2(22.9, -9.6), Vector2(24.4, -9.6)])
	K.line("p5", "cable", "power", "LAMP-W", Vector2(23.1, -10.19), "LAMP-B", Vector2(25.0, -13.24), [Vector2(23.1, -9.8), Vector2(24.6, -9.8), Vector2(24.6, -13.0), Vector2(25.0, -13.0)])
	K.line("p6", "cable", "power", "LAMP-B", Vector2(25.1, -13.24), "HELM", Vector2(30.4, -12.2), [Vector2(25.1, -13.1), Vector2(30.4, -13.1)])
	K.line("p7", "cable", "power", "HELM", Vector2(29.8, -11.6), "TOWLOG", Vector2(24.0, -11.8), [Vector2(29.8, -11.0), Vector2(24.0, -11.0)])
	K.line("p8", "cable", "power", "W-CON", Vector2(24.2, -3.2), "LATHE", Vector2(27.4, 2.2), [Vector2(24.2, -2.6), Vector2(27.4, -2.6)])
	K.line("p9", "cable", "power", "LAMP-W", Vector2(23.0, -10.19), "LAMP-F", Vector2(11.4, -7.19), [Vector2(16.4, -9.0), Vector2(16.4, -7.0), Vector2(11.4, -7.0)])
	K.line("p10", "cable", "power", "SWB", Vector2(33.6, -7.2), "PUMP-H", Vector2(34.2, -6.4), [Vector2(33.6, -6.8), Vector2(34.2, -6.8)])
	K.line("p11", "cable", "power", "SWB", Vector2(33.8, -9.6), "HPU", Vector2(50.4, 1.2), [Vector2(47.9, -9.6), Vector2(47.9, 0.8), Vector2(50.4, 0.8)])
	K.line("p12", "cable", "power", "HPU", Vector2(51.2, 1.2), "LAMP-A", Vector2(50.2, _iy(5, 50.2) + 0.16), [Vector2(51.2, -4.0), Vector2(50.2, -4.0)])
	K.line("p13", "cable", "power", "SWB", Vector2(32.8, -7.2), "LAMP-L", Vector2(40.0, DECK + 0.46), [Vector2(32.8, -6.6), Vector2(32.1, -6.6), Vector2(32.1, 5.2), Vector2(40.0, 5.2)])
	# hydraulics: the tank to the pump, out to both accumulators and the rams
	K.line("h1", "pipe", "hyd", "HYD", Vector2(35.0, 1.6), "PUMP-H", Vector2(34.6, -3.6), [Vector2(35.0, -2.0), Vector2(34.6, -2.0)])
	K.line("h2", "pipe", "hyd", "PUMP-H", Vector2(35.2, -5.0), "ACC-A", Vector2(46.2, -5.0))
	K.line("h3", "pipe", "hyd", "ACC-A", Vector2(47.0, -5.6), "CYL-A", Vector2(39.0, -11.8), [Vector2(47.0, -9.9), Vector2(39.0, -9.9)])
	K.line("h4", "pipe", "hyd", "PUMP-H", Vector2(32.0, -5.2), "ACC-J", Vector2(15.6, -3.4), [Vector2(16.6, -5.2), Vector2(16.6, -3.4)])
	K.line("h5", "pipe", "hyd", "ACC-J", Vector2(14.2, -4.4), "JR-U", Vector2(8.6, -4.1))
	K.line("h6", "pipe", "hyd", "ACC-J", Vector2(14.8, -1.6), "JR-L", Vector2(8.6, 3.4), [Vector2(14.8, 3.4)])


# ---------------------------------------------------------------- controls

static func _controls() -> void:
	K.ctrl("G-B", "port", by_tag["BR-R2"], Vector2(30.0, -14.0), {"medium": "gas", "target": "B"})
	for g in [ ["G-W", 16.6, -8.05, "W"], ["G-H", 42.0, -9.3, "H"], ["G-L", 30.0, 9.25, "L"], ["G-F", 8.0, -8.05, "F"], ["G-A", 50.5, -6.4, "A"]]:
		var gy: float = g[2]
		K.ctrl(g[0], "port", K.at(g[1], gy + (0.4 if gy < 0.0 else -0.4), ["hull"]), Vector2(g[1], gy), {"medium": "gas", "target": g[3]})
	# the outside panel on the belly: the bus breaker, a test point, the berth's supply
	var px = K.equip("PNL-X", "panel", K.rect(36.0, 9.0, 40.4, 9.6), {"cls": "metal", "dest": "metal", "mass": 0.08, "cut_speed": 240.0, "name_key": "p_panel"})
	K.bolt(px, K.at(36.6, 8.8, ["hull"]), 36.6, 9.0)
	K.bolt(px, K.at(39.8, 8.8, ["hull"]), 39.8, 9.0)
	K.ctrl("K-M", "switch", px, Vector2(36.6, 9.35), {"target": "K-M", "state": true})
	K.ctrl("E-1", "test", px, Vector2(37.6, 9.35), {"medium": "volt", "target": "bus"})
	K.ctrl("AUX-P", "socket", px, Vector2(39.6, 9.35), {"target": "aux", "state": false})
	for h in [["HATCH-BR", ""], ["HT-H", ""], ["HT-L", ""], ["HT-F", ""], ["DR-F", "F"], ["DR-WH", "W"], ["DR-HA", "H"]]:
		K.door(h[0], h[1])
	# tension gauges: the winch frame, the jaw's upper ram
	K.ctrl("T-W", "probe", by_tag["W-FRAME"], Vector2(42.0, 2.0), {"medium": "tension", "target": "WD-AX", "hidden_room": "H"})
	K.ctrl("T-J", "probe", by_tag["JR-U"], Vector2(5.8, -4.1), {"medium": "tension", "target": "JP-U", "hidden_room": "F"})
	# the accumulators' bleed ports, the hydraulic tank's
	K.ctrl("PA-A", "port", by_tag["ACC-A"], Vector2(47.0, -0.6), {"medium": "gas", "target": "ACC-A", "hidden_room": "H"})
	K.ctrl("PA-J", "port", by_tag["ACC-J"], Vector2(14.9, -1.8), {"medium": "gas", "target": "ACC-J", "hidden_room": "F"})
	K.ctrl("PH", "port", by_tag["HYD"], Vector2(35.1, 2.6), {"medium": "hydraulic", "target": "hyd", "hidden_room": "H"})
	for i in 2:
		K.ctrl("PW-%d" % (i + 1), "port", by_tag["WELD-%d" % (i + 1)], Vector2(29.9 + i * 0.9, 2.6), {"medium": "gas", "target": "WG-%d" % (i + 1), "hidden_room": "W"})
	# the hull support, outside on the stern
	K.ctrl("SUP", "switch", by_tag["SUP-P"], Vector2(53.3, 0.0), {"target": "SUP", "state": false})


# ---------------------------------------------------------------- rooms

static func _rooms() -> void:
	var inn := K.inner(OUT, T)
	var at := func(i: int, x: float) -> Vector2: return Vector2(x, _iy(i, x))
	# the jaw machinery: round the throat, in both lips, forward of BH1
	w.add_room("F", K.mp([inn[0], inn[1], at.call(1, BH1), at.call(9, BH1), inn[10], inn[11], inn[12], inn[13], inn[14], inn[15], inn[16]]))
	w.add_room("W", K.mp([at.call(1, BH1 + 0.4), inn[2], inn[3], Vector2(BH2, -10.35), Vector2(BH2, DECK), Vector2(BH1 + 0.4, DECK)]))
	w.add_room("H", K.mp([Vector2(BH2 + 0.4, -10.35), inn[4], at.call(4, BH3) if BH3 < inn[5].x else inn[5], at.call(5, BH3), Vector2(BH3, DECK), Vector2(BH2 + 0.4, DECK)]))
	w.add_room("L", K.mp([Vector2(BH1 + 0.4, DECK + 0.3), Vector2(BH3, DECK + 0.3), at.call(7, BH3), inn[8], inn[9], at.call(9, BH1 + 0.4)]))
	w.add_room("A", K.mp([at.call(5, BH3 + 0.4), inn[6], inn[7], at.call(7, BH3 + 0.4)]))
	w.add_room("B", K.mp([Vector2(22.55, -10.8), Vector2(24.1, -13.4), Vector2(31.2, -13.4), Vector2(33.45, -10.8)]))


static func meta() -> Dictionary:
	return {
		"id": "tw64",
		"name": "TW-64 BEDROCK",
		"title": ["TW-64「磐石」维修拖船 · 70 m", "TW-64 BEDROCK · SALVAGE TUG AND WORKSHOP · 70 m"],
		"contract": "TW-64",
		"length": 70.0,
		"value": {"total": 190000.0, "metal": 26000.0},
		"clamps": [[22.0, 9.0], [34.0, 9.0], [44.0, 9.0]],
		"room_names": {"F": "room_twF", "W": "room_twW", "H": "room_twH", "L": "room_twL", "A": "room_twA", "B": "room_twB"},
		"gas": {"rooms": {"F": 101.0, "W": 101.0, "H": 101.0, "L": 101.0, "A": 101.0, "B": 101.0},
			"vessels": {
				"ACC-A": {"V": 0.06, "kpa": 1800.0, "piece": "ACC-A", "burst": 200.0},
				"ACC-J": {"V": 0.04, "kpa": 1600.0, "piece": "ACC-J", "burst": 200.0},
				"WG-1": {"V": 0.01, "kpa": 1500.0, "piece": "WELD-1", "burst": 200.0},
				"WG-2": {"V": 0.01, "kpa": 1500.0, "piece": "WELD-2", "burst": 200.0},
			}, "valves": [], "value": 1200.0},
		"preloads": {
			# the winch's drum: the line still taut on its brake
			"WD-AX": {"pins": ["WB-1", "WB-2"], "vessel": "", "kpa": 300.0, "piece": "WINCH", "push": [0.6, -0.8], "hits": "W-FRAME", "kn": 64.0},
			# the jaw's pads: pinned, on their accumulator, and on the line the winch still holds
			"JP-U": {"pins": ["JL-U", "WB-1", "WB-2"], "vessel": "ACC-J", "kpa": 300.0, "piece": "JAW-U", "push": [0.0, 0.9], "hits": "TOW", "kn": 48.0},
			"JP-L": {"pins": ["JL-L", "WB-1", "WB-2"], "vessel": "ACC-J", "kpa": 300.0, "piece": "JAW-L", "push": [0.0, -0.9], "hits": "TOW", "kn": 48.0},
			# the arm folded on its cylinder
			"AP-1": {"pins": ["AL-1"], "vessel": "ACC-A", "kpa": 300.0, "piece": "ARM-1", "push": [0.6, -0.7], "hits": "ARM-B", "kn": 30.0},
			"AP-2": {"pins": ["AL-2"], "vessel": "ACC-A", "kpa": 300.0, "piece": "ARM-2", "push": [0.8, -0.4], "hits": "ARM-1", "kn": 24.0},
			"AP-3": {"pins": ["AL-3"], "vessel": "ACC-A", "kpa": 300.0, "piece": "CLAW", "push": [0.9, 0.2], "hits": "ARM-2", "kn": 12.0},
		},
		"balance": {"pairs": [["ENG-U", "ENG-L", ["PYL-U", "STR-U", "TIE-U"], ["PYL-L", "STR-L", "TIE-L"]]], "support": "SUP"},
		"power": {
			"bus": "SWB",
			"sources": [
				{"piece": "BAT", "kind": "battery", "volts": 440.0, "local_volts": 48.0, "cable": "p1", "switch": "K-M", "charge": 0.9, "drain": 0.0003},
			],
			"lamps": {"F": "LAMP-F", "W": "LAMP-W", "H": "LAMP-H", "L": "LAMP-L", "A": "LAMP-A", "B": "LAMP-B"},
		},
		"fluids": {"volumes": {
			"hyd": {"fluid": "hydraulic", "amount": 0.7, "piece": "HYD", "content": 1.0, "leak": 0.12, "port": "PH", "pump": [0.12, 0.008]},
			"hyd_line": {"fluid": "hydraulic", "amount": 0.02, "nets": ["hyd"], "leak": 0.06, "leak_min": 0.004},
		}, "joins": [], "value": {"hydraulic": 900.0}},
		"ctrls_cfg": {"G-B": {"rate": 7.0}, "G-W": {"rate": 10.0}, "G-H": {"rate": 10.0}, "G-L": {"rate": 8.0}, "G-F": {"rate": 8.0}, "G-A": {"rate": 5.0},
			"PA-A": {"rate": 0.4}, "PA-J": {"rate": 0.3}, "PW-1": {"rate": 0.2}, "PW-2": {"rate": 0.2}},
		"labels": {"HYD": "HYD", "ACC-A": "ACC", "ACC-J": "ACC", "SWB": "SWB", "BAT": "BAT", "TOWLOG": "LOG", "WINCH": "WINCH", "HPU": "HPU", "WELD-1": "O₂", "WELD-2": "C₂H₂"},
		"hints": {},
		"market": {
			"class": "TW", "name": ["磐石级维修拖船", "BEDROCK-CLASS SALVAGE TUG"], "time": 32.0,
			"rooms": {"W": [0.2, 40.0, 101.0], "H": [0.2, 40.0, 101.0], "B": [0.2, 40.0, 101.0], "L": [0.2, 40.0, 101.0], "F": [0.25, 0.0, 101.0]},
			"charge": {"BAT": [0.2, 1.0]},
			"fluids": {"hyd": [0.1, 0.7]}, "fill": {"hyd_line": "hyd"},
			"knockable": ["W-CON", "HELM", "PARTS", "LATHE"],
			"drift": [],
			"section_x": 31.6,
			"slots": {"hidden_damage": {"plates": ["HL3-2", "HL3-3", "HL8-2", "HL8-3", "HL8-5"]}},
			"mechanisms": true,
		},
		"procedures": {
			"TOWLOG": [
				{"do": "hose", "ctrl": "G-B"},
				{"do": "wait", "until": {"P": ["B", "<", 5.0]}, "max": 150.0},
				{"do": "operate", "ctrl": "HATCH-BR"},
				{"do": "wait", "until": {"open": ["B"]}, "max": 5.0},
				{"do": "operate", "ctrl": "K-M"},
				{"do": "measure", "ctrl": "E-1", "expect": ["<", 1.0]},
				{"do": "free", "piece": "TOWLOG"},
				{"do": "deliver", "piece": "TOWLOG", "zone": "equip"},
			],
		},
	}
