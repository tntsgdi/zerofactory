class_name Backdrop
extends Node2D
# What lies past the open berth: slow-parallax stars and the dark limb of the
# planet below, drawn around the camera so they never run out.

var game: Game
var stars: Array = []   # [base offset (screen px), size, parallax, phase]
const TILE := Vector2(2600, 1600)
var batch := Batch.new()


func _init() -> void:
	z_index = -20
	z_as_relative = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 260:
		stars.append([Vector2(rng.randf() * TILE.x, rng.randf() * TILE.y), rng.randf_range(0.5, 1.5), rng.randf_range(0.02, 0.12), rng.randf() * TAU])


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	if game == null or game.cam == null:
		return
	var cam: Vector2 = game.cam.position
	var z: float = game.cam_zoom()
	var t := Time.get_ticks_msec() / 1000.0
	var view := get_viewport_rect().size / z
	# planet limb, lower right, barely moving
	var pc := cam + Vector2(view.x * 0.55, view.y * 1.35) - cam * 0.02
	var pr := view.y * 1.05
	draw_circle(pc, pr, Color(0.047, 0.05, 0.058))
	draw_arc(pc, pr, PI * 1.02, PI * 1.62, 120, Pal.tint(Pal.AIR, 0.1), 2.0 / z, true)
	draw_arc(pc, pr + 6.0 / z, PI * 1.05, PI * 1.55, 120, Pal.tint(Pal.AIR, 0.04), 6.0 / z, true)
	# stars: each layer slides a little against the camera
	for s in stars:
		var off: Vector2 = s[0] - cam * s[2] * z
		off = Vector2(fposmod(off.x, TILE.x), fposmod(off.y, TILE.y)) - TILE * 0.5
		var tw := 0.6 + 0.4 * sin(t * 0.9 + s[3])
		batch.dot(cam + off / z, s[1] * 1.9 / z, Pal.ink(0.32 * tw * s[1] / 1.5))
	batch.flush(self, game.fx.soft_tex)
