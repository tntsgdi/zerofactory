class_name Jd38Author
# Authoring script for JD-38 "Turtledove", a 34 m express courier (R2 fleet,
# design/ships/全新舰队_R2_2026-10-18/JD-38_斑鸠.md; lengths as drawn, heights at
# 0.6 of the drawing, player 2026-10-19). Not part of the game:
# tools/ship_export.gd runs it and writes ships/jd38.json.
# Metres, x bow (0) to the nozzle (37), y down.
#
# A low wedge with the cockpit raised under its canopy, the machinery room under
# the cockpit deck, the hold behind them and the cargo lock at the stern; the main
# engine hangs under the stern on two pylons, the landing legs fold under the belly.
# What it asks of you: two boxes of express cargo ride two lock rails that run
# through the hold door and the stern cargo door. The rail locks hold them, not
# bolts: open both doors (they run on the bus: before the battery is isolated, or
# with the berth's supply), then turn the rails' locks off on the panel in the
# cargo lock and the boxes slide out along them; a shut door stops them hard.
# Cut a rail that still carries its box and the box is wrenched with it.
# The battery has its own switch in the machinery room and its own test point
# outside: the bus reads dead only once that switch is open.

const K = preload("res://tools/authoring/kit.gd")
const T := 0.35
const OUT := [Vector2(0.0, 0.6), Vector2(4.0, -3.0), Vector2(7.0, -6.6), Vector2(15.0, -7.2), Vector2(19.0, -4.8), Vector2(20.0, -2.4),
	Vector2(31.0, -2.4), Vector2(34.0, -1.0), Vector2(34.0, 3.6), Vector2(30.0, 4.8), Vector2(27.0, 6.0), Vector2(9.0, 6.0), Vector2(3.0, 3.6)]
const ROOF := -2.05              # the hold's ceiling (inside the roof plates)
const BELLY := 5.65              # the floor inside the belly
const B1 := 13.6                 # the bulkhead between the cockpit / machinery room and the hold (to 14.0)
const B2 := 29.0                 # the hold's aft bulkhead, the hold door in it (to 29.4)
const DECK := 1.6                # the cockpit deck (plate to 1.9)
const RU := 1.2                  # the upper rail's top (to 1.35)
const RL := 3.0                  # the lower rail's top (to 3.15)

static var w
static var by_tag := {}


static func build(world) -> void:
	K.begin(world, "JD38")
	w = world
	by_tag = K.by_tag
	_hull()
	_inside()
	_cockpit()
	_machinery()
	_hold()
	_engine()
	_lines()
	_controls()
	_rooms()


static func rooms_only(world) -> void:
	K.begin(world, "JD38")
	w = world
	_rooms()


# ---------------------------------------------------------------- the hull

static func _hull() -> void:
	K.ring(OUT, T, {
		2: [0.45, 0.65],
		5: [0.5],
		7: [0.04, 0.96],
		10: [0.25, 0.5, 0.75],
		11: [0.35, 0.75],
	}, {
		"1:0": {"art": "window", "tag": "CAN-F"},
		"2:0": {"art": "window", "tag": "CAN-T"},
		"2:1": {"kind": "hatch", "door": true, "tag": "HT-C", "open_dir": Vector2(1.6, 0.1) * Geom.M, "cut_speed": 200.0},
		"3:0": {"tag": "CAN-R"},
		"5:0": {"tag": "ROOF-1"},
		"5:1": {"tag": "ROOF-2"},
		"6:0": {"tag": "AFT-T"},
		"7:1": {"kind": "door", "door": true, "tag": "DR-ST", "open_dir": Vector2(0, -4.6) * Geom.M, "cut_speed": 200.0, "density": 1.2},
		"10:0": {"tag": "BELLY-1"},
		"10:1": {"tag": "BELLY-2"},
		"10:2": {"tag": "BELLY-3"},
		"10:3": {"tag": "BELLY-4"},
		"11:1": {"kind": "hatch", "door": true, "tag": "HT-M", "open_dir": Vector2(-1.3, -0.5) * Geom.M, "cut_speed": 200.0},
	}, {"density": 1.5, "barrier": true, "cut_speed": 230.0}, "HL")
	K.clamp(1, 12.0, 6.0, 5.8)
	K.clamp(2, 18.0, 6.0, 5.8)
	K.clamp(3, 24.0, 6.0, 5.8)


