extends Node
# A drill string still in its derrick (DR-150 "Derrick", design/ships/02_新设计十艘_设计稿.md:
# "eight stands of drill pipe hold residual torque and mud pressure: bleed the torque at
# the rotary brake, open the relief and let the mud out (recoverable); then break the
# stands out one at a time from the top, each with its slips set below it; broken out
# with torque on, it whips and smashes the drill floor; with pressure, the mud blows
# out; out of order, the stands above it lose their support and drop").
# A ship file's "drillstring":
#   {"stands": [the stand pieces, the top one first], "slips": [the slip switch under
#    each stand: slips[k] holds stand k+1 and everything below it], "bleed": the torque
#    bleed switch, "tau": s to bleed it down by e, "mud": the mud's volume, "mud_safe":
#    the mud fraction below which breaking out is clean, "floor": [x0, y0, x1, y1] m of
#    the drill floor the whip smashes, "whip": what equipment there keeps, "spray": what
#    the mud leaves of what it sprays (within "reach" m of the stand)}
#   A stand freed with the torque still on (above 5 %): it whips round (cracked), and the
#   drill floor's equipment is smashed. With the mud still in: it blows out (lost), the
#   equipment around fouled. With a stand above it still in the string: those drop. With
#   the slips under it open: the string below drops down the hole.
# Saved: torque, which stands went wrong.

const SAFE_TQ := 0.05
const DROP_KEEP := 0.3

var game
var world
var cfg := {}
var torque := 1.0
var _mud0 := -1.0
var dropped := {}
var whipped := false
var blown := false
var _done := {}


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("drillstring", {})


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"torque": torque, "mud0": _mud0, "dropped": dropped.keys(), "whipped": whipped, "blown": blown, "done": _done.keys()}


func load_state(d: Dictionary) -> void:
	torque = float(d.get("torque", torque))
	_mud0 = float(d.get("mud0", _mud0))
	for k in d.get("dropped", []):
		dropped[str(k)] = true
	for k in d.get("done", []):
		_done[str(k)] = true
	whipped = bool(d.get("whipped", false))
	blown = bool(d.get("blown", false))


func mud_level() -> float:
	if _mud0 <= 0.0:
		return 1.0
	return clampf(game.sys.fluid(str(cfg.get("mud", ""))) / _mud0, 0.0, 1.0)


# what the gauges read: torque %, mud pressure kPa
func torque_pct() -> float:
	return torque * 100.0


func mud_kpa() -> float:
	return mud_level() * float(cfg.get("kpa", 3200.0))


func _in_string(tag: String) -> bool:
	var p = world.tag(tag)
	return p != null and not p.gone and p.body == null


func unsafe() -> Array:
	var out: Array = []
	if not _anything_left():
		return out
	if torque > SAFE_TQ:
		out.append("drill string torque %.0f %%" % torque_pct())
	if mud_level() > float(cfg.get("mud_safe", 0.05)):
		out.append("mud %.0f kPa" % mud_kpa())
	var stands: Array = cfg.get("stands", [])
	var slips: Array = cfg.get("slips", [])
	for k in slips.size():
		if k + 1 < stands.size() and _in_string(str(stands[k + 1])) and not game.sys.on(str(slips[k])):
			out.append("slips %s open" % slips[k])
	return out


func _anything_left() -> bool:
	return cfg.get("stands", []).any(func(t): return _in_string(str(t)))


func bot_prep() -> Array:
	var b: String = str(cfg.get("bleed", ""))
	if torque > SAFE_TQ and b != "" and not game.sys.on(b):
		return [[b, "rotary brake: the torque bled off", 2.0]]
	for s in cfg.get("slips", []):
		if not game.sys.on(str(s)):
			return [[str(s), "slips %s set" % s, 1.5]]
	return []


# for tests/salvage_bot.gd: the stands first, from the top down
func bot_order(order: Array) -> Array:
	var ids: Array = []
	for t in cfg.get("stands", []):
		var p = world.tag(str(t))
		if p != null and not p.gone and p.body == null:
			ids.append(p.id)
	return ids + order.filter(func(id): return not ids.has(id))


func _physics_process(dt: float) -> void:
	if not active():
		return
	if _mud0 < 0.0:
		_mud0 = maxf(0.001, game.sys.fluid(str(cfg.get("mud", ""))))
	if game.sys.on(str(cfg.get("bleed", ""))) and torque > 0.0:
		torque = maxf(0.0, torque * exp(-dt / maxf(1.0, float(cfg.get("tau", 20.0)))))
		if torque < 0.002:
			torque = 0.0


func on_cut(p) -> void:
	pass


