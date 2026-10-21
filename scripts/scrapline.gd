extends RefCounted
# The pre-processing line between the scrap mouth and the furnace (player
# 2026-10-20: "a part goes in, and below you see a small copy of it: the shredder
# grinds it to powder, then it melts into liquid iron"; "the press really has to
# squash a tonne of plate into a puck"). The mouth still takes the scrap at once
# and pays for it; this is what happens to it afterwards, shown with the part's
# own outline:
#   a diverter sends plate (hull, deck, bulkhead, hatch, door) to a baling press:
#   the lid ram squashes it down, the side ram across, the end gate opens and a
#   puck about 5.5 t/m³ rolls out to the furnace's bunker;
#   everything else goes to a twin-shaft shredder whose counter-rotating hook teeth
#   bite the part in from below, a hammer mill beats the pieces through a 25 mm
#   screen, and a magnetic drum keeps the iron (a vibrating pan feeds it into the
#   furnace) and throws the aluminium and copper off into a bin of their own
#   (Jev A 0.94 / 0.91).
# Nothing here holds anything up: the line runs faster when it falls behind.
# Geometry in metres from the furnace axis X and the floor line F (y down).

const M := 48.0
const PLATE_KINDS := ["hull", "plate", "deck", "bulkhead", "hatch", "door"]
const PUCK_RHO := 5.5          # t/m³ of a pressed puck
const DEPTH := 0.6             # m: the press box's depth (into the screen)
const NONFERROUS := 0.06       # share of shredded scrap the drum throws off
const PRESS_T := [0.8, 1.4, 1.6, 0.5, 1.1]     # load, lid, side, hold, eject (s)
const PRESS_X0 := -9.0         # the press box's inside
const PRESS_X1 := -4.9
const PRESS_Y0 := 2.05
const PRESS_Y1 := 3.95
const ROT_Y := 2.95            # the shredder's rotor shafts
const ROT_L := 4.6
const ROT_R := 5.4
const ROT_RAD := 0.38
const MILL := Vector2(5.0, 4.3)
const MILL_R := 0.62
const DRUM := Vector2(5.0, 5.35)
const DRUM_R := 0.28

var X := 21.0
var game
var smelter
var t := 0.0
var arriving: Array = []      # items on their way from the mouth: {item, t, dur, from}
var press_q: Array = []
var shred_q: Array = []
var press = null              # the item in the press: {polys, w, h, mass, s, ph, pt, seed}
var shred = null              # the item in the shredder
var pucks: Array = []         # [x (m), mass, w, h]: on the rollers to the bunker
var frags: Array = []         # [pos, vel, rot, spin, size, stage, life]: shredder pieces into the mill
var fines: Array = []         # [pos, vel, ferrous, stage, a]: powder through the screen
var divert := 0.0             # the diverter's flap: -1 to the press, +1 to the shredder
var divert_goal := 0.0
var force := 0.0              # kN on the press's main cylinder
var torque := 0.0             # kN·m on the shredder's shafts
var pucks_made := 0
var shredded := 0.0
var ferrous := 0.0
var nonferrous := 0.0
var _charge_wait: Array = []  # [seconds left, t, dirty]: shredded mass still travelling as fines


func plate_like(kinds: Array) -> bool:
	if kinds.is_empty():
		return false
	for k in kinds:
		if not k in PLATE_KINDS:
			return false
	return true


# a body the mouth took: its pieces' outlines (m, around its middle), mass (t), the
# pieces' kinds, where along the floor the mouth was (m)
func take(polys: Array, mass: float, kinds: Array, from_x: float) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in polys:
		for q in p:
			lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
			hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	if lo.x == INF:
		lo = Vector2(-0.3, -0.3)
		hi = Vector2(0.3, 0.3)
	var c := (lo + hi) * 0.5
	var cp: Array = []
	for p in polys:
		var pp := PackedVector2Array()
		for q in p:
			pp.append(q - c)
		cp.append(pp)
	var it := {"polys": cp, "w": maxf(0.05, hi.x - lo.x), "h": maxf(0.05, hi.y - lo.y), "mass": mass, "seed": randi() % 1000,
		"route": "press" if plate_like(kinds) else "shred", "dirty": 0.0 if plate_like(kinds) else (1.0 if kinds.has("equip") else 0.4)}
	arriving.append({"item": it, "t": 0.0, "dur": 0.7 + absf(from_x - X) / 3.0, "from": from_x})