# ---------------------------------------------------------------- bulkheads and the deck

static func _inside() -> void:
	var S := {"density": 1.2, "barrier": true, "cut_speed": 230.0}
	var D := {"density": 1.0, "door": true, "cut_speed": 210.0}
	# B1: cockpit / machinery forward of it, the hold aft; the cockpit's door to the hold
	var b1t = K.plate("B1-T", K.R(B1, -6.85, B1 + 0.4, -1.4), S, "bulkhead")
	var drc = K.plate("DR-CH", K.R(B1, -1.4, B1 + 0.4, DECK), D.merged({"open_dir": Vector2(0, -2.6) * Geom.M}), "door")
	var b1b = K.plate("B1-B", K.R(B1, DECK, B1 + 0.4, BELLY), S, "bulkhead")
	K.bolt(b1t, K.at(B1 + 0.2, -6.95, ["hull"]), B1 + 0.2, -6.8, "weld")
	K.bolt(b1b, K.at(B1 + 0.2, 5.85, ["hull"]), B1 + 0.2, BELLY, "weld")
	K.bolt(drc, b1t, B1 + 0.2, -1.4, "weld")
	K.bolt(drc, b1b, B1 + 0.2, DECK, "weld")
	# B2: the hold door, tall enough for both rails' boxes
	var b2t = K.plate("B2-T", K.R(B2, ROOF, B2 + 0.4, -1.6), S, "bulkhead")
	var drh = K.plate("DR-H", K.R(B2, -1.6, B2 + 0.4, 3.9), D.merged({"open_dir": Vector2(0, 5.4) * Geom.M}), "door")
	var b2b = K.plate("B2-B", K.R(B2, 3.9, B2 + 0.4, 4.85), S, "bulkhead")
	K.bolt(b2t, K.at(B2 + 0.2, -2.25, ["hull"]), B2 + 0.2, ROOF, "weld")
	K.bolt(b2b, K.at(B2 + 0.2, 4.98, ["hull"]), B2 + 0.2, 4.82, "weld")
	K.bolt(drh, b2t, B2 + 0.2, -1.6, "weld")
	K.bolt(drh, b2b, B2 + 0.2, 3.9, "weld")
	# the cockpit deck over the machinery room
	var dk = K.plate("DK-C", K.R(1.45, DECK, B1, DECK + 0.3), {"density": 1.0, "barrier": true, "cut_speed": 230.0}, "deck")
	K.bolt(dk, K.at(1.4, DECK + 0.15, ["hull"]), 1.5, DECK + 0.15, "weld")
	K.bolt(dk, b1b, B1, DECK + 0.15, "weld")


# ---------------------------------------------------------------- the cockpit

static func _cockpit() -> void:
	var dk = by_tag["DK-C"]
	for i in 2:
		var sx := 6.4 + i * 3.0
		var st = K.seat("SEAT-%d" % (i + 1), Rect2(sx, DECK - 1.5, 0.8, 1.5), {"room": "C", "name_key": "p_seat_pilot"})
		K.bolt(st, dk, sx + 0.2, DECK)
		K.bolt(st, dk, sx + 0.6, DECK, "lock")
	var nav = K.equip("NAV", "nav", K.rect(2.9, -0.4, 5.6, DECK), {"mass": 0.3, "value": 6000.0, "fragile": 0.5, "room": "C", "name_key": "p_nav"},
		K.mp([Vector2(2.9, DECK), Vector2(5.6, DECK), Vector2(5.6, -0.4), Vector2(4.2, -0.4)]))
	K.bolt(nav, dk, 4.0, DECK)
	K.bolt(nav, dk, 5.2, DECK)
	var av = K.equip("AV", "nav_rack", K.rect(11.4, -2.6, 13.4, DECK), {"mass": 0.35, "value": 5000.0, "fragile": 0.5, "room": "C", "name_key": "p_avionics"})
	K.bolt(av, dk, 11.9, DECK)
	K.bolt(av, by_tag["B1-T"], B1, -2.0)
	var fdr = K.equip("FDR", "cabinet", K.rect(12.0, -4.6, 13.4, -3.4), {"mass": 0.06, "value": 4500.0, "fragile": 0.4, "room": "C", "mandatory": true, "name_key": "p_fdr"})
	K.bolt(fdr, by_tag["B1-T"], B1, -4.3)
	K.bolt(fdr, by_tag["B1-T"], B1, -3.7, "lock")
	var cm = K.equip("COMMS", "console", K.rect(7.4, -6.25, 9.2, -5.25), {"mass": 0.15, "value": 3000.0, "fragile": 0.5, "room": "C", "name_key": "p_comms_panel"})
	K.bolt(cm, K.at(8.3, -6.5, ["hull"]), 8.3, -6.25)
	K.lamp("LAMP-C", 9.9, -6.47, "C", K.at(9.9, -6.65, ["hull"]))


