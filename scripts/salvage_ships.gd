extends Node2D
# Where the recovered goods go (player 2026-10-20: "the mouths aren't just holes:
# behind them there has to be a ship; the player has to see what was recovered").
# Two vessels lie alongside the berth for the length of a contract (Jev A 0.53 / 0.30):
#   RT-07 "Albatross", an equipment freighter docked over the boom: a whole item
#   taken at an equipment bay rides the bay's lift up through the boom, a shuttle
#   runs it along the boom to the transfer tunnel, and it goes up into a rack slot
#   in the freighter's hold, its outline, tag and value on the slot;
#   HB-03, a barge under the furnace plant: casks from the hazard bay come down a
#   sealed transfer tube into its shielded hold (each made safe its own way:
#   vented and inerted, discharged, drained), and the ingots off the casting line
#   come down the ingot lift into its other hold, stacked; the non-ferrous bin and
#   the debris bales are on its manifest too.
# When the contract is settled and the hull is towed out, both cast off for the
# market (Jev A 0.72 / 0.58). Only picture: what they carry was paid for at the
# mouths. Drawn in the dock's space (px), only while in view.

const M := 48.0
const SLOT := Vector2(2.6, 1.9)      # m: a rack slot in the freighter's hold

var dock
var game
var t := 0.0
var equip: Array = []       # {polys, tag, value, t (s since it arrived), state}
var hazard: Array = []      # {tag, kind, value, t, state}
var shuttles: Array = []    # equipment on its way: {item, x0 (m), t}
var casks: Array = []       # hazard on its way down the tube: {item, t}
var lift_t := -1.0          # the ingot lift's car: < 0 idle, else 0..1 down
var _ingots_seen := -1
var leave := 0.0            # 0 docked .. 1 gone (when the hull is towed out)
var cv = null               # the batch this frame is drawn into (canvas_batch.gd)


func _init() -> void:
	z_index = 0


# ---------------------------------------------------------------- arrivals

static func outline(b, world) -> Array:
	var com: Vector2 = b.global_transform * b.center_of_mass
	var polys: Array = []
	for p in b.pieces:
		var pp := PackedVector2Array()
		for q in world.world_poly(p):
			pp.append((q - com) / Geom.M)
		polys.append(pp)
	return polys


func add_equip(b, value: float, from_x: float) -> void:
	var tags: Array = []
	for p in b.pieces:
		if p.tag != "" and p.cls == "equip":
			tags.append(p.tag)
	var it := {"polys": outline(b, game.world), "tag": ", ".join(tags) if not tags.is_empty() else "—", "value": value, "t": 0.0}
	shuttles.append({"item": it, "x0": from_x, "t": 0.0})


func add_hazard(b, value: float) -> void:
	var kind := ""
	var tags: Array = []
	for p in b.pieces:
		if p.hazard != "" and kind == "":
			kind = p.hazard
		if p.tag != "":
			tags.append(p.tag)
	if kind == "":
		kind = "fluid"
	var it := {"tag": ", ".join(tags) if not tags.is_empty() else "—", "kind": kind, "value": value, "t": 0.0}
	casks.append({"item": it, "t": 0.0})


# what this hazard is made safe by, in the shielded hold
static func treatment(kind: String) -> String:
	match kind:
		"gas_tank":
			return "hz_vent"
		"fuel_tank":
			return "hz_drain"
		"cap", "battery":
			return "hz_discharge"
		"gen":
			return "hz_lockout"
		"rad":
			return "hz_shield"
	return "hz_seal"


static func cask_col(kind: String) -> Color:
	match kind:
		"gas_tank":
			return Pal.AIR
		"fuel_tank":
			return Pal.HEAT
		"cap", "battery", "gen":
			return Pal.VOLT
		"rad":
			return Color(0.95, 0.85, 0.2)
	return Pal.FLUID


# ---------------------------------------------------------------- geometry (m)

# the freighter's hull box over the boom
func ship_rect() -> Rect2:
	var y1 := Dock.RAIL_Y - 4.0
	return Rect2(4.0, y1 - 8.5, 38.0, 8.5)


func tunnel_x() -> float:
	return 14.0


func hold_rect() -> Rect2:
	var r := ship_rect()
	return Rect2(r.position.x + 7.5, r.position.y + 1.2, 24.0, r.size.y - 2.2)