func busy() -> int:
	return arriving.size() + press_q.size() + shred_q.size() + (1 if press != null else 0) + (1 if shred != null else 0)


func waiting_mass() -> float:
	var m := 0.0
	for a in arriving:
		m += float(a.item.mass)
	for q in press_q + shred_q:
		m += float(q.mass)
	return m


# ---------------------------------------------------------------- per frame

func step(dt: float) -> void:
	if dt <= 0.0:
		return
	t += dt
	var hurry := 2.0 if busy() > 4 else 1.0
	# arrivals: along the belt, down the chute, through the diverter
	for a in arriving.duplicate():
		a.t += dt * hurry
		if a.t >= a.dur:
			arriving.erase(a)
			if a.item.route == "press":
				press_q.append(a.item)
			else:
				shred_q.append(a.item)
	if not arriving.is_empty():
		divert_goal = -1.0 if arriving[0].item.route == "press" else 1.0
	divert = move_toward(divert, divert_goal, dt * 3.0)
	_step_press(dt * hurry)
	_step_shred(dt * hurry)
	_step_bits(dt)
	for w in _charge_wait.duplicate():
		w[0] -= dt
		if w[0] <= 0.0:
			_charge_wait.erase(w)
			if smelter != null:
				smelter.charge(float(w[1]), X, float(w[2]))


func _step_press(dt: float) -> void:
	if press == null:
		force = move_toward(force, 0.0, 3000.0 * dt)
		if press_q.is_empty():
			return
		press = press_q.pop_front()
		press.s = minf(1.0, minf(3.6 / press.w, 1.6 / press.h))
		var area := float(press.mass) / PUCK_RHO / DEPTH
		var ph := clampf(sqrt(area / 1.25), 0.16, 1.1)
		press.ph_ = minf(ph, press.h * press.s)
		press.pw_ = minf(clampf(ph * 1.25, 0.2, 1.4), press.w * press.s)
		press.ph = 0
		press.pt = 0.0
		_sfx("hiss", 0.5)
	press.pt += dt
	if press.pt >= PRESS_T[press.ph]:
		press.pt -= PRESS_T[press.ph]
		press.ph += 1
		if press.ph == 1 or press.ph == 2:
			_sfx("clank", 0.7)
		if press.ph == 4:
			_sfx("hiss", 0.6)
		if press.ph >= PRESS_T.size():
			pucks.append([PRESS_X1, press.mass, press.pw_, press.ph_])
			pucks_made += 1
			press = null
			return
	var k := clampf(press.pt / PRESS_T[press.ph], 0.0, 1.0)
	match int(press.ph):
		1:
			force = 4000.0 * 0.6 * k * k
		2:
			force = 4000.0 * (0.6 + 0.4 * k * k)
		3:
			force = 4000.0
		_:
			force = move_toward(force, 0.0, 6000.0 * dt)


func _step_shred(dt: float) -> void:
	if shred == null:
		torque = move_toward(torque, 4.0, 60.0 * dt)
		if shred_q.is_empty():
			return
		shred = shred_q.pop_front()
		shred.s = minf(1.0, minf(1.5 / shred.w, 1.2 / shred.h))
		shred.y = 1.95 - shred.h * shred.s * 0.5
		shred.pt = 0.0
		shred.made = 0.0
	shred.pt += dt
	var hs: float = shred.h * shred.s
	if shred.pt < 0.6:
		return
	# fed down into the nip: the part below the bite line is gone into pieces
	var v := 0.45 * clampf(1.2 / maxf(0.3, float(shred.mass)), 0.4, 1.4)
	shred.y += v * dt
	var bitten := clampf((shred.y + hs * 0.5 - ROT_Y) / hs, 0.0, 1.0)
	torque = lerpf(torque, 20.0 + 70.0 * clampf(float(shred.mass), 0.1, 2.0), 1.0 - exp(-6.0 * dt))
	var want := int(bitten * 26.0)
	while shred.made < want:
		shred.made += 1
		var x := clampf(randf_range(ROT_L - 0.2, ROT_R + 0.2), 4.35, 5.65)
		frags.append([Vector2(x, ROT_Y + 0.2), Vector2(randf_range(-0.3, 0.3), randf_range(0.8, 1.3)), randf() * TAU, randf_range(-8, 8), randf_range(0.05, 0.11), 0, 0.0])
		if randf() < 0.3:
			_sfx("crack", 0.35)
	if bitten >= 1.0:
		shredded += float(shred.mass)
		var fe := float(shred.mass) * (1.0 - NONFERROUS)
		ferrous += fe
		nonferrous += float(shred.mass) * NONFERROUS * 1000.0
		_charge_wait.append([2.6, fe, shred.dirty])
		shred = null