# ---------------------------------------------------------------- the machinery room under the deck

static func _machinery() -> void:
	var fl := BELLY
	var bt = K.equip("BAT-P", "battery", K.rect(9.6, 4.1, 11.6, fl), {"mass": 0.6, "value": 3500.0, "fragile": 0.4, "room": "M", "hazard": "battery", "name_key": "p_battery"})
	K.bolt(bt, K.at(10.0, 5.8, ["hull"]), 10.0, fl)
	K.bolt(bt, K.at(11.2, 5.8, ["hull"]), 11.2, fl)
	var ecs = K.equip("ECS", "env", K.rect(11.8, 3.4, 13.5, fl), {"mass": 0.5, "value": 4000.0, "fragile": 0.4, "room": "M", "name_key": "p_ecs"})
	K.bolt(ecs, K.at(12.6, 5.8, ["hull"]), 12.6, fl)
	K.bolt(ecs, by_tag["B1-B"], B1, 4.0)
	var pdu = K.equip("PDU", "swb", K.rect(6.6, DECK + 0.3, 8.6, 3.4), {"mass": 0.3, "value": 3000.0, "fragile": 0.4, "room": "M", "name_key": "p_pdu"})
	K.bolt(pdu, by_tag["DK-C"], 7.0, DECK + 0.3)
	K.bolt(pdu, by_tag["DK-C"], 8.2, DECK + 0.3)
	var o2 = K.equip("O2-1", "gastank", K.rect(9.0, DECK + 0.3, 9.7, 3.6), {"mass": 0.06, "value": 500.0, "fragile": 0.3, "room": "M", "hazard": "gas_tank", "name_key": "p_o2bottle"})
	K.bolt(o2, by_tag["DK-C"], 9.35, DECK + 0.3, "lock")
	K.lamp("LAMP-M", 5.6, DECK + 0.3, "M", by_tag["DK-C"])


# ---------------------------------------------------------------- the hold, its rails, the cargo lock

