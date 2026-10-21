extends SceneTree
# Runs a ship's authoring script and writes the ship file the game builds from.
# godot --headless --path . -s tools/ship_export.gd -- gr7|ts1|e07a|e07b|e07c|e07d
#
# A ship file (ships/<id>.json) is plain data in metres:
#   pieces  [{key, kind, poly, ...}]       structure and equipment
#   joints  [{a, b, type, at, tag}]        b = null: clamped to the dock
#   lines   [{id, kind, net, a, pa, b, pb, path}]
#   ctrls   [{id, kind, piece, at, ...}]   ports, valves, switches, doors
#   rooms   [{name, poly}]
# plus the meta() sections of the authoring script (gas, power, fluids,
# per-control settings, contract value, the factory drawing).

const AUTHORS := {"gr7": "res://tools/authoring/gr7_author.gd", "s09": "res://tools/authoring/s09_author.gd", "tug": "res://tools/authoring/tug_author.gd", "pod": "res://tools/authoring/pod_author.gd", "h22": "res://tools/authoring/h22_author.gd", "med47": "res://tools/authoring/med47_author.gd", "m14": "res://tools/authoring/m14_author.gd", "fr26": "res://tools/authoring/fr26_author.gd", "ts1": "res://tools/authoring/ts1_author.gd", "pt34": "res://tools/authoring/pt34_author.gd", "jd38": "res://tools/authoring/jd38_author.gd", "tw64": "res://tools/authoring/tw64_author.gd", "hb86": "res://tools/authoring/hb86_author.gd", "cl104": "res://tools/authoring/cl104_author.gd", "es112": "res://tools/authoring/es112_author.gd", "fl116": "res://tools/authoring/fl116_author.gd", "sv122": "res://tools/authoring/sv122_author.gd", "mf126": "res://tools/authoring/mf126_author.gd", "ro128": "res://tools/authoring/ro128_author.gd", "cv138": "res://tools/authoring/cv138_author.gd", "vt80": "res://tools/authoring/vt80_author.gd", "ps12": "res://tools/authoring/ps12_author.gd", "cf90": "res://tools/authoring/cf90_author.gd", "sa200": "res://tools/authoring/sa200_author.gd", "nr95": "res://tools/authoring/nr95_author.gd", "ih55": "res://tools/authoring/ih55_author.gd", "mt140": "res://tools/authoring/mt140_author.gd", "md160": "res://tools/authoring/md160_author.gd", "tb180": "res://tools/authoring/tb180_author.gd", "ch110": "res://tools/authoring/ch110_author.gd", "my48": "res://tools/authoring/my48_author.gd", "ic120": "res://tools/authoring/ic120_author.gd", "arktest": "res://tools/authoring/arktest_author.gd", "ark01": "res://tools/authoring/ark01_author.gd", "qc30": "res://tools/authoring/qc30_author.gd", "st40": "res://tools/authoring/st40_author.gd", "ev55": "res://tools/authoring/ev55_author.gd", "dc84": "res://tools/authoring/dc84_author.gd", "ob90": "res://tools/authoring/ob90_author.gd", "fx70": "res://tools/authoring/fx70_author.gd", "bl88": "res://tools/authoring/bl88_author.gd", "lc140": "res://tools/authoring/lc140_author.gd", "dr150": "res://tools/authoring/dr150_author.gd", "hg170": "res://tools/authoring/hg170_author.gd",
	"e07a": "res://tools/authoring/e07_author.gd", "e07b": "res://tools/authoring/e07_author.gd",
	"e07c": "res://tools/authoring/e07_author.gd", "e07d": "res://tools/authoring/e07_author.gd",
	"sp_energy": "res://tools/authoring/sp_author.gd", "sp_cryo": "res://tools/authoring/sp_author.gd", "sp_fluid": "res://tools/authoring/sp_author.gd",
	"sp_atmos": "res://tools/authoring/sp_author.gd", "sp_load": "res://tools/authoring/sp_author.gd", "sp_precise": "res://tools/authoring/sp_author.gd",
	"sp_isolate": "res://tools/authoring/sp_author.gd"}


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var id: String = a[0] if a.size() > 0 else "gr7"
	var author = load(AUTHORS[id])
	if id.begins_with("e07"):
		author.variant = id.substr(3)
	if id.begins_with("sp_"):
		author.variant = id.substr(3)
	var w := World.new()
	author.build(w)
	_cut_lines(w, id)
	var d: Dictionary = author.meta()
	d.merge(export_world(w), true)
	var f := FileAccess.open("res://ships/%s.json" % id, FileAccess.WRITE)
	f.store_string(pretty(d, "") + "\n")
	f.close()
	print("wrote ships/%s.json: %d pieces, %d joints, %d lines, %d controls, %d rooms" % [id, d.pieces.size(), d.joints.size(), d.lines.size(), d.ctrls.size(), d.rooms.size()])
	w.free()
	quit()


# Equipment the base 3 t grapple can't take whole gets enough marked lines (across its
# long side, evenly) for every part to be one it can (player 2026-10-19: "anything
# recoverable must be cuttable or smaller, or the drone can't take it up").
const GRAB_T := 3.0