# the pieces into the mill, the powder over the drum, the pucks along their rollers
func _step_bits(dt: float) -> void:
	for f in frags.duplicate():
		f[6] += dt
		if f[5] == 0:
			# falling from the rotors into the mill's throat
			f[0] += f[1] * dt
			f[2] += f[3] * dt
			if f[0].y > MILL.y - MILL_R * 0.6:
				f[5] = 1
				f[6] = 0.0
		else:
			# swept round by the hammers, then beaten through the screen as powder
			var a: float = t * 9.0 + f[2]
			f[0] = MILL + Vector2.from_angle(a) * MILL_R * 0.55
			if f[6] > 0.5:
				frags.erase(f)
				for q in 3:
					if fines.size() < 260:
						fines.append([MILL + Vector2(randf_range(-0.35, 0.35), MILL_R * 0.85), Vector2(randf_range(-0.1, 0.1), randf_range(0.6, 1.0)), randf() > NONFERROUS * 1.6, 0, 0.0])
	for p in fines.duplicate():
		p[4] += dt
		match int(p[3]):
			0:
				p[0] += p[1] * dt
				if p[0].distance_to(DRUM) < DRUM_R + 0.03:
					p[3] = 1
					p[4] = atan2(p[0].y - DRUM.y, p[0].x - DRUM.x)
			1:
				if p[2]:
					# held on the magnetised half, carried round to the left and let go onto the pan
					p[4] -= 2.4 * dt
					p[0] = DRUM + Vector2.from_angle(p[4]) * (DRUM_R + 0.02)
					if p[0].x < DRUM.x - DRUM_R * 0.8:
						p[3] = 2
						p[1] = Vector2(-1.4, 0.2)
				else:
					# non-ferrous: no grip, thrown off to the right into its bin
					p[3] = 3
					p[4] = 0.0
					p[1] = Vector2(1.2, 0.3)
			2:
				# along the vibrating pan to the furnace's port
				p[0] += p[1] * dt
				p[0].y = lerpf(5.6, 6.0, clampf((4.6 - p[0].x) / 3.9, 0.0, 1.0)) + 0.015 * sin(t * 60.0 + p[0].x * 30.0)
				if p[0].x < 0.75:
					fines.erase(p)
			3:
				p[0] += p[1] * dt
				p[1] *= exp(-2.0 * dt)
				if p[4] > 1.0:
					fines.erase(p)
	for pk in pucks.duplicate():
		pk[0] = move_toward(float(pk[0]), -1.0, 1.2 * dt)
		if float(pk[0]) <= -1.0:
			pucks.erase(pk)
			if smelter != null:
				smelter.charge(float(pk[1]), X, 0.0)


func _sfx(name: String, vol: float) -> void:
	if game != null and game.sfx != null:
		game.sfx.play(name, Vector2(X, Dock.FLOOR_Y + 3.0) * M, vol)


# ---------------------------------------------------------------- drawing

func _p(x: float, y: float, F: float) -> Vector2:
	return Vector2(X + x, F + y) * M


func _rect(ci: CanvasItem, x0: float, y0: float, x1: float, y1: float, F: float, fill_c: Color, edge: Color = Color(0, 0, 0, 0), w: float = 1.0) -> void:
	var r := Rect2(_p(x0, y0, F), Vector2(x1 - x0, y1 - y0) * M)
	ci.draw_rect(r, fill_c)
	if edge.a > 0.0:
		ci.draw_rect(r, edge, false, w)


# an item's outline drawn at (m), scaled, squashed toward an anchor and crumpled as it goes
func _item(ci: CanvasItem, it: Dictionary, at: Vector2, F: float, sx: float, sy: float, crumple: float, col: Color, edge: Color, clip_y: float = INF) -> void:
	var s: float = it.s
	var i := 0
	for poly in it.polys:
		var pts := PackedVector2Array()
		for q in poly:
			var n := Vector2(sin(float(i) * 12.99 + float(it.seed)), cos(float(i) * 7.31 + float(it.seed))) * crumple
			var v: Vector2 = at + Vector2(q.x * s * sx, q.y * s * sy) + n
			pts.append(v)
			i += 1
		if clip_y < INF:
			var cut := Geometry2D.intersect_polygons(pts, PackedVector2Array([Vector2(-100, -100), Vector2(100, -100), Vector2(100, clip_y), Vector2(-100, clip_y)]))
			for c in cut:
				_poly(ci, c, F, col, edge)
		elif pts.size() >= 3:
			_poly(ci, pts, F, col, edge)