func slot_pos(i: int) -> Vector2:
	var h := hold_rect()
	var cols := int(h.size.x / SLOT.x)
	var c := i % cols
	var r := (i / cols) % 3
	return h.position + Vector2((c + 0.5) * SLOT.x, (r + 0.5) * SLOT.y)


func barge_rect() -> Rect2:
	var X: float = dock.furnace_x
	var y0 := Dock.FLOOR_Y + 12.5
	return Rect2(X - 14.0, y0, 38.0, 6.5)


# the shielded hold, at the barge's stern
func hazard_hold() -> Rect2:
	var r := barge_rect()
	return Rect2(Vector2(r.end.x - 9.5, r.position.y + 0.8), Vector2(8.0, 3.8))


# the sealed tube: down from the hazard bay, along under the plant, down into the hold (m)
func tube_path() -> PackedVector2Array:
	var hz: Vector2 = Dock.ZONES.hazard.pos
	var hh := hazard_hold()
	var yb := barge_rect().position.y - 1.6
	return PackedVector2Array([Vector2(hz.x, Dock.FLOOR_Y + 0.6), Vector2(hz.x, yb), Vector2(hh.get_center().x, yb), Vector2(hh.get_center().x, hh.position.y + 0.4)])


static func along(path: PackedVector2Array, u: float) -> Vector2:
	var L := 0.0
	for i in path.size() - 1:
		L += path[i].distance_to(path[i + 1])
	var d := u * L
	for i in path.size() - 1:
		var l := path[i].distance_to(path[i + 1])
		if d <= l:
			return path[i].lerp(path[i + 1], d / maxf(l, 0.001))
		d -= l
	return path[-1]


func ingot_lift_x() -> float:
	return dock.furnace_x + 11.25


# ---------------------------------------------------------------- per frame

func step(dt: float) -> void:
	t += dt
	if game != null and game.state == "towout":
		leave = minf(1.0, leave + dt / 6.0)
	for it in equip:
		it.t += dt
	for it in hazard:
		it.t += dt
	# equipment: up the bay's lift (1.2 s), along the boom (at 6 m/s), up the tunnel (1 s)
	for s in shuttles.duplicate():
		s.t += dt
		var run: float = absf(tunnel_x() - float(s.x0)) / 6.0
		if s.t >= 1.2 + run + 1.0:
			shuttles.erase(s)
			equip.append(s.item)
			if game != null:
				game.sfx.play("clamp", Vector2(tunnel_x(), Dock.RAIL_Y - 4.0) * M, 0.4)
	for c in casks.duplicate():
		c.t += dt
		if c.t >= 3.0:
			casks.erase(c)
			hazard.append(c.item)
	# the ingot lift: a car down every time an ingot comes off the casting line
	var shipped: int = dock.smelter.shipped
	if _ingots_seen < 0:
		_ingots_seen = shipped
	if shipped > _ingots_seen and lift_t < 0.0:
		_ingots_seen += 1
		lift_t = 0.0
	if lift_t >= 0.0:
		lift_t += dt / 1.6
		if lift_t >= 1.0:
			lift_t = -1.0
	if dock.draw_now and _seen():
		queue_redraw()


func _seen() -> bool:
	var vp := get_viewport()
	if vp == null:
		return true
	var inv := get_global_transform_with_canvas().affine_inverse()
	var r := vp.get_visible_rect()
	var a: Vector2 = inv * r.position
	var b: Vector2 = inv * r.end
	var view := Rect2(a, b - a).abs()
	var sr := ship_rect()
	var br := barge_rect()
	return view.intersects(Rect2(sr.position * M, sr.size * M).grow(400.0)) or view.intersects(Rect2(br.position * M, br.size * M).grow(400.0)) or view.intersects(Rect2(Vector2(Dock.TOWER_X, Dock.RAIL_Y - 1.0) * M, Vector2(Dock.FLOOR_X1 - Dock.TOWER_X, 1.0) * M))


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if dock == null or dock.furnace_x == -INF:
		return
	cv = preload("res://scripts/canvas_batch.gd").new(self)
	_draw_body()
	cv.flush()


