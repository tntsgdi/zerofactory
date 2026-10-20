extends Node
# Racks run immersed in dielectric fluid, and data under custody (DC-84 "Deep Mind",
# design/ships/02_新设计十艘_设计稿.md: "each rack stands in a tank of fluid: lift it
# out with the tank still full and it spills, shorting the racks beside it; the storage
# drives are the client's, to be locked into the shielded transport bays first").
# A ship file's "immersion":
#   {"tanks": {rack piece: {"vol": the tank's fluid volume, "row": [the racks beside
#    it]}}, "min": what counts as drained, "drives": {drive piece: its custody latch
#    (a switch)}, "fine": what an uncased drive taken out costs}
#   A rack freed with its tank's fluid still in it: the fluid spills (lost), the rack
#   and the racks beside it short (damaged). A drive freed with its custody latch open:
#   a breach of custody, fined; latched, it is the client's sealed property, whole.
# Saved: which racks spilt, which drives were breached.

const SPILL_KEEP := 0.6
const SHORT_KEEP := 0.5

var game
var world
var cfg := {}
var spilt := {}
var breached := {}


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("immersion", {})


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"spilt": spilt.keys(), "breached": breached.keys()}


func load_state(d: Dictionary) -> void:
	for t in d.get("spilt", []):
		spilt[str(t)] = true
	for t in d.get("breached", []):
		breached[str(t)] = true


func full(rack: String) -> bool:
	var e: Dictionary = cfg.get("tanks", {}).get(rack, {})
	return not e.is_empty() and game.sys.fluid(str(e.get("vol", ""))) > float(cfg.get("min", 0.02))


func cased(drive: String) -> bool:
	return game.sys.on(str(cfg.get("drives", {}).get(drive, "")))


func unsafe() -> Array:
	var out: Array = []
	for d in cfg.get("drives", {}):
		var p = world.tag(str(d))
		if p != null and not p.gone and p.body == null and not cased(d):
			out.append("drive %s not in custody" % d)
	return out


func _physics_process(_dt: float) -> void:
	pass


func on_cut(_p) -> void:
	pass


func on_freed(b) -> void:
	if not active():
		return
	for q in b.pieces:
		if cfg.get("tanks", {}).has(q.tag) and full(q.tag) and not spilt.has(q.tag):
			_spill(q)
		if cfg.get("drives", {}).has(q.tag) and not cased(q.tag) and not breached.has(q.tag):
			_breach(q)


func _spill(q) -> void:
	spilt[q.tag] = true
	var e: Dictionary = cfg.tanks[q.tag]
	var s = game.sys
	var vk: String = str(e.get("vol", ""))
	if s.fvol.has(vk):
		if game.liquids != null:
			var q_at: Vector2 = world.frame(q) * Geom.centroid(q.poly)
			game.liquids.spill(q_at, Vector2.UP, float(s.fvol[vk].amount) * 0.6, "glycol", 18, PI, 0.8, true)
		s.fvol[vk].amount = 0.0
	var lost := 0.0
	var at: Vector2 = world.frame(q) * Geom.centroid(q.poly)
	if q.intact:
		var b0: float = q.cond
		game._dent(q, minf(q.cond, SPILL_KEEP), "dv_immersion_spill")
		lost += (b0 - q.cond) * q.value
	for t in e.get("row", []):
		var n = world.tag(str(t))
		if n == null or n.gone or not n.intact:
			continue
		var before: float = n.cond
		game._dent(n, minf(n.cond, SHORT_KEEP), "dv_immersion_short")
		lost += (before - n.cond) * n.value
		game.fx.arc(world.frame(n) * Geom.centroid(n.poly), at, 0.25, 0.6)
	game.incident("immersion_spill", q.tag)
	game.say("immersion_spill", at, q.tag)
	game.note_loss("loss_immersion_spill", q.tag, lost)
	game.sfx.play("arc")


func _breach(q) -> void:
	breached[q.tag] = true
	var at: Vector2 = world.frame(q) * Geom.centroid(q.poly)
	var fine: float = float(cfg.get("fine", 20000.0))
	game.incident("custody_breach", q.tag)
	game.say("custody_breach", at, q.tag)
	game.lose("loss_custody", fine, at)