static func _hold() -> void:
	var R := {"density": 1.0, "barrier": false, "cut_speed": 190.0, "name_key": "p_rail"}
	# the rails: the hold's length, then on through the cargo lock to the stern door
	var ru = K.plate("RL-U", K.R(B1 + 0.4, RU, B2, RU + 0.15), R, "rail")
	var rl = K.plate("RL-L", K.R(B1 + 0.4, RL, B2, RL + 0.15), R, "rail")
	var ru2 = K.plate("RL-U2", K.R(B2 + 0.4, RU, 32.6, RU + 0.15), R, "rail")
	var rl2 = K.plate("RL-L2", K.R(B2 + 0.4, RL, 32.6, RL + 0.15), R, "rail")
	for r in [[ru, RU], [rl, RL]]:
		K.bolt(r[0], by_tag["B1-B"] if r[1] > DECK else by_tag["DR-CH"], B1 + 0.4, r[1] + 0.075, "weld")
		K.bolt(r[0], by_tag["DR-H"], B2, r[1] + 0.075, "weld")
	# the lock rails run from the hold door's frame on posts off the lock's floor
	for r in [[ru2, RU], [rl2, RL]]:
		K.bolt(r[0], by_tag["DR-H"], B2 + 0.4, r[1] + 0.075, "weld")
	var lp = K.plate("", K.R(31.0, RL + 0.15, 31.2, 4.15), {"density": 0.8, "barrier": false, "cut_speed": 200.0}, "strut")
	K.bolt(lp, rl2, 31.1, RL + 0.15, "weld")
	K.bolt(lp, K.at(31.1, 4.3, ["hull"]), 31.1, 4.12, "weld")
	# a post down to the belly under the lower rail (nothing stands between the rails: the boxes run there)
	for px in [26.6]:
		var po = K.plate("", K.R(px, RL + 0.15, px + 0.2, BELLY), {"density": 0.8, "barrier": false, "cut_speed": 200.0}, "strut")
		K.bolt(po, rl, px + 0.1, RL + 0.15, "weld")
		K.bolt(po, K.at(px + 0.1, 5.85, ["hull"]), px + 0.1, BELLY, "weld")
	# the two boxes of express cargo, each held to its rail by the rail's locks
	var b1 = K.equip("BOX-1", "cargo", K.rect(15.4, RU - 1.6, 25.4, RU), {"mass": 1.3, "value": 17000.0, "fragile": 0.5, "room": "H", "name_key": "p_express"})
	K.bolt(b1, ru, 16.4, RU, "lock")
	K.bolt(b1, ru, 24.4, RU, "lock")
	var b2 = K.equip("BOX-2", "cargo", K.rect(15.4, RL - 1.6, 25.4, RL), {"mass": 1.3, "value": 17000.0, "fragile": 0.5, "room": "H", "name_key": "p_express"})
	K.bolt(b2, rl, 16.4, RL, "lock")
	K.bolt(b2, rl, 24.4, RL, "lock")
	# the propellant tank under the lower rail
	var tk = K.equip("TK-F", "fueltank", K.rect(19.0, 3.7, 23.6, BELLY), {"mass": 0.5, "value": 1500.0, "fragile": 0.3, "room": "H", "hazard": "fuel_tank", "name_key": "p_fueltank"})
	K.bolt(tk, K.at(19.6, 5.8, ["hull"]), 19.6, BELLY)
	K.bolt(tk, K.at(23.0, 5.8, ["hull"]), 23.0, BELLY)
	# the rail-lock panel in the cargo lock, on its ceiling
	var pr = K.equip("PNL-R", "panel", K.rect(29.6, ROOF, 31.8, -1.4), {"cls": "metal", "dest": "metal", "mass": 0.05, "room": "L", "cut_speed": 240.0, "name_key": "p_rail_panel"})
	K.bolt(pr, K.at(30.4, -2.25, ["hull"]), 30.4, ROOF)
	K.lamp("LAMP-H", 21.5, ROOF, "H", K.at(21.5, -2.25, ["hull"]))
	K.lamp("LAMP-L", 32.4, -1.4, "L", K.at(32.4, -1.58, ["hull"]))


# ---------------------------------------------------------------- the engine under the stern, the legs

static func _engine() -> void:
	var py: Array = []
	for px in [[25.0, 6.0], [29.6, 4.95]]:
		var pl = K.plate("", K.R(px[0], px[1], px[0] + 0.5, 6.4), {"density": 1.6, "barrier": false, "cut_speed": 160.0, "name_key": "p_pylon"}, "beam")
		K.bolt(pl, K.at(px[0] + 0.25, px[1] - 0.2, ["hull"]), px[0] + 0.25, px[1], "weld")
		py.append(pl)
	var en = K.equip("ENG", "eng_core", K.rect(24.0, 6.4, 32.0, 8.8), {"mass": 2.6, "value": 14000.0, "fragile": 0.3, "name_key": "p_engine"})
	K.bolt(en, py[0], 25.25, 6.4)
	K.bolt(en, py[1], 29.85, 6.4)
	var nz = K.equip("NOZ", "nozzle", K.rect(32.0, 5.9, 37.0, 9.3), {"cls": "metal", "dest": "metal", "mass": 0.4, "cut_speed": 170.0, "name_key": "p_nozzle"},
		K.mp([Vector2(32.0, 6.8), Vector2(37.0, 5.9), Vector2(37.0, 9.3), Vector2(32.0, 8.4)]))
	K.bolt(nz, en, 32.0, 7.2)
	K.bolt(nz, en, 32.0, 8.0)
	for lx in [10.4, 21.0]:
		var lg = K.equip("LEG-%d" % (1 if lx < 15.0 else 2), "", K.rect(lx, 6.0, lx + 0.4, 7.7), {"cls": "metal", "dest": "metal", "mass": 0.12, "cut_speed": 180.0, "name_key": "p_leg"})
		K.bolt(lg, K.at(lx + 0.2, 5.8, ["hull"]), lx + 0.2, 6.0)
		var ft = K.equip("", "", K.rect(lx - 0.6, 7.7, lx + 1.0, 7.95), {"cls": "metal", "dest": "metal", "mass": 0.05, "cut_speed": 200.0, "name_key": "p_foot"})
		K.bolt(ft, lg, lx + 0.2, 7.7, "weld")