func on_freed(b) -> void:
	if not active():
		return
	var stands: Array = cfg.get("stands", [])
	for q in b.pieces:
		var k: int = stands.find(q.tag)
		if k < 0 or _done.has(q.tag):
			continue
		_done[q.tag] = true
		var at: Vector2 = world.frame(q) * Geom.centroid(q.poly)
		if torque > SAFE_TQ:
			_whip(q, at)
		if mud_level() > float(cfg.get("mud_safe", 0.05)):
			_blowout(q, at)
		# a stand above it still in the string: they had stood on this one
		var above: Array = []
		for j in k:
			if _in_string(str(stands[j])) and not dropped.has(str(stands[j])):
				above.append(str(stands[j]))
		if not above.is_empty():
			_drop(above, q.tag, "drill_drop_above")
		# the slips under it open: the rest of the string goes down the hole
		var slips: Array = cfg.get("slips", [])
		if k < slips.size() and not game.sys.on(str(slips[k])):
			var below: Array = []
			for j in range(k + 1, stands.size()):
				if _in_string(str(stands[j])) and not dropped.has(str(stands[j])):
					below.append(str(stands[j]))
			if not below.is_empty():
				_drop(below, q.tag, "drill_drop_below")


func _whip(q, at: Vector2) -> void:
	whipped = true
	var lost := 0.0
	if q.intact:
		var b0: float = q.cond
		game._dent(q, minf(q.cond, 0.2), "dv_drill_whip")
		lost += (b0 - q.cond) * q.value
	var f: Array = cfg.get("floor", [0, 0, 0, 0])
	var r := Rect2(Vector2(f[0], f[1]) * Geom.M, Vector2(float(f[2]) - float(f[0]), float(f[3]) - float(f[1])) * Geom.M)
	var keep: float = float(cfg.get("whip", 0.4))
	for id in world.order:
		var p = world.pieces[id]
		if p.gone or p.cls != "equip" or not p.intact or p == q or p.body != null or cfg.stands.has(p.tag):
			continue
		if r.has_point(world.frame(p) * Geom.centroid(p.poly)):
			var before: float = p.cond
			game._dent(p, minf(p.cond, maxf(keep, p.cond - p.fragile)), "dv_drill_whip")
			lost += (before - p.cond) * p.value
	game.shake(0.45)
	game.sfx.play("snap", at, 1.0)
	game.fx.sparks(at, Vector2.RIGHT, 30, Pal.heat(1.0, 2.0), 420.0, 0.4, PI)
	game.incident("drill_whip", q.tag)
	game.say("drill_whip", at, q.tag)
	game.note_loss("loss_drill_whip", q.tag, lost)


func _blowout(q, at: Vector2) -> void:
	blown = true
	var vk: String = str(cfg.get("mud", ""))
	var gush := 0.0
	if game.sys.fvol.has(vk):
		gush = float(game.sys.fvol[vk].amount)
		game.sys.fluid_lost += gush
		game.sys.fvol[vk].amount = 0.0
	if game.liquids != null:
		game.liquids.spill(at, Vector2.UP, minf(gush, 2.0) * 0.6, "mud", 34, 1.4, 3.5, true)
	var lost := 0.0
	var keep: float = float(cfg.get("spray", 0.6))
	for p in game._equip_near(at, float(cfg.get("reach", 8.0)) * Geom.M):
		if p.body != null or cfg.stands.has(p.tag):
			continue
		var before: float = p.cond
		game._dent(p, minf(p.cond, maxf(keep, p.cond - 0.4)), "dv_mud_fouled")
		lost += (before - p.cond) * p.value
	for i in 8:
		game.fx.puff(at, Vector2.from_angle(-PI * 0.5 + randf_range(-0.8, 0.8)) * 220.0, 1.6, 14.0, 70.0, Pal.ink(0.12))
	game.sfx.play("hiss", at, 1.0)
	game.incident("mud_blowout", q.tag)
	game.say("mud_blowout", at, q.tag)
	game.note_loss("loss_mud_blowout", q.tag, lost)


func _drop(tags: Array, by: String, key: String) -> void:
	var lost := 0.0
	var at := Vector2.ZERO
	for t in tags:
		dropped[t] = true
		var p = world.tag(t)
		if p == null or not p.intact:
			continue
		var b0: float = p.cond
		game._dent(p, minf(p.cond, DROP_KEEP), "dv_drill_drop")
		lost += (b0 - p.cond) * p.value
		at = world.frame(p) * Geom.centroid(p.poly)
	game.shake(0.3)
	game.sfx.play("clank", at, 1.0)
	game.incident("drill_drop", by)
	game.say(key, at, by)
	game.note_loss("loss_drill_drop", by, lost)
