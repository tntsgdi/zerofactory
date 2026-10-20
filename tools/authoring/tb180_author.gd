class_name Tb180Author
# Authoring script for TB-180 "Binary", a 185 m tethered twin-pod transport (exotic
# batch 07/10, design/ships/TB-180_连星_设计稿.md and TB-180_线稿.png, as drawn). Not
# part of the game: tools/ship_export.gd runs it and writes ships/tb180.json.
# Metres, x bow (0) to the nozzle (~185), y down.
#
# The A pod forward (control deck over the crew deck), a 148 m tether of eight
# segments spliced end to end and cast into both pods, the berth's brake gripping it
# in the middle (four pairs of rollers in a frame, its cooler and its control box),
# the B pod aft (the propellant deck over the power deck), its engine and its RCS.
# What it asks of you (scripts/tether.gd): the pair still turns at 2 rpm. Brake it with
# the brake's cooling on (braked dry its rollers slip for good, and then only the B
# pod's RCS can stop it, on the B pod's own battery and propellant), then let the
# brake's tensioner off; the tether parts quietly only once the pair is stopped and
# slack. Cut it while it turns and both pods are thrown; while it still pulls it
# whips, and its worn segment (two of seven strands gone) parts the lot.

const K = preload("res://tools/authoring/kit.gd")
const T := 0.45
const POD := [Vector2(1.6, -7.0), Vector2(14.4, -7.0), Vector2(16.0, -5.4), Vector2(16.0, 5.4), Vector2(14.4, 7.0), Vector2(1.6, 7.0),
	Vector2(0.0, 5.4), Vector2(0.0, -5.4)]
const BX := 164.0                # the B pod's forward wall
const SEG := [16.0, 35.0, 52.5, 70.0, 86.0, 94.0, 111.5, 129.0, 146.5, 164.0]
const ROLL := [87.0, 89.0, 91.0, 93.0]

static var w
static var by_tag := {}


static func build(world) -> void:
	K.begin(world, "TB180")
	w = world
	by_tag = K.by_tag
	_pod_a()
	_pod_b()
	_tether()
	_brake()
	_engine()
	_lines()
	_controls()
	_rooms()


static func rooms_only(world) -> void:
	K.begin(world, "TB180")
	w = world
	_rooms()


static func _shift(pts: Array, dx: float) -> Array:
	var out: Array = []
	for q in pts:
		out.append(q + Vector2(dx, 0.0))
	return out