static func _cut_lines(w, id: String) -> void:
	for pid in w.order:
		var p = w.pieces[pid]
		if p.cls != "equip" or p.gone:
			continue
		var seg: Array = p.get_meta("segments", [])
		var need := ceili(float(p.mass) / GRAB_T)
		if seg.size() + 1 >= need:
			continue
		var bb := Geom.bbox(p.poly)
		var r := Rect2(bb.position / Geom.M, bb.size / Geom.M)
		var out: Array = []
		for i in range(1, need):
			var f := float(i) / need
			if r.size.x >= r.size.y:
				var x := r.position.x + r.size.x * f
				out.append([x, r.position.y, x, r.end.y])
			else:
				var y := r.position.y + r.size.y * f
				out.append([r.position.x, y, r.end.x, y])
		p.set_meta("segments", out)
		print("  %s: %s %.1f t gets %d marked lines" % [id, p.tag, p.mass, out.size()])


# Readable JSON: one record per line in the long lists, nested settings indented,
# short arrays of numbers kept on one line.
static func pretty(v, ind: String) -> String:
	if v is Dictionary:
		if not _nested(v):
			return JSON.stringify(v)
		var parts: Array = []
		for k in v:
			parts.append(ind + "\t" + JSON.stringify(str(k)) + ": " + pretty(v[k], ind + "\t"))
		return "{\n" + ",\n".join(parts) + "\n" + ind + "}"
	if v is Array and v.size() > 0 and v[0] is Dictionary:
		var rows: Array = []
		for item in v:
			rows.append(ind + "\t" + JSON.stringify(item))
		return "[\n" + ",\n".join(rows) + "\n" + ind + "]"
	return JSON.stringify(v)


static func _nested(d: Dictionary) -> bool:
	for k in d:
		if d[k] is Dictionary or (d[k] is Array and d[k].size() > 0 and d[k][0] is Dictionary):
			return true
	return false


static func _m(v: Vector2) -> Array:
	return [snappedf(v.x / Geom.M, 0.0001), snappedf(v.y / Geom.M, 0.0001)]


static func _mpoly(p: PackedVector2Array) -> Array:
	var out: Array = []
	for q in p:
		out.append(_m(q))
	return out


static func export_world(w) -> Dictionary:
	var keys := {}
	var used := {}
	for id in w.order:
		var p = w.pieces[id]
		if p.gone:
			continue
		var k: String = p.tag if p.tag != "" and not used.has(p.tag) else "p%d" % p.id
		used[k] = true
		keys[p.id] = k
	var pieces: Array = []
	for id in w.order:
		var p = w.pieces[id]
		if p.gone:
			continue
		var pd := {"key": keys[p.id], "kind": p.kind, "poly": _mpoly(p.poly), "mass": snappedf(p.mass, 0.00001), "density": p.density,
			"cut_speed": p.cut_speed}
		if p.tag != "":
			pd.tag = p.tag
		if p.name_key != "":
			pd.name_key = p.name_key
		if p.cls != "metal":
			pd.cls = p.cls
		if p.value > 0.0:
			pd.value = p.value
		if p.cond != 1.0:
			pd.cond = p.cond
		if p.art != "":
			pd.art = p.art
			var xf: Transform2D = p.art_xf
			pd.art_xf = [xf.x.x, xf.x.y, xf.y.x, xf.y.y, xf.origin.x / Geom.M, xf.origin.y / Geom.M]
			pd.art_size = _m(p.art_size)
		if p.fragile != 0.3:
			pd.fragile = p.fragile
		if p.room != "":
			pd.room = p.room
		if p.has_meta("segments"):
			pd.segments = p.get_meta("segments")
		if p.barrier:
			pd.barrier = true
		if p.door:
			pd.door = true
			pd.door_open = p.door_open
			pd.open_dir = _m(p.open_dir)
		if p.hazard != "":
			pd.hazard = p.hazard
		if p.temp != 20.0:
			pd.temp = p.temp
		if p.mandatory:
			pd.mandatory = true
		if p.dest != "metal":
			pd.dest = p.dest
		if p.hidden_by >= 0 and keys.has(p.hidden_by):
			pd.hidden_by = keys[p.hidden_by]
		if p.has_meta("rig"):
			pd.rig = true
		pieces.append(pd)
	var joints: Array = []
	for j in w.joints:
		if not j.alive or not keys.has(j.a):
			continue
		if j.b != Model.ANCHOR and not keys.has(j.b):
			continue
		var jd := {"a": keys[j.a], "b": keys[j.b] if j.b != Model.ANCHOR else null, "type": j.type, "at": _m(j.pos)}
		if j.has_meta("tag"):
			jd.tag = j.get_meta("tag")
		joints.append(jd)
	var lines: Array = []
	for id in w.lines:
		var l = w.lines[id]
		var ld := {"id": l.id, "kind": l.kind, "net": l.net, "a": keys[l.a], "pa": _m(l.pa), "b": keys[l.b], "pb": _m(l.pb), "path": _mpoly(l.path)}
		if not l.alive:
			ld.cut = _m(l.cut_at)
		lines.append(ld)
	var ctrls: Array = []
	for id in w.ctrls:
		var c = w.ctrls[id]
		var cd := {"id": c.id, "kind": c.kind, "piece": keys.get(c.piece, null), "at": _m(c.pos)}
		if c.state:
			cd.state = true
		if c.medium != "":
			cd.medium = c.medium
		if c.target != "":
			cd.target = c.target
		if c.hidden_room != "":
			cd.hidden_room = c.hidden_room
		ctrls.append(cd)
	var rooms: Array = []
	for n in w.rooms:
		rooms.append({"name": n, "poly": _mpoly(w.rooms[n].poly)})
	return {"pieces": pieces, "joints": joints, "lines": lines, "ctrls": ctrls, "rooms": rooms}
