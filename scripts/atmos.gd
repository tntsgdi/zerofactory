class_name Atmos
extends Node
# Air that isn't plain air (R2 fleet, HB-86 "Haven Cove": "the culture halls'
# oxygen-rich air must be recovered hall by hall before the glass and the shutters
# are opened"). A ship file's "atmos" section: {"o2": {room: fraction}}; the
# oxygen itself moves with the gas (scripts/systems.gd: o2), so an open door mixes
# two halls and a hose takes it out with the air.
#   The beam cutting into anything beside a room still holding air (over 20 kPa)
#   richer than FIRE_O2 flashes over: a fire through that room, its equipment
#   scorched (the fragile worst), the drone burnt if it is close; the fire uses the
#   oxygen up (the room's air goes back to plain air).
#   An "o2" probe reads a room's oxygen fraction.
#   "glass": [tags] precision glazing: the beam working within GLASS_NEAR of a pane
#   heats it and it crazes (most of its value gone); unbolt it, don't cut by it.
# Saved: the oxygen in each room's air.

const FIRE_O2 := 0.35
const FIRE_P := 20.0
const NEAR := 0.9             # m round the cut that count as "beside"
const COOL := 6.0             # s before the same room can flash again
const GLASS_NEAR := 0.7       # m

var game
var world
var cfg := {}
var _last := {}               # room -> time it last flashed


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("atmos", {})


func active() -> bool:
	return not cfg.is_empty()


# the oxygen fraction over which a cut beside the room flashes it over ("fire_o2" in the ship file)
func fire_o2() -> float:
	return float(cfg.get("fire_o2", FIRE_O2))


func save_state() -> Dictionary:
	return {"o2": game.sys.o2.duplicate()}


func load_state(d: Dictionary) -> void:
	if d.has("o2"):
		game.sys.o2 = (d.o2 as Dictionary).duplicate()


# the rooms round a point (the cut may sit in the wall between two)
func _rooms_near(pos: Vector2) -> Array:
	var out: Array = []
	for i in 9:
		var q := pos if i == 0 else pos + Vector2.from_angle(TAU * i / 8.0) * NEAR * Geom.M
		var r: String = world.room_at(q)
		if r != "" and not out.has(r):
			out.append(r)
	return out


func on_cut(p, pos: Vector2) -> void:
	if not active():
		return
	_glass(p, pos)
	var s = game.sys
	for r in _rooms_near(pos):
		if s.P(r) < FIRE_P or s.o2_frac(r) < fire_o2():
			continue
		if s.time - float(_last.get(r, -99.0)) < COOL:
			continue
		_last[r] = s.time
		_flash(r, pos)


func _glass(p, pos: Vector2) -> void:
	for t in cfg.get("glass", []):
		var g = world.tag(str(t))
		if g == null or g.gone or not g.intact or g.cond < 0.3:
			continue
		var gp: PackedVector2Array = world.frame(g) * g.poly
		var d := 0.0 if Geometry2D.is_point_in_polygon(pos, gp) else Geom.dist_to_boundary(pos, gp)
		if d > GLASS_NEAR * Geom.M:
			continue
		game._dent(g, minf(g.cond, 0.15), "dv_glass")
		game.incident("glass_craze", g.tag)
		game.say("glass_craze", pos, g.tag)


func _flash(room: String, pos: Vector2) -> void:
	var s = game.sys
	var k: float = clampf((s.o2_frac(room) - fire_o2()) / 0.3, 0.3, 1.0) * clampf(s.P(room) / 101.0, 0.3, 1.0)
	game.incident("o2_fire", room)
	game.say("o2_fire", pos, room)
	var c: Vector2 = world.rooms[room].bbox.get_center()
	game.fx.flash(c, 520.0, 0.8, Pal.heat(1.0, 2.6))
	game.fx.sparks(pos, Vector2.UP, 60, Pal.heat(1.0, 2.2), 520.0, 0.7, PI)
	game.shake(0.5)
	game.sfx.play("boom")
	var lost := 0.0
	for id in world.order:
		var q = world.pieces[id]
		if q.gone or q.cls != "equip" or not q.intact or q.room != room:
			continue
		var before: float = q.cond
		game._dent(q, maxf(0.0, q.cond - q.fragile * 0.9 * k), "dv_fire")
		lost += (before - q.cond) * q.value
	if game.drone.alive and game.drone.global_position.distance_to(pos) < 4.0 * Geom.M:
		game.hurt_drone(30.0 * k, pos, "fire_hit", "o2_fire", 1.0)
	game.lose("loss_o2_fire", 2000.0, pos + Vector2(0, -60))
	# the fire takes the extra oxygen with it
	if s.vols.has(room):
		s.o2[room] = 0.21 * s.vols[room].n