func _draw_body() -> void:
	var font: Font = dock.font
	var font_b: Font = dock.font_b
	var z: float = game.cam_zoom() if game != null else 1.0
	if z < 0.55:
		# far out: the two hulls' outlines
		var sr := ship_rect()
		var br := barge_rect()
		cv.draw_set_transform(Vector2(-40.0, -60.0) * Pal.ease_in(leave) * M)
		_rect(sr, Color(0.045, 0.048, 0.056), Pal.ink(0.5), 1.2)
		cv.draw_set_transform(Vector2(30.0, 50.0) * Pal.ease_in(leave) * M)
		_rect(br, Color(0.045, 0.048, 0.056), Pal.ink(0.5), 1.2)
		cv.draw_set_transform(Vector2.ZERO)
		return
	_draw_routes(font, z)
	var up := Vector2(-40.0, -60.0) * Pal.ease_in(leave)
	cv.draw_set_transform(up * M)
	_draw_freighter(font, font_b, z)
	cv.draw_set_transform(Vector2(30.0, 50.0) * Pal.ease_in(leave) * M)
	_draw_barge(font, font_b, z)
	cv.draw_set_transform(Vector2.ZERO)


func _rect(r: Rect2, fill_c: Color, edge: Color = Color(0, 0, 0, 0), w: float = 1.0) -> void:
	var rr := Rect2(r.position * M, r.size * M)
	cv.draw_rect(rr, fill_c)
	if edge.a > 0.0:
		cv.draw_rect(rr, edge, false, w)


func _lbl(at: Vector2, s: String, z: float, col: Color = Pal.ink(0.55), size: int = 11) -> void:
	var a := clampf((z - 0.5) / 0.3, 0.0, 1.0)
	if a > 0.01:
		cv.draw_string(dock.font, at * M, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col.r, col.g, col.b, col.a * a))


# an item's outline fitted into a box (m), centred on c
func _fit(polys: Array, c: Vector2, box: Vector2, col: Color, edge: Color) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in polys:
		for q in p:
			lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
			hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	if lo.x == INF:
		return
	var sz := hi - lo
	var s := minf(box.x / maxf(sz.x, 0.01), box.y / maxf(sz.y, 0.01))
	var mid := (lo + hi) * 0.5
	for p in polys:
		var pts := PackedVector2Array()
		for q in p:
			pts.append((c + (q - mid) * s) * M)
		if pts.size() >= 3 and not Geometry2D.triangulate_polygon(pts).is_empty():
			cv.draw_colored_polygon(pts, col)
			pts.append(pts[0])
			cv.draw_polyline(pts, edge, 1.0)


