class_name UI
# One look for every panel, button, selection and readout, on site and at the
# terminal: a near-black plate with a faint ink edge, a heat bar on the left
# for what is chosen, buttons with a heat underline, text never smaller than
# 13 px or fainter than 45% for anything a player has to read.

const PLATE := Color(0.03, 0.032, 0.037)
const SMALL := 13          # the smallest size for text that matters
const DIM := 0.5           # the faintest alpha for text that matters


static func panel(ci: CanvasItem, r: Rect2, a: float = 1.0, chosen: float = 0.0, accent: Color = Pal.HEAT) -> void:
	ci.draw_rect(r, Color(PLATE.r + 0.012 * chosen, PLATE.g + 0.012 * chosen, PLATE.b + 0.012 * chosen, 0.95 * a))
	ci.draw_rect(r, Pal.ink((0.14 + 0.4 * chosen) * a), false, 1.0)
	if chosen > 0.005:
		var h := r.size.y * chosen
		ci.draw_rect(Rect2(r.position.x, r.position.y + (r.size.y - h) * 0.5, 3, h), Color(accent.r, accent.g, accent.b, a))


# a full-screen sheet behind a result (settlement, assessment): nothing of the scene shows through
static func sheet(ci: CanvasItem, s: Vector2, a: float) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, s), Color(0.012, 0.013, 0.016, 0.94 * a))


static func text(ci: CanvasItem, font: Font, s: String, pos: Vector2, size_px: int, col: Color, align: int = -1) -> void:
	var x := pos.x
	if align != -1:
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		x -= w * (0.5 if align == 0 else 1.0)
	ci.draw_string(font, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)


# a button: hover lifts it, disabled greys it with the reason under the label,
# `shake` (0..1, decaying) jolts it sideways when it was pressed and could not act
static func button(ci: CanvasItem, font: Font, r: Rect2, label: String, hover: float, enabled: bool, a: float, t: float, shake: float = 0.0, note: String = "") -> void:
	var off := Vector2(sin(t * 70.0) * 9.0 * shake * shake, 0)
	r.position += off
	var hk := hover if enabled else 0.0
	ci.draw_rect(r, Color(0.05 + 0.03 * hk, 0.05 + 0.03 * hk, 0.055 + 0.03 * hk, 0.96 * a))
	ci.draw_rect(r, (Pal.ink((0.45 + 0.4 * hk) * a) if enabled else Pal.ink(0.2 * a)) if shake < 0.05 else Pal.heat(a, 1.3), false, 1.4)
	if enabled:
		ci.draw_rect(Rect2(r.position.x, r.end.y - 3, r.size.x, 3), Pal.heat(a * (0.75 + 0.25 * sin(t * 3.0)), 1.1))
		var run := fposmod(t * 0.6, 1.0)
		ci.draw_rect(Rect2(r.position.x + (r.size.x - 60) * run, r.end.y - 3, 60, 3), Pal.heat(0.6 * a, 2.2))
	var ly := r.get_center().y + (0.0 if note == "" else -6.0) + 7.0
	text(ci, font, label, Vector2(r.get_center().x, ly), 20, Pal.ink((0.95 if enabled else 0.45) * a), 0)
	if note != "":
		text(ci, font, note, Vector2(r.get_center().x, ly + 20), 13, Pal.heat(0.9 * a, 1.1) if not enabled else Pal.ink(0.55 * a), 0)


# now → after: two bars, the gain drawn hot
static func compare(ci: CanvasItem, font: Font, r: Rect2, label: String, now_s: String, after_s: String, now_k: float, after_k: float, a: float, grow: float) -> void:
	text(ci, font, label, r.position + Vector2(0, 14), 14, Pal.ink(0.6 * a))
	text(ci, font, now_s + "  →  " + after_s, Vector2(r.end.x, r.position.y + 14), 15, Pal.ink(0.95 * a), 1)
	var br := Rect2(r.position.x, r.position.y + 24, r.size.x, 5)
	ci.draw_rect(br, Pal.ink(0.08 * a))
	ci.draw_rect(Rect2(br.position, Vector2(br.size.x * now_k, 5)), Pal.ink(0.7 * a))
	var g := lerpf(now_k, after_k, grow)
	if g > now_k:
		ci.draw_rect(Rect2(br.position + Vector2(br.size.x * now_k, 0), Vector2(br.size.x * (g - now_k), 5)), Pal.heat(0.9 * a, 1.3))
