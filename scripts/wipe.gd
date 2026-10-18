class_name Wipe
extends CanvasLayer
# The transition between screens, redone after the player's sibling games
# (2026-10-18, player: "the transitions still aren't smooth — look at NANOFALL,
# Resonance, Skyguard"). No black curtain any more: the screen being left is
# kept as a picture, the next scene is built behind it (the scene change's
# ~0.2 s of work falls on a frame where nothing moves), and then the picture
# goes over the live new screen.
#   lift  (most changes): it lifts a little and fades, 0.26 s
#   fold  (taking a contract): the screen folds into a bright hairline through
#         the chosen card — height first, then width, a flash — and the berth
#         opens out of the line
# The layer hangs off the tree's root, so it outlives the change it covers.
# "Off" animation cuts straight over; "lite" only fades.
#   Wipe.go(get_tree(), func(): get_tree().change_scene_to_file(...))
#   Wipe.go(get_tree(), f, "fold", card_rect)

const LIFT_T := 0.26
const FOLD_Y := 0.2            # the height folds in
const FOLD_X := 0.18           # then the width, overlapping by FOLD_LAP
const FOLD_LAP := 0.06
const OPEN_T := 0.34
const SETTLE := 2              # frames the new scene draws before the picture goes
const FIRST_T := 0.4           # the game's first screen fades up from black

static var current: Wipe = null
static var _changed_at := -100000   # msec the last covered change happened

var style := "lift"
var phase := "cover"           # cover (picture held, scene changing) · out · fold · line · open · first
var t := 0.0
var then: Callable
var at := Rect2()              # fold: the card the screen folds through
var shot: Texture2D
var c: Control
var level := 2
var _frames := 0


# cover the change f makes; a second call while one runs just runs f
static func go(tree: SceneTree, f: Callable, how: String = "lift", through: Rect2 = Rect2()) -> void:
	if Txt.anim_level() == 0 or tree == null:
		f.call()
		return
	if current != null and is_instance_valid(current):
		if current.phase in ["fold"] and current.then.is_valid():
			current.then = f
		else:
			f.call()
		return
	var w := Wipe.new()
	w.then = f
	w.style = how if Txt.anim_level() >= 2 else "lift"
	w.at = through
	w.shot = _snapshot(tree)
	w.phase = "fold" if w.style == "fold" else "cover"
	current = w
	tree.root.add_child(w)
	# lift: the change happens under the held picture straight away
	if w.phase == "cover":
		w._change()


# the game's first screen: it comes up out of black
static func open_only(tree: SceneTree) -> void:
	if Txt.anim_level() == 0 or tree == null or (current != null and is_instance_valid(current)):
		return
	var w := Wipe.new()
	w.phase = "first"
	current = w
	tree.root.add_child.call_deferred(w)


# true for a moment after a change this layer covered: the new scene skips its
# own opening (the berth's black bars), the picture lifting off it is the entry
static func arrived() -> bool:
	return (current != null and is_instance_valid(current)) or Time.get_ticks_msec() - _changed_at < 900


# true while the screen is held or folded shut (scenes hold back their own entries)
static func busy() -> bool:
	return current != null and is_instance_valid(current) and current.phase in ["cover", "fold", "line", "first"]


static func _snapshot(tree: SceneTree) -> Texture2D:
	var img := tree.root.get_texture().get_image()
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	level = Txt.anim_level()
	c = Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(_draw_wipe)
	add_child(c)


func _change() -> void:
	_frames = 0
	_changed_at = Time.get_ticks_msec()
	if then.is_valid():
		var f := then
		then = Callable()
		f.call()


func _process(dt: float) -> void:
	# a long frame (the scene change itself) doesn't eat the motion that follows
	dt = minf(dt, 1.0 / 30.0)
	t += dt
	match phase:
		"cover":
			# wait for the new scene to have drawn itself, then let the picture go
			_frames += 1
			if _frames > SETTLE:
				phase = "out" if style == "lift" else "open"
				t = 0.0
		"out":
			if t >= LIFT_T:
				_done()
				return
		"fold":
			if t >= FOLD_Y + FOLD_X - FOLD_LAP:
				phase = "line"
				t = 0.0
				_change()
		"line":
			_frames += 1
			if _frames > SETTLE:
				phase = "open"
				t = 0.0
		"open":
			if t >= OPEN_T:
				_done()
				return
		"first":
			if t >= FIRST_T:
				_done()
				return
	c.queue_redraw()


