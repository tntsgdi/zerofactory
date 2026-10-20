extends Node2D
# A water ball held in a net (BL-88 "Floating Isle", design/ships/02_新设计十艘_设计稿.md:
# "tens of cubic metres of water held together in a net, fish in it; cut the net or
# take its frame away and the ball drifts apart, soaking the room's electrics and the
# water lost; pump it down first, the ball shrinking as it goes").
# A ship file's "waterball":
#   {"vol": the ball's water volume, "room": the room it floats in, "net": [the net's
#    panels], "frame": [the struts that hold the net], "centre": [x, y] m, "radius": m
#    when full, "safe": the fraction of the water below which the net can come away,
#    "fish": the fish holding tank (its stock dies with a burst), "soak": what the
#    room's electrics keep, "short": what they keep if the bus was live}
#   A net panel or a frame strut cut or freed with the ball above "safe": it bursts.
#   The water is lost, every electrical thing in the room is soaked (and shorted if
#   the bus is live), the fish in the ball die.
# Saved: whether it burst.

var game
var world
var cfg := {}
var burst := false
var _full := 1.0
var _have_full := false
var _t := 0.0
var _parts := {}               # net and frame tags


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("waterball", {})
	z_index = 30
	for t in cfg.get("net", []) + cfg.get("frame", []):
		_parts[str(t)] = true


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"burst": burst, "full": _full}


func load_state(d: Dictionary) -> void:
	burst = bool(d.get("burst", false))
	_full = float(d.get("full", _full))
	_have_full = true
	queue_redraw()


func water() -> float:
	return game.sys.fluid(str(cfg.get("vol", "")))


func level() -> float:
	return 0.0 if burst else clampf(water() / maxf(0.001, _full), 0.0, 1.0)


func held() -> bool:
	return not burst and level() > float(cfg.get("safe", 0.12))


func unsafe() -> Array:
	return ["water ball %.0f %% full" % (level() * 100.0)] if held() else []


func bot_prep() -> Array:
	return []


func _physics_process(dt: float) -> void:
	if not active():
		return
	if not _have_full:
		_full = maxf(0.001, water())
		_have_full = true
	_t += dt
	queue_redraw()


func on_cut(p) -> void:
	if active() and p != null and _parts.has(p.tag) and held():
		_burst(p.tag)


func on_freed(b) -> void:
	if not active() or not held():
		return
	for q in b.pieces:
		if _parts.has(q.tag):
			_burst(q.tag)
			return


func _burst(by: String) -> void:
	burst = true
	var vk: String = str(cfg.get("vol", ""))
	var s = game.sys
	var lost_w := 0.0
	if s.fvol.has(vk):
		lost_w = float(s.fvol[vk].amount)
		s.fvol[vk].amount = 0.0
		s.fluid_lost += lost_w
	var room: String = str(cfg.get("room", ""))
	var live: bool = s.bus_live
	var keep: float = float(cfg.get("short", 0.3)) if live else float(cfg.get("soak", 0.5))
	var lost := 0.0
	for id in world.order:
		var p = world.pieces[id]
		if p.gone or p.cls != "equip" or not p.intact or p.room != room or not s.electric_piece(p):
			continue
		var before: float = p.cond
		game._dent(p, minf(p.cond, keep), "dv_water_short" if live else "dv_water_soak")
		lost += (before - p.cond) * p.value
	var fish = world.tag(str(cfg.get("fish", "")))
	if fish != null and not fish.gone and fish.intact:
		var b0: float = fish.cond
		game._dent(fish, minf(fish.cond, 0.2), "dv_fish_lost")
		lost += (b0 - fish.cond) * fish.value
	var at := _centre()
	# the ball comes apart into globules that go on drifting in the room
	if game.liquids != null:
		game.liquids.spill(at, Vector2.ZERO, lost_w * 0.9, "water", 46, TAU, 0.5, true)
	for i in 6:
		game.fx.puff(at + Vector2.from_angle(i * TAU / 6.0) * 2.0 * Geom.M, Vector2.from_angle(i * TAU / 6.0) * 60.0, 2.5, 30.0, 140.0, Pal.ink(0.08))
	if live:
		game.sfx.play("arc", at, 0.8)
	game.sfx.play("hiss", at, 0.8)
	game.incident("water_ball_burst", by)
	game.say("water_ball_burst", at, by)
	game.note_loss("loss_water_ball", by, lost)
	queue_redraw()


func _centre() -> Vector2:
	var c: Array = cfg.get("centre", [0.0, 0.0])
	return Vector2(float(c[0]), float(c[1])) * Geom.M


# ---------------------------------------------------------------- drawing

# the ball seen through its net: a wobbling outline that shrinks as it is pumped down,
# ripples across it, the fish turning inside
func _draw() -> void:
	if not active() or burst:
		return
	var k := level()
	if k <= 0.01:
		return
	var c := _centre()
	var r: float = float(cfg.get("radius", 4.5)) * Geom.M * pow(k, 1.0 / 3.0)
	var pts := PackedVector2Array()
	for i in 49:
		var a: float = TAU * i / 48.0
		var wob: float = 1.0 + 0.025 * sin(a * 3.0 + _t * 1.3) + 0.015 * sin(a * 5.0 - _t * 0.9)
		pts.append(c + Vector2(cos(a), sin(a)) * r * wob)
	draw_polyline(pts, Pal.ink(0.4), 1.5, true)
	for j in 3:
		var rr: float = r * (0.35 + j * 0.2)
		draw_arc(c + Vector2(r * 0.12, -r * 0.1), rr, -1.2 + sin(_t * 0.5 + j) * 0.2, -0.3, 12, Pal.ink(0.12), 1.0, true)
	var n := int(4 + 10 * k)
	for i in n:
		var a: float = _t * (0.25 + 0.05 * (i % 3)) + i * 2.4
		var fr: float = r * (0.25 + 0.6 * fposmod(i * 0.37, 1.0))
		var fp: Vector2 = c + Vector2(cos(a), sin(a * 1.3) * 0.8) * fr
		var dir := Vector2(-sin(a), cos(a)).normalized()
		draw_line(fp - dir * 5.0, fp + dir * 5.0, Pal.ink(0.5), 1.5, true)
		draw_line(fp - dir * 5.0, fp - dir * 8.0 + dir.orthogonal() * 2.5, Pal.ink(0.35), 1.0, true)
