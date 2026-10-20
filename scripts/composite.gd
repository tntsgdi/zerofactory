extends Node
# A composite hull (ST-40 "Hummingbird", design/ships/02_新设计十艘_设计稿.md: "the
# carbon-fibre airframe gives off toxic smoke when the laser cuts it; in a room with
# air the smoke settles into the electronics"). A ship file's "composite":
#   {"prefixes": [tag prefixes of the composite panels], "fume": smoke a cut puts into
#    the room beside it, "rate": the share of value a unit of smoke takes off each
#    electronic piece a second, "floor": the condition it stops at, "electronics":
#    [arts that count], "fog": {pane tag: room} glass the smoke fogs, "fog_at": smoke
#    over which it does}
#   A cut into a composite panel next to a room with air in it fills that room with
#   smoke (the more air, the more of it stays: venting the room takes it out with
#   the air). While a room holds smoke, every electronic piece in it loses value,
#   down to "floor"; past "fog_at" its glass fogs. The panels are bolted, not bonded:
#   unbolted, or cut in vacuum, they give off nothing.
# Saved: each room's smoke, which panes fogged.

var game
var world
var cfg := {}
var smoke := {}               # room -> smoke (as if at full pressure)
var fogged := {}
var _said := {}


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("composite", {})


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"smoke": smoke, "fogged": fogged.keys()}


func load_state(d: Dictionary) -> void:
	for r in d.get("smoke", {}):
		smoke[str(r)] = float(d.smoke[r])
	for t in d.get("fogged", []):
		fogged[str(t)] = true


func is_composite(p) -> bool:
	if p == null:
		return false
	for pf in cfg.get("prefixes", []):
		if p.tag.begins_with(str(pf)):
			return true
	return false


# the smoke in a room as it stands (it leaves with the air)
func level(room: String) -> float:
	var s = game.sys
	if not s.vols.has(room):
		return 0.0
	return float(smoke.get(room, 0.0)) * clampf(s.P(room) / 101.0, 0.0, 1.0)


func unsafe() -> Array:
	var out: Array = []
	for r in smoke:
		if level(r) > 0.05:
			out.append("smoke in %s %.2f" % [r, level(r)])
	return out


func _physics_process(dt: float) -> void:
	if not active() or game == null or game.paused_sim or game.state != "play":
		return
	var arts: Array = cfg.get("electronics", [])
	for r in smoke.keys():
		var lv := level(r)
		if lv < 0.02:
			if game.sys.P(r) < 1.0:
				smoke.erase(r)
			continue
		for id in world.order:
			var p = world.pieces[id]
			if p.gone or p.room != r or p.cls != "equip" or not p.intact or not arts.has(p.art):
				continue
			var fl: float = float(cfg.get("floor", 0.55))
			if p.cond > fl:
				game._dent(p, maxf(fl, p.cond - float(cfg.get("rate", 0.01)) * lv * dt), "dv_fume")
		for t in cfg.get("fog", {}):
			if str(cfg.fog[t]) == r and lv > float(cfg.get("fog_at", 1.5)) and not fogged.has(t):
				var q = world.tag(str(t))
				if q != null and not q.gone and q.intact:
					fogged[t] = true
					game._dent(q, minf(q.cond, 0.5), "dv_glass_fog")
					game.say("glass_fog", world.frame(q) * Geom.centroid(q.poly), str(t))
					world.redraw_near([q])


func on_cut(p) -> void:
	if not active() or p == null or not is_composite(p):
		return
	var at: Vector2 = world.frame(p) * Geom.centroid(p.poly)
	var room := ""
	var best := INF
	for n in world.rooms:
		var r = world.rooms[n]
		var bb: Rect2 = r.bbox.grow(1.2 * Geom.M)
		if not bb.has_point(at):
			continue
		var d: float = r.bbox.get_center().distance_to(at)
		if d < best:
			best = d
			room = n
	if room == "" or game.sys.P(room) < 5.0:
		return
	smoke[room] = float(smoke.get(room, 0.0)) + float(cfg.get("fume", 1.0))
	if not _said.has(room):
		_said[room] = true
		game.incident("composite_fumes", room)
	game.say("composite_fumes", at, room)
	game.sfx.play("hiss")


# a panel unbolted gives off nothing
func on_freed(_b) -> void:
	pass
