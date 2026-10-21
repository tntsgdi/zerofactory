extends Node2D
# A ship carried inside a ship (LC-140 "Shell Mountain", design/ships/02_新设计十艘_设计稿.md:
# "the contract wants the small ship out whole, priced as one, far above its parts:
# make it safe first (its battery, its fuel, its air), then the cradle locks from the
# stern forward, the bow door open, and out it slides along the cradle; cut any of its
# hull and it is only parts").
# A ship file's "nested":
#   {"pieces": [every piece of the small ship], "hull": [its hull pieces], "room": its
#    cabin, "battery": its battery switch (safe open), "fuel": its fuel volume, "locks":
#    [the cradle lock switches, the stern's first], "door": the hold's bow door piece,
#    "door_ctrl": its control, "winch": the winch switch, "winch_piece": the winch (it
#    needs power), "bonus": what the ship pays whole over its parts, "lurch_keep": the
#    bonus kept after it lurched into the door, "lurch_dent": what its equipment keeps,
#    "exit": [dx, dy] m it slides out by, "time": s}
#   A bow-side lock released while one aft of it still holds: the ship pivots on it
#   and lurches into the bow door (the bonus cut, its fittings knocked).
#   A hull piece cut or taken off: it is no longer whole (no bonus).
#   The winch thrown with the ship ready: it goes out whole, paid as one.
# Saved: whole, lurched, out.

var game
var world
var cfg := {}
var whole := true
var lurched := false
var out := false
var _released := {}
var _winch_was := false
var _ghost: Array = []         # [world polygon] of the ship as it went
var _ghost_t := -1.0
var _hull := {}
var _mine := {}


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("nested", {})
	z_index = 30
	for t in cfg.get("hull", []):
		_hull[str(t)] = true
	for t in cfg.get("pieces", []):
		_mine[str(t)] = true


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"whole": whole, "lurched": lurched, "out": out, "released": _released.keys()}


func load_state(d: Dictionary) -> void:
	whole = bool(d.get("whole", true))
	lurched = bool(d.get("lurched", false))
	out = bool(d.get("out", false))
	for k in d.get("released", []):
		_released[str(k)] = true


# 1 once the small ship is out (the special course's test)
func is_out() -> float:
	return 1.0 if out else 0.0


func _on(id: String) -> bool:
	return game.sys.on(id)


func locks_held() -> Array:
	return cfg.get("locks", []).filter(func(l): return _on(str(l)))


func hazards() -> Array:
	var out_h: Array = []
	if str(cfg.get("battery", "")) != "" and _on(str(cfg.battery)):
		out_h.append("battery")
	if game.sys.fluid(str(cfg.get("fuel", ""))) > 0.02:
		out_h.append("fuel")
	if game.sys.P(str(cfg.get("room", ""))) > 5.0:
		out_h.append("air")
	return out_h


func door_open() -> bool:
	var d = world.tag(str(cfg.get("door", "")))
	return d == null or d.gone or d.door_open


func _winch_live() -> bool:
	var p = world.tag(str(cfg.get("winch_piece", "")))
	return p != null and not p.gone and p.body == null and game.sys.piece_volts(p) > 1.0


# what still stands between the ship and the winch
func blockers() -> Array:
	var b: Array = []
	b.append_array(hazards())
	if not locks_held().is_empty():
		b.append("locks")
	if not door_open():
		b.append("door")
	if not _winch_live():
		b.append("winch")
	return b


func unsafe() -> Array:
	return [] if out else ["the small ship still aboard (%s)" % ", ".join(blockers())]


# for tests/salvage_bot.gd: its battery off, the locks from the stern, the bow door once
# the hold is empty of air, then the winch
func bot_prep() -> Array:
	if out:
		return []
	var bat: String = str(cfg.get("battery", ""))
	if bat != "" and _on(bat):
		return [[bat, "the small ship's battery off", 2.0]]
	for l in cfg.get("locks", []):
		if _on(str(l)):
			return [[str(l), "cradle lock %s released" % l, 2.0]]
	if not hazards().is_empty():
		return []
	var hold: String = str(cfg.get("hold", ""))
	if not door_open() and (hold == "" or game.sys.P(hold) < 5.0):
		return [[str(cfg.get("door_ctrl", "")), "the bow door open", 3.0]]
	if blockers().is_empty() and not _on(str(cfg.get("winch", ""))):
		return [[str(cfg.get("winch", "")), "winch the small ship out", 3.0]]
	return []


func hold_power() -> bool:
	return not out


