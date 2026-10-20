class_name ArktestAuthor
# A bare stress-test hull at ARK-01's scale (design/ships/ARK-01_远航者_设计稿.md, the
# roadmap's 6.3: "press-test with a test ship without art first"). Not in the market:
# tests/ark_perf.gd builds it and times the frame. ~600 m long, ~220 m tall; the spine
# a 440 m pressure tube in twelve segments, two rings seen edge-on (a hub on the spine,
# a spoke up and one down to a rim module top and bottom), an industrial block, a
# shielded power core, a tail of tanks and engines; ~1,500 pieces, most of them
# equipment in the rooms.

const K = preload("res://tools/authoring/kit.gd")
const T := 0.9
const SEG := 36.0
const X0 := 50.0                 # the spine starts behind the bridge
const SPINE_H := 6.0             # the spine tube's half height
const RINGS := [[85.0, 105.0, 30.0], [193.0, 110.0, 40.0]]   # hub x, rim radius, rim module length

static var w
static var by_tag := {}
static var n_eq := 0


static func build(world) -> void:
	K.begin(world, "ARKT")
	w = world
	by_tag = K.by_tag
	n_eq = 0
	_box("BR", 0.0, -10.0, X0, 10.0, "BR", 4)
	for i in 12:
		var x0 := X0 + i * SEG
		_box("S%d" % (i + 1), x0, -SPINE_H, x0 + SEG, SPINE_H, "S%d" % (i + 1), 2)
	for r in 2:
		var hx: float = RINGS[r][0]
		var rad: float = RINGS[r][1]
		var ln: float = RINGS[r][2]
		for sg in [-1.0, 1.0]:
			var nm := "R%d%s" % [r + 1, "U" if sg < 0.0 else "D"]
			# the spoke, a tube from the spine's skin out to the rim
			var y_in: float = sg * SPINE_H
			var y_out: float = sg * (rad - 17.0)
			_box(nm, hx - ln * 0.5, minf(sg * (rad - 17.0), sg * (rad + 17.0)), hx + ln * 0.5, maxf(sg * (rad - 17.0), sg * (rad + 17.0)), nm, 3)
			_tube(nm + "-SP", hx - 2.0, minf(y_in, y_out), hx + 2.0, maxf(y_in, y_out))
	_box("IND", 240.0, -30.0, 360.0, -SPINE_H - 0.2, "IND", 3)
	_box("PWR", 385.0, SPINE_H + 0.2, 475.0, 40.0, "PWR", 3)
	# the tail: a truss on from the spine, tanks on posts off it, a thrust plate and the engines
	var x_end: float = X0 + 12 * SEG
	var tr = K.plate("TRUSS", K.R(x_end, -2.0, 586.0, 2.0), {"density": 1.5, "barrier": false}, "beam")
	K.bolt(tr, K.at(x_end - 0.3, 0.0, ["hull"]), x_end, 0.0, "weld")
	var tp = K.plate("THRUST", K.R(586.0, -22.0, 588.0, 22.0), {"density": 1.5, "barrier": false}, "beam")
	K.bolt(tp, tr, 586.0, 0.0, "weld")
	for k in 8:
		var tx := 495.0 + (k % 4) * 22.0
		var up := k < 4
		var ty := -22.0 if up else 4.0
		var tk = K.equip("PT-%d" % (k + 1), "sphere_tank", K.rect(tx, ty, tx + 18.0, ty + 18.0), {"mass": 2.5, "value": 8000.0, "fragile": 0.3})
		var post = K.plate("", K.R(tx + 8.0, -4.0 if up else 2.0, tx + 10.0, -2.0 if up else 4.0), {"density": 1.5, "barrier": false}, "strut")
		K.bolt(post, tr, tx + 9.0, -2.0 if up else 2.0, "weld")
		K.bolt(tk, post, tx + 9.0, -4.0 if up else 4.0)
		n_eq += 1
	for e in 5:
		var ey := -20.0 + e * 8.4
		var en = K.equip("ENG-%d" % (e + 1), "eng_core", K.rect(588.0, ey, 600.0, ey + 7.0), {"mass": 2.8, "value": 30000.0, "fragile": 0.3})
		K.bolt(en, tp, 588.0, ey + 1.0)
		K.bolt(en, tp, 588.0, ey + 6.0)
		n_eq += 1
	# the boxes welded where they meet
	for i in 12:
		var bx := X0 + i * SEG
		K.bolt(K.at(bx - 0.3, 0.0, ["hull"]), K.at(bx + 0.3, 0.0, ["hull"]), bx, 0.0, "weld")
	for x in [250.0, 300.0, 350.0]:
		K.bolt(K.at(x, -6.4, ["hull"]), K.at(x, -5.6, ["hull"]), x, -6.1, "weld")
	for x in [395.0, 430.0, 465.0]:
		K.bolt(K.at(x, 6.4, ["hull"]), K.at(x, 5.6, ["hull"]), x, 6.1, "weld")
	K.clamp(1, 100.0, SPINE_H, SPINE_H - 0.2)
	K.clamp(2, 300.0, SPINE_H, SPINE_H - 0.2)
	K.clamp(3, 450.0, SPINE_H, SPINE_H - 0.2)


