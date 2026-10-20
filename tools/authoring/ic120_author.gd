class_name Ic120Author
# Authoring script for IC-120 "Iceberg", a 122 m ice-hulled water carrier (exotic batch
# 10/10, design/ships/IC-120_冰山_设计稿.md and IC-120_线稿.png, as drawn). Not part of
# the game: tools/ship_export.gd runs it and writes ships/ic120.json.
# Metres, x bow (0) to the nozzles (~123), y down.
#
# A body of water ice 100 m long held in a metal saddle (six ribs and two longitudinal
# beams); the ice between them in blocks. The habitat is frozen into the middle, reached
# by a shaft through the ice to its hatch; the metal engine module hangs on the saddle's
# tail. Heater mats on the ribs' tops melt the ice block by block into the water main;
# the saddle's four seats under the ribs are its lifting points.
# What it asks of you (scripts/ice.gd): melt the ice and keep the water drawn off as it
# melts (standing meltwater shorts the engine module's gear while the bus is live);
# don't cut ice by the crack while the seats beside it hold (it runs and splits the
# ice); let the seats go only once the ice is gone (or it drops on the engine module).

const K = preload("res://tools/authoring/kit.gd")
const ICE := [Vector2(0.0, 0.0), Vector2(4.0, -8.5), Vector2(12.0, -15.0), Vector2(40.0, -22.0), Vector2(58.0, -20.0), Vector2(72.0, -23.0),
	Vector2(90.0, -17.0), Vector2(100.0, -10.0), Vector2(100.0, 10.0), Vector2(90.0, 14.5), Vector2(72.0, 18.0), Vector2(50.0, 20.0),
	Vector2(34.0, 17.5), Vector2(20.0, 13.5), Vector2(8.0, 8.0)]
const RIBS := [30.4, 42.4, 54.4, 66.4, 78.4, 90.4]
const RW := 0.6
const BT := -11.4                # the upper beam (to -10.8)
const BB := 10.8                 # the lower beam (to 11.4)
const HAB := [55.0, -6.4, 66.4, 6.4]
const SHAFT := [59.4, 62.0]
const EOUT := [Vector2(101.6, -8.6), Vector2(118.4, -8.6), Vector2(120.0, -7.0), Vector2(120.0, 7.0), Vector2(118.4, 8.6), Vector2(101.6, 8.6),
	Vector2(100.0, 7.0), Vector2(100.0, -7.0)]
const T := 0.45

# which heater melts what, nearest first
const HEAT := {
	"HT-1": ["ICE-2T", "ICE-2B", "ICE-1T", "ICE-1B"], "HT-2": ["ICE-0T", "ICE-0B"],
	"HT-3": ["ICE-3T", "ICE-3M", "ICE-3B"], "HT-4": ["ICE-4T", "ICE-4M", "ICE-4B"],
	"HT-5": ["ICE-5TL", "ICE-5AL", "ICE-5L"], "HT-6": ["ICE-5TR", "ICE-5AR", "ICE-5B"],
	"HT-7": ["ICE-6T", "ICE-6M", "ICE-6B"], "HT-8": ["ICE-7T", "ICE-7M", "ICE-7B"], "HT-9": ["ICE-8T", "ICE-8B"],
}

static var w
static var by_tag := {}


static func build(world) -> void:
	K.begin(world, "IC120")
	w = world
	by_tag = K.by_tag
	_saddle()
	_habitat()
	_engine_module()
	_ice()
	_heaters()
	_lines()
	_controls()
	_rooms()


static func rooms_only(world) -> void:
	K.begin(world, "IC120")
	w = world
	_rooms()


# the ice's top / bottom at x
static func top(x: float) -> float:
	for i in 7:
		if x >= ICE[i].x and x <= ICE[i + 1].x:
			return ICE[i].y + (x - ICE[i].x) / (ICE[i + 1].x - ICE[i].x) * (ICE[i + 1].y - ICE[i].y)
	return 0.0


static func bot(x: float) -> float:
	var b: Array = [ICE[0], ICE[14], ICE[13], ICE[12], ICE[11], ICE[10], ICE[9], ICE[8]]
	for i in 7:
		if x >= b[i].x and x <= b[i + 1].x:
			return b[i].y + (x - b[i].x) / (b[i + 1].x - b[i].x) * (b[i + 1].y - b[i].y)
	return 0.0