# ---------------------------------------------------------------- lines

static func _lines() -> void:
	K.line("p1", "cable", "power", "BAT-P", Vector2(10.6, 4.1), "PDU", Vector2(8.4, 3.2), [Vector2(10.6, 3.7), Vector2(8.4, 3.7)])
	K.line("p2", "cable", "power", "PDU", Vector2(8.6, 2.4), "ECS", Vector2(12.0, 3.4), [Vector2(12.0, 2.4)])
	K.line("p3", "cable", "power", "PDU", Vector2(6.6, 2.4), "LAMP-M", Vector2(5.6, DECK + 0.46), [Vector2(5.6, 2.4)])
	K.line("p4", "cable", "power", "PDU", Vector2(7.2, DECK + 0.3), "NAV", Vector2(5.0, 0.4), [Vector2(7.2, 1.2), Vector2(5.0, 1.2)])
	K.line("p5", "cable", "power", "NAV", Vector2(5.4, -0.2), "AV", Vector2(11.4, -1.0), [Vector2(5.8, -1.0)])
	K.line("p6", "cable", "power", "AV", Vector2(12.4, -2.6), "FDR", Vector2(12.7, -3.4), [Vector2(12.4, -3.0), Vector2(12.7, -3.0)])
	K.line("p7", "cable", "power", "AV", Vector2(11.6, -2.6), "LAMP-C", Vector2(9.9, -6.31), [Vector2(11.6, -6.0), Vector2(9.9, -6.0)])
	K.line("p8", "cable", "power", "LAMP-C", Vector2(9.7, -6.31), "COMMS", Vector2(9.0, -5.6), [Vector2(9.7, -5.6)])
	# through the bulkhead under the deck and along the hold's ceiling
	K.line("p9", "cable", "power", "PDU", Vector2(8.6, 3.0), "LAMP-H", Vector2(21.5, ROOF + 0.16), [Vector2(13.0, 3.0), Vector2(13.0, -1.9), Vector2(21.5, -1.9)])
	K.line("p10", "cable", "power", "LAMP-H", Vector2(21.7, ROOF + 0.16), "PNL-R", Vector2(29.8, -1.6), [Vector2(28.8, -1.9), Vector2(29.8, -1.9)])
	K.line("p11", "cable", "power", "PNL-R", Vector2(31.6, -1.6), "LAMP-L", Vector2(32.4, -1.25), [Vector2(32.4, -1.6)])
	K.line("f1", "pipe", "fuel", "TK-F", Vector2(23.4, 5.4), "ENG", Vector2(25.4, 6.6), [Vector2(24.0, 5.4), Vector2(24.0, 6.6)])


# ---------------------------------------------------------------- controls

