extends Control
# P.6 (player 2026-10-17: "I can't see the whole ship; hauling something big I
# can't see the mouth I'm going to"): a map of the berth that stays on screen,
# bottom right. The ship as it stands (rooms nobody has opened stay dark
# blocks), what is loose, the three mouths where they sit on their rails, the
# drone, what it hauls and the line to where that goes, and the frame of the
# view. The ship layer is redrawn only when the ship changes; the rest a few
# times a second.

const W := 330.0
const PAD := 8.0
const SHIP_EVERY := 0.5       # s between checks that the ship changed
const LIVE_EVERY := 1.0 / 20.0

var game
var ship_layer: Control
var live_layer: Control
var origin := Vector2.ZERO    # m: the map's top left in the berth
var scale_m := 1.0            # px per m
var map_size := Vector2(W, 120.0)
var _cache := {}              # piece id (or "room:name") -> {h, s, pts, tri, col}
var _pts := PackedVector2Array()
var _cols := PackedColorArray()
var _idx := PackedInt32Array()
var _ship_sig := []
var _ship_t := 99.0
var _live_t := 99.0
var t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ship_layer = Control.new()
	ship_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ship_layer.draw.connect(_draw_ship)
	add_child(ship_layer)
	live_layer = Control.new()
	live_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	live_layer.draw.connect(_draw_live)
	add_child(live_layer)


# the berth's frame in metres, and the scale that fits it to the map's width
func layout() -> void:
	# from just over the boom down to the floor: nothing works above the boom
	var top := Dock.RAIL_Y - 1.4
	var r := Rect2(Dock.TOWER_X - 1.0, top, Dock.FLOOR_X1 - Dock.TOWER_X + 3.0, Dock.FLOOR_Y + 1.0 - top)
	origin = r.position
	scale_m = (W - PAD * 2.0) / r.size.x
	map_size = Vector2(W, r.size.y * scale_m + PAD * 2.0)
	size = map_size
	ship_layer.size = map_size
	live_layer.size = map_size


func to_map(w: Vector2) -> Vector2:
	return (w / Geom.M - origin) * scale_m + Vector2(PAD, PAD)


func _process(dt: float) -> void:
	t += dt
	if game == null or game.world == null:
		return
	_ship_t += dt
	if _ship_t >= SHIP_EVERY:
		_ship_t = 0.0
		var w = game.world
		var sig := [w.pieces.size(), w.bodies.size(), Dock.FLOOR_X1]
		var gone := 0
		var shown := 0
		for id in w.pieces:
			var p = w.pieces[id]
			if p.gone:
				gone += 1
		for n in w.rooms:
			if w.rooms[n].revealed:
				shown += 1
		sig.append_array([gone, shown])
		if sig != _ship_sig:
			_ship_sig = sig
			_rebuild_ship()
	_live_t += dt
	if _live_t >= LIVE_EVERY:
		_live_t = 0.0
		live_layer.queue_redraw()


func _rebuild_ship() -> void:
	layout()
	var w = game.world
	var keep := {}
	var parts: Array = []
	for n in w.rooms:
		var r: Dictionary = w.rooms[n]
		if not r.revealed:
			parts.append(_part("room:" + n, r.poly, Color(0.11, 0.115, 0.13, 0.95), keep))
	for id in w.pieces:
		var p = w.pieces[id]
		if p.gone or p.body != null or w.room_hidden(p.room):
			continue
		var col := Pal.ink(0.2)
		if p.cls == "equip" and p.intact:
			col = Pal.ink(0.55)
		elif p.kind in ["keel", "beam", "rail"]:
			col = Pal.ink(0.32)
		parts.append(_part(id, w.world_poly(p), col, keep))
	_cache = keep
	# one triangle list for the lot: a single draw call, triangulated once per piece
	_pts = PackedVector2Array()
	_cols = PackedColorArray()
	_idx = PackedInt32Array()
	for e in parts:
		if e.tri.is_empty():
			continue
		var base := _pts.size()
		_pts.append_array(e.pts)
		for i in e.pts.size():
			_cols.append(e.col)
		for i in e.tri:
			_idx.append(base + i)
	ship_layer.queue_redraw()


# a piece (or a dark room) in map px, triangulated; reused while it hasn't changed
func _part(key, poly: PackedVector2Array, col: Color, keep: Dictionary) -> Dictionary:
	var h := hash(poly)
	var e: Dictionary = _cache.get(key, {})
	if e.is_empty() or e.h != h or e.s != scale_m:
		var mp := Geom.simplify(_map_poly(poly), 0.5)
		if mp.size() < 3:
			mp = _map_poly(poly)
		e = {"h": h, "s": scale_m, "pts": mp, "tri": Geometry2D.triangulate_polygon(mp), "col": col}
	e.col = col
	keep[key] = e
	return e


