extends Node
# A train of modules on couplers (exotic batch, MT-140 "Centipede": "seven modules
# on six couplers; the 400 V bus and the coolant run through every one of them;
# K-4 has jammed bent 8 degrees and carries the train's bending"). A ship file's
# "train":
#   {"jam": {"coupler": its piece, "pins": [its lock pins], "aft": [pieces aft of
#     it], "keep": t of them it can let go of quietly, "hits": [what it tears]},
#    "pumps": {fluid volume: the pump that draws it (on the bus)}}
#   A tank's pump draws it only while it has power: uncouple the bus upstream of it
#   first and it can't be drained until power comes back (a module's own battery).
#   The jammed coupler holds the bend: a pin of it undone, or the coupler cut,
#   while more than "keep" of the train aft of it is still on, and the bend lets go
#   — the aft train springs away, tearing what is either side. Take the train apart
#   from its tail (or strip what is aft) before K-4.
# Saved: whether the jam sprang.

const SPRING_KEEP := 0.5

var game
var world
var cfg := {}
var sprang := false
var _done := false            # the jam let go one way or the other
var _pump0 := {}
var _t := 0.0


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("train", {})
	var vols: Dictionary = ship.get("fluids", {}).get("volumes", {})
	for vk in cfg.get("pumps", {}):
		_pump0[vk] = vols.get(vk, {}).get("pump", [0.12, 0.008])


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"sprang": sprang}


func load_state(d: Dictionary) -> void:
	sprang = bool(d.get("sprang", false))
	_done = sprang


func powered(vk: String) -> bool:
	var p = world.tag(str(cfg.get("pumps", {}).get(vk, "")))
	return p != null and not p.gone and p.intact and p.body == null and game.sys.piece_volts(p) > 1.0


# what the pumps still have to draw
func fluid_left() -> float:
	var tot := 0.0
	for vk in cfg.get("pumps", {}):
		tot += game.sys.fluid(vk)
	return tot


# t of the train aft of the jam still on it
func aft_mass() -> float:
	var m := 0.0
	for t in cfg.get("jam", {}).get("aft", []):
		var p = world.tag(str(t))
		if p != null and not p.gone and p.body == null:
			m += float(p.mass)
	return m


func _physics_process(dt: float) -> void:
	if not active() or game == null or game.paused_sim or game.state != "play":
		return
	for vk in cfg.get("pumps", {}):
		if game.sys.fvol.has(vk):
			game.sys.fvol[vk].pump = _pump0[vk] if powered(vk) else [0.0, 0.0]
	_t += dt
	if _t < 0.2 or _done:
		return
	_t = 0.0
	var jm: Dictionary = cfg.get("jam", {})
	if jm.is_empty():
		return
	var gone := false
	for pt in jm.get("pins", []):
		if game.mech != null and game.mech._joint(str(pt)) == null:
			gone = true
	if gone:
		_check("pin")


func on_cut(p) -> void:
	if active() and not _done and p.tag == cfg.get("jam", {}).get("coupler", ""):
		_check("cut")


func _check(why: String) -> void:
	var jm: Dictionary = cfg.jam
	_done = true
	if aft_mass() <= float(jm.get("keep", 20.0)):
		return
	sprang = true
	# the bend lets go: every pin of it goes, the aft train springs away
	for pt in jm.get("pins", []):
		var j = game.mech._joint(str(pt)) if game.mech != null else null
		if j != null:
			world.kill_joint(j)
	var c = world.tag(jm.get("coupler", ""))
	var at: Vector2 = world.frame(c) * Geom.centroid(c.poly) if c != null else game.drone.global_position
	var lost := 0.0
	for t in jm.get("hits", []):
		var q = world.tag(str(t))
		if q == null or q.gone or q.cls != "equip" or not q.intact:
			continue
		var before: float = q.cond
		game._dent(q, minf(q.cond, SPRING_KEEP), "dv_train_spring")
		lost += (before - q.cond) * q.value
	game.incident("train_spring", why)
	game.say("train_spring", at, jm.get("coupler", ""))
	game.note_loss("loss_train_spring", jm.get("coupler", ""), lost)
	game.shake(0.9)
	game.sfx.play("snap")