static func _controls() -> void:
	K.ctrl("G-C", "port", K.at(13.4, -6.95, ["hull"]), Vector2(13.4, -7.25), {"medium": "gas", "target": "C"})
	K.ctrl("G-H", "port", K.at(22.0, -2.25, ["hull"]), Vector2(22.0, -2.55), {"medium": "gas", "target": "H"})
	K.ctrl("G-L", "port", K.at(32.5, -1.45, ["hull"]), Vector2(32.5, -1.85), {"medium": "gas", "target": "L"})
	K.ctrl("G-M", "port", K.at(10.0, 5.85, ["hull"]), Vector2(10.0, 6.15), {"medium": "gas", "target": "M"})
	# the outside panel on the belly: the bus and the battery's own terminals, the berth's supply
	var px = K.equip("PNL-X", "panel", K.rect(13.0, 6.0, 16.4, 6.5), {"cls": "metal", "dest": "metal", "mass": 0.05, "cut_speed": 240.0, "name_key": "p_panel"})
	K.bolt(px, K.at(13.5, 5.8, ["hull"]), 13.5, 6.0)
	K.bolt(px, K.at(15.9, 5.8, ["hull"]), 15.9, 6.0)
	K.ctrl("E-BUS", "test", px, Vector2(13.6, 6.3), {"medium": "volt", "target": "bus"})
	K.ctrl("E-BAT", "test", px, Vector2(14.6, 6.3), {"medium": "volt", "target": "BAT-P"})
	K.ctrl("AUX-P", "socket", px, Vector2(15.8, 6.3), {"target": "aux", "state": false})
	for h in [["HT-C", ""], ["HT-M", ""], ["DR-ST", ""], ["DR-CH", "C"], ["DR-H", "H"]]:
		K.door(h[0], h[1])
	K.ctrl("K-BAT", "switch", by_tag["BAT-P"], Vector2(10.0, 4.5), {"target": "K-BAT", "state": true, "hidden_room": "M"})
	K.ctrl("LK-U", "switch", by_tag["PNL-R"], Vector2(30.1, -1.7), {"target": "LK-U", "state": true, "hidden_room": "L"})
	K.ctrl("LK-L", "switch", by_tag["PNL-R"], Vector2(31.0, -1.7), {"target": "LK-L", "state": true, "hidden_room": "L"})
	K.ctrl("O2P", "port", by_tag["O2-1"], Vector2(9.35, 2.2), {"medium": "gas", "target": "O2", "hidden_room": "M"})
	K.ctrl("PF-1", "port", by_tag["TK-F"], Vector2(21.3, 4.1), {"medium": "fuel", "target": "fuel", "hidden_room": "H"})


# ---------------------------------------------------------------- rooms

static func _rooms() -> void:
	var inn := K.inner(OUT, T)
	# where the inside of an edge runs at x (between inner corners i and j)
	var on := func(i: int, j: int, x: float) -> Vector2:
		var a: Vector2 = inn[i]
		var b: Vector2 = inn[j]
		return Vector2(x, a.y + (x - a.x) / (b.x - a.x) * (b.y - a.y))
	var bow := func(y: float) -> Vector2:
		var a: Vector2 = inn[12]
		var b: Vector2 = inn[0]
		return Vector2(a.x + (y - a.y) / (b.y - a.y) * (b.x - a.x), y)
	# the cockpit: under the canopy, down to the deck, forward of B1
	w.add_room("C", K.mp([bow.call(DECK), inn[0], inn[1], inn[2], on.call(2, 3, B1), Vector2(B1, DECK)]))
	# the machinery room under the deck
	w.add_room("M", K.mp([bow.call(DECK + 0.3), Vector2(B1, DECK + 0.3), Vector2(B1, BELLY), inn[11], inn[12]]))
	# the hold: from B1 up under the canopy's back and the roof to the hold door
	w.add_room("H", K.mp([on.call(2, 3, B1 + 0.4), inn[3], inn[4], inn[5], Vector2(B2, ROOF), on.call(9, 10, B2), inn[10], Vector2(B1 + 0.4, BELLY)]))
	# the cargo lock: aft of the hold door to the stern door
	w.add_room("L", K.mp([Vector2(B2 + 0.4, ROOF), inn[6], inn[7], inn[8], inn[9], on.call(9, 10, B2 + 0.4)]))


