class_name Pour
extends Control
# A button's pointer finish for screens drawn by hand (2026-10-18, after the
# player's Skyguard and Resonance): hovered, an inverting fill pours in from
# where the pointer came in (cubic-bezier .16 1 .3 1 over 0.62 s), a soft light
# follows the pointer and lights the border near it; left, the fill drains back
# toward where the pointer went out. Its owner moves it onto the button each
# frame: place(rect, hot, pointer). With the motion off it isn't drawn.

const SHADER = preload("res://assets/fx/pour.gdshader")
const FILL_T := 0.62

var mat: ShaderMaterial
var buffer: BackBufferCopy
var hot := false
var radius := 0.0
var fill_from := 0.0
var fill_target := 0.0
var fill_time := FILL_T
var center := Vector2.ZERO
var center_target := Vector2.ZERO
var spot := Vector2.ZERO
var spot_alpha := 0.0
var tint := Color(1, 1, 1)


static func make(owner: Node, tint_col: Color = Color(1, 1, 1)) -> Pour:
	var b := BackBufferCopy.new()
	b.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
	owner.add_child(b)
	var p := Pour.new()
	p.buffer = b
	p.tint = tint_col
	owner.add_child(p)
	return p


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	material = mat
	visible = false


# the button's rect (in the owner's space), whether it's hovered and usable, the pointer
func place(r: Rect2, is_hot: bool, pointer: Vector2) -> void:
	var local := pointer - r.position
	if is_hot and not hot:
		center_target = local
		if radius < 0.5:
			center = local
	elif not is_hot and hot:
		center_target = local.clamp(Vector2.ZERO, r.size)
	hot = is_hot
	position = r.position
	size = r.size
	spot = spot.lerp(local, 1.0 - exp(-get_process_delta_time() * 40.0))


static func pour_ease(t: float) -> float:
	if t >= 1.0:
		return 1.0
	if t <= 0.0:
		return 0.0
	var lo := 0.0
	var hi := 1.0
	for i in 12:
		var u := (lo + hi) * 0.5
		var x := 3.0 * (1.0 - u) * (1.0 - u) * u * 0.16 + 3.0 * (1.0 - u) * u * u * 0.3 + u * u * u
		if x < t:
			lo = u
		else:
			hi = u
	return 1.0 - pow(1.0 - (lo + hi) * 0.5, 3.0)


func _process(dt: float) -> void:
	if Txt.anim_level() == 0:
		visible = false
		buffer.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
		radius = 0.0
		fill_target = 0.0
		return
	var target := size.length() + 8.0 if hot else 0.0
	if target != fill_target:
		fill_from = radius
		fill_target = target
		fill_time = 0.0
	fill_time = minf(FILL_T, fill_time + dt)
	radius = lerpf(fill_from, fill_target, pour_ease(fill_time / FILL_T))
	spot_alpha = lerpf(spot_alpha, 1.0 if hot else 0.0, 1.0 - exp(-dt * 12.0))
	center = center.lerp(center_target, 1.0 - exp(-dt * 12.0))
	var active := radius > 0.5 or spot_alpha > 0.02
	visible = active
	buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT if active else BackBufferCopy.COPY_MODE_DISABLED
	if not active:
		return
	mat.set_shader_parameter("rect_size", size)
	mat.set_shader_parameter("fill_center", center)
	mat.set_shader_parameter("fill_radius", radius)
	mat.set_shader_parameter("spot", spot)
	mat.set_shader_parameter("spot_alpha", spot_alpha)
	mat.set_shader_parameter("tint", tint)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
