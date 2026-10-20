extends Node
# Inflatable bags on a rigid spine (exotic batch, IH-55 "Puffer": "four 19-21 m
# bags, no flat plate anywhere; cut the straps and they whip, cut a bag still
# inflated and it comes down over the equipment"). A ship file's "softshell":
#   {"bags": {bag piece: {"vessel": its gas, "straps": [strap pieces],
#     "tensioner": its tensioner control (on: taut), "near": [what it would come
#     down on], "patch": a patch on it ("" none), "side": -1 above the spine / 1
#     below}}, "flat": kPa under which a bag is slack}
#   A bag holds its shape only by its pressure: let down under "flat" it folds
#   flat against the spine. Cut into while still inflated it rips and comes down
#   at once over what is near it (badly damaged), and over the drone if it is in
#   the way. A strap cut or freed while its bag's tensioner is taut whips into
#   what is near. A patch on a bag still inflated, cut or freed, blows out and
#   rips the bag the same way.
# Saved: which bags folded, which ripped, which straps whipped.

const RIP_KEEP := 0.5
const WHIP_KEEP := 0.6

var game
var world
var cfg := {}
var folded := {}              # bag -> true
var ripped := {}              # bag -> true
var whipped := {}             # strap -> true
var _t := 0.0


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("softshell", {})


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"folded": folded.keys(), "ripped": ripped.keys(), "whipped": whipped.keys()}


func load_state(d: Dictionary) -> void:
	for t in d.get("whipped", []):
		whipped[str(t)] = true
	for t in d.get("ripped", []):
		ripped[str(t)] = true
	for t in d.get("folded", []):
		_fold(str(t))


func inflated(bag: String) -> bool:
	var e: Dictionary = cfg.bags.get(bag, {})
	return not ripped.has(bag) and game.sys.P(str(e.get("vessel", ""))) >= float(cfg.get("flat", 3.0))


func taut(bag: String) -> bool:
	return game.sys.on(str(cfg.bags.get(bag, {}).get("tensioner", "")))


func _bag_of_strap(t: String) -> String:
	for b in cfg.bags:
		if (cfg.bags[b].get("straps", []) as Array).has(t):
			return b
	return ""


func _bag_of_patch(t: String) -> String:
	for b in cfg.bags:
		if str(cfg.bags[b].get("patch", "")) == t:
			return b
	return ""


func _physics_process(dt: float) -> void:
	if not active() or game == null or game.paused_sim or game.state != "play":
		return
	_t += dt
	if _t < 0.25:
		return
	_t = 0.0
	for b in cfg.bags:
		if not folded.has(b) and not inflated(b):
			_fold(b)


# let down: the bag folds flat against the spine
func _fold(b: String) -> void:
	folded[b] = true
	var p = world.tag(b)
	if p == null or p.gone or p.body != null:
		return
	var bb := Geom.bbox(p.poly)
	var side: float = float(cfg.bags[b].get("side", -1))
	var edge: float = bb.end.y if side < 0.0 else bb.position.y
	var th := 1.4 * Geom.M
	var x0 := bb.position.x + bb.size.x * 0.1
	var x1 := bb.end.x - bb.size.x * 0.1
	var pts := PackedVector2Array()
	for i in 9:
		var f := float(i) / 8.0
		pts.append(Vector2(lerpf(x0, x1, f), edge + side * th * sin(PI * f)))
	p.poly = pts
	world.rebuild_cols(p)
	world.redraw_all()


func _rip(b: String, why: String) -> void:
	if ripped.has(b):
		return
	ripped[b] = true
	var e: Dictionary = cfg.bags[b]
	var vk: String = e.get("vessel", "")
	var p = world.tag(b)
	var at: Vector2 = world.frame(p) * Geom.centroid(p.poly) if p != null else game.drone.global_position
	var r := 0.0
	if p != null:
		var bb := Geom.bbox(world.frame(p) * p.poly)
		r = maxf(bb.size.x, bb.size.y) * 0.5
	if game.sys.vols.has(vk):
		game.sys.vols[vk].n = 0.0
	var lost := 0.0
	for t in e.get("near", []):
		var q = world.tag(str(t))
		if q == null or q.gone or q.cls != "equip" or not q.intact:
			continue
		var before: float = q.cond
		game._dent(q, minf(q.cond, RIP_KEEP), "dv_bag_rip")
		lost += (before - q.cond) * q.value
	if game.drone.global_position.distance_to(at) < r + 2.0 * Geom.M:
		game.hurt_drone(20.0, at, "bag_rip", "bag_rip", 1.0)
	game.incident("bag_rip", why)
	game.say("bag_rip", at, b)
	game.note_loss("loss_bag_rip", b, lost)
	game.shake(0.5)
	_fold(b)


func on_cut(p) -> void:
	if not active():
		return
	if cfg.bags.has(p.tag):
		if inflated(p.tag):
			_rip(p.tag, p.tag)
		return
	var pb := _bag_of_patch(p.tag)
	if pb != "" and inflated(pb):
		_rip(pb, p.tag)
		return
	_strap(p.tag)


func on_freed(b) -> void:
	if not active():
		return
	for q in b.pieces:
		var pb := _bag_of_patch(q.tag)
		if pb != "" and inflated(pb):
			q.body.linear_velocity = Vector2(0, float(cfg.bags[pb].get("side", -1)) * 6.0) * Geom.M if q.body != null else Vector2.ZERO
			_rip(pb, q.tag)
		_strap(q.tag)


func _strap(t: String) -> void:
	var b := _bag_of_strap(t)
	if b == "" or whipped.has(t) or not taut(b):
		return
	whipped[t] = true
	var p = world.tag(t)
	var at: Vector2 = world.frame(p) * Geom.centroid(p.poly)
	var lost := 0.0
	for n in cfg.bags[b].get("near", []):
		var q = world.tag(str(n))
		if q == null or q.gone or q.cls != "equip" or not q.intact:
			continue
		var before: float = q.cond
		game._dent(q, minf(q.cond, WHIP_KEEP), "dv_strap_whip")
		lost += (before - q.cond) * q.value
	game.incident("strap_whip", t)
	game.say("strap_whip", at, t)
	game.note_loss("loss_strap_whip", t, lost)
	game.shake(0.4)
	game.sfx.play("snap")
