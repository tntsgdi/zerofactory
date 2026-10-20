extends Node
# Vault doors (R2 fleet, ES-112 "Iron Oath": "each vault door has two electric
# lock circuits and a mechanical lock; open the maintenance path first, then move
# what is in custody out whole"). A ship file's "vaults" section:
#   {door tag: {"locks": [lock solenoid pieces], "release": control id}}
#   A vault door is no ordinary door: its control opens it only once every one of
#   its lock solenoids reads dead (both circuits: the main bus and the locks' own
#   backup supply, which also feeds back into the bus through them) and its
#   mechanical release has been thrown in the maintenance cabinet. It needs no
#   power of its own to swing. The release lever won't move against a live
#   solenoid.
# Saved through the controls themselves (the release's state, the door's).

var game
var world
var cfg := {}


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("vaults", {})


func active() -> bool:
	return not cfg.is_empty()


func _live(tags: Array) -> bool:
	for t in tags:
		var p = world.tag(str(t))
		if p != null and not p.gone and game.sys.piece_volts(p) > 1.0:
			return true
	return false


# the vault a release control belongs to ("" none)
func _of_release(id: String) -> String:
	for d in cfg:
		if cfg[d].get("release", "") == id:
			return d
	return ""


# a switch about to be thrown: true when the vault refuses it (the lever against a live lock)
func blocks_switch(c, at: Vector2) -> bool:
	var d := _of_release(c.id)
	if d == "" or c.state:
		return false
	if _live(cfg[d].get("locks", [])):
		game.say("vault_mr_live", at, c.id)
		game.sfx.play("deny")
		return true
	return false


# a door control on a vault door: true when the vault handled it
func operate(c, at: Vector2) -> bool:
	if not cfg.has(c.target):
		return false
	var e: Dictionary = cfg[c.target]
	var dp = world.tag(c.target)
	if dp == null:
		return true
	if not dp.door_open:
		if _live(e.get("locks", [])):
			game.say("vault_locked_live", at, c.id)
			game.sfx.play("deny")
			return true
		var rel = world.ctrls.get(e.get("release", ""))
		if rel != null and not rel.state:
			game.say("vault_locked_mech", at, c.id)
			game.sfx.play("deny")
			return true
	dp.door_open = not dp.door_open
	c.state = dp.door_open
	game.sfx.play("door")
	game.say("vault_open" if dp.door_open else "vault_shut", at, c.id)
	return true