static func _circle(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var out: Array = []
	for i in n:
		out.append(c + Vector2.from_angle(TAU * (i + 0.5) / n) * r)
	return K.mp(out)


# equipment on the deck (y1 on its top), under it (y0 on its bottom), on the floor or ceiling
static func E(tag: String, art: String, x0: float, y0: float, x1: float, y1: float, opts: Dictionary, base, at_y: float):
	var p = K.equip(tag, art, K.rect(x0, y0, x1, y1), opts)
	for x in [x0 + 0.3, x1 - 0.3]:
		var b = base if base != null else K.at(x, at_y + (0.25 if at_y > 0.0 else -0.25), ["hull"])
		K.bolt(p, b, x, at_y)
	return p


# a pod's deck across y 0: two plates either side of its hatch
static func _deck(pre: String, x0: float, h0: float, h1: float, x1: float) -> void:
	var D := {"density": 1.1, "barrier": true, "cut_speed": 210.0}
	var d1 = K.plate(pre + "-1", K.R(x0, -0.15, h0, 0.15), D, "deck")
	var dh = K.plate("DK-" + pre.substr(1), K.R(h0, -0.15, h1, 0.15), {"density": 1.0, "door": true, "open_dir": Vector2(h1 - h0 + 0.2, 0) * Geom.M, "cut_speed": 200.0}, "hatch")
	var d2 = K.plate(pre + "-2", K.R(h1, -0.15, x1, 0.15), D, "deck")
	K.bolt(d1, K.at(x0 - 0.2, 0.6, ["hull"]), x0, 0.0, "weld")
	K.bolt(d2, K.at(x1 + 0.2, 0.6, ["hull"]), x1, 0.0, "weld")
	K.bolt(dh, d1, h0, 0.0, "weld")
	K.bolt(dh, d2, h1, 0.0, "weld")


# ---------------------------------------------------------------- the A pod: control over crew

static func _pod_a() -> void:
	K.ring(POD, T, {0: [0.45, 0.6], 4: [0.4, 0.55]}, {
		"0:1": {"kind": "hatch", "door": true, "tag": "HT-A", "open_dir": Vector2(2.1, 0) * Geom.M, "cut_speed": 200.0},
		"4:1": {"kind": "hatch", "door": true, "tag": "HT-AL", "open_dir": Vector2(-2.1, 0) * Geom.M, "cut_speed": 200.0},
	}, {"density": 1.6, "barrier": true, "cut_speed": 210.0}, "HA")
	_deck("DA", 0.45, 12.0, 13.6, 15.55)
	var d1 = by_tag["DA-1"]
	var d2 = by_tag["DA-2"]
	# the control deck
	E("CON-A", "console", 1.4, -1.75, 4.8, -0.2, {"mass": 0.4, "value": 9000.0, "fragile": 0.5, "room": "AU", "name_key": "p_helm"}, d1, -0.15)
	for i in 2:
		var sx := 5.2 + i * 1.3
		var st = K.seat("SEAT-%d" % (i + 1), Rect2(sx, -1.7, 0.8, 1.5), {"room": "AU", "name_key": "p_seat_pilot"})
		K.bolt(st, d1, sx + 0.2, -0.15)
		K.bolt(st, d1, sx + 0.6, -0.15, "lock")
	E("AV-A", "nav_rack", 9.6, -3.6, 11.6, -0.2, {"mass": 0.3, "value": 9000.0, "fragile": 0.5, "room": "AU", "name_key": "p_avionics"}, d1, -0.15)
	E("LOG-A", "blackbox", 13.8, -2.2, 15.3, -0.2, {"mass": 0.15, "value": 9000.0, "fragile": 0.4, "room": "AU", "mandatory": true, "name_key": "p_voyage_recorder"}, d2, -0.15)
	E("COMMS-A", "screen", 2.0, -6.5, 4.6, -5.2, {"mass": 0.1, "value": 4000.0, "fragile": 0.5, "room": "AU", "name_key": "p_comms"}, null, -6.55)
	E("TEN-MON", "screen", 10.0, -6.5, 13.6, -5.0, {"mass": 0.15, "value": 5000.0, "fragile": 0.5, "room": "AU", "name_key": "p_tether_mon"}, null, -6.55)
	var rt = K.equip("ROOT-A", "module", K.rect(14.6, -4.6, 15.5, -2.6), {"mass": 0.3, "value": 3000.0, "fragile": 0.3, "room": "AU", "name_key": "p_tether_root"})
	K.bolt(rt, K.at(15.8, -4.0, ["hull"]), 15.5, -4.0)
	K.bolt(rt, K.at(15.8, -3.2, ["hull"]), 15.5, -3.2)
	K.lamp("LAMP-AU", 6.0, -6.55, "AU", K.at(6.0, -6.75, ["hull"]))
	# the crew deck
	E("ECS-A", "env", 1.9, 4.0, 4.8, 6.5, {"mass": 0.6, "value": 7000.0, "fragile": 0.4, "room": "AL", "name_key": "p_ecs"}, null, 6.55)
	E("GALLEY-A", "cabinet", 5.1, 4.6, 7.2, 6.5, {"mass": 0.4, "value": 3500.0, "fragile": 0.35, "room": "AL", "name_key": "p_galley"}, null, 6.55)
	E("BAT-A", "battery", 9.6, 4.4, 12.6, 6.5, {"mass": 1.2, "value": 8000.0, "fragile": 0.4, "room": "AL", "hazard": "battery", "name_key": "p_battery"}, null, 6.55)
	E("DIST-A", "swb", 12.9, 3.4, 14.2, 6.5, {"mass": 0.4, "value": 5000.0, "fragile": 0.4, "room": "AL", "name_key": "p_swb"}, null, 6.55)
	E("WATER-A", "water", 1.0, 0.2, 3.0, 2.0, {"mass": 0.3, "value": 1200.0, "fragile": 0.3, "room": "AL", "name_key": "p_water_tank"}, d1, 0.15)
	E("LOCKER-A", "locker", 3.4, 0.2, 5.2, 2.6, {"mass": 0.25, "value": 2000.0, "fragile": 0.3, "room": "AL", "name_key": "p_suit_locker"}, d1, 0.15)
	E("BUNK-A", "bunk", 5.6, 0.2, 9.8, 1.6, {"mass": 0.3, "value": 1500.0, "fragile": 0.3, "room": "AL", "name_key": "p_bunk"}, d1, 0.15)
	E("O2-A", "gastank", 10.0, 0.2, 11.6, 2.6, {"mass": 0.2, "value": 1500.0, "fragile": 0.3, "room": "AL", "hazard": "gas_tank", "name_key": "p_o2_bottle"}, d1, 0.15)
	K.lamp("LAMP-AL", 14.6, 0.15, "AL", d2)
	var dk = K.equip("DOCK", "dock", K.rect(-1.2, -1.4, 0.0, 1.4), {"mass": 0.5, "value": 4000.0, "fragile": 0.3, "name_key": "p_dock_ring"})
	K.bolt(dk, K.at(0.2, -1.0, ["hull"]), 0.0, -1.0)
	K.bolt(dk, K.at(0.2, 1.0, ["hull"]), 0.0, 1.0)
	K.clamp(1, 11.0, 7.0, 6.8)


# ---------------------------------------------------------------- the B pod: propellant over power

static func _pod_b() -> void:
	K.ring(_shift(POD, BX), T, {0: [0.45, 0.6], 4: [0.1, 0.25]}, {
		"0:1": {"kind": "hatch", "door": true, "tag": "HT-B", "open_dir": Vector2(2.1, 0) * Geom.M, "cut_speed": 200.0},
		"4:1": {"kind": "hatch", "door": true, "tag": "HT-BL", "open_dir": Vector2(-2.1, 0) * Geom.M, "cut_speed": 200.0},
	}, {"density": 1.6, "barrier": true, "cut_speed": 210.0}, "HB")
	_deck("DB", BX + 0.45, 167.0, 168.6, BX + 15.55)
	var d1 = by_tag["DB-1"]
	var d2 = by_tag["DB-2"]
	# the propellant deck: two tanks, their pressurant, the RCS controller, the tether's root
	for e in [["TANK-1", 169.0, 173.8], ["TANK-2", 174.2, 179.0]]:
		E(e[0], "fueltank", e[1], -5.4, e[2], -0.2, {"mass": 1.2, "value": 6000.0, "fragile": 0.3, "room": "BU", "hazard": "fuel_tank", "name_key": "p_prop_tank"}, d2, -0.15)
	E("HE-B", "gastank", 165.8, -6.5, 168.4, -5.6, {"mass": 0.2, "value": 1500.0, "fragile": 0.3, "room": "BU", "hazard": "gas_tank", "name_key": "p_pressurant"}, null, -6.55)
	E("RCSC-B", "panel", 165.6, -2.4, 166.8, -0.2, {"mass": 0.15, "value": 6000.0, "fragile": 0.45, "room": "BU", "name_key": "p_rcs_ctrl"}, d1, -0.15)
	var rt = K.equip("ROOT-B", "module", K.rect(BX + 0.45, -4.6, BX + 1.4, -2.6), {"mass": 0.3, "value": 3000.0, "fragile": 0.3, "room": "BU", "name_key": "p_tether_root"})
	K.bolt(rt, K.at(BX + 0.2, -4.0, ["hull"]), BX + 0.45, -4.0)
	K.bolt(rt, K.at(BX + 0.2, -3.2, ["hull"]), BX + 0.45, -3.2)
	K.lamp("LAMP-BU", 170.6, -6.55, "BU", K.at(170.6, -6.75, ["hull"]))
	# the power deck: generator, battery, radiator; under the deck the board, the inverter, the feed pump
	E("GEN-B", "gen", 165.8, 3.4, 169.4, 6.5, {"mass": 1.6, "value": 12000.0, "fragile": 0.35, "room": "BL", "name_key": "p_generator"}, null, 6.55)
	E("BAT-B", "battery", 169.8, 4.2, 172.6, 6.5, {"mass": 1.0, "value": 7000.0, "fragile": 0.4, "room": "BL", "hazard": "battery", "name_key": "p_battery"}, null, 6.55)
	E("RAD-B", "radiator", 172.9, 3.6, 175.0, 6.5, {"mass": 0.8, "value": 6000.0, "fragile": 0.35, "room": "BL", "name_key": "p_radiator"}, null, 6.55)
	E("PWR-B", "swb", 175.6, 0.2, 178.0, 2.6, {"mass": 0.3, "value": 5000.0, "fragile": 0.4, "room": "BL", "name_key": "p_power_board"}, d2, 0.15)
	E("INV-B", "cap", 172.4, 0.2, 174.8, 1.8, {"mass": 0.3, "value": 4000.0, "fragile": 0.4, "room": "BL", "name_key": "p_inverter"}, d2, 0.15)
	E("PUMP-B", "pump", 169.0, 0.2, 171.4, 1.8, {"mass": 0.4, "value": 4000.0, "fragile": 0.35, "room": "BL", "name_key": "p_transfer_pump"}, d2, 0.15)
	K.lamp("LAMP-BL", 178.6, 0.15, "BL", d2)
	K.clamp(3, 166.0, 7.0, 6.8)


# ---------------------------------------------------------------- the tether and what hangs on it

static func _tether() -> void:
	for i in SEG.size() - 1:
		var x0: float = SEG[i]
		var x1: float = SEG[i + 1]
		var tag := "TH-B" if x0 == 86.0 else "TH-%d" % (i + 1 if x0 < 86.0 else i)
		var th = K.equip(tag, "", K.rect(x0, -0.15, x1, 0.15), {"mass": 0.12, "value": 1100.0, "fragile": 0.2, "cut_speed": 120.0, "name_key": "p_tether"})
		if i > 0:
			K.bolt(th, w.piece_at(K.p(x0 - 0.5, 0.0), ["equip"]), x0, 0.0, "lock")
	# cast into both pods
	K.bolt(by_tag["TH-1"], K.at(15.8, 0.0, ["hull"]), 16.0, 0.0, "weld")
	K.bolt(by_tag["TH-8"], K.at(BX + 0.2, 0.0, ["hull"]), BX, 0.0, "weld")
	# the dressing: beacons, dampers, a tension sensor node, the inspection crawler stopped at the wear
	for e in [["BEACON-1", 30.0, "TH-1", true], ["BEACON-2", 64.0, "TH-3", true], ["BEACON-3", 100.0, "TH-5", true], ["BEACON-4", 140.0, "TH-7", true]]:
		_on_tether(e[0], "insp", e[1], e[1] + 0.8, -0.75, -0.15, e[2], {"mass": 0.03, "value": 800.0, "fragile": 0.5, "name_key": "p_beacon"})
	for e in [["DAMPER-1", 44.0, "TH-2"], ["DAMPER-2", 120.0, "TH-6"]]:
		_on_tether(e[0], "module", e[1], e[1] + 1.6, 0.15, 0.85, e[2], {"mass": 0.08, "value": 2500.0, "fragile": 0.3, "name_key": "p_tether_damper"})
	_on_tether("SENS-T", "insp", 76.0, 77.2, -0.6, -0.15, "TH-4", {"mass": 0.04, "value": 3000.0, "fragile": 0.5, "name_key": "p_strain_gauge"})
	_on_tether("CRAWLER", "arm", 56.0, 58.4, -1.0, -0.15, "TH-3", {"mass": 0.15, "value": 7000.0, "fragile": 0.4, "name_key": "p_crawler"})


static func _on_tether(tag: String, art: String, x0: float, x1: float, y0: float, y1: float, seg: String, opts: Dictionary) -> void:
	var p = K.equip(tag, art, K.rect(x0, y0, x1, y1), opts)
	var yb := y1 if y1 <= -0.15 else y0
	K.bolt(p, by_tag[seg], x0 + 0.2, yb)
	K.bolt(p, by_tag[seg], x1 - 0.2, yb)


# ---------------------------------------------------------------- the berth's brake

static func _brake() -> void:
	var fu = K.equip("BF-U", "module", K.rect(86.0, -4.6, 94.0, -1.6), {"mass": 2.0, "value": 4000.0, "fragile": 0.2, "name_key": "p_brake_frame"})
	var fl = K.equip("BF-L", "module", K.rect(86.0, 1.6, 94.0, 4.6), {"mass": 2.0, "value": 4000.0, "fragile": 0.2, "name_key": "p_brake_frame"})
	# the cheeks either side of the tether
	var C := {"density": 1.4, "barrier": false, "cut_speed": 160.0, "name_key": "p_brake_frame"}
	for e in [["BS-FU", 85.6, -4.6, -0.3], ["BS-FL", 85.6, 0.3, 4.6], ["BS-AU", 94.0, -4.6, -0.3], ["BS-AL", 94.0, 0.3, 4.6]]:
		var x0: float = e[1]
		var ch = K.plate(e[0], K.R(x0, e[2], x0 + 0.4, e[3]), C, "strut")
		var fr = fu if e[2] < 0.0 else fl
		var xf: float = 86.0 if x0 < 90.0 else 94.0
		K.bolt(ch, fr, xf, (e[2] + e[3]) * 0.5, "weld")
	# four pairs of rollers gripping the tether
	var k := 0
	for cx in ROLL:
		k += 1
		for e in [["U", -0.87, fu, -1.6, -0.15], ["L", 0.87, fl, 1.6, 0.15]]:
			var c := Vector2(cx, e[1])
			var rl = K.equip("ROL-%s%d" % [e[0], k], "drum", K.rect(cx - 0.72, e[1] - 0.72, cx + 0.72, e[1] + 0.72), {"mass": 0.25, "value": 1500.0, "fragile": 0.3, "name_key": "p_brake_roller"}, _circle(c, 0.72, 16))
			K.bolt(rl, e[2], cx, e[3])
			K.bolt(rl, by_tag["TH-B"], cx, e[4], "lock")
	var bc = K.equip("BCOOL", "radiator", K.rect(87.0, -5.8, 93.0, -4.6), {"mass": 0.5, "value": 4000.0, "fragile": 0.35, "name_key": "p_brake_cooler"})
	K.bolt(bc, fu, 87.4, -4.6)
	K.bolt(bc, fu, 92.6, -4.6)
	var ct = K.equip("BRK-CTL", "swb", K.rect(87.0, 4.6, 93.0, 5.6), {"mass": 0.3, "value": 5000.0, "fragile": 0.4, "name_key": "p_brake_ctrl"})
	K.bolt(ct, fl, 87.4, 4.6)
	K.bolt(ct, fl, 92.6, 4.6)
	K.clamp(2, 86.5, 4.6, 4.4, ["equip"])


# ---------------------------------------------------------------- the B pod's engine and RCS

static func _engine() -> void:
	var en = K.equip("ENG-B", "eng_core", K.rect(180.0, -1.8, 182.4, 1.8), {"mass": 1.4, "value": 16000.0, "fragile": 0.3, "name_key": "p_engine"})
	K.bolt(en, K.at(179.8, -1.2, ["hull"]), 180.0, -1.2)
	K.bolt(en, K.at(179.8, 1.2, ["hull"]), 180.0, 1.2)
	var nz = K.equip("NOZ-B", "nozzle", K.rect(182.4, -2.6, 185.0, 2.6), {"cls": "metal", "dest": "metal", "mass": 0.3, "cut_speed": 160.0, "name_key": "p_nozzle"},
		K.mp([Vector2(182.4, -1.4), Vector2(185.0, -2.6), Vector2(185.0, 2.6), Vector2(182.4, 1.4)]))
	K.bolt(nz, en, 182.4, -0.8)
	K.bolt(nz, en, 182.4, 0.8)
	for e in [["RCS-1", -8.0, -7.0, -6.8, -7.0], ["RCS-2", 7.0, 8.0, 6.8, 7.0]]:
		var rc = K.equip(e[0], "rcs_quad", K.rect(168.8, e[1], 170.4, e[2]), {"mass": 0.2, "value": 4000.0, "fragile": 0.35, "name_key": "p_rcs_q"})
		K.bolt(rc, K.at(169.2, e[3], ["hull"]), 169.2, e[4])
		K.bolt(rc, K.at(170.0, e[3], ["hull"]), 170.0, e[4])


# ---------------------------------------------------------------- lines

static func _lines() -> void:
	# the A pod's bus, up through the deck to the control deck
	K.line("b1", "cable", "power", "BAT-A", Vector2(12.6, 5.0), "DIST-A", Vector2(12.9, 5.0))
	K.line("p1", "cable", "power", "DIST-A", Vector2(14.0, 3.4), "LAMP-AL", Vector2(14.6, 0.31), [Vector2(14.0, 0.8), Vector2(14.6, 0.8)])
	K.line("p2", "cable", "power", "DIST-A", Vector2(13.2, 3.4), "ECS-A", Vector2(3.0, 4.0), [Vector2(13.2, 3.0), Vector2(3.0, 3.0)])
	K.line("p3", "cable", "power", "ECS-A", Vector2(4.8, 5.6), "GALLEY-A", Vector2(5.1, 5.6))
	K.line("p4", "cable", "power", "DIST-A", Vector2(13.6, 3.4), "AV-A", Vector2(11.6, -1.0), [Vector2(13.6, 2.8), Vector2(11.9, 2.8), Vector2(11.9, -1.0)])
	K.line("p5", "cable", "power", "AV-A", Vector2(9.6, -1.2), "CON-A", Vector2(4.8, -1.2))
	K.line("p6", "cable", "power", "AV-A", Vector2(10.6, -3.6), "TEN-MON", Vector2(10.6, -5.0))
	K.line("p7", "cable", "power", "AV-A", Vector2(11.4, -3.6), "LOG-A", Vector2(13.8, -1.6), [Vector2(11.4, -4.2), Vector2(13.4, -4.2), Vector2(13.4, -1.6)])
	K.line("p8", "cable", "power", "CON-A", Vector2(3.0, -1.75), "COMMS-A", Vector2(3.0, -5.2))
	K.line("p9", "cable", "power", "COMMS-A", Vector2(4.6, -5.8), "LAMP-AU", Vector2(6.0, -6.39), [Vector2(6.0, -5.8)])
	# the B pod on its own battery: the board, the controller, the pump, the lamps, the RCS
	K.line("b2", "cable", "power", "BAT-B", Vector2(171.0, 4.2), "PWR-B", Vector2(176.4, 2.6), [Vector2(171.0, 3.0), Vector2(176.4, 3.0)])
	K.line("q1", "cable", "power", "PWR-B", Vector2(175.6, 1.0), "INV-B", Vector2(174.8, 1.0))
	K.line("q2", "cable", "power", "INV-B", Vector2(172.4, 1.0), "PUMP-B", Vector2(171.4, 1.0))
	K.line("q3", "cable", "power", "PWR-B", Vector2(178.0, 1.0), "LAMP-BL", Vector2(178.6, 0.31), [Vector2(178.6, 1.0)])
	K.line("q4", "cable", "power", "GEN-B", Vector2(169.4, 4.6), "BAT-B", Vector2(169.8, 4.6))
	K.line("q5", "cable", "power", "PUMP-B", Vector2(169.6, 0.2), "RCSC-B", Vector2(166.2, -0.2), [Vector2(169.6, 0.0), Vector2(166.2, 0.0)])
	K.line("q6", "cable", "power", "RCSC-B", Vector2(166.6, -2.4), "LAMP-BU", Vector2(170.6, -6.39), [Vector2(166.6, -5.5), Vector2(170.6, -5.5)])
	K.line("q7", "cable", "power", "RCSC-B", Vector2(165.6, -1.6), "RCS-1", Vector2(169.6, -7.0), [Vector2(165.2, -1.6), Vector2(165.2, -5.45), Vector2(169.6, -5.45)])
	K.line("q8", "cable", "power", "RCSC-B", Vector2(165.8, -0.2), "RCS-2", Vector2(169.6, 7.0), [Vector2(165.8, 0.0), Vector2(164.8, 0.0), Vector2(164.8, 6.9), Vector2(169.6, 6.9)])
	# the feed: both tanks down to the pump, the pump aft to the engine
	K.line("f1", "pipe", "feed", "TANK-1", Vector2(171.4, -0.2), "PUMP-B", Vector2(170.4, 0.2), [Vector2(171.4, 0.0), Vector2(170.4, 0.0)])
	K.line("f2", "pipe", "feed", "TANK-2", Vector2(176.6, -0.2), "PUMP-B", Vector2(171.0, 0.2), [Vector2(176.6, -0.05), Vector2(171.0, -0.05)])
	K.line("f3", "pipe", "feed", "PUMP-B", Vector2(171.4, 1.4), "ENG-B", Vector2(180.0, 0.0), [Vector2(171.8, 1.4), Vector2(171.8, 2.8), Vector2(179.0, 2.8), Vector2(179.0, 0.0)])


# ---------------------------------------------------------------- controls

static func _controls() -> void:
	K.ctrl("G-AU", "port", K.at(4.0, -6.75, ["hull"]), Vector2(4.0, -7.25), {"medium": "gas", "target": "AU"})
	K.ctrl("G-AL", "port", K.at(13.0, 6.75, ["hull"]), Vector2(13.0, 7.25), {"medium": "gas", "target": "AL"})
	K.ctrl("G-BU", "port", K.at(176.0, -6.75, ["hull"]), Vector2(176.0, -7.25), {"medium": "gas", "target": "BU"})
	K.ctrl("G-BL", "port", K.at(171.0, 6.75, ["hull"]), Vector2(171.0, 7.25), {"medium": "gas", "target": "BL"})
	for h in [["HT-A", ""], ["HT-AL", ""], ["HT-B", ""], ["HT-BL", ""], ["DK-A", "AU"], ["DK-B", "BU"]]:
		K.door(h[0], h[1])
	# the outside panel under the A pod
	var px = K.equip("PNL-X", "panel", K.rect(2.0, 7.0, 4.6, 7.5), {"cls": "metal", "dest": "metal", "mass": 0.05, "cut_speed": 240.0, "name_key": "p_panel"})
	K.bolt(px, K.at(2.4, 6.8, ["hull"]), 2.4, 7.0)
	K.bolt(px, K.at(4.2, 6.8, ["hull"]), 4.2, 7.0)
	K.ctrl("K-M", "switch", px, Vector2(2.4, 7.25), {"target": "K-M", "state": true})
	K.ctrl("E-1", "test", px, Vector2(3.3, 7.25), {"medium": "volt", "target": "bus"})
	K.ctrl("AUX-P", "socket", px, Vector2(4.2, 7.25), {"target": "aux", "state": false})
	# the brake's box: brake, cooling, tensioner; its gauges
	var bc = by_tag["BRK-CTL"]
	K.ctrl("BRK-C", "switch", bc, Vector2(87.8, 5.4), {"target": "BRK-C", "state": false})
	K.ctrl("BRK", "switch", bc, Vector2(88.8, 5.4), {"target": "BRK", "state": false})
	K.ctrl("TEN", "switch", bc, Vector2(89.8, 5.4), {"target": "TEN", "state": true})
	K.ctrl("RPM-T", "probe", bc, Vector2(90.8, 5.4), {"medium": "spin", "target": "pair"})
	K.ctrl("T-TH", "probe", bc, Vector2(91.6, 5.4), {"medium": "tether", "target": "TH-B"})
	K.ctrl("HEAT-B", "probe", bc, Vector2(92.4, 5.4), {"medium": "heat", "target": "brake"})
	K.ctrl("W-TH", "probe", by_tag["TH-3"], Vector2(61.0, 0.0), {"medium": "strand", "target": "TH-3"})
	# the B pod: its battery's switch, the RCS, the tanks' and the pressurant's ports, the radiator's
	K.ctrl("K-B", "switch", by_tag["BAT-B"], Vector2(170.4, 5.0), {"target": "K-B", "state": true, "hidden_room": "BL"})
	K.ctrl("RCS-B", "switch", by_tag["RCSC-B"], Vector2(166.2, -1.4), {"target": "RCS-B", "state": false, "hidden_room": "BU"})
	K.ctrl("PB-1", "port", by_tag["TANK-1"], Vector2(169.6, -0.8), {"medium": "fuel", "target": "pb1", "hidden_room": "BU"})
	K.ctrl("PB-2", "port", by_tag["TANK-2"], Vector2(174.8, -0.8), {"medium": "fuel", "target": "pb2", "hidden_room": "BU"})
	K.ctrl("PHE", "port", by_tag["HE-B"], Vector2(167.1, -5.9), {"medium": "gas", "target": "HEB", "hidden_room": "BU"})
	K.ctrl("PRB", "port", by_tag["RAD-B"], Vector2(173.9, 4.0), {"medium": "coolant", "target": "rcool", "hidden_room": "BL"})
	K.ctrl("PO2", "port", by_tag["O2-A"], Vector2(10.8, 2.2), {"medium": "gas", "target": "O2A", "hidden_room": "AL"})


# ---------------------------------------------------------------- rooms

static func _rooms() -> void:
	for e in [["A", 0.0], ["B", BX]]:
		var inn: Array = K.inner(_shift(POD, e[1]), T)
		var x0: float = e[1] + 0.45
		var x1: float = e[1] + 15.55
		w.add_room(e[0] + "U", K.mp([Vector2(x0, -0.15), inn[7], inn[0], inn[1], inn[2], Vector2(x1, -0.15)]))
		w.add_room(e[0] + "L", K.mp([Vector2(x0, 0.15), Vector2(x1, 0.15), inn[3], inn[4], inn[5], inn[6]]))


static func meta() -> Dictionary:
	var segs: Array = ["TH-1", "TH-2", "TH-3", "TH-4", "TH-B", "TH-5", "TH-6", "TH-7", "TH-8"]
	return {
		"id": "tb180",
		"name": "TB-180 BINARY",
		"title": ["TB-180「连星」系绳双体运输船 · 180 m", "TB-180 BINARY · TETHERED TWIN-POD TRANSPORT · 180 m"],
		"contract": "TB-180",
		"length": 185.0,
		"value": {"total": 260000.0, "metal": 26000.0},
		"clamps": [[11.0, 7.0], [86.5, 4.6], [166.0, 7.0]],
		"room_names": {"AU": "room_tbAU", "AL": "room_tbAL", "BU": "room_tbBU", "BL": "room_tbBL"},
		"gas": {"rooms": {"AU": 101.0, "AL": 101.0, "BU": 101.0, "BL": 101.0},
			"vessels": {"O2A": {"V": 0.06, "kpa": 12000.0, "piece": "O2-A", "burst": 200.0}, "HEB": {"V": 0.08, "kpa": 20000.0, "piece": "HE-B", "burst": 200.0}},
			"valves": [], "value": 2400.0},
		"tether": {
			"rpm": 2.0, "safe": 0.1, "kn": 40.0, "residual": 8.0, "release": "TEN",
			"brake": {"switch": "BRK", "cool": "BRK-C", "rate": 0.025, "slip": 6.0, "rollers": ["ROL-U1", "ROL-U2", "ROL-U3", "ROL-U4", "ROL-L1", "ROL-L2", "ROL-L3", "ROL-L4"]},
			"rcs": {"switch": "RCS-B", "rate": 0.012, "fuel": ["pb1", "pb2"], "use": 0.004, "live": "RCSC-B"},
			"segments": segs, "worn": "TH-3", "strands": [5, 7],
			"dressing": {"TH-1": ["BEACON-1"], "TH-2": ["DAMPER-1"], "TH-3": ["BEACON-2", "CRAWLER"], "TH-4": ["SENS-T"], "TH-5": ["BEACON-3"], "TH-6": ["DAMPER-2"], "TH-7": ["BEACON-4"]},
			"pods": ["CON-A", "AV-A", "LOG-A", "COMMS-A", "TEN-MON", "ECS-A", "GALLEY-A", "BAT-A", "DIST-A", "WATER-A", "O2-A",
				"TANK-1", "TANK-2", "HE-B", "RCSC-B", "GEN-B", "BAT-B", "RAD-B", "PWR-B", "INV-B", "PUMP-B", "ENG-B"],
		},
		"power": {
			"bus": "DIST-A",
			"sources": [
				{"piece": "BAT-A", "kind": "battery", "volts": 220.0, "local_volts": 48.0, "cable": "b1", "switch": "K-M", "charge": 0.9, "drain": 0.0003},
			],
			# the tether carries no power: the B pod runs on its own battery
			"isolated": [{"piece": "BAT-B", "volts": 220.0, "charge": 0.9, "switch": "K-B"}],
			"lamps": {"AU": "LAMP-AU", "AL": "LAMP-AL"},
		},
		"fluids": {"volumes": {
			"pb1": {"fluid": "fuel", "amount": 0.8, "piece": "TANK-1", "port": "PB-1", "full": 1.0, "content": 1.0, "leak": 0.12, "pump": [0.12, 0.008]},
			"pb2": {"fluid": "fuel", "amount": 0.8, "piece": "TANK-2", "port": "PB-2", "full": 1.0, "content": 1.0, "leak": 0.12, "pump": [0.12, 0.008]},
			"feed_line": {"fluid": "fuel", "amount": 0.02, "nets": ["feed"], "leak": 0.06, "leak_min": 0.004},
			"rcool": {"fluid": "coolant", "amount": 0.25, "piece": "RAD-B", "port": "PRB", "full": 0.3, "content": 1.0, "leak": 0.2, "pump": [0.2, 0.006]},
		}, "joins": [], "value": {"fuel": 2400.0, "coolant": 500.0}},
		"ctrls_cfg": {"G-AU": {"rate": 18.0}, "G-AL": {"rate": 18.0}, "G-BU": {"rate": 18.0}, "G-BL": {"rate": 18.0}, "PHE": {"rate": 0.4}, "PO2": {"rate": 0.4}},
		"labels": {"BAT-A": "BAT", "DIST-A": "BUS", "BAT-B": "BAT B", "TANK-1": "PROP 1", "TANK-2": "PROP 2", "BRK-CTL": "BRAKE", "LOG-A": "LOG", "TH-3": "WORN"},
		"hints": {},
		"market": {
			"class": "TB", "name": ["连星级系绳双体运输船", "BINARY-CLASS TETHERED TRANSPORT"], "time": 45.0,
			"rooms": {"AU": [0.2, 40.0, 101.0], "AL": [0.2, 40.0, 101.0], "BU": [0.2, 40.0, 101.0], "BL": [0.2, 40.0, 101.0]},
			"charge": {"BAT-A": [0.3, 1.0]},
			"fluids": {"pb1": [0.3, 0.8], "pb2": [0.3, 0.8]}, "fill": {"feed_line": "pb1"},
			"knockable": ["CON-A", "AV-A"],
			"drift": [],
			"section_x": 86.0,
			# no hidden damage: a crack in a pod's short wall plates opens it to space
			"slots": {"fire_system": {"x": 177.3, "y0": 5.0, "y1": 6.55, "base": ["HB4-0", 6.55], "room": "BL", "port": [177.7, 5.07]}},
			"mechanisms": true,
		},
		"procedures": {
			"LOG-A": [
				{"do": "hose", "ctrl": "G-AU"},
				{"do": "wait", "until": {"P": ["AU", "<", 5.0]}, "max": 150.0},
				{"do": "operate", "ctrl": "HT-A"},
				{"do": "wait", "until": {"open": ["AU"]}, "max": 20.0},
				{"do": "operate", "ctrl": "K-M"},
				{"do": "measure", "ctrl": "E-1", "expect": ["<", 1.0]},
				{"do": "free", "piece": "LOG-A"},
				{"do": "deliver", "piece": "LOG-A", "zone": "equip"},
			],
		},
	}