# the paths things take: the shuttle track on the boom, the tunnel, the hazard tube, the ingot lift
func _draw_routes(font: Font, z: float) -> void:
	var R := Dock.RAIL_Y
	var F := Dock.FLOOR_Y
	var tx := tunnel_x()
	# the shuttle track along the top of the boom
	var x0 := Dock.TOWER_X + 1.0
	var x1 := maxf(Dock.ARM_X1, Dock.equip_rail_x1())
	cv.draw_line(Vector2(x0, R - 0.75) * M, Vector2(x1, R - 0.75) * M, Pal.ink(0.4), 1.4)
	cv.draw_line(Vector2(x0, R - 0.68) * M, Vector2(x1, R - 0.68) * M, Pal.ink(0.2), 1.0)
	# the transfer tunnel up to the freighter's belly (folds away when it casts off)
	var tun := 1.0 - Pal.ease_io(clampf(leave * 4.0, 0.0, 1.0))
	if tun > 0.01:
		var top := R - 0.75 - 3.25 * tun
		_rect(Rect2(tx - 0.8, top, 1.6, R - 0.75 - top), Color(0.05, 0.053, 0.06, 0.95), Pal.ink(0.5), 1.2)
		var y := top + 0.3
		while y < R - 0.9:
			cv.draw_line(Vector2(tx - 0.8, y) * M, Vector2(tx + 0.8, y) * M, Pal.ink(0.15), 1.0)
			y += 0.5
		_lbl(Vector2(tx + 1.0, R - 2.4), Txt.t("sh_tunnel"), z)
	# equipment on its way: up the lift from the bay, along the boom, up the tunnel
	for s in shuttles:
		var tt: float = s.t
		var run: float = absf(tx - float(s.x0)) / 6.0
		var p := Vector2.ZERO
		if tt < 1.2:
			p = Vector2(s.x0, lerpf(R + 1.6, R - 1.3, Pal.ease_io(tt / 1.2)))
		elif tt < 1.2 + run:
			p = Vector2(lerpf(s.x0, tx, Pal.ease_io((tt - 1.2) / maxf(run, 0.01))), R - 1.3)
		else:
			p = Vector2(tx, lerpf(R - 1.3, R - 4.6, Pal.ease_io((tt - 1.2 - run) / 1.0)))
		_rect(Rect2(p + Vector2(-0.9, 0.35), Vector2(1.8, 0.25)), Color(0.1, 0.104, 0.115), Pal.ink(0.6), 1.0)
		_fit(s.item.polys, p, Vector2(1.6, 0.9), Color(0.16, 0.17, 0.19), Pal.ink(0.75))
	# the hazard bay's sealed transfer tube down to the barge's shielded hold
	var hz: Vector2 = Dock.ZONES.hazard.pos
	if leave < 0.05:
		var tp := tube_path()
		var pts := PackedVector2Array()
		for q in tp:
			pts.append(q * M)
		cv.draw_polyline(pts, Pal.tint(Pal.FLUID, 0.6), 0.9 * M)
		cv.draw_polyline(pts, Color(0.05, 0.06, 0.055), 0.7 * M)
		cv.draw_polyline(pts, Pal.tint(Pal.FLUID, 0.25), 1.0)
		_lbl(tp[0] + Vector2(0.7, 2.0), Txt.t("sh_tube"), z)
		for c in casks:
			var u: float = clampf(float(c.t) / 3.0, 0.0, 1.0)
			_cask(along(tp, Pal.ease_io(u)), c.item.kind, 0.3)
	# the ingot lift from the casting line's end down to the barge
	var lx := ingot_lift_x()
	if leave < 0.05:
		var ly0 := F + 2.65 + 6.0
		var ly1 := barge_rect().position.y + 0.8
		cv.draw_line(Vector2(lx - 0.35, ly0) * M, Vector2(lx - 0.35, ly1) * M, Pal.ink(0.35), 1.4)
		cv.draw_line(Vector2(lx + 0.35, ly0) * M, Vector2(lx + 0.35, ly1) * M, Pal.ink(0.35), 1.4)
		var cy2 := lerpf(ly0, ly1, Pal.ease_io(lift_t)) if lift_t >= 0.0 else ly0
		_rect(Rect2(lx - 0.33, cy2 - 0.1, 0.66, 0.12), Color(0.12, 0.125, 0.14), Pal.ink(0.6), 1.0)
		if lift_t >= 0.0:
			_rect(Rect2(lx - 0.24, cy2 - 0.32, 0.48, 0.22), Color(0.22, 0.2, 0.2))
		_lbl(Vector2(lx + 0.5, ly0 + 1.5), Txt.t("sh_lift"), z)


func _cask(c: Vector2, kind: String, r: float) -> void:
	var col := cask_col(kind)
	_rect(Rect2(c - Vector2(r, r * 1.5), Vector2(r * 2.0, r * 3.0)), Color(0.08, 0.085, 0.09), Pal.tint(col, 0.85, 1.1), 1.4)
	cv.draw_line((c - Vector2(r, r * 0.6)) * M, (c + Vector2(r, -r * 0.6)) * M, Pal.tint(col, 0.6), 2.0)
	cv.draw_line((c - Vector2(r, -r * 0.6)) * M, (c + Vector2(r, r * 0.6)) * M, Pal.tint(col, 0.6), 2.0)
	cv.draw_circle(c * M, r * 0.35 * M, Pal.tint(col, 0.9, 1.3))