static func _clip(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	var a := PackedVector2Array(ICE)
	var r := PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
	var out: Array = Geometry2D.intersect_polygons(a, r)
	return out[0] if not out.is_empty() else PackedVector2Array()


# ---------------------------------------------------------------- the saddle: ribs, beams, seats

static func _saddle() -> void:
	var S := {"density": 2.0, "barrier": false, "cut_speed": 120.0, "name_key": "p_saddle_rib"}
	var k := 0
	for x in RIBS:
		k += 1
		var xm: float = x + RW * 0.5
		var tp: float = minf(top(x), top(x + RW))
		var bt: float = maxf(bot(x), bot(x + RW))
		var parts: Array = [["R%d-T" % k, top(x), BT], ["R%d-M" % k, BT, BB + 0.6], ["R%d-B" % k, BB + 0.6, bot(x)]]
		var prev = null
		for pr in parts:
			var y0: float = pr[1]
			var y1: float = pr[2]
			var poly := K.mp([Vector2(x, top(x) if pr[0].ends_with("-T") else y0), Vector2(x + RW, top(x + RW) if pr[0].ends_with("-T") else y0),
				Vector2(x + RW, bot(x + RW) if pr[0].ends_with("-B") else y1), Vector2(x, bot(x) if pr[0].ends_with("-B") else y1)])
			var pc = K.plate(pr[0], poly, S, "beam")
			if prev != null:
				K.bolt(pc, prev, xm, y0, "bolt")
			prev = pc
		k = k
	# the beams, a length between each pair of ribs
	var B := {"density": 2.0, "barrier": false, "cut_speed": 120.0, "name_key": "p_saddle_beam"}
	for i in RIBS.size() - 1:
		var x0: float = RIBS[i] + RW
		var x1: float = RIBS[i + 1]
		for e in [["BU-%d" % (i + 1), BT, BT + 0.6, "R%d-M"], ["BL-%d" % (i + 1), BB, BB + 0.6, "R%d-M"]]:
			var ym: float = (e[1] + e[2]) * 0.5
			if i == 2 and e[1] == BT:
				# broken for the shaft down to the habitat's hatch
				var ba = K.plate(e[0] + "a", K.R(x0, e[1], SHAFT[0], e[2]), B, "beam")
				var bb = K.plate(e[0] + "b", K.R(SHAFT[1], e[1], x1, e[2]), B, "beam")
				K.bolt(ba, by_tag[e[3] % (i + 1)], x0, ym, "weld")
				K.bolt(bb, by_tag[e[3] % (i + 2)], x1, ym, "weld")
				continue
			var bm = K.plate(e[0], K.R(x0, e[1], x1, e[2]), B, "beam")
			K.bolt(bm, by_tag[e[3] % (i + 1)], x0, ym, "weld")
			K.bolt(bm, by_tag[e[3] % (i + 2)], x1, ym, "weld")
	# the seats under ribs 1, 3, 5, 6: the lifting points, each with its hold
	var n := 0
	for ri in [0, 2, 4, 5]:
		n += 1
		var x: float = RIBS[ri]
		var y0: float = maxf(bot(x), bot(x + RW))
		var pd = K.equip("PAD-%d" % n, "module", K.rect(x - 0.7, y0 + 0.05, x + 1.3, y0 + 1.65), {"mass": 2.0, "value": 4000.0, "fragile": 0.2, "name_key": "p_saddle_seat"})
		K.bolt(pd, by_tag["R%d-B" % (ri + 1)], x + 0.15, bot(x + 0.15))
		K.bolt(pd, by_tag["R%d-B" % (ri + 1)], x + 0.45, bot(x + 0.45))
		K.clamp(n, x + 0.3, y0 + 1.65, y0 + 1.45, ["equip"])


# ---------------------------------------------------------------- the habitat frozen in the middle

static func _habitat() -> void:
	var x0: float = HAB[0]
	var y0: float = HAB[1]
	var x1: float = HAB[2]
	var y1: float = HAB[3]
	var hout := [Vector2(x0 + 1.0, y0), Vector2(x1 - 1.0, y0), Vector2(x1, y0 + 1.0), Vector2(x1, y1 - 1.0), Vector2(x1 - 1.0, y1), Vector2(x0 + 1.0, y1),
		Vector2(x0, y1 - 1.0), Vector2(x0, y0 + 1.0)]
	var t0 := (SHAFT[0] + 0.4 - (x0 + 1.0)) / (x1 - x0 - 2.0)
	var t1 := (SHAFT[1] - 0.4 - (x0 + 1.0)) / (x1 - x0 - 2.0)
	K.ring(hout, 0.4, {0: [t0, t1]}, {"0:1": {"kind": "hatch", "door": true, "tag": "HT-H", "open_dir": Vector2(1.8, 0) * Geom.M, "cut_speed": 200.0}},
		{"density": 1.5, "barrier": true, "cut_speed": 200.0, "name_key": "p_hab_shell"}, "HH")
	# welded to the ribs either side
	K.bolt(K.at(x0 + 0.2, 0.0, ["hull"]), by_tag["R3-M"], x0, 0.0, "weld")
	K.bolt(K.at(x1 - 0.2, 0.0, ["hull"]), by_tag["R4-M"], x1, 0.0, "weld")
	var fl: float = y1 - 0.4
	var cl: float = y0 + 0.4
	var lo = _E("BUNK-HA", "bunk", 55.6, fl - 1.45, 59.2, fl - 0.05, fl, fl + 0.2, "p_bunk", 0.3, 1500.0)
	var hi = K.equip("BUNK-HB", "bunk", K.rect(55.6, fl - 2.95, 59.2, fl - 1.5), {"mass": 0.3, "value": 1500.0, "fragile": 0.3, "room": "H", "name_key": "p_bunk"})
	K.bolt(hi, lo, 56.1, fl - 1.45)
	K.bolt(hi, lo, 58.7, fl - 1.45)
	_E("ECS-H", "env", 59.6, fl - 2.25, 62.2, fl - 0.05, fl, fl + 0.2, "p_ecs", 0.6, 7000.0)
	_E("BAT-H", "battery", 62.6, fl - 1.85, 65.6, fl - 0.05, fl, fl + 0.2, "p_battery", 0.8, 6000.0, "battery")
	_E("LOG-H", "blackbox", 55.8, cl + 0.05, 57.6, cl + 1.85, cl, cl - 0.2, "p_voyage_recorder", 0.2, 9000.0, "", true)
	_E("CON-H", "screen", 57.8, cl + 0.05, 59.2, cl + 1.25, cl, cl - 0.2, "p_crew_station", 0.15, 5000.0)
	_E("AHU-H", "env", 62.4, cl + 0.05, 64.8, cl + 1.25, cl, cl - 0.2, "p_ahu", 0.3, 4000.0)
	K.lamp("LAMP-H", 65.4, cl, "H", K.at(65.4, cl - 0.2, ["hull"]))
	for e in [["SUITS-H", "suit", 55.45, 56.9, 55.4, 55.2, "p_suit_locker", 2500.0], ["RADIO-H", "nav", 64.5, 65.95, 66.0, 66.2, "p_comms", 4000.0]]:
		var p = K.equip(e[0], e[1], K.rect(e[2], -4.0, e[3], -0.4), {"mass": 0.2, "value": e[7], "fragile": 0.4, "room": "H", "name_key": e[6]})
		K.bolt(p, K.at(e[5], -3.4, ["hull"]), e[4], -3.4)
		K.bolt(p, K.at(e[5], -1.0, ["hull"]), e[4], -1.0)


static func _E(tag: String, art: String, x0: float, y0: float, x1: float, y1: float, at: float, probe: float, nk: String, m: float, v: float, hz := "", mand := false):
	var o := {"mass": m, "value": v, "fragile": 0.4, "room": "H", "name_key": nk}
	if hz != "":
		o.hazard = hz
	if mand:
		o.mandatory = true
	var p = K.equip(tag, art, K.rect(x0, y0, x1, y1), o)
	for x in [x0 + 0.3, x1 - 0.3]:
		K.bolt(p, K.at(x, probe, ["hull"]), x, at)
	return p


# ---------------------------------------------------------------- the engine module on the saddle's tail

static func _engine_module() -> void:
	K.ring(EOUT, T, {0: [0.345, 0.464], 4: [0.5]}, {"0:1": {"kind": "hatch", "door": true, "tag": "HT-E", "open_dir": Vector2(2.2, 0) * Geom.M, "cut_speed": 200.0}},
		{"density": 1.6, "barrier": true, "cut_speed": 210.0}, "HE")
	var fl := 8.15
	var cl := -8.15
	var em := func(tag: String, art: String, x0: float, x1: float, h: float, on_floor: bool, nk: String, m: float, v: float, hz: String = ""):
		var o := {"mass": m, "value": v, "fragile": 0.35, "room": "E", "name_key": nk}
		if hz != "":
			o.hazard = hz
		var y0: float = fl - 0.05 - h if on_floor else cl + 0.05
		var y1: float = fl - 0.05 if on_floor else cl + 0.05 + h
		var p = K.equip(tag, art, K.rect(x0, y0, x1, y1), o)
		for x in [x0 + 0.3, x1 - 0.3]:
			K.bolt(p, K.at(x, fl + 0.2 if on_floor else cl - 0.2, ["hull"]), x, fl if on_floor else cl)
		return p
	em.call("TK-1", "fueltank", 102.0, 107.0, 4.4, false, "p_prop_tank", 1.6, 5000.0, "fuel_tank")
	em.call("TK-2", "fueltank", 109.8, 114.8, 4.4, false, "p_prop_tank", 1.6, 5000.0, "fuel_tank")
	em.call("GEN-E", "gen", 102.0, 106.4, 3.4, true, "p_generator", 2.0, 18000.0)
	em.call("MP-1", "pump", 106.8, 109.6, 2.2, true, "p_water_pump", 1.2, 8000.0)
	em.call("MP-2", "pump", 110.0, 112.8, 2.2, true, "p_water_pump", 1.2, 8000.0)
	em.call("BAT-E", "battery", 113.2, 116.2, 2.4, true, "p_battery", 1.5, 8000.0, "battery")
	em.call("DIST-E", "swb", 116.6, 118.6, 3.0, true, "p_swb", 0.4, 5000.0)
	em.call("HUM-E", "insp", 116.2, 117.4, 1.0, false, "p_humidity", 0.05, 2500.0)
	K.lamp("LAMP-E", 118.0, cl, "E", K.at(118.0, cl - 0.2, ["hull"]))
	# on the walls: the meltwater separator and the heaters' controller forward, the console aft
	var wl := func(tag: String, art: String, x0: float, y0: float, x1: float, y1: float, wx: float, nk: String, m: float, v: float):
		var p = K.equip(tag, art, K.rect(x0, y0, x1, y1), {"mass": m, "value": v, "fragile": 0.4, "room": "E", "name_key": nk})
		K.bolt(p, K.at(wx + (-0.2 if wx < 110.0 else 0.2), y0 + 0.5, ["hull"]), wx, y0 + 0.5)
		K.bolt(p, K.at(wx + (-0.2 if wx < 110.0 else 0.2), y1 - 0.5, ["hull"]), wx, y1 - 0.5)
		return p
	wl.call("SEP-E", "filter", 100.5, -3.4, 102.6, 0.0, 100.45, "p_separator", 0.6, 5000.0)
	wl.call("HTC-E", "nav_rack", 100.5, 0.4, 102.2, 3.2, 100.45, "p_process_cabinet", 0.4, 6000.0)
	wl.call("CON-E", "console", 117.6, -3.0, 119.5, 0.4, 119.55, "p_helm", 0.3, 7000.0)
	for e in [["ENG-1", -6.4, -0.6], ["ENG-2", 0.6, 6.4]]:
		var en = K.equip(e[0], "eng_core", K.rect(120.0, e[1], 122.4, e[2]), {"mass": 2.5, "value": 20000.0, "fragile": 0.3, "name_key": "p_engine"})
		var ym: float = (e[1] + e[2]) * 0.5
		K.bolt(en, K.at(119.8, ym - 1.5, ["hull"]), 120.0, ym - 1.5)
		K.bolt(en, K.at(119.8, ym + 1.5, ["hull"]), 120.0, ym + 1.5)
	K.clamp(5, 110.0, 8.6, 8.4)


# ---------------------------------------------------------------- the ice, in blocks

static func _ice() -> void:
	var I := {"density": 0.02, "barrier": true, "cut_speed": 18.0, "art": "ice", "name_key": "p_ice"}
	var cols: Array = [[0.0, 10.0], [10.0, 20.0], [20.0, RIBS[0]]]
	for i in RIBS.size() - 1:
		cols.append([RIBS[i] + RW, RIBS[i + 1]])
	cols.append([RIBS[5] + RW, 100.0])
	var blocks: Array = []
	for ci in cols.size():
		var x0: float = cols[ci][0]
		var x1: float = cols[ci][1]
		var rows: Array = []
		if ci < 3 or ci == cols.size() - 1:
			rows = [["T", -30.0, 0.0, x0, x1], ["B", 0.0, 30.0, x0, x1]]
		elif ci == 5:
			rows = [["TL", -30.0, BT, x0, SHAFT[0]], ["TR", -30.0, BT, SHAFT[1], x1], ["AL", BT + 0.6, HAB[1], x0, SHAFT[0]], ["AR", BT + 0.6, HAB[1], SHAFT[1], x1],
				["L", HAB[3], BB, x0, x1], ["B", BB + 0.6, 30.0, x0, x1]]
		else:
			rows = [["T", -30.0, BT, x0, x1], ["M", BT + 0.6, BB, x0, x1], ["B", BB + 0.6, 30.0, x0, x1]]
		for r in rows:
			var poly := _clip(r[3], r[1], r[4], r[2])
			if poly.size() < 3:
				continue
			var tag := "ICE-%d%s" % [ci, r[0]]
			var ip = K.plate(tag, K.mp(Array(poly)), I, "ice")
			blocks.append([tag, ci, r])
	# frozen to the saddle and to each other
	for b in blocks:
		var p = by_tag[b[0]]
		var ci: int = b[1]
		var r: Array = b[2]
		var yc: float = clampf((maxf(r[1], -20.0) + minf(r[2], 18.0)) * 0.5, -8.0, 8.0)
		var x0: float = r[3]
		var x1: float = r[4]
		var bb := Geom.bbox(p.poly)
		yc = clampf(yc, bb.position.y / Geom.M + 0.5, bb.end.y / Geom.M - 0.5)
		for pt in [Vector2(x0 - 0.2, yc), Vector2(x1 + 0.2, yc), Vector2((x0 + x1) * 0.5, bb.position.y / Geom.M - 0.2), Vector2((x0 + x1) * 0.5, bb.end.y / Geom.M + 0.2)]:
			var q = w.piece_at(K.p(pt.x, pt.y))
			if q == null or q == p:
				continue
			var jx := clampf(pt.x, x0, x1)
			var jy := clampf(pt.y, bb.position.y / Geom.M, bb.end.y / Geom.M)
			K.bolt(p, q, jx, jy, "weld")


# ---------------------------------------------------------------- the heater mats on the ribs' tops

static func _heaters() -> void:
	var at := {"HT-1": [0, 0], "HT-2": [0, 1], "HT-3": [1, 0], "HT-4": [2, 0], "HT-5": [2, 1], "HT-6": [3, 0], "HT-7": [4, 0], "HT-8": [5, 0], "HT-9": [5, 1]}
	for h in at:
		var ri: int = at[h][0]
		var lv: int = at[h][1]
		var x: float = RIBS[ri]
		var y1: float = _hy(x, lv)
		var hp
		if lv == 0:
			# the mat's underside on the slope of the ice
			hp = K.equip("HTR-" + h.substr(3), "radiator", K.rect(x - 0.4, y1 - 1.0, x + 1.0, maxf(top(x - 0.4), top(x + 1.0)) - 0.05), {"mass": 0.2, "value": 2500.0, "fragile": 0.35, "name_key": "p_ice_heater"},
				K.mp([Vector2(x - 0.4, y1 - 1.0), Vector2(x + 1.0, y1 - 1.0), Vector2(x + 1.0, top(x + 1.0) - 0.05), Vector2(x - 0.4, top(x - 0.4) - 0.05)]))
			K.bolt(hp, by_tag["R%d-T" % (ri + 1)], x + 0.15, top(x + 0.15))
			K.bolt(hp, by_tag["R%d-T" % (ri + 1)], x + 0.45, top(x + 0.45))
		else:
			hp = K.equip("HTR-" + h.substr(3), "radiator", K.rect(x - 0.4, y1 - 1.0 + 0.05 - 0.05, x + 1.0, y1 + 0.05 - 0.05), {"mass": 0.2, "value": 2500.0, "fragile": 0.35, "name_key": "p_ice_heater"})
			var below = by_tag["HTR-" + str(int(h.substr(3)) - 1)]
			K.bolt(hp, below, x - 0.1, y1 + 0.05)
			K.bolt(hp, below, x + 0.7, y1 + 0.05)


# a heater mat's bottom edge on rib x at level lv
static func _hy(x: float, lv: int) -> float:
	return minf(top(x - 0.4), top(x + 1.0)) - 0.05 - lv * 1.1


# ---------------------------------------------------------------- lines

static func _lines() -> void:
	# the engine module's bus
	K.line("b1", "cable", "power", "BAT-E", Vector2(116.2, 7.0), "DIST-E", Vector2(116.6, 7.0))
	K.line("b2", "cable", "power", "GEN-E", Vector2(104.2, 4.7), "DIST-E", Vector2(117.6, 5.1), [Vector2(104.2, 4.0), Vector2(117.6, 4.0)])
	K.line("p1", "cable", "power", "DIST-E", Vector2(118.0, 5.1), "LAMP-E", Vector2(118.0, -7.99), [Vector2(118.0, 3.6), Vector2(119.0, 3.6), Vector2(119.0, -7.6), Vector2(118.0, -7.6)])
	K.line("p2", "cable", "power", "DIST-E", Vector2(117.0, 5.1), "MP-2", Vector2(111.4, 5.9), [Vector2(117.0, 4.4), Vector2(111.4, 4.4)])
	K.line("p3", "cable", "power", "MP-2", Vector2(110.0, 7.0), "MP-1", Vector2(109.6, 7.0))
	K.line("p4", "cable", "power", "DIST-E", Vector2(118.3, 5.1), "HUM-E", Vector2(116.8, -7.1), [Vector2(118.3, 3.2), Vector2(116.8, 3.2)])
	# out over the ice along the ribs' tops: heater to heater
	var chain: Array = ["HTR-9", "HTR-8", "HTR-7", "HTR-6", "HTR-5", "HTR-4", "HTR-3", "HTR-2", "HTR-1"]
	var hx := {"HTR-1": 30.4, "HTR-2": 30.4, "HTR-3": 42.4, "HTR-4": 54.4, "HTR-5": 54.4, "HTR-6": 66.4, "HTR-7": 78.4, "HTR-8": 90.4, "HTR-9": 90.4}
	K.line("h0", "cable", "power", "DIST-E", Vector2(117.4, 5.1), "HTR-8", Vector2(91.4, _hy(90.4, 0) - 0.5), [Vector2(117.4, 4.8), Vector2(119.4, 4.8), Vector2(119.4, -9.4), Vector2(91.4, -9.4)])
	K.line("hs9", "cable", "power", "HTR-8", Vector2(91.0, _hy(90.4, 0) - 0.5), "HTR-9", Vector2(91.0, _hy(90.4, 1) - 0.5))
	var prev := "HTR-8"
	for t in ["HTR-7", "HTR-6", "HTR-4", "HTR-3", "HTR-1"]:
		var xa: float = hx[prev] - 0.4
		var xb: float = hx[t] + 1.0
		var ya: float = _hy(hx[prev], 0) - 0.5
		var yb: float = _hy(hx[t], 0) - 0.5
		K.line("h" + t.substr(4), "cable", "power", prev, Vector2(xa, ya), t, Vector2(xb, yb))
		prev = t
	K.line("hs5", "cable", "power", "HTR-4", Vector2(55.0, _hy(54.4, 0) - 0.5), "HTR-5", Vector2(55.0, _hy(54.4, 1) - 0.5))
	K.line("hs2", "cable", "power", "HTR-1", Vector2(31.0, _hy(30.4, 0) - 0.5), "HTR-2", Vector2(31.0, _hy(30.4, 1) - 0.5))
	# the water main: from the forward rib along the lower beam to the pumps
	K.line("m1", "pipe", "main", "BL-1", Vector2(36.0, BB + 0.3), "MP-1", Vector2(108.2, 5.9), [Vector2(36.0, 11.1), Vector2(99.0, 11.1), Vector2(99.0, 5.0), Vector2(108.2, 5.0)])
	K.line("m2", "pipe", "main", "MP-1", Vector2(109.6, 6.6), "MP-2", Vector2(110.0, 6.6))
	# the habitat on its own battery
	K.line("r1", "cable", "power", "BAT-H", Vector2(64.0, 4.15), "ECS-H", Vector2(62.2, 4.6), [Vector2(64.0, 3.4), Vector2(62.6, 3.4), Vector2(62.6, 4.6)])
	K.line("r2", "cable", "power", "ECS-H", Vector2(60.8, 3.75), "AHU-H", Vector2(63.6, -4.7), [Vector2(60.8, 0.0), Vector2(63.6, 0.0)])
	K.line("r3", "cable", "power", "AHU-H", Vector2(64.8, -5.4), "LAMP-H", Vector2(65.4, -5.84), [Vector2(65.4, -5.4)])
	K.line("r4", "cable", "power", "AHU-H", Vector2(62.4, -5.4), "CON-H", Vector2(59.2, -5.4))
	K.line("r5", "cable", "power", "CON-H", Vector2(57.8, -5.4), "LOG-H", Vector2(57.6, -5.4))
	K.line("r6", "cable", "power", "AHU-H", Vector2(64.6, -4.7), "RADIO-H", Vector2(64.9, -4.0), [Vector2(64.9, -4.7)])
	K.line("p5", "cable", "power", "DIST-E", Vector2(117.8, 5.1), "CON-E", Vector2(118.4, 0.4), [Vector2(117.8, 2.0), Vector2(118.4, 2.0)])
	K.line("p6", "cable", "power", "GEN-E", Vector2(102.0, 5.6), "HTC-E", Vector2(101.4, 3.2), [Vector2(101.4, 5.6)])
	# propellant to the engines
	K.line("f1", "pipe", "feed", "TK-1", Vector2(105.0, -3.7), "ENG-1", Vector2(120.0, -3.5), [Vector2(105.0, -3.4), Vector2(119.0, -3.4), Vector2(119.0, -3.5)])
	K.line("f2", "pipe", "feed", "TK-2", Vector2(111.6, -3.7), "ENG-2", Vector2(120.0, 3.5), [Vector2(111.6, -2.6), Vector2(118.8, -2.6), Vector2(118.8, 3.5)])


# ---------------------------------------------------------------- controls

static func _controls() -> void:
	K.ctrl("G-E", "port", K.at(104.0, -8.4, ["hull"]), Vector2(104.0, -8.85), {"medium": "gas", "target": "E"})
	K.ctrl("G-H", "port", K.at(61.7, HAB[1] + 0.2, ["hull"]), Vector2(61.6, HAB[1] - 0.25), {"medium": "gas", "target": "H"})
	K.door("HT-E", "")
	K.door("HT-H", "")
	# the outside panel on the engine module's belly
	var px = K.equip("PNL-X", "panel", K.rect(112.0, 8.6, 114.6, 9.1), {"cls": "metal", "dest": "metal", "mass": 0.05, "cut_speed": 240.0, "name_key": "p_panel"})
	K.bolt(px, K.at(112.4, 8.4, ["hull"]), 112.4, 8.6)
	K.bolt(px, K.at(114.2, 8.4, ["hull"]), 114.2, 8.6)
	K.ctrl("K-M", "switch", px, Vector2(112.4, 8.85), {"target": "K-M", "state": true})
	K.ctrl("E-1", "test", px, Vector2(113.3, 8.85), {"medium": "volt", "target": "bus"})
	K.ctrl("AUX-P", "socket", px, Vector2(114.2, 8.85), {"target": "aux", "state": false})
	# the water main's port outside on top of the engine module
	K.ctrl("PW", "port", K.at(116.6, -8.4, ["hull"]), Vector2(116.6, -8.85), {"medium": "water", "target": "melt"})
	K.ctrl("K-G", "switch", by_tag["GEN-E"], Vector2(104.2, 6.0), {"target": "K-G", "state": true, "hidden_room": "E"})
	K.ctrl("K-H", "switch", by_tag["BAT-H"], Vector2(64.1, 5.0), {"target": "K-H", "state": true, "hidden_room": "H"})
	K.ctrl("PT-1", "port", by_tag["TK-1"], Vector2(103.0, -4.0), {"medium": "fuel", "target": "t1", "hidden_room": "E"})
	K.ctrl("PT-2", "port", by_tag["TK-2"], Vector2(109.6, -4.0), {"medium": "fuel", "target": "t2", "hidden_room": "E"})
	# each heater's switch on its mat, each seat's hold, the crack's strain gauge
	for i in 9:
		var hp = by_tag["HTR-%d" % (i + 1)]
		var bb := Geom.bbox(hp.poly)
		K.ctrl("HT-%d" % (i + 1), "switch", hp, bb.get_center() / Geom.M, {"target": "HT-%d" % (i + 1), "state": false})
	for n in 4:
		var pd = by_tag["PAD-%d" % (n + 1)]
		var c: Vector2 = Geom.bbox(pd.poly).get_center() / Geom.M
		K.ctrl("PH-%d" % (n + 1), "switch", pd, c + Vector2(-0.4, 0.0), {"target": "PH-%d" % (n + 1), "state": true})
	var p1c: Vector2 = Geom.bbox(by_tag["PAD-1"].poly).get_center() / Geom.M
	K.ctrl("SG-C", "probe", by_tag["PAD-1"], p1c + Vector2(0.5, 0.0), {"medium": "crack", "target": "crack"})


# ---------------------------------------------------------------- rooms

static func _rooms() -> void:
	var x0: float = HAB[0]
	var y0: float = HAB[1]
	var x1: float = HAB[2]
	var y1: float = HAB[3]
	var hout := [Vector2(x0 + 1.0, y0), Vector2(x1 - 1.0, y0), Vector2(x1, y0 + 1.0), Vector2(x1, y1 - 1.0), Vector2(x1 - 1.0, y1), Vector2(x0 + 1.0, y1),
		Vector2(x0, y1 - 1.0), Vector2(x0, y0 + 1.0)]
	w.add_room("H", K.mp(K.inner(hout, 0.4)))
	w.add_room("E", K.mp(K.inner(EOUT, T)))


static func _heaters_cfg() -> Dictionary:
	var out := {}
	for h in HEAT:
		out[h] = {"piece": "HTR-" + h.substr(3), "blocks": HEAT[h]}
	return out


static func _clamps() -> Array:
	var out: Array = []
	for ri in [0, 2, 4, 5]:
		var x: float = RIBS[ri]
		out.append([x + 0.3, maxf(bot(x), bot(x + RW)) + 1.65])
	out.append([110.0, 8.6])
	return out


static func meta() -> Dictionary:
	var e_gear: Array = ["GEN-E", "MP-1", "MP-2", "BAT-E", "DIST-E", "HUM-E"]
	return {
		"id": "ic120",
		"name": "IC-120 ICEBERG",
		"title": ["IC-120「冰山」冰体水货船 · 120 m", "IC-120 ICEBERG · ICE-HULLED WATER CARRIER · 120 m"],
		"contract": "IC-120",
		"length": 123.0,
		"value": {"total": 330100.0, "metal": 40000.0},
		"clamps": _clamps(),
		"room_names": {"H": "room_icH", "E": "room_icE"},
		"gas": {"rooms": {"H": 101.0, "E": 101.0}, "vessels": {}, "valves": [], "value": 1200.0},
		"ice": {
			"heaters": _heaters_cfg(),
			"water": 0.6, "melt_s": 24.0, "volume": "melt",
			"short": {"limit": 3.0, "hits": e_gear},
			"crack": {"blocks": ["ICE-3T", "ICE-3M", "ICE-4M", "ICE-4B"], "holds": ["PH-1", "PH-2"], "hits": ["BUNK-HA", "BUNK-HB", "ECS-H", "BAT-H", "LOG-H", "CON-H", "AHU-H", "HTR-3", "HTR-4"]},
			"pads": {"holds": ["PH-1", "PH-2", "PH-3", "PH-4"], "keep": 0.5, "hits": e_gear + ["TK-1", "TK-2", "ENG-1", "ENG-2"]},
		},
		"power": {
			"bus": "DIST-E",
			"sources": [
				{"piece": "BAT-E", "kind": "battery", "volts": 440.0, "local_volts": 48.0, "cable": "b1", "switch": "K-M", "charge": 0.9, "drain": 0.0003},
				{"piece": "GEN-E", "kind": "gen", "volts": 440.0, "cable": "b2", "switch": "K-G", "running": true},
			],
			"isolated": [{"piece": "BAT-H", "volts": 220.0, "charge": 0.9, "switch": "K-H"}],
			"lamps": {"E": "LAMP-E"},
		},
		"fluids": {"volumes": {
			"melt": {"fluid": "water", "amount": 0.0, "piece": "MP-1", "port": "PW", "full": 20.0, "content": 0.0, "nets": ["main"], "leak": 0.1, "pump": [0.3, 0.01]},
			"t1": {"fluid": "fuel", "amount": 0.6, "piece": "TK-1", "port": "PT-1", "full": 0.8, "content": 1.0, "leak": 0.12, "pump": [0.12, 0.008]},
			"t2": {"fluid": "fuel", "amount": 0.6, "piece": "TK-2", "port": "PT-2", "full": 0.8, "content": 1.0, "leak": 0.12, "pump": [0.12, 0.008]},
			"feed_line": {"fluid": "fuel", "amount": 0.02, "nets": ["feed"], "leak": 0.06, "leak_min": 0.004},
		}, "joins": [], "value": {"water": 90000.0, "fuel": 2400.0}},
		"ctrls_cfg": {"G-E": {"rate": 22.0}, "G-H": {"rate": 18.0}},
		"labels": {"BAT-E": "BAT", "DIST-E": "BUS", "GEN-E": "GEN", "MP-1": "MAIN", "LOG-H": "LOG", "BAT-H": "BAT H"},
		"hints": {},
		"market": {
			"class": "IC", "name": ["冰山级冰体水货船", "ICEBERG-CLASS WATER CARRIER"], "time": 45.0,
			"rooms": {"H": [0.2, 40.0, 101.0], "E": [0.2, 40.0, 101.0]},
			"charge": {"BAT-E": [0.4, 1.0]},
			"fluids": {"t1": [0.2, 0.6], "t2": [0.2, 0.6]}, "fill": {"feed_line": "t1"},
			"knockable": ["DIST-E", "CON-H"],
			"drift": [],
			"section_x": 100.0,
			"slots": {"fire_system": {"x": 115.0, "y0": -8.1, "y1": -6.4, "base": ["HE0-2", -8.15], "room": "E", "port": [115.4, -6.47]}},
			"mechanisms": true,
		},
		"procedures": {
			"LOG-H": [
				{"do": "hose", "ctrl": "G-H"},
				{"do": "wait", "until": {"P": ["H", "<", 5.0]}, "max": 150.0},
				{"do": "operate", "ctrl": "HT-H"},
				{"do": "wait", "until": {"open": ["H"]}, "max": 20.0},
				{"do": "operate", "ctrl": "K-H"},
				{"do": "free", "piece": "LOG-H"},
				{"do": "deliver", "piece": "LOG-H", "zone": "equip"},
			],
		},
	}