func _poly(ci: CanvasItem, pts: PackedVector2Array, F: float, col: Color, edge: Color) -> void:
	var w := PackedVector2Array()
	for p in pts:
		w.append(_p(p.x, p.y, F))
	if Geometry2D.triangulate_polygon(w).is_empty():
		return
	ci.draw_colored_polygon(w, col)
	w.append(w[0])
	ci.draw_polyline(w, edge, 1.0)


func draw(ci: CanvasItem, F: float, mx: float, font: Font, font_b: Font, zoom: float, txt: Callable) -> void:
	var ink := Pal.ink(0.42)
	if zoom < 0.55:
		# far out: the machines' outlines
		_rect(ci, PRESS_X0 - 0.2, PRESS_Y0 - 0.2, PRESS_X1 + 0.2, PRESS_Y1 + 0.2, F, Color(0.06, 0.063, 0.072), ink)
		_rect(ci, 4.15, 1.85, 5.85, 3.55, F, Color(0.03, 0.031, 0.036), ink)
		ci.draw_circle(_p(MILL.x, MILL.y, F), MILL_R * M, Color(0.03, 0.031, 0.036))
		ci.draw_circle(_p(DRUM.x, DRUM.y, F), DRUM_R * M, Color(0.08, 0.083, 0.095))
		ci.draw_rect(Rect2(_p(10.5, 0.95, F), Vector2(6.9, 2.4) * M), Color(0.035, 0.037, 0.042, 0.96))
		return
	var steel := Color(0.06, 0.063, 0.072)
	var part_c := Color(0.2, 0.2, 0.215)
	var part_e := Pal.ink(0.55)
	# ---- the chute from the mouth's throat, and the return belt when the mouth has moved
	_rect(ci, -0.5, 0.45, 0.5, 1.2, F, Color(0.035, 0.037, 0.042), Pal.ink(0.3))
	if absf(mx - X) > 0.3:
		var bx0 := minf(mx, X)
		var bx1 := maxf(mx, X)
		ci.draw_rect(Rect2(_p(bx0 - X - 0.4, 0.62, F), Vector2(bx1 - bx0 + 0.8, 0.36) * M), Color(0.04, 0.042, 0.048))
		ci.draw_line(_p(bx0 - X - 0.4, 0.62, F), _p(bx1 - X + 0.4, 0.62, F), ink, 1.0)
		ci.draw_line(_p(bx0 - X - 0.4, 0.98, F), _p(bx1 - X + 0.4, 0.98, F), ink, 1.0)
		var sl := PackedVector2Array()
		var x := bx0 + fposmod(t * 2.5, 0.5)
		while x < bx1:
			sl.append_array([Vector2(x, F + 0.66) * M, Vector2(x, F + 0.94) * M])
			x += 0.5
		if not sl.is_empty():
			ci.draw_multiline(sl, Pal.ink(0.16), 1.6)
		ci.draw_line(Vector2(mx, F + 0.45) * M, Vector2(mx, F + 0.62) * M, ink, 2.0)
		_label(ci, font, Vector2(mx + 0.6 * signf(X - mx), F + 1.45) * M, txt.call("fu_belt"), zoom)
	# what is on its way: a small copy of the part, along the belt and down the chute
	for a in arriving:
		var u: float = clampf(float(a.t) / float(a.dur), 0.0, 1.0)
		var fx: float = a.from
		var d0 := 0.7 / float(a.dur)
		var p := Vector2(0.0, 0.5)
		if u < 1.0 - d0:
			p = Vector2(lerpf(fx, X, u / maxf(0.001, 1.0 - d0)) - X, 0.8)
		else:
			p = Vector2(0.0, lerpf(0.8, 1.5, (u - 1.0 + d0) / d0))
		var it: Dictionary = a.item
		var tmp := it.duplicate()
		tmp.s = minf(0.5 / it.w, 0.4 / it.h)
		_item(ci, tmp, p, F, 1.0, 1.0, 0.0, part_c, part_e)
	# ---- the diverter
	_rect(ci, -0.9, 1.2, 0.9, 1.75, F, Color(0.04, 0.042, 0.048), Pal.ink(0.45), 1.2)
	var fa := deg_to_rad(42.0) * divert
	ci.draw_line(_p(0.0, 1.25, F), _p(0.0, 1.25, F) + Vector2.from_angle(PI * 0.5 + fa) * 0.5 * M, Pal.ink(0.75), 3.0)
	ci.draw_circle(_p(0.0, 1.25, F), 3.0, Pal.ink(0.7))
	_label(ci, font, _p(1.0, 1.42, F), txt.call("sl_divert"), zoom)
	# chutes out of it: left to the press, right to the shredder
	ci.draw_polyline(PackedVector2Array([_p(-0.6, 1.75, F), _p(-4.6, 2.05, F)]), ink, 1.4)
	ci.draw_polyline(PackedVector2Array([_p(-0.6, 1.55, F), _p(-4.8, 1.85, F)]), ink, 1.4)
	ci.draw_polyline(PackedVector2Array([_p(0.6, 1.55, F), _p(3.8, 1.8, F)]), ink, 1.4)
	ci.draw_polyline(PackedVector2Array([_p(0.6, 1.75, F), _p(4.1, 2.05, F)]), ink, 1.4)
	_draw_press(ci, F, font, zoom, txt, steel, part_c, part_e)
	_draw_shredder(ci, F, font, zoom, txt, steel, part_c, part_e)
	_panel(ci, F, font, font_b, txt, zoom)


