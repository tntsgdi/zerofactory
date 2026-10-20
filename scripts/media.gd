extends Node
# Media that look alike (R2 fleet, FL-116 "Tide": "the pipework looks like one,
# but three media have to be told apart, isolated and recovered branch by
# branch"). A ship file's "media" section:
#   {"branches": {id: {"vol": fluid volume, "valve": its branch valve,
#     "port": the manifold port it comes out at, "sample": its sample point}},
#    "manifold": piece}
#   The branches cross on the way to the manifold: a port's number says nothing of
#   what comes out of it. A sample point reads the medium at its port.
#   Drawn off through its port while another branch's valve is still open, a
#   branch's medium mixes in the manifold: what comes out is mixed waste (worth
#   nothing, a disposal charge).
#   The manifold freed or cut into while a branch still holds its medium: the
#   branches spill through it.
# Saved: what has been spoilt as mixed, whether the manifold spilt.

const SPILL_MIN := 0.05

var game
var world
var cfg := {}
var mixed := 0.0              # medium spoilt as mixed waste
var spilt := false
var _was := {}                # branch -> its volume's amount last frame
var _told := false
var _owed := 0.0              # the mixed waste's charge, settled once a second
var _owed_t := 0.0


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("media", {})


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"mixed": mixed, "spilt": spilt}


func load_state(d: Dictionary) -> void:
	mixed = float(d.get("mixed", 0.0))
	spilt = bool(d.get("spilt", false))


func branches() -> Dictionary:
	return cfg.get("branches", {})


# the branch whose sample point this is, its medium and how full it is
func sample(id: String) -> Array:
	for b in branches():
		var e: Dictionary = branches()[b]
		if e.get("sample", "") == id or b == id:
			var v: Dictionary = game.sys.fvol.get(e.vol, {})
			var amt := float(v.get("amount", 0.0))
			return [amt, "%s · %.2f m³" % [Txt.t("med_" + str(v.get("fluid", ""))), amt]]
	return [0.0, "—"]


# the branch a manifold port draws, or ""
func branch_of_port(port: String) -> String:
	for b in branches():
		if branches()[b].get("port", "") == port:
			return b
	return ""


func _open_others(b: String) -> bool:
	for o in branches():
		if o == b:
			continue
		var vc: String = branches()[o].get("valve", "")
		if vc != "" and world.ctrls.has(vc) and world.ctrls[vc].state:
			return true
	return false


func _physics_process(dt: float) -> void:
	if not active() or game == null or game.state != "play":
		return
	_owed_t += dt
	if _owed_t > 1.0 and _owed > 1.0:
		var at: Vector2 = world.ctrl_world(world.ctrls[branches().values()[0].port])
		game.lose("loss_mixed", snappedf(_owed, 10.0), at + Vector2(0, -50))
		_owed = 0.0
		_owed_t = 0.0
	var s = game.sys
	for b in branches():
		var e: Dictionary = branches()[b]
		var v: Dictionary = s.fvol.get(e.vol, {})
		if v.is_empty():
			continue
		var now: float = float(v.amount)
		var was: float = float(_was.get(b, now))
		_was[b] = now
		var drawn := was - now
		if drawn <= 0.0 or not s.hoses.has(e.get("port", "")):
			continue
		# a branch shut at its own valve delivers nothing to mix
		var own: String = e.get("valve", "")
		if own != "" and world.ctrls.has(own) and not world.ctrls[own].state:
			continue
		if not _open_others(b):
			continue
		# what came out of that port wasn't one medium: mixed waste
		var f: String = str(v.fluid)
		s.fluid_rec[f] = maxf(0.0, float(s.fluid_rec.get(f, 0.0)) - drawn)
		mixed += drawn
		if not _told:
			_told = true
			game.incident("media_mixed", b)
			game.say("media_mixed", world.ctrl_world(world.ctrls[e.port]), e.port)
		_owed += drawn * 2500.0


# the manifold coming out (freed or cut) while a branch still holds its medium
func on_manifold(p) -> void:
	if not active() or spilt or p.tag != cfg.get("manifold", ""):
		return
	var s = game.sys
	var full: Array = []
	for b in branches():
		var v: Dictionary = s.fvol.get(branches()[b].vol, {})
		if float(v.get("amount", 0.0)) > SPILL_MIN:
			full.append(b)
	if full.is_empty():
		return
	spilt = true
	var at: Vector2 = world.frame(p) * Geom.centroid(p.poly)
	game.incident("manifold_spill", p.tag)
	game.say("manifold_spill", at, p.tag)
	var lost := 0.0
	for b in full:
		var v: Dictionary = s.fvol[branches()[b].vol]
		var amt: float = float(v.amount) * 0.6
		v.amount -= amt
		s.fluid_lost += amt
		lost += amt * 2500.0
	game.lose("loss_spill", lost + 3000.0, at + Vector2(0, -50))
