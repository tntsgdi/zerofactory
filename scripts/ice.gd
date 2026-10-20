extends Node
# A hull of ice (exotic batch, IC-120 "Iceberg": "9,000 t of water ice held in a metal
# saddle; the ice is the cargo, the shield and the structure: it melts, refreezes and
# cracks; the water is what pays"). A ship file's "ice":
#   {"heaters": {switch: {"piece": the heater, "blocks": [ice blocks it melts, in order]}},
#    "water": m³ in each block, "melt_s": s a heater takes to melt a block,
#    "volume": the fluid volume the meltwater runs into (pumped out at its port),
#    "short": {"limit": m³ of standing meltwater, "hits": [what it shorts]},
#    "crack": {"blocks": [blocks the crack runs through], "holds": [the saddle seats'
#     hold switches either side of it], "hits": [what the split ice hits]},
#    "pads": {"holds": [every saddle seat's hold], "keep": fraction of the ice that may
#     still be left when a seat lets go, "hits": [what the ice drops on]},
#    "probe": the crack's strain probe target}
#   A heater melts its blocks one after another while it is switched on and powered; a
#   melted block is gone and its water is in "volume". Meltwater left standing over
#   "short.limit" with the bus live shorts what it reaches. An ice block on the crack cut
#   or freed while a seat beside the crack still holds: the crack runs and the ice
#   splits. A seat let go with more than "keep" of the ice still on it: the ice drops.
#   Cutting ice is slow: the kerf refreezes behind the beam (its cut_speed).
# Saved: each block's melt, which events happened.

var game
var world
var cfg := {}
var melt := {}               # block -> 0..1
var shorted := false
var split := false
var dropped := false
var _blocks0 := 0
var _was := {}


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("ice", {})
	if cfg.is_empty():
		return
	for h in cfg.get("heaters", {}):
		for b in cfg.heaters[h].get("blocks", []):
			melt[b] = 0.0
			_blocks0 += 1
	for t in cfg.get("pads", {}).get("holds", []):
		_was[t] = true
	# the frozen water counts in what the ship's water is worth
	var vol: Dictionary = g.sys.fvol.get(str(cfg.get("volume", "")), {})
	if not vol.is_empty():
		var f: String = vol.fluid
		g.sys.fluid0[f] = float(g.sys.fluid0.get(f, 0.0)) + float(cfg.get("water", 0.6)) * _blocks0
		if not g.sys.fluid_rec.has(f):
			g.sys.fluid_rec[f] = 0.0


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"melt": melt, "shorted": shorted, "split": split, "dropped": dropped}


func load_state(d: Dictionary) -> void:
	for b in d.get("melt", {}):
		melt[str(b)] = float(d.melt[b])
	shorted = bool(d.get("shorted", false))
	split = bool(d.get("split", false))
	dropped = bool(d.get("dropped", false))
	for t in cfg.get("pads", {}).get("holds", []):
		_was[t] = game.sys.on(str(t))


func _ice_piece(b: String):
	var p = world.tag(b)
	return p if p != null and not p.gone else null


func blocks_left() -> int:
	var n := 0
	for b in melt:
		if _ice_piece(b) != null:
			n += 1
	return n


func left_fraction() -> float:
	return float(blocks_left()) / maxf(1.0, _blocks0)


# the crack's strain, %: high while the seats beside it hold
func strain() -> float:
	var held := 0
	var holds: Array = cfg.get("crack", {}).get("holds", [])
	for t in holds:
		if game.sys.on(str(t)):
			held += 1
	if split:
		return 0.0
	return 20.0 + 70.0 * float(held) / maxf(1.0, holds.size())


func unsafe() -> Array:
	var out: Array = []
	if blocks_left() > 0:
		out.append("ice %d blocks" % blocks_left())
	return out


func _physics_process(dt: float) -> void:
	if not active() or game == null or game.paused_sim or game.state != "play":
		return
	var s = game.sys
	var vol: String = str(cfg.get("volume", ""))
	for h in cfg.get("heaters", {}):
		var e: Dictionary = cfg.heaters[h]
		if not s.on(str(h)):
			continue
		var hp = world.tag(str(e.get("piece", "")))
		if hp == null or hp.gone or s.piece_volts(hp) < 1.0:
			continue
		for b in e.get("blocks", []):
			var ip = _ice_piece(b)
			if ip == null:
				continue
			melt[b] = float(melt.get(b, 0.0)) + dt / float(cfg.get("melt_s", 20.0))
			var w: float = float(cfg.get("water", 0.6)) * dt / float(cfg.get("melt_s", 20.0))
			if s.fvol.has(vol):
				s.fvol[vol].amount = minf(float(s.fvol[vol].get("full", 99.0)), s.fvol[vol].amount + w)
			if melt[b] >= 1.0:
				world.remove_piece(ip)
				game.sfx.play("hiss")
			break
	# meltwater standing on live gear
	var sh: Dictionary = cfg.get("short", {})
	if not shorted and s.fvol.has(vol) and s.fvol[vol].amount > float(sh.get("limit", 3.0)) and s.bus_live:
		shorted = true
		_hit(sh.get("hits", []), 0.5, "melt_short")
	# a seat let go with the ice still on it
	var pd: Dictionary = cfg.get("pads", {})
	for t in pd.get("holds", []):
		var now: bool = s.on(str(t))
		if _was.get(t, true) and not now and not dropped and left_fraction() > float(pd.get("keep", 0.5)):
			dropped = true
			_hit(pd.get("hits", []), 0.5, "ice_drop")
		_was[t] = now


func _hit(tags: Array, keep: float, why: String) -> void:
	var lost := 0.0
	var at: Vector2 = game.drone.global_position
	for t in tags:
		var q = world.tag(str(t))
		if q == null or q.gone or q.cls != "equip" or not q.intact:
			continue
		var before: float = q.cond
		game._dent(q, minf(q.cond, keep), "dv_" + why)
		lost += (before - q.cond) * q.value
		at = world.frame(q) * Geom.centroid(q.poly)
	game.incident(why, "")
	game.say(why, at, "")
	game.note_loss("loss_" + why, "", lost)
	game.shake(0.6)
	game.sfx.play("snap")


func _check(p) -> void:
	var cr: Dictionary = cfg.get("crack", {})
	if split or not (cr.get("blocks", []) as Array).has(p.tag):
		return
	for t in cr.get("holds", []):
		if game.sys.on(str(t)):
			split = true
			_hit(cr.get("hits", []), 0.5, "crack_run")
			return


func on_cut(p) -> void:
	if active():
		_check(p)


func on_freed(b) -> void:
	if not active():
		return
	for q in b.pieces:
		_check(q)
