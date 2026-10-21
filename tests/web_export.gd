extends SceneTree
# Everything the website's ship renderer draws, exported in the ship's own frame (px,
# 48 to the metre): every piece's outline, fill and line colours and triangles, its
# equipment art as the raw primitives it is recorded from (segments by width, fill
# triangles, text), the rooms with their back-wall seams, the pipes and cables, the
# lamps and what each container holds. Nothing is drawn and no save is touched.
# tools/run_test.sh tests/web_export.gd -- <ship> <out.json>
const EQ = preload("res://scripts/art_equip.gd")
const SH = preload("res://scripts/art_ships.gd")

var w: World
var done := false
var ship_id := "ark01"
var out_path := ""


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		ship_id = a[0]
	out_path = a[1] if a.size() > 1 else "G:/CODE/tmp/zp_web/%s_raw.json" % ship_id
	w = World.new()
	root.add_child(w)
	var d := Ship.load_data(ship_id)
	Ship.build(w, d)
	w.finalize()
	EQ.ext = SH
	var out := {"id": ship_id, "M": Geom.M, "pieces": [], "rooms": [], "lines": [], "lamps": d.get("power", {}).get("lamps", {}),
		"gas": d.get("gas", {}), "fluids": d.get("fluids", {}), "room_names": {}}
	for id in w.order:
		var p = w.pieces[id]
		out.pieces.append(_piece(p))
	for n in w.rooms:
		var r = w.rooms[n]
		var g: Array = w._room_grid(r)
		out.rooms.append({"name": n, "poly": _pts(r.poly), "seams_v": _pts(g[0]), "seams_h": _pts(g[1])})
		Txt.zh = true
		var zn := Txt.t(Ship.room_name_key(d, n))
		Txt.zh = false
		out.room_names[n] = [zn, Txt.t(Ship.room_name_key(d, n))]
	Txt.zh = true
	for id in w.lines:
		var l = w.lines[id]
		out.lines.append({"id": id, "kind": l.kind, "net": l.net, "path": _pts(l.path), "alive": l.alive})
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("WEB_EXPORT %s pieces=%d rooms=%d lines=%d -> %s" % [ship_id, out.pieces.size(), out.rooms.size(), out.lines.size(), out_path])
	done = true


func _pts(a: PackedVector2Array) -> Array:
	var o := []
	for q in a:
		o.append(snappedf(q.x, 0.01))
		o.append(snappedf(q.y, 0.01))
	return o


func _col(c: Color) -> Array:
	return [snappedf(c.r, 0.001), snappedf(c.g, 0.001), snappedf(c.b, 0.001), snappedf(c.a, 0.001)]


func _piece(p) -> Dictionary:
	var st: Array = w._style(p)
	var o := {"id": p.id, "kind": p.kind, "cls": p.cls, "key": p.name_key, "tag": p.tag, "room": p.room, "value": p.value,
		"poly": _pts(p.poly), "fill": _col(st[0]), "line": _col(st[1]), "tri": Array(w._tri_cached(p)), "art": p.art,
		"door": p.door, "hidden_by": p.hidden_by}
	Txt.zh = true
	o.zh = Txt.piece_name(p)
	Txt.zh = false
	o.en = Txt.piece_name(p)
	Txt.zh = true
	if p.art != "":
		o.rec = _record(p)
	return o


# the piece's art as primitives in the ship's frame
func _record(p) -> Dictionary:
	var art: String = p.art
	var sz: Vector2 = p.art_size
	var alt := ""
	if SH.BY_NAME.has(p.name_key):
		alt = SH.BY_NAME[p.name_key]
	elif EQ.BY_NAME.has(p.name_key):
		alt = EQ.BY_NAME[p.name_key]
	if alt != "" and alt != art and EQ._has(alt):
		art = alt
	EQ._rec = true
	EQ._lines = {}
	EQ._tp = []
	EQ._tc = []
	EQ._ti = []
	EQ._texts = []
	var ci: CanvasItem = w
	if EQ._has(art):
		EQ._draw_art(ci, art, Rect2(Vector2.ZERO, sz), p, w.font)
	elif art != "window":
		Art._draw_old(ci, art, sz.x, sz.y, p, w.font)
	EQ._rec = false
	var xf: Transform2D = p.art_xf
	var segs := {}
	for k in EQ._lines:
		var pts: Array = EQ._lines[k][0]
		var cols: Array = EQ._lines[k][1]
		var s := []
		for i in cols.size():
			var a: Vector2 = xf * (pts[i * 2] as Vector2)
			var b: Vector2 = xf * (pts[i * 2 + 1] as Vector2)
			var c: Color = cols[i]
			s.append_array([snappedf(a.x, 0.01), snappedf(a.y, 0.01), snappedf(b.x, 0.01), snappedf(b.y, 0.01), snappedf(c.r, 0.01), snappedf(c.g, 0.01), snappedf(c.b, 0.01), snappedf(c.a, 0.001)])
		segs[str(k)] = s
	var tris := []
	for i in EQ._ti:
		var q: Vector2 = xf * (EQ._tp[i] as Vector2)
		var c: Color = EQ._tc[i]
		tris.append_array([snappedf(q.x, 0.01), snappedf(q.y, 0.01), snappedf(c.r, 0.01), snappedf(c.g, 0.01), snappedf(c.b, 0.01), snappedf(c.a, 0.001)])
	var texts := []
	for t in EQ._texts:
		var at: Vector2 = xf * (t[1] as Vector2)
		var c: Color = t[5]
		texts.append([snappedf(at.x, 0.01), snappedf(at.y, 0.01), t[2], t[4], snappedf(xf.get_rotation(), 0.001), snappedf(xf.get_scale().x, 0.001), snappedf(c.a, 0.001)])
	EQ._lines = {}
	EQ._tp = []
	EQ._tc = []
	EQ._ti = []
	EQ._texts = []
	return {"segs": segs, "tris": tris, "texts": texts}


func _process(_dt: float) -> bool:
	return done