static func meta() -> Dictionary:
	return {
		"id": "jd38",
		"name": "JD-38 TURTLEDOVE",
		"title": ["JD-38「斑鸠」短途快件艇 · 37 m", "JD-38 TURTLEDOVE · EXPRESS COURIER · 37 m"],
		"contract": "JD-38",
		"length": 37.0,
		"value": {"total": 98000.0, "metal": 9000.0},
		"clamps": [[12.0, 6.0], [18.0, 6.0], [24.0, 6.0]],
		"room_names": {"C": "room_jdC", "M": "room_jdM", "H": "room_jdH", "L": "room_jdL"},
		"gas": {"rooms": {"C": 101.0, "M": 101.0, "H": 101.0, "L": 101.0},
			"vessels": {"O2": {"V": 0.012, "kpa": 1500.0, "piece": "O2-1", "burst": 200.0}}, "valves": [], "value": 500.0},
		"power": {
			"bus": "PDU",
			"sources": [
				{"piece": "BAT-P", "kind": "battery", "volts": 120.0, "local_volts": 48.0, "cable": "p1", "switch": "K-BAT", "charge": 0.85, "drain": 0.0003},
			],
			"lamps": {"C": "LAMP-C", "M": "LAMP-M", "H": "LAMP-H", "L": "LAMP-L"},
		},
		"fluids": {"volumes": {
			"fuel": {"fluid": "fuel", "amount": 0.35, "piece": "TK-F", "content": 0.5, "leak": 0.12, "port": "PF-1", "pump": [0.15, 0.01], "hazard": 0.03},
			"fuel_line": {"fluid": "fuel", "amount": 0.01, "nets": ["fuel"], "leak": 0.05, "leak_min": 0.004},
		}, "joins": [], "value": {"fuel": 1200.0}},
		"rails": {
			"U": {"lock": "LK-U", "boxes": ["BOX-1"], "rails": ["RL-U", "RL-U2"], "out": [2.2, 0.0], "doors": ["DR-H", "DR-ST"]},
			"L": {"lock": "LK-L", "boxes": ["BOX-2"], "rails": ["RL-L", "RL-L2"], "out": [2.2, 0.0], "doors": ["DR-H", "DR-ST"]},
		},
		"ctrls_cfg": {"G-C": {"rate": 7.0}, "G-M": {"rate": 6.0}, "G-H": {"rate": 9.0}, "G-L": {"rate": 5.0}, "O2P": {"rate": 0.25}},
		"labels": {"BAT-P": "BAT", "PDU": "PDU", "TK-F": "FUEL", "O2-1": "O₂", "BOX-1": "EXPRESS", "BOX-2": "EXPRESS", "FDR": "FDR", "ECS": "ECS"},
		"hints": {},
		"market": {
			"class": "JD", "name": ["斑鸠级快件艇", "TURTLEDOVE-CLASS COURIER"], "time": 18.0,
			"rooms": {"C": [0.2, 40.0, 101.0], "H": [0.2, 40.0, 101.0], "M": [0.2, 40.0, 101.0], "L": [0.2, 40.0, 101.0]},
			"charge": {"BAT-P": [0.2, 1.0]},
			"fluids": {"fuel": [0.05, 0.35]}, "fill": {"fuel_line": "fuel"},
			"knockable": ["NAV", "AV", "COMMS", "ECS"],
			"drift": [],
			"section_x": 14.0,
			"slots": {"hidden_damage": {"plates": ["ROOF-1", "ROOF-2", "BELLY-2", "BELLY-3"]}, "fire_system": {"x": 16.0, "y0": 3.9, "y1": 5.65, "base": ["BELLY-3", 5.65], "room": "H", "port": [16.4, 3.97]}},
			"mechanisms": true,
		},
		"procedures": {
			"FDR": [
				{"do": "hose", "ctrl": "G-C"},
				{"do": "wait", "until": {"P": ["C", "<", 5.0]}, "max": 120.0},
				{"do": "operate", "ctrl": "HT-C"},
				{"do": "wait", "until": {"open": ["C"]}, "max": 5.0},
				{"do": "hose", "ctrl": "G-M"},
				{"do": "wait", "until": {"P": ["M", "<", 5.0]}, "max": 120.0},
				{"do": "operate", "ctrl": "HT-M"},
				{"do": "wait", "until": {"open": ["M"]}, "max": 5.0},
				{"do": "operate", "ctrl": "K-BAT"},
				{"do": "measure", "ctrl": "E-BUS", "expect": ["<", 1.0]},
				{"do": "free", "piece": "FDR"},
				{"do": "deliver", "piece": "FDR", "zone": "equip"},
			],
		},
	}
