extends Node
# Superconducting magnets (FX-70 "Fusion Core", design/ships/02_新设计十艘_设计稿.md:
# "eight coil packs hold stored energy, run down slowly through the dump resistor with
# the dump switch closed and the cooling kept on; lose the cooling and the coils warm
# past their critical temperature and quench: the energy comes out at once, wrecking
# the coil and what is near it, and spreads to the coils beside it; cutting or freeing
# a coil's supports while it is energised quenches it too; the liquid helium is dear").
# A ship file's "supercon" (not "magnets": that is scripts/mech.gd's):
#   {"coils": {piece: {"next": [the coils beside it], "fix": [its supports], "line":
#    its helium line}}, "dump": the dump switch, "tau": seconds the dump takes to bring
#    the energy down by e, "plant": the cryoplant's cold box (it needs power), "he": the
#    liquid helium's volume, "he_min": what still cools, "T0": K, "Tc": K, "warm": K/s
#    without cooling, "cool": K/s back down with it, "safe": the energy fraction below
#    which a coil warms up harmlessly, "reach": metres a quench damages around it,
#    "boil": the helium fraction a quench boils off}
#   A coil quenches when it is above its critical temperature, or its supports are cut
#   or freed, or it is freed itself, while it holds more than "safe" of its energy.
#   A quench: the coil wrecked, equipment within reach damaged by how much energy it
#   held, helium boiled off, and the coils beside it quench a moment later if they
#   are still energised.
# Saved: each coil's energy and temperature, which quenched.

const WRECK_KEEP := 0.25
const SPREAD_T := 0.6            # s from one coil's quench to its neighbours'

var game
var world
var cfg := {}
var energy := {}                 # coil -> fraction of its stored energy left
var temp := {}                   # coil -> K
var quenched := {}
var _pending := {}               # coil -> time left before it quenches (spreading)
var _support_of := {}            # support piece tag -> its coil


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("supercon", {})
	for c in cfg.get("coils", {}):
		energy[c] = 1.0
		temp[c] = float(cfg.get("T0", 4.5))
		for f in cfg.coils[c].get("fix", []):
			_support_of[str(f)] = str(c)


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"energy": energy, "temp": temp, "quenched": quenched.keys()}


func load_state(d: Dictionary) -> void:
	for c in d.get("energy", {}):
		energy[str(c)] = float(d.energy[c])
	for c in d.get("temp", {}):
		temp[str(c)] = float(d.temp[c])
	for c in d.get("quenched", []):
		quenched[str(c)] = true


func field() -> float:
	var s := 0.0
	for c in energy:
		s += float(energy[c])
	return s / maxf(1, energy.size()) * 100.0


func max_temp() -> float:
	var t := 0.0
	for c in temp:
		t = maxf(t, float(temp[c]))
	return t


func energised(c: String) -> bool:
	return float(energy.get(c, 0.0)) > float(cfg.get("safe", 0.05)) and not quenched.has(c)


func any_energised() -> bool:
	return energy.keys().any(func(c): return energised(str(c)))


func cooled(c: String) -> bool:
	var plant = world.tag(str(cfg.get("plant", "")))
	if plant == null or plant.gone or plant.body != null or not plant.intact or game.sys.piece_volts(plant) < 1.0:
		return false
	if game.sys.fluid(str(cfg.get("he", ""))) < float(cfg.get("he_min", 0.03)):
		return false
	var ln: String = str(cfg.coils[c].get("line", ""))
	if ln != "" and world.lines.has(ln) and not world.lines[ln].alive:
		return false
	return true


func unsafe() -> Array:
	var out: Array = []
	for c in energy:
		if energised(str(c)):
			out.append("coil %s energised (%.0f %%)" % [c, float(energy[c]) * 100.0])
	return out


# for tests/salvage_bot.gd: the dump switch closed first, with the cooling still on
func bot_prep() -> Array:
	var d: String = str(cfg.get("dump", ""))
	if any_energised() and d != "" and not game.sys.on(d):
		return [[d, "magnet dump closed", 2.0]]
	return []


