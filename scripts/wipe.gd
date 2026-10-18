class_name Wipe
extends CanvasLayer
# The transition between screens (UI animation, 2026-10-17): the screen closes
# on a heat line — sparks running along it, a flare when it shuts — and the
# next screen opens out of it as a blueprint: a grid of cells lit from the line
# outward, each drawn on in outline, then gone. The layer hangs off the tree's
# root, so it outlives the scene change it covers. "Off" animation cuts
# straight over; "reduced" keeps the motion without sparks and flares.
#   Wipe.go(get_tree(), func(): get_tree().change_scene_to_file(...))

const CLOSE_T := 0.42
const HOLD_T := 0.06
const OPEN_T := 0.7
const CELL := 64.0

static var current: Wipe = null

var phase := "close"           # close hold open
var t := 0.0
var then: Callable
var c: Control
var sparks: Array = []         # [pos, vel, age]
var level := 2


# cover the change f makes; a second call while one runs just runs f at the shut
static func go(tree: SceneTree, f: Callable) -> void:
	if Txt.anim_level() == 0 or tree == null:
		f.call()
		return
	if current != null and is_instance_valid(current):
		if current.phase == "close":
			current.then = f
		else:
			f.call()
		return
	var w := Wipe.new()
	w.then = f
	current = w
	tree.root.add_child(w)


# a screen opening by itself (the game's first scene): only the blueprint half
static func open_only(tree: SceneTree) -> void:
	if Txt.anim_level() == 0 or tree == null or (current != null and is_instance_valid(current)):
		return
	var w := Wipe.new()
	w.phase = "open"
	current = w
	tree.root.add_child.call_deferred(w)


# true while a wipe covers or opens the screen (scenes skip their own wipes)
static func busy() -> bool:
	return current != null and is_instance_valid(current)


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	level = Txt.anim_level()
	c = Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(_draw_wipe)
	add_child(c)


func _process(dt: float) -> void:
	t += dt
	var s := c.size
	if phase == "close":
		# sparks thrown off the line as it closes
		if level >= 2 and t > CLOSE_T * 0.55:
			for i in 6:
				var x := randf() * s.x
				sparks.append([Vector2(x, s.y * 0.5), Vector2(randf_range(-260, 260), randf_range(-160, 160)), 0.0])
		if t >= CLOSE_T:
			phase = "hold"
			t = 0.0
			if then.is_valid():
				var f := then
				then = Callable()
				f.call()
	elif phase == "hold":
		if t >= HOLD_T:
			phase = "open"
			t = 0.0
	elif phase == "open" and t >= OPEN_T:
		if current == self:
			current = null
		queue_free()
		return
	for sp in sparks:
		sp[2] += dt
		sp[0] += sp[1] * dt
		sp[1] *= exp(-3.0 * dt)
	sparks = sparks.filter(func(sp): return sp[2] < 0.5)
	c.queue_redraw()


func _draw_wipe() -> void:
	var s := c.size
	var mid := s.y * 0.5
	if phase == "close":
		var e := Pal.ease_in(clampf(t / CLOSE_T, 0.0, 1.0))
		var h := mid * e
		c.draw_rect(Rect2(0, 0, s.x, h), Color(0, 0, 0, 1))
		c.draw_rect(Rect2(0, s.y - h, s.x, h), Color(0, 0, 0, 1))
		# the two edges glow hotter as they meet
		c.draw_rect(Rect2(0, h - 1, s.x, 2), Pal.heat(0.3 + 0.7 * e, 1.2 + 1.6 * e))
		c.draw_rect(Rect2(0, s.y - h - 1, s.x, 2), Pal.heat(0.3 + 0.7 * e, 1.2 + 1.6 * e))
	elif phase == "hold":
		c.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 1))
		# shut: the line flares out to both ends
		var k := clampf(t / HOLD_T, 0.0, 1.0)
		c.draw_rect(Rect2(0, mid - 1.5, s.x, 3), Pal.heat(1.0, 3.0))
		if level >= 2:
			var w := s.x * (0.5 + 0.5 * k)
			c.draw_rect(Rect2(s.x * 0.5 - w * 0.5, mid - 8, w, 16), Pal.heat(0.25 * (1.0 - k * 0.5), 2.0))
	else:
		_draw_open(s, mid)
	for sp in sparks:
		var a: float = 1.0 - sp[2] / 0.5
		c.draw_line(sp[0], sp[0] - (sp[1] as Vector2) * 0.03, Pal.heat(a, 2.4), 1.5)


# the blueprint: cells clear in order of their distance from the line; each
# one, as it goes, shows its outline (and a cross at the grid's nodes)
func _draw_open(s: Vector2, mid: float) -> void:
	var cols := ceili(s.x / CELL)
	var rows := ceili(s.y / CELL)
	var ox := (s.x - cols * CELL) * 0.5
	var oy := mid - CELL * 0.5 - floorf((rows - 1) * 0.5) * CELL - CELL
	var far := 0.0
	for j in rows + 2:
		far = maxf(far, absf(oy + j * CELL + CELL * 0.5 - mid))
	var u := clampf(t / OPEN_T, 0.0, 1.0)
	for j in rows + 2:
		var cy := oy + j * CELL
		if cy > s.y or cy + CELL < 0.0:
			continue
		var dy := absf(cy + CELL * 0.5 - mid) / maxf(far, 1.0)
		for i in cols:
			var cx := ox + i * CELL
			var dx := absf(cx + CELL * 0.5 - s.x * 0.5) / (s.x * 0.5)
			# when this cell goes: the middle of the line first, then outward
			var start := 0.08 + 0.55 * (dy * 0.8 + dx * 0.2)
			var k := clampf((u - start) / 0.22, 0.0, 1.0)
			if k >= 1.0:
				continue
			var r := Rect2(cx, cy, CELL, CELL)
			c.draw_rect(r, Color(0, 0, 0, 1.0 - k))
			if k > 0.0:
				var la := sin(k * PI)
				c.draw_rect(r.grow(-0.5), Pal.tint(Pal.AIR, 0.35 * la, 1.0 + 0.8 * la * (1 if level >= 2 else 0)), false, 1.0)
				if level >= 2:
					var p := r.position
					c.draw_line(p + Vector2(-4, 0), p + Vector2(4, 0), Pal.tint(Pal.AIR, 0.7 * la, 1.6), 1.0)
					c.draw_line(p + Vector2(0, -4), p + Vector2(0, 4), Pal.tint(Pal.AIR, 0.7 * la, 1.6), 1.0)
	# the heat line the screen closed on fades as it opens
	var la2 := 1.0 - clampf(t / 0.3, 0.0, 1.0)
	if la2 > 0.0:
		c.draw_rect(Rect2(0, mid - 1, s.x, 2), Pal.heat(la2, 2.4))
