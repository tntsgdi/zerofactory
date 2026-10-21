class_name Vt80Author
# Authoring script for VT-80 "Long Whale", a 96 m propellant carrier
# (design/ships/VT-80_长鲸_设计稿.md v2 and VT-80_结构图.png, as drawn). Not part of
# the game: tools/ship_export.gd runs it and writes ships/vt80.json.
# Metres, x bow (0) to the nozzle (96), y down.
#
# A slim ship in modules on a long box spine: the forward module (the cockpit,
# the crew quarters over the valve section), the spine with its pressurised crawl
# tube, the six nitrogen spheres on it, three giant propellant tanks slung under
# it, the cross-connect manifold under them, the aft module (the auxiliary power
# room over the pump room), the main engine on the stern.
# What it asks of you: the tanks are cross-connected (scripts/tanknet.gd). Open a
# tank's cross valve and it shares the manifold with every other tank whose valve
# is open, their levels evening out; the main pump on the bus draws the manifold
# at the recovery port, so the propellant goes before the power does, and a pump
# left drawing a dry manifold runs dry. Each tank is kept pressurised from the
# nitrogen bank: drawn with its pressurisation shut and its ullage vented, it
# pulls a vacuum and buckles; drawn pressurised, then its pressurisation shut and
# its ullage vented, it is safe to cut (cut under pressure, it bursts). A branch
# keeps its residue once its valve is shut, until its low-point drain is opened.
# A contract may carry a cross valve that leaks while it reads shut.

const K = preload("res://tools/authoring/kit.gd")
const T := 0.45
const OUT_F := [Vector2(0.0, 1.0), Vector2(2.0, -2.0), Vector2(9.4, -2.4), Vector2(9.4, -7.1), Vector2(20.0, -7.1),
	Vector2(20.0, 6.7), Vector2(9.4, 6.7), Vector2(9.4, 4.6), Vector2(3.6, 4.6), Vector2(0.8, 2.8)]
const OUT_A := [Vector2(71.7, -6.6), Vector2(86.0, -6.6), Vector2(86.0, 7.4), Vector2(71.7, 7.4)]
const SPINE := [20.0, 33.0, 46.0, 59.0, 71.7]
const TX0 := [20.7, 37.7, 54.8]
const TX1 := [36.7, 53.9, 70.9]
const TY0 := 2.1
const TY1 := 9.5
const MY := 10.1                 # the manifold (to 10.5)
const SPHERES := [23.7, 28.7, 40.8, 45.8, 57.9, 62.9]
const FILL := [1.4, 0.2, 2.4]    # each tank's propellant (of 4.0)
const CAP := 4.0
# a bipropellant cargo: monomethylhydrazine fore and aft, nitrogen tetroxide in the
# middle. The two light on contact, so the oxidiser tank is kept off the fuel manifold:
# its sump drains at its own low-point port (XV-2 / LD-2 on SUMP-2)
const CHEM := ["mmh", "nto", "mmh"]
const OX := 1                    # the oxidiser tank's index

static var w
static var by_tag := {}


static func build(world) -> void:
	K.begin(world, "VT80")
	w = world
	by_tag = K.by_tag
	_hulls()
	_forward()
	_spine()
	_tanks()
	_nitrogen()
	_aft()
	_engine()
	_lines()
	_controls()
	_rooms()


static func rooms_only(world) -> void:
	K.begin(world, "VT80")
	w = world
	_rooms()


static func _iy(out: Array, i: int, x: float) -> float:
	var inn := K.inner(out, T)
	var a: Vector2 = inn[i]
	var b: Vector2 = inn[(i + 1) % inn.size()]
	return a.y + (x - a.x) / (b.x - a.x) * (b.y - a.y)