func _draw_press(ci: CanvasItem, F: float, font: Font, zoom: float, txt: Callable, steel: Color, part_c: Color, part_e: Color) -> void:
	# the box: thick walls, the side-ram cylinder to the left, the lid cylinder above
	_rect(ci, PRESS_X0 - 0.2, PRESS_Y0 - 0.2, PRESS_X1 + 0.2, PRESS_Y1 + 0.2, F, steel, Pal.ink(0.6), 1.6)
	_rect(ci, PRESS_X0, PRESS_Y0, PRESS_X1, PRESS_Y1, F, Color(0.025, 0.026, 0.03))
	for q in 6:
		var rx := PRESS_X0 + 0.3 + q * 0.7
		ci.draw_line(_p(rx, PRESS_Y0 - 0.2, F), _p(rx, PRESS_Y0 - 0.05, F), Pal.ink(0.35), 2.0)
		ci.draw_line(_p(rx, PRESS_Y1 + 0.05, F), _p(rx, PRESS_Y1 + 0.2, F), Pal.ink(0.35), 2.0)
	_rect(ci, -12.3, 2.55, PRESS_X0 - 0.2, 3.45, F, Color(0.08, 0.083, 0.095), Pal.ink(0.5), 1.2)
	_rect(ci, -7.35, 0.7, -6.55, PRESS_Y0 - 0.2, F, Color(0.08, 0.083, 0.095), Pal.ink(0.5), 1.2)
	# where the platens are: lid down to the part's squashed height, side ram across to its squashed width
	var lid_y := PRESS_Y0
	var side_x := PRESS_X0
	var gate := 0.0
	var it = press
	var sy := 1.0
	var sx := 1.0
	var crumple := 0.0
	if it != null:
		var ph: int = it.ph
		var k: float = clampf(float(it.pt) / PRESS_T[ph], 0.0, 1.0)
		var hs: float = it.h * it.s
		var ws: float = it.w * it.s
		var ky := 1.0
		var kx := 1.0
		if ph >= 1:
			ky = lerpf(1.0, it.ph_ / hs, Pal.ease_in(k) if ph == 1 else 1.0)
		if ph >= 2:
			kx = lerpf(1.0, it.pw_ / ws, Pal.ease_in(k) if ph == 2 else 1.0)
		sy = ky
		sx = kx
		crumple = 0.05 * (1.0 - ky) + 0.06 * (1.0 - kx)
		lid_y = PRESS_Y1 - hs * ky - 0.02
		side_x = PRESS_X1 - ws * kx - 0.02
		if ph == 0:
			lid_y = PRESS_Y0
			side_x = PRESS_X0
		gate = Pal.ease_io(k) if ph == 4 else 0.0
		# the part: in at the top right, settled into the corner, then squashed
		var at := Vector2(PRESS_X1 - ws * kx * 0.5, PRESS_Y1 - hs * ky * 0.5)
		if ph == 0:
			at = Vector2(-4.6, 1.9).lerp(Vector2(PRESS_X1 - ws * 0.5, PRESS_Y1 - hs * 0.5), Pal.ease_io(k))
		if ph >= 3:
			# pressed: a puck, its compressed layers showing on its face
			var pw: float = it.pw_
			var phh: float = it.ph_
			var cx := PRESS_X1 - pw * 0.5 + (gate * 1.4 if ph == 4 else 0.0)
			_puck(ci, Vector2(cx, PRESS_Y1 - phh * 0.5), pw, phh, F, it.seed)
		else:
			_item(ci, it, at, F, sx, sy, crumple, part_c, part_e)
	# lid platen and side platen, with their rods back to the cylinders
	_rect(ci, PRESS_X0, lid_y - 0.1, PRESS_X1, lid_y, F, Color(0.11, 0.115, 0.13), Pal.ink(0.7), 1.2)
	ci.draw_line(_p(-6.95, PRESS_Y0 - 0.2, F), _p(-6.95, lid_y - 0.1, F), Pal.ink(0.8), 4.0)
	_rect(ci, side_x - 0.1, PRESS_Y0, side_x, PRESS_Y1, F, Color(0.11, 0.115, 0.13), Pal.ink(0.7), 1.2)
	ci.draw_line(_p(PRESS_X0 - 0.2, 3.0, F), _p(side_x - 0.1, 3.0, F), Pal.ink(0.8), 5.0)
	# the end gate lifts to let the puck out
	_rect(ci, PRESS_X1, PRESS_Y0 - gate * 1.6, PRESS_X1 + 0.2, PRESS_Y1 - gate * 1.6, F, Color(0.1, 0.104, 0.115), Pal.ink(0.6), 1.2)
	# the force gauge on the box
	var gc := _p(-10.6, 2.0, F)
	ci.draw_arc(gc, 13.0, PI * 0.75, PI * 2.25, 20, Pal.ink(0.55), 1.4)
	ci.draw_line(gc, gc + Vector2.from_angle(PI * 0.75 + PI * 1.5 * force / 4500.0) * 11.0, Pal.heat(0.95, 1.4), 1.6)
	# the rollers out to the bunker, and the pucks on them
	ci.draw_line(_p(PRESS_X1 + 0.2, PRESS_Y1 + 0.05, F), _p(-1.0, PRESS_Y1 + 0.05, F), Pal.ink(0.45), 1.4)
	var rx2 := PRESS_X1 + 0.35
	while rx2 < -1.0:
		ci.draw_arc(_p(rx2, PRESS_Y1 + 0.12, F), 0.06 * M, 0.0, TAU, 8, Pal.ink(0.35), 1.0)
		rx2 += 0.32
	for pk in pucks:
		_puck(ci, Vector2(float(pk[0]) + float(pk[2]) * 0.5, PRESS_Y1 - float(pk[3]) * 0.5), float(pk[2]), float(pk[3]), F, int(pk[1] * 100.0))
	_label(ci, font, _p(PRESS_X0 - 3.2, PRESS_Y0 - 0.45, F), txt.call("sl_press_l"), zoom)
	_label(ci, font, _p(PRESS_X1 + 0.3, PRESS_Y1 + 0.5, F), txt.call("sl_out_l"), zoom)