func _draw_freighter(font: Font, font_b: Font, z: float) -> void:
	var r := ship_rect()
	var x0 := r.position.x
	var x1 := r.end.x
	var y0 := r.position.y
	var y1 := r.end.y
	# the hull: bow to the left, engines aft
	var hull := PackedVector2Array([Vector2(x0 + 4.0, y0), Vector2(x1 - 5.0, y0), Vector2(x1 - 3.0, y0 + 1.2), Vector2(x1 - 3.0, y1 - 1.2), Vector2(x1 - 5.0, y1),
		Vector2(x0 + 4.0, y1), Vector2(x0, y1 - 2.5), Vector2(x0, y0 + 2.5)])
	var hp := PackedVector2Array()
	for q in hull:
		hp.append(q * M)
	cv.draw_colored_polygon(hp, Color(0.045, 0.048, 0.056))
	hp.append(hp[0])
	cv.draw_polyline(hp, Pal.ink(0.6), 1.6)
	# the bridge's windows, the frames, the engines and their bells
	for i in 4:
		_rect(Rect2(Vector2(x0 + 1.0 + i * 0.6, y0 + 2.6), Vector2(0.4, 0.5)), Pal.tint(Pal.AIR, 0.35 + 0.15 * sin(t + i), 1.2))
	var fx := x0 + 4.0
	while fx < x1 - 5.0:
		cv.draw_line(Vector2(fx, y0) * M, Vector2(fx, y1) * M, Pal.ink(0.1), 1.0)
		fx += 3.0
	for e in 3:
		var ey := y0 + 1.8 + e * 2.4
		var bell := PackedVector2Array([Vector2(x1 - 3.0, ey - 0.5) * M, Vector2(x1 - 1.0, ey - 0.9) * M, Vector2(x1 - 1.0, ey + 0.9) * M, Vector2(x1 - 3.0, ey + 0.5) * M])
		cv.draw_colored_polygon(bell, Color(0.08, 0.083, 0.095))
		bell.append(bell[0])
		cv.draw_polyline(bell, Pal.ink(0.5), 1.2)
		if leave > 0.0:
			cv.draw_colored_polygon(PackedVector2Array([Vector2(x1 - 1.0, ey - 0.7) * M, Vector2(x1 + 3.0 + 6.0 * leave, ey) * M, Vector2(x1 - 1.0, ey + 0.7) * M]), Pal.heat(0.8, 1.8))
	# the hold, cut away: racks of slots, each item stored with its outline, tag and value
	var h := hold_rect()
	_rect(h, Color(0.025, 0.027, 0.032), Pal.ink(0.4), 1.2)
	var cols := int(h.size.x / SLOT.x)
	for c in cols + 1:
		cv.draw_line(Vector2(h.position.x + c * SLOT.x, h.position.y) * M, Vector2(h.position.x + c * SLOT.x, h.end.y) * M, Pal.ink(0.12), 1.0)
	for rr in 5:
		var ry := h.position.y + rr * SLOT.y
		if ry <= h.end.y + 0.01:
			cv.draw_line(Vector2(h.position.x, ry) * M, Vector2(h.end.x, ry) * M, Pal.ink(0.2), 1.2)
	var shown := mini(equip.size(), cols * 4)
	var total := 0.0
	for it in equip:
		total += float(it.value)
	for i in shown:
		var it: Dictionary = equip[equip.size() - shown + i]
		var c := slot_pos(i)
		var fresh := clampf(1.0 - float(it.t) / 1.5, 0.0, 1.0)
		if fresh > 0.0:
			_rect(Rect2(c - SLOT * 0.5, SLOT), Pal.tint(Pal.FLUID, 0.18 * fresh, 1.3))
		_fit(it.polys, c - Vector2(0, 0.15), SLOT * Vector2(0.8, 0.55), Color(0.14, 0.15, 0.17), Pal.ink(0.75))
		if z > 0.7:
			cv.draw_string(font, (c + Vector2(-SLOT.x * 0.45, SLOT.y * 0.42)) * M, str(it.tag), HORIZONTAL_ALIGNMENT_LEFT, SLOT.x * 0.9 * M, 11, Pal.ink(0.75))
			cv.draw_string(font, (c + Vector2(-SLOT.x * 0.45, -SLOT.y * 0.28)) * M, Pal.money(float(it.value)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.tint(Pal.FLUID, 0.85, 1.1))
	# the manifest, painted beside the hold
	cv.draw_string(font_b, Vector2(x0 + 4.4, y0 + 1.0) * M, "RT-07 · " + Txt.t("sh_freighter"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.ink(0.9))
	cv.draw_string(font, Vector2(h.position.x, y1 - 0.3) * M, Txt.t("sh_manifest_e") % [equip.size(), Pal.money(total)], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.tint(Pal.FLUID, 0.9, 1.1))
	# docking clamps onto the boom
	if leave < 0.02:
		for cx in [x0 + 6.0, x1 - 8.0]:
			cv.draw_line(Vector2(cx, y1) * M, Vector2(cx, Dock.RAIL_Y - 0.6) * M, Pal.ink(0.45), 3.0)


func _draw_barge(font: Font, font_b: Font, z: float) -> void:
	var r := barge_rect()
	var X: float = dock.furnace_x
	var hp := PackedVector2Array([r.position * M, Vector2(r.end.x - 2.0, r.position.y) * M, Vector2(r.end.x, r.position.y + 2.0) * M,
		Vector2(r.end.x, r.end.y) * M, Vector2(r.position.x + 2.0, r.end.y) * M, Vector2(r.position.x, r.end.y - 2.0) * M])
	cv.draw_colored_polygon(hp, Color(0.045, 0.048, 0.056))
	hp.append(hp[0])
	cv.draw_polyline(hp, Pal.ink(0.6), 1.6)
	cv.draw_string(font_b, (r.position + Vector2(1.0, r.size.y - 0.6)) * M, "HB-03 · " + Txt.t("sh_barge"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.ink(0.9))
	# the ingot hold: stacks growing from under the lift
	var ih := Rect2(Vector2(r.position.x + 1.5, r.position.y + 0.8), Vector2(ingot_lift_x() + 1.5 - r.position.x - 1.5, 3.8))
	_rect(ih, Color(0.025, 0.027, 0.032), Pal.ink(0.4), 1.2)
	var n: int = dock.smelter.shipped
	var per_row := maxi(1, int(ih.size.x / 0.55))
	var rows := mini(int(ceil(float(n) / per_row)), 12)
	var bars := PackedVector2Array()
	for i in mini(n, per_row * 12):
		var c := i % per_row
		var row := i / per_row
		var bx := ih.end.x - 0.4 - c * 0.55
		var by := ih.end.y - 0.15 - row * 0.3
		bars.append_array([Vector2(bx - 0.24, by) * M, Vector2(bx + 0.24, by) * M])
	if not bars.is_empty():
		cv.draw_multiline(bars, Color(0.32, 0.31, 0.32), 0.22 * M)
	cv.draw_string(font, (ih.position + Vector2(0.3, 0.6)) * M, Txt.t("sh_ingots") % [n, dock.smelter.shipped_t], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.8))
	# the shielded hazard hold: thick walls, hazard stripes, one cask per thing, made safe
	var hz: Vector2 = Dock.ZONES.hazard.pos
	var hh := hazard_hold()
	_rect(hh.grow(0.2), Color(0.07, 0.08, 0.07), Pal.tint(Pal.FLUID, 0.7), 1.6)
	_rect(hh, Color(0.02, 0.026, 0.024))
	var sx := hh.position.x
	while sx < hh.end.x:
		cv.draw_line(Vector2(sx, hh.position.y - 0.2) * M, Vector2(minf(sx + 0.3, hh.end.x), hh.position.y) * M, Pal.tint(Pal.FLUID, 0.5), 2.0)
		sx += 0.6
	var per := maxi(1, int(hh.size.x / 0.9))
	for i in mini(hazard.size(), per * 2):
		var it: Dictionary = hazard[i]
		var c := Vector2(hh.position.x + 0.5 + (i % per) * 0.9, hh.end.y - 0.7 - (i / per) * 1.7)
		_cask(c, it.kind, 0.3)
		if z > 0.7:
			cv.draw_string(font, (c + Vector2(-0.4, -0.65)) * M, str(it.tag), HORIZONTAL_ALIGNMENT_LEFT, 0.85 * M, 8, Pal.ink(0.7))
			var done := float(it.t) > 4.0
			cv.draw_string(font, (c + Vector2(-0.4, 0.75)) * M, Txt.t(treatment(it.kind)) if done else "…", HORIZONTAL_ALIGNMENT_LEFT, 0.85 * M, 8, Pal.tint(Pal.FLUID, 0.85, 1.1) if done else Pal.heat(0.8, 1.2))
	cv.draw_string(font, (hh.position + Vector2(0.3, 0.55)) * M, Txt.t("sh_hazards") % hazard.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.tint(Pal.FLUID, 0.9, 1.1))
	# the rest of the manifest: non-ferrous, debris bales
	var nf: float = dock.scrapline.nonferrous
	cv.draw_string(font, (Vector2(r.position.x + 1.5, r.position.y + 5.3)) * M, Txt.t("sh_manifest_b") % [n, dock.smelter.shipped_t, hazard.size(), nf, dock.net_bales], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.7))
	# moored to the plant's base frame
	if leave < 0.02:
		for mx in [X - 10.0, X + 6.0]:
			cv.draw_line(Vector2(mx, Dock.FLOOR_Y + 10.6) * M, Vector2(mx, r.position.y) * M, Pal.ink(0.4), 2.0)
	if leave > 0.0:
		for e in 2:
			var ey := r.position.y + 1.5 + e * 3.0
			cv.draw_colored_polygon(PackedVector2Array([Vector2(r.position.x, ey - 0.5) * M, Vector2(r.position.x - 3.0 - 6.0 * leave, ey) * M, Vector2(r.position.x, ey + 0.5) * M]), Pal.heat(0.8, 1.8))
