extends Node
# A furnace core that is shut down but not cool (R2 fleet, MF-126 "Molten Ridge":
# "shut down is not cooled: keep the heat exchange running, deal with the feed
# line, then take the core out"). A ship file's "furnace" section:
#   {"core": piece, "T0": °C, "safe": °C, "crit": °C, "cool": °C/s, "idle": °C/s,
#    "pumps": [pieces], "loop": fluid volume, "loop_min": fraction}
#   The core cools while its heat-exchange pumps have power and the cooling loop
#   is still full ("loop_min" of what it started with); otherwise it barely does.
#   Cooling lost while the core is still over "crit" (the power cut, the loop cut
#   or drained) and the core cracks from the thermal shock; lifted out over
#   "safe", the same. Cracked, it keeps CRACK_KEEP of its value.
#   A "core" probe reads the core's temperature.
# Saved: the core's temperature, whether it cracked.

const CRACK_KEEP := 0.4

var game
var world
var cfg := {}
var T := 20.0
var cracked := false
var _cooling_was := true
var _loop0 := 0.0


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("furnace", {})
	T = float(cfg.get("T0", 20.0))
	var v: Dictionary = ship.get("fluids", {}).get("volumes", {}).get(cfg.get("loop", ""), {})
	_loop0 = float(v.get("amount", 0.0))


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"T": T, "cracked": cracked}


func load_state(d: Dictionary) -> void:
	T = float(d.get("T", T))
	cracked = bool(d.get("cracked", false))


func hot() -> bool:
	return active() and not cracked and T > float(cfg.get("safe", 150.0))


func core_temp() -> float:
	return T


# what keeps the core cooling right now
func cooling() -> bool:
	var s = game.sys
	var lp: String = cfg.get("loop", "")
	if lp != "" and s.fluid(lp) < _loop0 * float(cfg.get("loop_min", 0.6)):
		return false
	for t in cfg.get("pumps", []):
		var p = world.tag(str(t))
		if p != null and not p.gone and p.intact and p.body == null and s.piece_volts(p) > 1.0:
			return true
	return false


func _physics_process(dt: float) -> void:
	if not active() or game == null or game.paused_sim or game.state != "play":
		return
	var c := cooling()
	var crit: float = float(cfg.get("crit", 350.0))
	if _cooling_was and not c and T > crit and not cracked:
		_crack("core_shock")
	_cooling_was = c
	var rate: float = float(cfg.get("cool", 4.0)) if c else float(cfg.get("idle", 0.1))
	T = maxf(20.0, T - rate * dt)


# the core lifted out of its cradle (its body freed) while still hot
func on_freed(b) -> void:
	if not active() or cracked:
		return
	for q in b.pieces:
		if q.tag == cfg.get("core", "") and T > float(cfg.get("safe", 150.0)):
			_crack("core_lifted_hot")


func _crack(why: String) -> void:
	cracked = true
	var p = world.tag(cfg.get("core", ""))
	var at: Vector2 = world.frame(p) * Geom.centroid(p.poly) if p != null else game.drone.global_position
	var lost := 0.0
	if p != null and not p.gone:
		lost = p.value * (1.0 - CRACK_KEEP)
		p.value *= CRACK_KEEP
		p.set_meta("cracked", true)
	game.incident("core_cracked", why)
	game.say(why, at, cfg.get("core", ""))
	game.note_loss("loss_core", cfg.get("core", ""), lost)
	game.shake(0.4)
	game.sfx.play("snap")