func _physics_process(dt: float) -> void:
	if not active():
		return
	if _ghost_t >= 0.0:
		_ghost_t += dt
		queue_redraw()
		if _ghost_t > float(cfg.get("time", 12.0)) + 1.0:
			_ghost_t = -1.0
			_ghost = []
	if out:
		return
	var locks: Array = cfg.get("locks", [])
	for i in locks.size():
		var l: String = str(locks[i])
		if _released.has(l) or _on(l):
			continue
		_released[l] = true
		# a lock let go while one aft of it still holds: the ship pivots on that one
		for j in i:
			if _on(str(locks[j])):
				_lurch(l)
				break
	var wn: String = str(cfg.get("winch", ""))
	var won: bool = _on(wn)
	if won and not _winch_was:
		var why := blockers()
		if why.is_empty():
			_extract()
		else:
			var c = world.ctrls.get(wn)
			game.say("nested_not_ready", world.ctrl_world(c) if c != null else Vector2.ZERO, ", ".join(why.map(func(k): return game.txt("nb_" + k))))
			game.sfx.play("deny")
	_winch_was = won


func _lurch(by: String) -> void:
	if lurched:
		return
	lurched = true
	var lost := 0.0
	var keep: float = float(cfg.get("lurch_dent", 0.5))
	var at := Vector2.ZERO
	for t in _mine:
		var p = world.tag(t)
		if p == null or p.gone or p.body != null or p.cls != "equip" or not p.intact:
			continue
		var before: float = p.cond
		game._dent(p, maxf(0.0, p.cond - p.fragile * (1.0 - keep)), "dv_nested_lurch")
		lost += (before - p.cond) * p.value
		at = world.frame(p) * Geom.centroid(p.poly)
	if whole:
		lost += float(cfg.get("bonus", 0.0)) * (1.0 - float(cfg.get("lurch_keep", 0.5)))
	game.shake(0.4)
	game.sfx.play("boom", at, 0.6)
	game.incident("nested_lurch", by)
	game.say("nested_lurch", at, by)
	game.note_loss("loss_nested_lurch", by, lost)


func on_cut(p) -> void:
	if active() and p != null and not out and whole and _hull.has(p.tag):
		_broken(p.tag)


func on_freed(b) -> void:
	if not active() or out or not whole:
		return
	for q in b.pieces:
		if _hull.has(q.tag):
			_broken(q.tag)
			return


func _broken(by: String) -> void:
	whole = false
	var p = world.tag(by)
	var at: Vector2 = world.frame(p) * Geom.centroid(p.poly) if p != null else Vector2.ZERO
	game.incident("nested_cut", by)
	game.say("nested_cut", at, by)
	game.note_loss("loss_nested_whole", by, float(cfg.get("bonus", 0.0)) * (float(cfg.get("lurch_keep", 0.5)) if lurched else 1.0))


func bonus_now() -> float:
	if not whole:
		return 0.0
	return float(cfg.get("bonus", 0.0)) * (float(cfg.get("lurch_keep", 0.5)) if lurched else 1.0)


# out it goes, paid as one: its parts as they are, and the bonus if it is whole
func _extract() -> void:
	out = true
	var v := 0.0
	var names: Array = []
	var at := Vector2.ZERO
	var n := 0
	_ghost = []
	for t in cfg.get("pieces", []):
		var p = world.tag(str(t))
		if p == null or p.gone or p.body != null:
			continue
		v += game.piece_value(p, "equip" if p.cls == "equip" else "metal")
		if p.cls == "equip" and p.tag != "":
			names.append(p.tag)
		var wp: PackedVector2Array = world.world_poly(p)
		_ghost.append(wp)
		at += Geom.centroid(wp)
		n += 1
		world.remove_piece(p)
	v += bonus_now()
	at = at / maxf(1, n)
	_ghost_t = 0.0
	game.ledger.append([game.txt("nested_whole") if whole else game.txt("nested_parts"), "equip", v])
	game.log_op("deliver_equip")
	game.gain("equip", v, at, game.txt("nested_whole") if whole else game.txt("nested_parts"))
	game.sfx.play("release", at, 0.8)
	game.say("nested_out", at, Pal.money(v))
	world.dirty_links = true
	queue_redraw()


# ---------------------------------------------------------------- drawing

# the ship sliding out of the bow door along its cradle, fading as it goes
func _draw() -> void:
	if _ghost_t < 0.0 or _ghost.is_empty():
		return
	var tt: float = float(cfg.get("time", 12.0))
	var k: float = clampf(_ghost_t / tt, 0.0, 1.0)
	var ease_k: float = k * k * (3.0 - 2.0 * k)
	var e: Array = cfg.get("exit", [-60.0, 0.0])
	var off := Vector2(float(e[0]), float(e[1])) * Geom.M * ease_k
	var al: float = 0.55 * (1.0 - clampf((_ghost_t - tt) / 1.0, 0.0, 1.0))
	for wp in _ghost:
		var q := PackedVector2Array()
		for v in wp:
			q.append(v + off)
		q.append(q[0])
		draw_polyline(q, Pal.ink(al), 1.0, true)
