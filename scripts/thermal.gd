extends Node
# A hull still hot from a pass close to the sun (EV-55 "Fire-Eye",
# design/ships/02_新设计十艘_设计稿.md: "the heat shield's tiles and the forward hull
# are still hundreds of degrees; they cool zone by zone, faster with the berth's
# cooling loop on; a hot tile shatters when cut, equipment taken out of a hot zone is
# heat-damaged, and the drone is burnt in the hottest").
# A ship file's "thermal":
#   {"zones": {zone: {"T0": °C at the start, "rect": [x0, y0, x1, y1] m (what lies in it
#     is the zone's), "k": its cooling rate (/s)}}, "order": [zones, first match wins],
#    "ambient": °C, "loop": the berth cooling socket's control, "loop_k": how much
#    faster the zones it reaches cool, "loop_zones": [those zones], "tiles": [tag
#    prefixes of the shield tiles], "shatter_T": °C over which a tile cut or freed
#    shatters, "spoil_T": °C over which equipment freed from its zone is damaged,
#    "burn_T": °C over which the drone is burnt in a zone, "burn": damage a second}
#   Each zone cools towards ambient on its own, faster with the cooling loop plugged
#   in. A probe reads a zone's temperature.
# Saved: the zones' temperatures, which tiles shattered.

const SPOIL_KEEP := 0.5

var game
var world
var cfg := {}
var temp := {}
var shattered := {}
var spoiled := {}
var _zone_of := {}          # piece id -> zone (sorted once)
var _burn_t := -99.0


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("thermal", {})
	for z in cfg.get("zones", {}):
		temp[z] = float(cfg.zones[z].get("T0", 20.0))
	for id in world.order:
		var p = world.pieces[id]
		var c: Vector2 = Geom.centroid(p.poly) / Geom.M
		for z in cfg.get("order", []):
			var r: Array = cfg.zones[z].get("rect", [])
			if r.size() == 4 and c.x >= float(r[0]) and c.x <= float(r[2]) and c.y >= float(r[1]) and c.y <= float(r[3]):
				_zone_of[p.id] = z
				break


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"temp": temp, "shattered": shattered.keys(), "spoiled": spoiled.keys()}


func load_state(d: Dictionary) -> void:
	for z in d.get("temp", {}):
		temp[str(z)] = float(d.temp[z])
	for t in d.get("shattered", []):
		shattered[str(t)] = true
	for t in d.get("spoiled", []):
		spoiled[str(t)] = true


func zone_temp(z: String) -> float:
	return float(temp.get(z, float(cfg.get("ambient", 20.0))))


func zone_of(p) -> String:
	if p == null:
		return ""
	if _zone_of.has(p.id):
		return str(_zone_of[p.id])
	# a part a cut made: where it is
	var c: Vector2 = world.frame(p) * Geom.centroid(p.poly) / Geom.M
	for z in cfg.get("order", []):
		var r: Array = cfg.zones[z].get("rect", [])
		if r.size() == 4 and c.x >= float(r[0]) and c.x <= float(r[2]) and c.y >= float(r[1]) and c.y <= float(r[3]):
			return z
	return ""


func is_tile(p) -> bool:
	for pf in cfg.get("tiles", []):
		if p.tag.begins_with(str(pf)) or str(p.get_meta("origin", "")).begins_with(str(pf)):
			return true
	return false


func looped() -> bool:
	return game.sys.on(str(cfg.get("loop", "")))


# what still has to be made safe: a zone too hot to work in
func unsafe() -> Array:
	var out: Array = []
	for z in temp:
		var lim: float = float(cfg.get("spoil_T", 150.0))
		if zone_temp(z) > lim:
			out.append("zone %s %.0f C" % [z, zone_temp(z)])
	return out


func _physics_process(dt: float) -> void:
	if not active() or game == null or game.paused_sim or game.state != "play":
		return
	var amb: float = float(cfg.get("ambient", 20.0))
	var lp := looped()
	for z in temp:
		var k: float = float(cfg.zones[z].get("k", 0.002))
		if lp and (cfg.get("loop_zones", []) as Array).has(z):
			k *= float(cfg.get("loop_k", 4.0))
		temp[z] = amb + (float(temp[z]) - amb) * exp(-k * dt)
	# the drone in a zone still past burning
	if game.drone != null and game.drone.alive:
		var dp: Vector2 = game.drone.global_position / Geom.M
		for z in cfg.get("order", []):
			if zone_temp(z) < float(cfg.get("burn_T", 400.0)):
				continue
			var r: Array = cfg.zones[z].get("rect", [])
			if r.size() == 4 and dp.x >= float(r[0]) - 1.0 and dp.x <= float(r[2]) + 1.0 and dp.y >= float(r[1]) - 1.0 and dp.y <= float(r[3]) + 1.0:
				# a second's burn at a time (the thermal kit takes some of it off)
				game.hurt_drone(float(cfg.get("burn", 6.0)), game.drone.global_position, "heat_hit", "heat_zone", 1.0)
				if game.playtime - _burn_t > 4.0:
					_burn_t = game.playtime
					game.say("heat_burn", game.drone.global_position + Vector2(0, -70), z)
				break


func _shatter(p, why: String) -> void:
	if shattered.has(p.tag) or not p.intact:
		return
	shattered[p.tag] = true
	var at: Vector2 = world.frame(p) * Geom.centroid(p.poly)
	var was: float = p.value * clampf(p.cond, 0.0, 1.0)
	p.intact = false
	p.value = 0.0
	game.incident("tile_shatter", p.tag)
	game.say("tile_shatter", at, p.tag)
	game.note_loss("loss_tile_shatter", p.tag, was)
	game.fx.burst_shards(at, 12, 240.0, Pal.heat(0.8, 1.6), 5.0)
	game.sfx.play("crack")
	world.redraw_near([p])


func on_cut(p) -> void:
	if not active() or p == null:
		return
	var z := zone_of(p)
	if z != "" and is_tile(p) and zone_temp(z) > float(cfg.get("shatter_T", 300.0)):
		_shatter(p, "cut")


func on_freed(b) -> void:
	if not active():
		return
	for q in b.pieces:
		var z := zone_of(q)
		if z == "":
			continue
		var t := zone_temp(z)
		if is_tile(q) and t > float(cfg.get("shatter_T", 300.0)):
			_shatter(q, "freed")
		elif q.cls == "equip" and q.intact and not is_tile(q) and t > float(cfg.get("spoil_T", 150.0)) and not spoiled.has(q.tag):
			spoiled[q.tag] = true
			var before: float = q.cond
			game._dent(q, minf(q.cond, SPOIL_KEEP), "dv_heat_spoil")
			game.incident("heat_spoil", q.tag)
			game.say("heat_spoil", world.frame(q) * Geom.centroid(q.poly), q.tag)
			game.note_loss("loss_heat_spoil", q.tag, (before - q.cond) * q.value)
