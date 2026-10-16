class_name Batch
# One draw call for many small things. A Batch collects soft round dots (a
# textured quad each) and hands them to the renderer as a single triangle
# array, instead of one draw_circle per star, mote or ember.

var pts := PackedVector2Array()
var uvs := PackedVector2Array()
var cols := PackedColorArray()
var n := 0

static var _idx := PackedInt32Array()
const UV := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]


func clear() -> void:
	pts.resize(0)
	uvs.resize(0)
	cols.resize(0)
	n = 0


func dot(c: Vector2, r: float, col: Color) -> void:
	pts.append(c + Vector2(-r, -r))
	pts.append(c + Vector2(r, -r))
	pts.append(c + Vector2(r, r))
	pts.append(c + Vector2(-r, r))
	for i in 4:
		uvs.append(UV[i])
		cols.append(col)
	n += 1


func flush(ci: CanvasItem, tex: Texture2D) -> void:
	if n == 0:
		return
	if _idx.size() < n * 6:
		var m := maxi(n, 512)
		_idx.resize(m * 6)
		for i in m:
			var b := i * 4
			_idx[i * 6] = b
			_idx[i * 6 + 1] = b + 1
			_idx[i * 6 + 2] = b + 2
			_idx[i * 6 + 3] = b
			_idx[i * 6 + 4] = b + 2
			_idx[i * 6 + 5] = b + 3
	var idx := _idx.slice(0, n * 6)
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols, uvs, PackedInt32Array(), PackedFloat32Array(), tex.get_rid())
	clear()


# A cached triangulation of a polygon, filled with one colour in one call.
static func fill(ci: CanvasItem, poly: PackedVector2Array, idx: PackedInt32Array, col: Color) -> void:
	if idx.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, poly, PackedColorArray([col]))