# a pressed puck: dense, its folded layers showing as wavy lines across its face
func _puck(ci: CanvasItem, c: Vector2, w: float, h: float, F: float, seed: int) -> void:
	var r := Rect2(_p(c.x - w * 0.5, c.y - h * 0.5, F), Vector2(w, h) * M)
	ci.draw_rect(r, Color(0.23, 0.225, 0.23))
	var n := maxi(2, int(h / 0.06))
	for i in n:
		var yy := r.position.y + (i + 0.5) * r.size.y / n
		var pts := PackedVector2Array()
		for q in 7:
			var xx := r.position.x + r.size.x * q / 6.0
			pts.append(Vector2(xx, yy + 1.5 * sin(q * 2.1 + i * 1.7 + seed)))
		ci.draw_polyline(pts, Color(0.38, 0.37, 0.38), 1.0)
	ci.draw_rect(r, Pal.ink(0.6), false, 1.2)


func _draw_shredder(ci: CanvasItem, F: float, font: Font, zoom: float, txt: Callable, steel: Color, part_c: Color, part_e: Color) -> void:
	# the hopper narrowing to the cutting chamber
	var hop := PackedVector2Array([_p(3.8, 1.85, F), _p(6.2, 1.85, F), _p(5.8, 2.35, F), _p(4.2, 2.35, F)])
	ci.draw_colored_polygon(hop, Color(0.035, 0.037, 0.042))
	var hc := hop.duplicate()
	hc.append(hop[0])
	ci.draw_polyline(hc, Pal.ink(0.55), 1.4)
	_rect(ci, 4.15, 2.35, 5.85, 3.55, F, Color(0.03, 0.031, 0.036), Pal.ink(0.6), 1.6)
	# the part going in: drawn only above the bite line, the rest already in pieces
	if shred != null:
		var at := Vector2(5.0, float(shred.y))
		if float(shred.pt) < 0.6:
			at = Vector2(3.4, 1.6).lerp(Vector2(5.0, float(shred.y)), Pal.ease_io(float(shred.pt) / 0.6))
		_item(ci, shred, at, F, 1.0, 1.0, 0.0, part_c, part_e, ROT_Y)
	# the two rotors, turning toward each other, hook teeth biting down between them
	var spin := t * (2.9 if shred != null else 1.2)
	for r in [[ROT_L, 1.0], [ROT_R, -1.0]]:
		var c := _p(float(r[0]), ROT_Y, F)
		var dir: float = r[1]
		ci.draw_circle(c, ROT_RAD * 0.62 * M, Color(0.1, 0.104, 0.115))
		ci.draw_arc(c, ROT_RAD * 0.62 * M, 0.0, TAU, 20, Pal.ink(0.55), 1.2)
		for q in 6:
			var a := spin * dir + TAU * q / 6.0
			var b0 := c + Vector2.from_angle(a) * ROT_RAD * 0.6 * M
			var b1 := c + Vector2.from_angle(a + 0.25 * dir) * ROT_RAD * M
			var b2 := c + Vector2.from_angle(a + 0.55 * dir) * ROT_RAD * 0.72 * M
			ci.draw_colored_polygon(PackedVector2Array([b0, b1, b2]), Color(0.32, 0.32, 0.34))
			ci.draw_polyline(PackedVector2Array([b0, b1, b2]), Pal.ink(0.7), 1.0)
		ci.draw_circle(c, 0.07 * M, Pal.ink(0.6))
	# the drive: motors and gearboxes on the right
	_rect(ci, 5.95, 2.45, 6.75, 3.35, F, Color(0.07, 0.073, 0.082), Pal.ink(0.45), 1.2)
	ci.draw_arc(_p(6.35, 2.9, F), 0.25 * M, 0.0, TAU, 14, Pal.ink(0.4), 1.0)
	_label(ci, font, _p(3.8, 1.75, F), txt.call("sl_shred_l"), zoom)
	# chute down into the hammer mill
	ci.draw_line(_p(4.35, 3.55, F), _p(4.55, 3.75, F), Pal.ink(0.45), 1.4)
	ci.draw_line(_p(5.65, 3.55, F), _p(5.45, 3.75, F), Pal.ink(0.45), 1.4)
	# the mill: its housing, the rotor with swinging hammers, the screen underneath
	var mc := _p(MILL.x, MILL.y, F)
	ci.draw_circle(mc, MILL_R * M, Color(0.03, 0.031, 0.036))
	ci.draw_arc(mc, MILL_R * M, PI * 0.85, PI * 2.15, 28, Pal.ink(0.6), 1.6)
	var ms := t * 14.0
	for q in 4:
		var a2 := ms + TAU * q / 4.0
		var pv := mc + Vector2.from_angle(a2) * 0.22 * M
		var swing := a2 + 0.25 * sin(t * 30.0 + q)
		ci.draw_line(mc, pv, Pal.ink(0.5), 2.0)
		ci.draw_line(pv, pv + Vector2.from_angle(swing) * 0.26 * M, Color(0.35, 0.35, 0.37), 5.0)
	ci.draw_circle(mc, 0.08 * M, Pal.ink(0.6))
	# the screen: an arc of bars with gaps the powder passes
	var bars := PackedVector2Array()
	for q in 14:
		var a3 := lerpf(PI * 0.15, PI * 0.85, q / 13.0)
		bars.append_array([mc + Vector2.from_angle(a3) * (MILL_R - 0.05) * M, mc + Vector2.from_angle(a3) * (MILL_R + 0.03) * M])
	ci.draw_multiline(bars, Pal.ink(0.55), 2.0)
	_label(ci, font, _p(MILL.x + MILL_R + 0.15, MILL.y, F), txt.call("sl_mill_l"), zoom)
	# the shredded pieces, the powder
	for f in frags:
		var c2 := _p(f[0].x, f[0].y, F)
		var sz: float = f[4] * M
		var pts := PackedVector2Array()
		for q in 4:
			pts.append(c2 + Vector2.from_angle(f[2] + q * 1.7) * sz * (0.6 + 0.4 * float(q % 2)))
		ci.draw_colored_polygon(pts, Color(0.36, 0.36, 0.38))
	var dots_fe := PackedVector2Array()
	for p in fines:
		var c3 := _p(p[0].x, p[0].y, F)
		if p[2] or p[3] == 0:
			dots_fe.append(c3)
		else:
			ci.draw_circle(c3, 1.6, Color(0.85, 0.55, 0.3))
	Dock._dots(ci, dots_fe, 1.3, Color(0.55, 0.56, 0.6))
	# the magnetic drum: the magnet's arc inside it, the shell turning round it
	var dc := _p(DRUM.x, DRUM.y, F)
	ci.draw_circle(dc, DRUM_R * M, Color(0.08, 0.083, 0.095))
	ci.draw_arc(dc, DRUM_R * 0.75 * M, PI * 0.45, PI * 1.6, 14, Pal.tint(Pal.VOLT, 0.8, 1.2), 3.0)
	for q in 8:
		var a4 := -t * 2.4 + TAU * q / 8.0
		ci.draw_line(dc + Vector2.from_angle(a4) * DRUM_R * 0.85 * M, dc + Vector2.from_angle(a4) * DRUM_R * M, Pal.ink(0.5), 1.0)
	ci.draw_arc(dc, DRUM_R * M, 0.0, TAU, 20, Pal.ink(0.6), 1.4)
	_label(ci, font, _p(DRUM.x + 0.35, DRUM.y - 0.2, F), txt.call("sl_drum_l"), zoom)
	# the vibrating pan to the furnace's port, the non-ferrous bin
	ci.draw_line(_p(4.65, 5.66, F), _p(0.7, 6.06, F), Pal.ink(0.55), 2.0)
	ci.draw_line(_p(4.65, 5.74, F), _p(0.7, 6.14, F), Pal.ink(0.25), 1.0)
	_label(ci, font, _p(1.6, 5.7, F), txt.call("sl_pan_l"), zoom)
	_rect(ci, 5.5, 5.45, 6.35, 6.15, F, Color(0.04, 0.042, 0.048), Pal.ink(0.45), 1.2)
	var nf := clampf(nonferrous / 400.0, 0.0, 1.0)
	_rect(ci, 5.55, 6.1 - 0.6 * nf, 6.3, 6.1, F, Color(0.6, 0.42, 0.25, 0.75))
	_label(ci, font, _p(6.45, 5.9, F), txt.call("sl_bin_l"), zoom)