func _done() -> void:
	if current == self:
		current = null
	queue_free()


static func _eo(x: float, p: float = 3.0) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), p)


static func _ei(x: float, p: float = 4.0) -> float:
	return pow(clampf(x, 0.0, 1.0), p)


# where the fold closes: through the middle of the card, or the screen's
func _line_y(s: Vector2) -> float:
	return at.get_center().y if at.size != Vector2.ZERO else s.y * 0.5


func _line_x(s: Vector2) -> float:
	return at.get_center().x if at.size != Vector2.ZERO else s.x * 0.5


func _draw_wipe() -> void:
	var s := c.size
	match phase:
		"cover":
			_picture(Rect2(Vector2.ZERO, s), 1.0)
		"out":
			# it lifts and fades over the live screen
			var k := _eo(t / LIFT_T, 2.0)
			_picture(Rect2(Vector2(0, -26.0 * k), s), 1.0 - k)
		"fold":
			_draw_fold(s)
		"line":
			c.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 1))
			_hairline(s, s.x * 0.5, 1.0)
		"open":
			_draw_open(s)
		"first":
			c.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 1.0 - _eo(t / FIRST_T, 2.0)))


func _picture(r: Rect2, a: float, bright: float = 1.0) -> void:
	if shot == null:
		c.draw_rect(r, Color(0, 0, 0, a))
		return
	c.draw_texture_rect(shot, r, false, Color(bright, bright, bright, a))


# the screen presses flat onto the line through the card, then narrows to its middle
func _draw_fold(s: Vector2) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 1))
	var ly := _line_y(s)
	var lx := _line_x(s)
	var ky := _ei(t / FOLD_Y, 4.0)
	var kx := _ei((t - (FOLD_Y - FOLD_LAP)) / FOLD_X, 3.0)
	var h := lerpf(s.y, 3.0, ky)
	var w := lerpf(s.x, s.x * 0.5, kx)
	# the picture squeezed toward the line (the card's middle stays put), brightening as it goes thin
	var top := ly * (1.0 - h / s.y)
	var left := lx * (1.0 - w / s.x)
	_picture(Rect2(left, top, w, h), 1.0 - 0.4 * kx, 1.0 + 1.2 * ky)
	if ky > 0.5:
		_hairline(s, w, (ky - 0.5) * 2.0)


func _hairline(s: Vector2, w: float, k: float) -> void:
	var ly := _line_y(s)
	var lx := _line_x(s) if phase == "fold" else s.x * 0.5
	c.draw_rect(Rect2(lx - w * 0.5, ly - 1.5, w, 3), Pal.heat(k, 3.0))
	if level >= 2:
		c.draw_rect(Rect2(lx - w * 0.5, ly - 9, w, 18), Pal.heat(0.18 * k, 2.0))


# the berth opens out of the line: the dark parts top and bottom draw back
func _draw_open(s: Vector2) -> void:
	var ly := _line_y(s) if style == "fold" else s.y * 0.5
	var k := _eo(t / OPEN_T, 3.0)
	var up := ly * (1.0 - k)
	var down := (s.y - ly) * (1.0 - k)
	c.draw_rect(Rect2(0, 0, s.x, up), Color(0, 0, 0, 1))
	c.draw_rect(Rect2(0, s.y - down, s.x, down), Color(0, 0, 0, 1))
	var la := 1.0 - _eo(t / 0.22, 2.0)
	if la > 0.0:
		c.draw_rect(Rect2(0, up - 1, s.x, 2), Pal.heat(la, 2.4))
		c.draw_rect(Rect2(0, s.y - down - 1, s.x, 2), Pal.heat(la, 2.4))