func _map_poly(poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(poly.size())
	for i in poly.size():
		out[i] = to_map(poly[i])
	return out


func _draw_ship() -> void:
	ship_layer.draw_rect(Rect2(Vector2.ZERO, map_size), Color(0.018, 0.02, 0.024, 0.97))
	UI.panel(ship_layer, Rect2(Vector2.ZERO, map_size), 0.9)
	# the berth: floor, boom and rail, trough
	var fl0 := to_map(Vector2(Dock.TOWER_X, Dock.FLOOR_Y) * Geom.M)
	var fl1 := to_map(Vector2(Dock.FLOOR_X1, Dock.FLOOR_Y) * Geom.M)
	ship_layer.draw_line(fl0, fl1, Pal.ink(0.35), 1.4)
	ship_layer.draw_line(to_map(Vector2(Dock.TOWER_X, Dock.RAIL_Y) * Geom.M), to_map(Vector2(Dock.equip_rail_x1() + 2.6, Dock.RAIL_Y) * Geom.M), Pal.ink(0.3), 1.2)
	ship_layer.draw_line(to_map(Vector2(Dock.TOWER_X + 0.3, -12.6) * Geom.M), fl0, Pal.ink(0.3), 1.4)
	var tr0 := to_map(Vector2(Dock.TROUGH_X0, Dock.TROUGH_Y) * Geom.M)
	var tr1 := to_map(Vector2(Dock.TROUGH_X1, Dock.TROUGH_Y) * Geom.M)
	ship_layer.draw_line(tr0, tr1, Pal.heat(0.3, 1.1), 1.0)
	if not _idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(ship_layer.get_canvas_item(), _idx, _pts, _cols)


func _draw_live() -> void:
	if game == null or game.world == null:
		return
	var ci := live_layer
	var w = game.world
	var tl = game.tools
	# loose bodies, live
	for b in w.bodies:
		if not is_instance_valid(b):
			continue
		var held: bool = tl != null and tl.held_body == b
		var col := Pal.ink(0.75)
		if held:
			col = Dock.zone_col(game.hud._zone_for(b), 1.0, 1.3)
		for p in b.pieces:
			var mp := _map_poly(w.world_poly(p))
			if mp.size() >= 3:
				ci.draw_colored_polygon(mp, Color(col.r, col.g, col.b, 0.5 if held else 0.35))
				if held:
					var ol := mp.duplicate()
					ol.append(mp[0])
					ci.draw_polyline(ol, col, 1.2, true)
	# the mouths where they sit
	for id in Dock.ZONES:
		var mp := to_map(Dock.zpos(id))
		var f: Vector2 = Dock.ZONES[id].face
		var side := Vector2(-f.y, f.x)
		var hw: float = Dock.ZONES[id].w * 0.5 * scale_m + 2.0
		var col := Dock.zone_col(id, 0.95, 1.2)
		ci.draw_colored_polygon(PackedVector2Array([mp + side * hw, mp - side * hw, mp - side * hw * 0.5 - f * 5.0, mp + side * hw * 0.5 - f * 5.0]), col)
	# what is hauled: a line to where it goes
	if tl != null and tl.held_body != null and is_instance_valid(tl.held_body) and not tl.overweight:
		var zone: String = game.hud._zone_for(tl.held_body)
		var from := to_map(tl.held_body.global_transform * tl.held_body.center_of_mass)
		var to := to_map(Dock.zpos(zone))
		var col := Dock.zone_col(zone, 0.9, 1.3)
		var n := int(from.distance_to(to) / 6.0)
		var ph := fposmod(t * 2.0, 1.0)
		for i in n:
			if i % 2 == 0:
				var a := from.lerp(to, (i + ph) / maxf(1.0, n))
				var b2 := from.lerp(to, minf(1.0, (i + 1 + ph) / maxf(1.0, n)))
				ci.draw_line(a, b2, col, 1.8)
		ci.draw_arc(to, 6.0 + 2.0 * sin(t * 6.0), 0.0, TAU, 16, col, 1.6, true)
	# the view
	var vs: Vector2 = get_viewport_rect().size
	var cam = game.cam
	if cam != null and cam.zoom.x > 0.0:
		var half: Vector2 = vs * 0.5 / cam.zoom.x
		var r := Rect2(to_map(cam.global_position - half), (half * 2.0) / Geom.M * scale_m)
		r = r.intersection(Rect2(Vector2(1, 1), map_size - Vector2(2, 2)))
		if r.has_area():
			ci.draw_rect(r, Pal.ink(0.4), false, 1.0)
	# the drone
	if game.drone != null:
		var dp := to_map(game.drone.global_position)
		var pulse := 0.5 + 0.5 * sin(t * 5.0)
		ci.draw_circle(dp, 5.0 + 2.0 * pulse, Pal.tint(Pal.AIR, 0.18 * (1.0 - pulse), 1.2))
		ci.draw_circle(dp, 2.8, Pal.tint(Pal.AIR, 1.0, 1.4))
	ci.draw_string(game.hud.font, Vector2(18.0, map_size.y - 18.0), game.txt("minimap"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.45))