static func _capsule(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	var r := (y1 - y0) * 0.22
	return K.mp([Vector2(x0 + r, y0), Vector2(x1 - r, y0), Vector2(x1, y0 + r * 1.4), Vector2(x1, y1 - r * 1.4),
		Vector2(x1 - r, y1), Vector2(x0 + r, y1), Vector2(x0, y1 - r * 1.4), Vector2(x0, y0 + r * 1.4)])


# the spine segment over x
static func _seg(top: bool, x: float) -> String:
	for i in SPINE.size() - 1:
		if x >= SPINE[i] and x <= SPINE[i + 1]:
			return ("SP-T-%d" if top else "SP-B-%d") % (i + 1)
	return ""


# ---------------------------------------------------------------- the two modules' shells

static func _hulls() -> void:
	var base := {"density": 1.6, "barrier": true, "cut_speed": 210.0}
	K.ring(OUT_F, T, {
		3: [0.75, 0.9],
		4: [0.42, 0.58],
		5: [0.62, 0.78],
	}, {
		"0:0": {"tag": "WS", "art": "window"},
		"3:1": {"kind": "hatch", "door": true, "tag": "HT-Q", "open_dir": Vector2(2.2, 0) * Geom.M, "cut_speed": 200.0},
		"4:1": {"kind": "door", "door": true, "tag": "D-QK", "open_dir": Vector2(0, -2.3) * Geom.M, "cut_speed": 190.0},
		"5:1": {"kind": "hatch", "door": true, "tag": "HT-V", "open_dir": Vector2(-2.2, 0) * Geom.M, "cut_speed": 200.0},
	}, base, "HF")
	K.ring(OUT_A, T, {
		0: [0.4, 0.6],
		1: [0.3, 0.7],
		2: [0.5, 0.62, 0.74],
		3: [0.464, 0.621],
	}, {
		"0:1": {"kind": "hatch", "door": true, "tag": "HT-A", "open_dir": Vector2(-2.9, 0) * Geom.M, "cut_speed": 200.0},
		"2:2": {"kind": "hatch", "door": true, "tag": "HT-P", "open_dir": Vector2(-1.8, 0) * Geom.M, "cut_speed": 200.0},
		"3:1": {"kind": "door", "door": true, "tag": "D-KP", "open_dir": Vector2(0, -2.3) * Geom.M, "cut_speed": 190.0},
	}, base, "HA")
	K.clamp(1, 15.0, 6.7, 6.5)
	K.clamp(2, 79.0, 7.4, 7.2)


# ---------------------------------------------------------------- forward: the cockpit, the crew, the valves

static func _forward() -> void:
	var S := {"density": 1.2, "barrier": true, "cut_speed": 220.0}
	var fu = K.plate("FB1-U", K.R(9.4, -1.95, 9.85, -0.4), S, "bulkhead")
	var dq = K.plate("D-CQ", K.R(9.4, -0.4, 9.85, 1.1), {"density": 1.0, "door": true, "barrier": true, "open_dir": Vector2(0, -1.4) * Geom.M, "cut_speed": 190.0}, "door")
	var fl = K.plate("FB1-L", K.R(9.4, 1.1, 9.85, 4.15), S, "bulkhead")
	K.bolt(fu, K.at(9.62, -2.1, ["hull"]), 9.62, -1.95, "weld")
	K.bolt(fu, dq, 9.62, -0.4, "weld")
	K.bolt(dq, fl, 9.62, 1.1, "weld")
	K.bolt(fl, K.at(9.62, 4.3, ["hull"]), 9.62, 4.15, "weld")
	var qd = K.plate("QD", K.R(9.85, 1.1, 19.55, 1.5), {"density": 1.2, "barrier": true, "cut_speed": 200.0, "name_key": "p_deck"}, "deck")
	K.bolt(qd, fl, 9.85, 1.3, "weld")
	K.bolt(qd, K.at(19.8, 1.3, ["hull"]), 19.55, 1.3, "weld")
	# the cockpit
	var st = K.seat("SEAT-1", Rect2(7.9, 2.65, 0.8, 1.5), {"room": "C", "name_key": "p_seat_pilot"})
	K.bolt(st, K.at(8.1, 4.35, ["hull"]), 8.1, 4.15)
	K.bolt(st, K.at(8.5, 4.35, ["hull"]), 8.5, 4.15, "lock")
	var fm = K.equip("FMON", "console", K.rect(4.6, 2.6, 7.4, 4.15), {"mass": 0.3, "value": 8000.0, "fragile": 0.5, "room": "C", "mandatory": true, "name_key": "p_fluid_monitor"})
	K.bolt(fm, K.at(5.0, 4.35, ["hull"]), 5.0, 4.15)
	K.bolt(fm, K.at(7.0, 4.35, ["hull"]), 7.0, 4.15)
	var vm = K.equip("VMAP", "screen", K.rect(8.0, -1.5, 9.4, -0.5), {"mass": 0.1, "value": 2000.0, "fragile": 0.5, "room": "C", "name_key": "p_valve_map"})
	K.bolt(vm, fu, 9.4, -1.2)
	K.bolt(vm, fu, 9.4, -0.8)
	var nv = K.equip("NAV", "nav", K.rect(3.2, _iy(OUT_F, 1, 4.8), 4.8, 0.0), {"mass": 0.2, "value": 4500.0, "fragile": 0.5, "room": "C", "name_key": "p_nav"})
	K.bolt(nv, K.at(3.6, _iy(OUT_F, 1, 4.8) - 0.2, ["hull"]), 3.6, _iy(OUT_F, 1, 4.8))
	K.bolt(nv, K.at(4.4, _iy(OUT_F, 1, 4.8) - 0.2, ["hull"]), 4.4, _iy(OUT_F, 1, 4.8))
	K.lamp("LAMP-C", 6.5, _iy(OUT_F, 1, 6.5), "C", K.at(6.5, _iy(OUT_F, 1, 6.5) - 0.2, ["hull"]))
	# the crew quarters: three bunks, stores, the galley, life support, the oxygen
	for i in 3:
		var y0 := -6.2 + i * 1.8
		var bk = K.equip("BUNK-%d" % (i + 1), "bunk", K.rect(9.85, y0, 13.85, y0 + 1.4), {"mass": 0.12, "value": 600.0, "fragile": 0.3, "room": "Q", "name_key": "p_bunk"})
		K.bolt(bk, K.at(9.62, y0 + 0.4, ["hull", "bulkhead"]), 9.85, y0 + 0.4)
		K.bolt(bk, K.at(9.62, y0 + 1.0, ["hull", "bulkhead"]), 9.85, y0 + 1.0)
	var lk = K.equip("LOCKER", "locker", K.rect(18.0, -2.8, 19.55, 1.1), {"mass": 0.2, "value": 900.0, "fragile": 0.3, "room": "Q", "name_key": "p_locker"})
	K.bolt(lk, qd, 18.6, 1.1)
	K.bolt(lk, K.at(19.8, -2.0, ["hull"]), 19.55, -2.0)
	var gl = K.equip("GALLEY", "cabinet", K.rect(14.6, -0.6, 17.4, 1.1), {"mass": 0.3, "value": 1500.0, "fragile": 0.35, "room": "Q", "name_key": "p_galley"})
	K.bolt(gl, qd, 15.0, 1.1)
	K.bolt(gl, qd, 17.0, 1.1)
	var ls = K.equip("LSS", "env", K.rect(14.6, -6.65, 17.6, -4.6), {"mass": 0.35, "value": 6000.0, "fragile": 0.4, "room": "Q", "name_key": "p_life_support"})
	K.bolt(ls, K.at(15.0, -6.85, ["hull"]), 15.0, -6.65)
	K.bolt(ls, K.at(17.2, -6.85, ["hull"]), 17.2, -6.65)
	var ob = K.equip("O2B", "gastank", K.rect(18.4, -6.2, 19.4, -3.4), {"mass": 0.15, "value": 900.0, "fragile": 0.3, "room": "Q", "hazard": "gas_tank", "name_key": "p_o2_bottle"})
	K.bolt(ob, K.at(19.8, -5.6, ["hull"]), 19.4, -5.6, "lock")
	K.bolt(ob, K.at(19.8, -4.0, ["hull"]), 19.4, -4.0, "lock")
	K.lamp("LAMP-Q", 12.0, -6.65, "Q", K.at(12.0, -6.85, ["hull"]))
	# the valve section: the main valve group, the flow controller, the emergency shutdown, the purge panel
	var mv = K.equip("MV", "pump", K.rect(11.0, 3.4, 14.6, 6.25), {"mass": 0.8, "value": 9000.0, "fragile": 0.35, "room": "V", "name_key": "p_main_valves"})
	K.bolt(mv, K.at(11.4, 6.45, ["hull"]), 11.4, 6.25)
	K.bolt(mv, K.at(14.2, 6.45, ["hull"]), 14.2, 6.25)
	var fc = K.equip("FC-V", "cabinet", K.rect(15.2, 4.0, 16.6, 6.25), {"mass": 0.3, "value": 6000.0, "fragile": 0.45, "room": "V", "name_key": "p_flow_ctrl"})
	K.bolt(fc, K.at(15.6, 6.45, ["hull"]), 15.6, 6.25)
	K.bolt(fc, K.at(16.2, 6.45, ["hull"]), 16.2, 6.25)
	var es = K.equip("ESD-V", "swb", K.rect(17.2, 3.8, 19.0, 6.25), {"mass": 0.4, "value": 5000.0, "fragile": 0.4, "room": "V", "name_key": "p_esd"})
	K.bolt(es, K.at(17.6, 6.45, ["hull"]), 17.6, 6.25)
	K.bolt(es, K.at(18.6, 6.45, ["hull"]), 18.6, 6.25)
	var pp = K.equip("NPP", "panel", K.rect(12.0, 1.5, 15.0, 2.2), {"mass": 0.08, "value": 1800.0, "fragile": 0.4, "room": "V", "name_key": "p_purge_panel"})
	K.bolt(pp, qd, 12.4, 1.5)
	K.bolt(pp, qd, 14.6, 1.5)


# ---------------------------------------------------------------- the spine and its crawl tube

static func _spine() -> void:
	var S := {"density": 2.0, "barrier": true, "cut_speed": 130.0, "name_key": "p_spine"}
	for i in SPINE.size() - 1:
		var x0: float = SPINE[i]
		var x1: float = SPINE[i + 1]
		var t = K.plate("SP-T-%d" % (i + 1), K.R(x0, -1.8, x1, -1.4), S, "beam")
		var b = K.plate("SP-B-%d" % (i + 1), K.R(x0, 1.1, x1, 1.5), S, "beam")
		if i > 0:
			K.bolt(t, by_tag["SP-T-%d" % i], x0, -1.6, "weld")
			K.bolt(b, by_tag["SP-B-%d" % i], x0, 1.3, "weld")
	K.bolt(by_tag["SP-T-1"], K.at(19.8, -1.6, ["hull"]), 20.0, -1.6, "weld")
	K.bolt(by_tag["SP-B-1"], K.at(19.8, 1.3, ["hull"]), 20.0, 1.3, "weld")
	K.bolt(by_tag["SP-T-4"], K.at(71.9, -1.6, ["hull"]), 71.7, -1.6, "weld")
	K.bolt(by_tag["SP-B-4"], K.at(71.9, 1.3, ["hull"]), 71.7, 1.3, "weld")
	K.lamp("LAMP-K", 45.0, -1.4, "K", by_tag["SP-T-2"])


# ---------------------------------------------------------------- the three tanks slung under it

static func _tanks() -> void:
	for i in 3:
		var n := str(i + 1)
		var x0: float = TX0[i]
		var x1: float = TX1[i]
		var tk = K.equip("T-" + n, "fueltank", K.mbox(_capsule(x0, TY0, x1, TY1)), {"mass": 6.0, "value": 18000.0, "fragile": 0.25, "hazard": "fuel_tank", "name_key": "p_nto_tank" if i == OX else "p_mmh_tank"}, _capsule(x0, TY0, x1, TY1))
		var third := (x1 - x0) / 3.0
		tk.set_meta("segments", [[x0 + third, TY0, x0 + third, TY1], [x1 - third, TY0, x1 - third, TY1]])
		# slung from the spine on two hangers, each strapped with two locks
		var k := 0
		for hx in [x0 + 3.0, x1 - 3.5]:
			k += 1
			var hg = K.plate("HG-%s%d" % [n, k], K.R(hx, 1.5, hx + 0.5, TY0), {"density": 1.6, "barrier": false, "cut_speed": 150.0, "name_key": "p_tank_hanger"}, "strut")
			K.bolt(hg, by_tag[_seg(false, hx + 0.25)], hx + 0.25, 1.5, "weld")
			K.bolt(tk, hg, hx + 0.1, TY0, "lock")
			K.bolt(tk, hg, hx + 0.4, TY0, "lock")
		# the sump and its pump under it, the manifold hung from those
		var sp = K.equip("SUMP-" + n, "pump", K.rect(x1 - 4.4, TY1 - 0.05, x1 - 3.2, MY), {"mass": 0.15, "value": 1500.0, "fragile": 0.35, "name_key": "p_sump_pump"})
		K.bolt(sp, tk, x1 - 4.0, TY1 - 0.05)
		K.bolt(sp, tk, x1 - 3.6, TY1 - 0.05)
	var xm = K.equip("XMAN", "pipe", K.rect(19.0, MY, 78.0, MY + 0.4), {"mass": 1.2, "value": 3000.0, "fragile": 0.3, "name_key": "p_cross_manifold"})
	for i in 3:
		# the fuel manifold runs past the oxidiser tank's sump without a connection to it
		if i != OX:
			K.bolt(xm, by_tag["SUMP-%d" % (i + 1)], TX1[i] - 3.8, MY)
	var rf = K.equip("RISER-F", "pipe", K.rect(19.0, 6.7, 19.4, MY), {"mass": 0.1, "value": 400.0, "fragile": 0.3, "name_key": "p_riser"})
	K.bolt(rf, K.at(19.2, 6.5, ["hull"]), 19.2, 6.7)
	K.bolt(rf, xm, 19.2, MY)
	var ra = K.equip("RISER-A", "pipe", K.rect(77.6, 7.4, 78.0, MY), {"mass": 0.1, "value": 400.0, "fragile": 0.3, "name_key": "p_riser"})
	K.bolt(ra, K.at(77.8, 7.2, ["hull"]), 77.8, 7.4)
	K.bolt(ra, xm, 77.8, MY)


# ---------------------------------------------------------------- the nitrogen bank on the spine

static func _nitrogen() -> void:
	var i := 0
	for cx in SPHERES:
		i += 1
		var ns = K.equip("NS-%d" % i, "sphere_tank", K.rect(cx - 1.7, -5.2, cx + 1.7, -1.8), {"mass": 0.6, "value": 2200.0, "fragile": 0.3, "hazard": "gas_tank", "name_key": "p_n2_sphere"})
		K.bolt(ns, by_tag[_seg(true, cx - 1.0)], cx - 1.0, -1.8, "lock")
		K.bolt(ns, by_tag[_seg(true, cx + 1.0)], cx + 1.0, -1.8, "lock")
	var hd = K.equip("NHDR", "pipe", K.rect(22.0, -5.6, 64.6, -5.2), {"mass": 0.3, "value": 1200.0, "fragile": 0.3, "hazard": "gas_tank", "name_key": "p_n2_header"})
	i = 0
	for cx in SPHERES:
		i += 1
		K.bolt(hd, by_tag["NS-%d" % i], cx, -5.2)


# ---------------------------------------------------------------- aft: auxiliary power over the pump room

static func _aft() -> void:
	var ad = K.plate("AD", K.R(72.15, -1.8, 85.55, -1.4), {"density": 1.2, "barrier": true, "cut_speed": 200.0, "name_key": "p_deck"}, "deck")
	K.bolt(ad, K.at(71.95, -1.6, ["hull"]), 72.15, -1.6, "weld")
	K.bolt(ad, K.at(85.8, -1.6, ["hull"]), 85.55, -1.6, "weld")
	# the auxiliary power room
	var ap = K.equip("APU", "gen", K.rect(72.6, -5.0, 77.0, -1.8), {"mass": 1.4, "value": 9000.0, "fragile": 0.35, "room": "A", "name_key": "p_apu"})
	K.bolt(ap, ad, 73.0, -1.8)
	K.bolt(ap, ad, 76.6, -1.8)
	var bt = K.equip("BAT", "battery", K.rect(77.6, -4.6, 80.4, -1.8), {"mass": 1.4, "value": 7000.0, "fragile": 0.4, "room": "A", "hazard": "battery", "name_key": "p_battery"})
	K.bolt(bt, ad, 78.0, -1.8)
	K.bolt(bt, ad, 80.0, -1.8)
	for k in 2:
		var x0 := 81.0 + k * 1.6
		var cb = K.equip("CO2-%d" % (k + 1), "gastank", K.rect(x0, -5.6, x0 + 1.2, -1.8), {"mass": 0.2, "value": 1200.0, "fragile": 0.3, "room": "A", "hazard": "gas_tank", "name_key": "p_co2_bottle"})
		K.bolt(cb, ad, x0 + 0.6, -1.8, "lock")
	K.lamp("LAMP-A", 82.0, -6.15, "A", K.at(82.0, -6.35, ["hull"]))
	# the pump room
	var pm = K.equip("PUMP-M", "pump", K.rect(74.0, 4.2, 77.6, 6.95), {"mass": 1.8, "value": 14000.0, "fragile": 0.35, "room": "P", "name_key": "p_main_pump"})
	K.bolt(pm, K.at(74.4, 7.15, ["hull"]), 74.4, 6.95)
	K.bolt(pm, K.at(77.2, 7.15, ["hull"]), 77.2, 6.95)
	var p2 = K.equip("PUMP-2", "pump", K.rect(78.0, 4.8, 80.4, 6.95), {"mass": 1.0, "value": 8000.0, "fragile": 0.35, "room": "P", "name_key": "p_transfer_pump"})
	K.bolt(p2, K.at(78.4, 7.15, ["hull"]), 78.4, 6.95)
	K.bolt(p2, K.at(80.0, 7.15, ["hull"]), 80.0, 6.95)
	var pr = K.equip("PUMP-R", "pump", K.rect(81.6, 5.2, 83.4, 6.95), {"mass": 0.9, "value": 8000.0, "fragile": 0.35, "room": "P", "name_key": "p_return_pump"})
	K.bolt(pr, K.at(82.0, 7.15, ["hull"]), 82.0, 6.95)
	K.bolt(pr, K.at(83.0, 7.15, ["hull"]), 83.0, 6.95)
	var fi = K.equip("FILTER", "filter", K.rect(83.8, 3.4, 85.4, 6.95), {"mass": 0.3, "value": 2000.0, "fragile": 0.35, "room": "P", "hazard": "chem", "name_key": "p_strainer"})
	K.bolt(fi, K.at(84.6, 7.15, ["hull"]), 84.6, 6.95, "lock")
	var fw = K.equip("FM", "nav", K.rect(72.15, 1.0, 73.0, 3.0), {"mass": 0.08, "value": 2500.0, "fragile": 0.5, "room": "P", "name_key": "p_flow_meter"})
	K.bolt(fw, K.at(71.95, 1.4, ["hull"]), 72.15, 1.4)
	K.bolt(fw, K.at(71.95, 2.6, ["hull"]), 72.15, 2.6)
	var sw = K.equip("PWR-P", "swb", K.rect(84.4, -1.0, 85.55, 2.6), {"mass": 0.6, "value": 6000.0, "fragile": 0.4, "room": "P", "name_key": "p_pump_power"})
	K.bolt(sw, K.at(85.8, -0.6, ["hull"]), 85.55, -0.6)
	K.bolt(sw, K.at(85.8, 2.2, ["hull"]), 85.55, 2.2)
	K.lamp("LAMP-P", 79.0, -1.4, "P", ad)
	# the vent tower on the roof
	var vt = K.equip("VTWR", "nozzle", K.rect(83.6, -9.6, 84.6, -6.6), {"cls": "metal", "dest": "metal", "mass": 0.2, "cut_speed": 170.0, "name_key": "p_vent_tower"})
	K.bolt(vt, K.at(84.1, -6.4, ["hull"]), 84.1, -6.6)


static func _engine() -> void:
	var en = K.equip("ENG-V", "eng_core", K.rect(86.0, -2.6, 90.0, 4.6), {"mass": 2.2, "value": 10000.0, "fragile": 0.3, "name_key": "p_engine"})
	K.bolt(en, K.at(85.75, -1.5, ["hull"]), 86.0, -1.5)
	K.bolt(en, K.at(85.75, 3.0, ["hull"]), 86.0, 3.0)
	var nz = K.equip("NOZ-V", "nozzle", K.rect(90.0, -3.4, 96.0, 5.4), {"cls": "metal", "dest": "metal", "mass": 0.5, "cut_speed": 160.0, "name_key": "p_nozzle"},
		K.mp([Vector2(90.0, -1.8), Vector2(96.0, -3.4), Vector2(96.0, 5.4), Vector2(90.0, 3.8)]))
	K.bolt(nz, en, 90.0, -1.0)
	K.bolt(nz, en, 90.0, 3.0)
	for e in [["RCS-1", -7.4, -6.6], ["RCS-2", 7.4, 8.2]]:
		var rc = K.equip(e[0], "rcs_quad", K.rect(84.0, e[1], 86.0, e[2]), {"cls": "metal", "dest": "metal", "mass": 0.1, "cut_speed": 180.0, "name_key": "p_rcs"})
		var yy: float = e[2] if e[0] == "RCS-1" else e[1]
		K.bolt(rc, K.at(85.0, yy + (0.2 if e[0] == "RCS-1" else -0.2), ["hull"]), 85.0, yy)


# ---------------------------------------------------------------- lines

static func _lines() -> void:
	# power: the battery to the pump room's board, the pumps, the lamps, forward along the tube
	K.line("e1", "cable", "power", "BAT", Vector2(79.0, -1.8), "PWR-P", Vector2(84.4, 0.0), [Vector2(79.0, -0.6), Vector2(84.0, -0.6), Vector2(84.0, 0.0)])
	K.line("e2", "cable", "power", "PWR-P", Vector2(84.4, 1.2), "PUMP-M", Vector2(76.0, 4.2), [Vector2(76.0, 1.2)])
	K.line("e3", "cable", "power", "PWR-P", Vector2(84.4, 2.0), "PUMP-2", Vector2(79.2, 4.8), [Vector2(79.2, 2.0)])
	K.line("e4", "cable", "power", "PWR-P", Vector2(84.8, -1.0), "LAMP-P", Vector2(79.0, -1.24), [Vector2(84.8, -1.2), Vector2(79.0, -1.2)])
	K.line("e5", "cable", "power", "LAMP-P", Vector2(79.2, -1.24), "LAMP-A", Vector2(82.0, -5.99), [Vector2(80.8, -1.2), Vector2(80.8, -5.8), Vector2(82.0, -5.8)])
	K.line("e6", "cable", "power", "LAMP-P", Vector2(78.8, -1.24), "LAMP-K", Vector2(45.0, -1.24), [Vector2(78.8, -1.1), Vector2(45.0, -1.1)])
	K.line("e7", "cable", "power", "LAMP-K", Vector2(44.8, -1.24), "LAMP-Q", Vector2(12.0, -6.49), [Vector2(44.8, -1.05), Vector2(19.0, -1.05), Vector2(19.0, -6.3), Vector2(12.0, -6.3)])
	K.line("e8", "cable", "power", "LAMP-Q", Vector2(11.8, -6.49), "LSS", Vector2(14.6, -5.6), [Vector2(11.8, -6.0), Vector2(14.6, -6.0)])
	K.line("e9", "cable", "power", "LAMP-Q", Vector2(12.2, -6.49), "LAMP-C", Vector2(6.5, _iy(OUT_F, 1, 6.5) + 0.16), [Vector2(12.2, -0.8), Vector2(9.0, -0.8), Vector2(9.0, -1.4), Vector2(6.5, -1.4)])
	K.line("e10", "cable", "power", "LAMP-C", Vector2(6.7, _iy(OUT_F, 1, 6.5) + 0.16), "FMON", Vector2(6.8, 2.6), [Vector2(6.8, -1.2)])
	K.line("e11", "cable", "power", "FMON", Vector2(7.4, 3.2), "VMAP", Vector2(8.6, -0.5), [Vector2(7.7, 3.2), Vector2(7.7, 0.2), Vector2(8.6, 0.2)])
	K.line("e12", "cable", "power", "FMON", Vector2(5.0, 2.6), "NAV", Vector2(4.0, 0.0), [Vector2(5.0, 1.0), Vector2(4.0, 1.0)])
	K.line("e13", "cable", "power", "LAMP-Q", Vector2(12.4, -6.49), "ESD-V", Vector2(18.0, 3.8), [Vector2(19.3, -6.5), Vector2(19.3, 3.0), Vector2(18.0, 3.0)])
	K.line("e14", "cable", "power", "ESD-V", Vector2(17.2, 4.6), "FC-V", Vector2(16.6, 4.6))
	# propellant: each tank's branch to the manifold, the manifold up to the valves forward and the pumps aft
	for i in 3:
		var bx: float = TX1[i] - 2.0
		K.line("b%d" % (i + 1), "pipe", "pb%d" % (i + 1), "T-%d" % (i + 1), Vector2(bx, TY1 - 0.1), "XMAN", Vector2(bx, MY + 0.1))
	K.line("r1", "pipe", "pxm", "RISER-A", Vector2(77.8, 7.5), "PUMP-M", Vector2(77.0, 5.0), [Vector2(77.8, 5.0)])
	K.line("r2", "pipe", "pxm", "RISER-F", Vector2(19.2, 6.8), "MV", Vector2(14.6, 5.0), [Vector2(19.2, 5.0)])
	# the pressurisation down from the header to each tank's top
	for i in 3:
		var zx: float = (TX0[i] + TX1[i]) * 0.5 + 1.2
		K.line("z%d" % (i + 1), "pipe", "n2", "NHDR", Vector2(zx, -5.3), "T-%d" % (i + 1), Vector2(zx, TY0 + 0.1))


# ---------------------------------------------------------------- controls

static func _controls() -> void:
	K.ctrl("G-C", "port", K.at(5.0, _iy(OUT_F, 1, 5.0) - 0.25, ["hull"]), Vector2(5.0, -2.42), {"medium": "gas", "target": "C"})
	K.ctrl("G-Q", "port", K.at(17.0, -6.9, ["hull"]), Vector2(17.0, -7.35), {"medium": "gas", "target": "Q"})
	K.ctrl("G-K", "port", by_tag["SP-T-3"], Vector2(52.0, -1.95), {"medium": "gas", "target": "K"})
	K.ctrl("G-P", "port", K.at(80.0, 7.2, ["hull"]), Vector2(80.0, 7.65), {"medium": "gas", "target": "P"})
	K.ctrl("G-A", "port", K.at(75.0, -6.4, ["hull"]), Vector2(75.0, -6.85), {"medium": "gas", "target": "A"})
	var px = K.equip("PNL-X", "panel", K.rect(72.4, 7.4, 75.0, 7.9), {"cls": "metal", "dest": "metal", "mass": 0.06, "cut_speed": 240.0, "name_key": "p_panel"})
	K.bolt(px, K.at(72.8, 7.2, ["hull"]), 72.8, 7.4)
	K.bolt(px, K.at(74.6, 7.2, ["hull"]), 74.6, 7.4)
	K.ctrl("K-M", "switch", px, Vector2(72.8, 7.65), {"target": "K-M", "state": true})
	K.ctrl("E-1", "test", px, Vector2(73.7, 7.65), {"medium": "volt", "target": "bus"})
	K.ctrl("AUX-P", "socket", px, Vector2(74.6, 7.65), {"target": "aux", "state": false})
	for h in [["HT-Q", ""], ["HT-V", ""], ["HT-A", ""], ["D-CQ", "Q"], ["D-QK", "Q"], ["D-KP", "K"], ["HT-P", ""]]:
		K.door(h[0], h[1])
	for i in 3:
		var n := str(i + 1)
		var x0: float = TX0[i]
		var x1: float = TX1[i]
		var tk = by_tag["T-" + n]
		if i == OX:
			# the oxidiser's own valve and drain, on its sump
			K.ctrl("XV-" + n, "valve", by_tag["SUMP-" + n], Vector2(x1 - 4.1, MY - 0.3), {"target": "XV-" + n, "state": false})
			K.ctrl("LD-" + n, "port", by_tag["SUMP-" + n], Vector2(x1 - 3.5, MY - 0.25), {"medium": "fuel", "target": "b" + n})
		else:
			K.ctrl("XV-" + n, "valve", by_tag["XMAN"], Vector2(x1 - 2.6, MY + 0.2), {"target": "XV-" + n, "state": false})
			K.ctrl("LD-" + n, "port", by_tag["XMAN"], Vector2(x1 - 1.3, MY + 0.3), {"medium": "fuel", "target": "b" + n})
		K.ctrl("L-" + n, "probe", tk, Vector2(x0 + 1.0, 5.8), {"medium": "level", "target": "t" + n})
		K.ctrl("TV-" + n, "port", tk, Vector2(x0 + 6.0, TY0 + 0.3), {"medium": "gas", "target": "TU-" + n})
		K.ctrl("PV-" + n, "valve", by_tag["NHDR"], Vector2((x0 + x1) * 0.5 + 1.2, -5.4), {"target": "PV-" + n, "state": true})
	K.ctrl("NV", "valve", by_tag["NHDR"], Vector2(22.6, -5.4), {"target": "NV", "state": true})
	for i in SPHERES.size():
		K.ctrl("NP-%d" % (i + 1), "port", by_tag["NS-%d" % (i + 1)], Vector2(SPHERES[i], -4.8), {"medium": "gas", "target": "N-%d" % (i + 1)})
	K.ctrl("PR", "port", by_tag["PUMP-M"], Vector2(75.0, 4.4), {"medium": "fuel", "target": "xm", "hidden_room": "P"})
	K.ctrl("PO", "port", by_tag["O2B"], Vector2(18.9, -6.0), {"medium": "gas", "target": "O2B", "hidden_room": "Q"})
	K.ctrl("CP-1", "port", by_tag["CO2-1"], Vector2(81.6, -5.4), {"medium": "gas", "target": "CO2-1", "hidden_room": "A"})
	K.ctrl("CP-2", "port", by_tag["CO2-2"], Vector2(83.2, -5.4), {"medium": "gas", "target": "CO2-2", "hidden_room": "A"})


# ---------------------------------------------------------------- rooms

static func _rooms() -> void:
	var fi := K.inner(OUT_F, T)
	var ai := K.inner(OUT_A, T)
	w.add_room("C", K.mp([fi[0], fi[1], Vector2(9.4, _iy(OUT_F, 1, 9.4)), Vector2(9.4, _iy(OUT_F, 7, 9.4)), fi[8], fi[9]]))
	w.add_room("Q", K.mp([fi[3], fi[4], Vector2(fi[4].x, 1.1), Vector2(fi[3].x, 1.1)]))
	w.add_room("V", K.mp([Vector2(fi[3].x, 1.5), Vector2(fi[4].x, 1.5), fi[5], fi[6]]))
	w.add_room("K", K.mp([Vector2(20.0, -1.4), Vector2(71.7, -1.4), Vector2(71.7, 1.1), Vector2(20.0, 1.1)]))
	w.add_room("A", K.mp([ai[0], ai[1], Vector2(ai[1].x, -1.8), Vector2(ai[0].x, -1.8)]))
	w.add_room("P", K.mp([Vector2(ai[0].x, -1.4), Vector2(ai[1].x, -1.4), ai[2], ai[3]]))


static func meta() -> Dictionary:
	var vols := {}
	var tanks := {}
	var joins: Array = []
	var gas_v := {}
	var valves: Array = []
	for i in 3:
		var n := str(i + 1)
		vols["t" + n] = {"fluid": "fuel", "look": CHEM[i], "amount": FILL[i], "piece": "T-" + n, "port": "L-" + n, "full": CAP, "content": 1.0, "leak": 0.15}
		vols["b" + n] = {"fluid": "fuel", "look": CHEM[i], "amount": 0.02 if FILL[i] > 0.0 else 0.0, "nets": ["pb" + n], "leak": 0.06, "leak_min": 0.004, "port": "LD-" + n, "full": 0.02}
		joins.append({"a": "t" + n, "b": "b" + n, "valves": ["XV-" + n], "mode": "fill", "cap": 0.02, "leak_through": 0.05})
		tanks["T-" + n] = {"vol": "t" + n, "valve": "XV-" + n, "cap": CAP, "ullage": "TU-" + n, "pv": "PV-" + n, "branch": "b" + n}
		if i == OX:
			# drawn at its own drain, not through the fuel manifold
			vols["b" + n]["pump"] = [0.5, 0.03]
			tanks["T-" + n]["own"] = true
			tanks["T-" + n]["drain"] = "LD-" + n
		gas_v["TU-" + n] = {"V": CAP - FILL[i], "kpa": 320.0, "piece": "T-" + n, "burst": 200.0}
		valves.append({"ctrl": "PV-" + n, "a": "NH", "b": "TU-" + n, "g": 1.2})
	# the pressurisation pipes hold the bank's gas, no liquid
	vols["n2_line"] = {"fluid": "n2", "amount": 0.0, "nets": ["n2"]}
	vols["xm"] = {"fluid": "fuel", "amount": 0.15, "piece": "XMAN", "nets": ["pxm"], "port": "PR", "full": 0.4, "leak": 0.1, "leak_min": 0.004, "pump": [0.12, 0.01]}
	for i in SPHERES.size():
		gas_v["N-%d" % (i + 1)] = {"V": 0.6, "kpa": 1800.0, "piece": "NS-%d" % (i + 1), "burst": 200.0}
		valves.append({"ctrl": "NV", "a": "N-%d" % (i + 1), "b": "NH", "g": 2.0})
	gas_v["NH"] = {"V": 0.05, "kpa": 1800.0, "piece": "NHDR", "burst": 200.0}
	gas_v["O2B"] = {"V": 0.1, "kpa": 6000.0, "piece": "O2B", "burst": 200.0}
	gas_v["CO2-1"] = {"V": 0.12, "kpa": 5000.0, "piece": "CO2-1", "burst": 200.0}
	gas_v["CO2-2"] = {"V": 0.12, "kpa": 5000.0, "piece": "CO2-2", "burst": 200.0}
	var hold: Array = ["NP-1", "NP-2", "NP-3", "NP-4", "NP-5", "NP-6", "TV-1", "TV-2", "TV-3"]
	return {
		"id": "vt80",
		"name": "VT-80 LONG WHALE",
		"title": ["VT-80「长鲸」推进剂运输船 · 96 m", "VT-80 LONG WHALE · PROPELLANT CARRIER · 96 m"],
		"contract": "VT-80",
		"length": 96.0,
		"value": {"total": 300000.0, "metal": 40000.0},
		"clamps": [[15.0, 6.7], [79.0, 7.4]],
		"room_names": {"C": "room_vtC", "Q": "room_vtQ", "V": "room_vtV", "K": "room_vtK", "A": "room_vtA", "P": "room_vtP"},
		"gas": {"rooms": {"C": 101.0, "Q": 101.0, "V": 0.2, "K": 101.0, "A": 101.0, "P": 101.0},
			"vessels": gas_v, "valves": valves, "value": 6000.0},
		"tanknet": {"tanks": tanks, "manifold": "xm", "mcap": 0.4, "pump": "PUMP-M", "port": "PR", "flow": 0.25, "hold": hold, "bank": "NV"},
		"power": {
			"bus": "PWR-P",
			"sources": [
				{"piece": "BAT", "kind": "battery", "volts": 440.0, "local_volts": 48.0, "cable": "e1", "switch": "K-M", "charge": 0.9, "drain": 0.0003},
			],
			"lamps": {"C": "LAMP-C", "Q": "LAMP-Q", "K": "LAMP-K", "A": "LAMP-A", "P": "LAMP-P"},
		},
		"fluids": {"volumes": vols, "joins": joins, "value": {"fuel": 60000.0}},
		"ctrls_cfg": {"G-C": {"rate": 24.0}, "G-Q": {"rate": 30.0}, "G-K": {"rate": 40.0}, "G-P": {"rate": 36.0}, "G-A": {"rate": 24.0},
			"TV-1": {"rate": 0.8}, "TV-2": {"rate": 0.8}, "TV-3": {"rate": 0.8},
			"NP-1": {"rate": 0.5}, "NP-2": {"rate": 0.5}, "NP-3": {"rate": 0.5}, "NP-4": {"rate": 0.5}, "NP-5": {"rate": 0.5}, "NP-6": {"rate": 0.5},
			"PO": {"rate": 0.3}, "CP-1": {"rate": 0.3}, "CP-2": {"rate": 0.3}},
		"labels": {"BAT": "BAT", "PWR-P": "PUMP PWR", "T-1": "T1 MMH", "T-2": "T2 N2O4", "T-3": "T3 MMH", "XMAN": "XCONN", "PUMP-M": "MAIN PUMP", "PUMP-2": "PUMP 2", "PUMP-R": "RETURN",
			"MV": "MAIN VALVES", "FMON": "FLUID MON", "VMAP": "VALVE MAP", "APU": "APU", "NHDR": "N2 HDR",
			"NS-1": "N2", "NS-2": "N2", "NS-3": "N2", "NS-4": "N2", "NS-5": "N2", "NS-6": "N2", "CO2-1": "CO2", "CO2-2": "CO2", "O2B": "O2"},
		"hints": {},
		"market": {
			"class": "VT", "name": ["长鲸级推进剂运输船", "LONG WHALE-CLASS PROPELLANT CARRIER"], "time": 55.0,
			"rooms": {"C": [0.2, 40.0, 101.0], "Q": [0.2, 40.0, 101.0], "K": [0.2, 40.0, 101.0], "A": [0.2, 40.0, 101.0], "P": [0.2, 40.0, 101.0]},
			"charge": {"BAT": [0.3, 1.0]},
			"fluids": {"t1": [0.4, 2.4], "t2": [0.1, 1.2], "t3": [0.6, 3.0]}, "fill": {"b1": "t1", "b2": "t2", "b3": "t3"},
			"knockable": ["VMAP", "FC-V"],
			"drift": [],
			"section_x": 45.0,
			"slots": {"hidden_damage": {"plates": ["HF3-0", "HF3-2", "HA0-0", "HA0-2"]},
				"fire_system": {"x": 80.6, "y0": 5.6, "y1": 6.95, "base": ["HA2-0", 6.95], "room": "P", "port": [81.0, 5.67]},
				"valve_leak": {"tanks": ["T-1", "T-3"]}},
			"mechanisms": true,
		},
		"procedures": {
			"FMON": [
				{"do": "hose", "ctrl": "G-Q"},
				{"do": "hose", "ctrl": "G-C"},
				{"do": "wait", "until": {"P": ["Q", "<", 5.0]}, "max": 150.0},
				{"do": "operate", "ctrl": "HT-Q"},
				{"do": "wait", "until": {"open": ["Q"]}, "max": 5.0},
				{"do": "wait", "until": {"P": ["C", "<", 5.0]}, "max": 150.0},
				{"do": "operate", "ctrl": "D-CQ"},
				{"do": "wait", "until": {"open": ["C"]}, "max": 5.0},
				{"do": "operate", "ctrl": "K-M"},
				{"do": "measure", "ctrl": "E-1", "expect": ["<", 1.0]},
				{"do": "free", "piece": "FMON"},
				{"do": "deliver", "piece": "FMON", "zone": "equip"},
			],
		},
	}
