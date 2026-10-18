class_name Consoles
extends Node2D
# The berth's two computers (the user, 2026-10-17): mounted on the tower wall at
# the berth's near end, one for the equipment shop and one for berth management.
# Fly the drone up to one and press the use key: the terminal's page opens over
# the berth (play stops while it is open, Esc closes it). What is bought there
# counts from the next contract. Only on a career's contracts.

# one computer now (player 2026-10-18: "two computers opening the same thing is
# odd"): the berth terminal, the same device the terminal key opens anywhere
const SPOTS := [["terminal", Vector2(-6.2, -2.4)]]   # m: the screen's top-left
const SIZE := Vector2(1.3, 1.5)    # m
const REACH := 2.6                 # m from the screen's centre

var game: Game
var t := 0.0


func _init() -> void:
	z_index = 2
	z_as_relative = false


static func centre(i: int) -> Vector2:
	return (SPOTS[i][1] + SIZE * 0.5) * Geom.M


# which console the drone is at ("" for none)
func near() -> String:
	if game == null or game.drone == null or not game.drone.alive:
		return ""
	for i in SPOTS.size():
		if game.drone.global_position.distance_to(centre(i)) < REACH * Geom.M:
			return SPOTS[i][0]
	return ""


func _process(dt: float) -> void:
	t += dt
	queue_redraw()


func _draw() -> void:
	var font: Font = Fonts.get_font("Medium")
	var at := near()
	for i in SPOTS.size():
		var id: String = SPOTS[i][0]
		var r := Rect2(SPOTS[i][1] * Geom.M, SIZE * Geom.M)
		var on := at == id
		# the bracket to the tower, the housing, the screen
		draw_line(Vector2(r.position.x - 10.0, r.get_center().y), Vector2(r.position.x, r.get_center().y), Pal.ink(0.4), 3.0)
		draw_rect(r, Color(0.05, 0.053, 0.06))
		draw_rect(r, Pal.ink(0.75 if on else 0.4), false, 1.6)
		var sr := Rect2(r.position + Vector2(6, 6), Vector2(r.size.x - 12, r.size.y * 0.55))
		var glow := 0.18 + 0.06 * sin(t * 2.0 + i) + (0.2 if on else 0.0)
		draw_rect(sr, Pal.tint(Pal.AIR, glow, 1.1))
		draw_rect(sr, Pal.tint(Pal.AIR, 0.7, 1.2), false, 1.0)
		# a few lines of what it shows
		for k in 3:
			var ly := sr.position.y + 10.0 + k * 10.0
			draw_line(Vector2(sr.position.x + 6, ly), Vector2(sr.position.x + 6 + sr.size.x * (0.4 + 0.15 * ((k + i) % 3)), ly), Pal.tint(Pal.AIR, 0.6, 1.3), 1.4)
		# keys under the screen
		for k in 4:
			draw_rect(Rect2(Vector2(r.position.x + 8 + k * 14, sr.end.y + 8), Vector2(10, 6)), Pal.ink(0.35))
		draw_string(font, Vector2(r.position.x, r.end.y + 16), game.txt("cn_" + id), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(0.85 if on else 0.55))
		if on:
			var p := 0.6 + 0.4 * sin(t * 5.0)
			draw_string(font, Vector2(r.position.x, r.position.y - 10), "[%s] %s  ·  %s" % [Keys.label("use"), game.txt("cn_open") + game.txt("cn_" + id), game.txt("cn_anytime") % Keys.label("terminal")], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.heat(p, 1.3))