# a pressure box (a room) with decks every few metres and equipment along each
static func _box(tag: String, x0: float, y0: float, x1: float, y1: float, room: String, decks: int) -> void:
	var out := [Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]
	var splits := []
	var nseg := maxi(2, int((x1 - x0) / 6.0))
	for k in range(1, nseg):
		splits.append(float(k) / nseg)
	K.ring(out, T, {0: splits, 2: splits}, {}, {"density": 1.6, "barrier": true, "cut_speed": 200.0}, "H" + tag)
	w.add_room(room, K.mp(K.inner(out, T)))
	var ih: float = (y1 - y0) - 2.0 * T
	var dh: float = ih / decks
	for d in decks:
		var fy: float = y0 + T + dh * (d + 1)
		var base = null
		if d < decks - 1:
			base = K.plate("", K.R(x0 + T, fy, x1 - T, fy + 0.3), {"density": 1.0, "barrier": false}, "deck")
			K.bolt(base, K.at(x0 + T - 0.2, fy + 0.15, ["hull"]), x0 + T, fy + 0.15, "weld")
			K.bolt(base, K.at(x1 - T + 0.2, fy + 0.15, ["hull"]), x1 - T, fy + 0.15, "weld")
		var x := x0 + T + 0.6
		var arts := ["cabinet", "pump", "env", "swb", "locker", "console", "battery", "gen"]
		var k := 0
		while x + 2.6 < x1 - T:
			var hgt: float = minf(dh - 0.6, 1.4 + (k % 3) * 0.6)
			var eq = K.equip("", arts[k % arts.size()], K.rect(x, fy - hgt - 0.05, x + 2.2, fy - 0.05), {"mass": 0.4, "value": 2000.0, "fragile": 0.4, "room": room})
			var bp = base if base != null else null
			if bp != null:
				K.bolt(eq, bp, x + 0.4, fy)
				K.bolt(eq, bp, x + 1.8, fy)
			else:
				K.bolt(eq, K.at(x + 0.4, fy + 0.2, ["hull"]), x + 0.4, fy)
				K.bolt(eq, K.at(x + 1.8, fy + 0.2, ["hull"]), x + 1.8, fy)
			n_eq += 1
			k += 1
			x += 2.8


static func _tube(tag: String, x0: float, y0: float, x1: float, y1: float) -> void:
	for xx in [[x0, x0 + 0.6], [x1 - 0.6, x1]]:
		var pc = K.plate("", K.R(xx[0], y0, xx[1], y1), {"density": 1.2, "barrier": false}, "beam")
		K.bolt(pc, K.at((xx[0] + xx[1]) * 0.5, y0 - 0.3, ["hull"]), (xx[0] + xx[1]) * 0.5, y0, "weld")
		K.bolt(pc, K.at((xx[0] + xx[1]) * 0.5, y1 + 0.3, ["hull"]), (xx[0] + xx[1]) * 0.5, y1, "weld")


static func rooms_only(world) -> void:
	pass


static func meta() -> Dictionary:
	var rooms := {}
	for r in ["BR", "IND", "PWR", "R1U", "R1D", "R2U", "R2D"]:
		rooms[r] = 101.0
	for i in 12:
		rooms["S%d" % (i + 1)] = 101.0
	return {
		"id": "arktest",
		"name": "ARK STRESS TEST",
		"title": ["ARK 压测船", "ARK STRESS TEST"],
		"contract": "ARK-T",
		"length": 600.0,
		"gas_cell_max": 0.8,
		"value": {"total": 4000000.0, "metal": 200000.0},
		"clamps": [[100.0, SPINE_H], [300.0, SPINE_H], [450.0, SPINE_H]],
		"room_names": {},
		"gas": {"rooms": rooms, "vessels": {}, "valves": [], "value": 0.0},
		"power": {"bus": "", "sources": [], "lamps": {}},
		"ctrls_cfg": {},
		"labels": {},
		"hints": {},
		"procedures": {},
	}