func _label(ci: CanvasItem, font: Font, at: Vector2, s: String, zoom: float) -> void:
	var a := clampf((zoom - 0.8) / 0.3, 0.0, 1.0)
	if a > 0.01:
		ci.draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.5 * a))


# the plate: what the line is doing, in numbers
func _panel(ci: CanvasItem, F: float, font: Font, font_b: Font, txt: Callable, zoom: float) -> void:
	var r := Rect2(_p(10.5, 0.95, F), Vector2(6.9, 2.4) * M)
	if zoom < 0.3:
		return
	ci.draw_rect(r, Color(0.035, 0.037, 0.042, 0.96))
	ci.draw_rect(Rect2(r.position, Vector2(4, r.size.y)), Pal.ink(0.8))
	ci.draw_rect(r, Pal.ink(0.3), false, 1.0)
	var x := r.position.x + 14.0
	var y := r.position.y + 20.0
	ci.draw_string(font_b, Vector2(x, y), txt.call("sl_title"), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24.0, 12, Pal.ink(0.92))
	var lines := [
		txt.call("sl_press") % [int(force), lerpf(0.5, PUCK_RHO, clampf(force / 4000.0, 0.0, 1.0)), pucks_made],
		txt.call("sl_shred") % [int(28 if shred != null else 12), torque, shredded],
		txt.call("sl_mill") % [1480, ferrous, nonferrous],
		txt.call("sl_queue") % [busy(), waiting_mass()],
	]
	for i in lines.size():
		ci.draw_string(font, Vector2(x, y + 21.0 + i * 18.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24.0, 12, Pal.ink(0.66))