# for tests/salvage_bot.gd: the helium stays in while a coil still holds its energy
func hold_port(id: String) -> bool:
	if not any_energised():
		return false
	return game.sys.fluid_at_port(id) == str(cfg.get("he", ""))


# for tests/salvage_bot.gd: the cryoplant keeps its power while a coil does
func hold_power() -> bool:
	return any_energised()


func _physics_process(dt: float) -> void:
	if not active():
		return
	var dumping: bool = game.sys.on(str(cfg.get("dump", "")))
	var tau: float = maxf(1.0, float(cfg.get("tau", 35.0)))
	var tc: float = float(cfg.get("Tc", 9.0))
	var t0: float = float(cfg.get("T0", 4.5))
	for c in energy:
		if quenched.has(c):
			continue
		if dumping:
			energy[c] = float(energy[c]) * exp(-dt / tau)
		if cooled(c):
			temp[c] = maxf(t0, float(temp[c]) - float(cfg.get("cool", 0.2)) * dt)
		else:
			temp[c] = float(temp[c]) + float(cfg.get("warm", 0.04)) * dt
		if float(temp[c]) > tc and energised(c):
			_quench(c, "magnet_quench_warm")
	for c in _pending.keys():
		_pending[c] = float(_pending[c]) - dt
		if float(_pending[c]) <= 0.0:
			_pending.erase(c)
			if energised(c):
				_quench(c, "magnet_quench_spread")


func on_cut(p) -> void:
	if not active() or p == null:
		return
	var c: String = _support_of.get(p.tag, p.tag if cfg.get("coils", {}).has(p.tag) else "")
	if c != "" and energised(c):
		_quench(c, "magnet_quench_cut")


func on_freed(b) -> void:
	if not active():
		return
	for q in b.pieces:
		var c: String = _support_of.get(q.tag, q.tag if cfg.get("coils", {}).has(q.tag) else "")
		if c != "" and energised(c):
			_quench(c, "magnet_quench_cut")


func _quench(c: String, why: String) -> void:
	if quenched.has(c):
		return
	quenched[c] = true
	var e: float = float(energy[c])
	energy[c] = 0.0
	temp[c] = maxf(float(temp[c]), 80.0)
	var coil = world.tag(c)
	if coil == null:
		return
	var at: Vector2 = world.frame(coil) * Geom.centroid(coil.poly)
	var lost := 0.0
	if coil.intact:
		var b0: float = coil.cond
		game._dent(coil, minf(coil.cond, WRECK_KEEP), "dv_magnet_quench")
		lost += (b0 - coil.cond) * coil.value
	var reach: float = float(cfg.get("reach", 6.0)) * Geom.M
	for p in game._equip_near(at, reach):
		if p == coil or p.gone or not p.intact or cfg.coils.has(p.tag):
			continue
		var before: float = p.cond
		var k: float = 1.0 - clampf(at.distance_to(world.frame(p) * Geom.centroid(p.poly)) / reach, 0.0, 1.0)
		game._dent(p, maxf(0.0, p.cond - p.fragile * 0.8 * e * k), "dv_magnet_quench")
		lost += (before - p.cond) * p.value
	# the coil's helium flashes off through the relief
	var hv: String = str(cfg.get("he", ""))
	if game.sys.fvol.has(hv):
		game.sys.fvol[hv].amount = maxf(0.0, float(game.sys.fvol[hv].amount) * (1.0 - float(cfg.get("boil", 0.25))))
	for n in cfg.coils[c].get("next", []):
		if energised(str(n)) and not _pending.has(str(n)):
			_pending[str(n)] = SPREAD_T
	# the helium in the coil's channels flashes out as boiling liquid
	if game.liquids != null:
		game.liquids.spill(at, Vector2.ZERO, 0.05, "lhe", 10, TAU, 2.5, true)
	game.fx.flash(at, 5.0 * Geom.M, 0.5, Pal.heat(1.0, 2.0))
	game.fx.sparks(at, Vector2.UP, 30, Pal.heat(1.0, 2.0), 360.0, 0.5, PI)
	game.shake(0.35)
	game.sfx.play("boom", at, 0.7)
	game.incident("magnet_quench", c)
	game.say(why, at, c)
	game.note_loss("loss_magnet_quench", c, lost)
