extends Node
# A tethered pair still turning (exotic batch, TB-180 "Binary": "two 16 m pods on one
# 148 m tether, the pair turning at 2.0 rpm; the tether at 40 kN is the ship's only
# structure; the berth's brake in the middle is the only way to stop it"). A ship file's
# "tether":
#   {"rpm": at the start, "safe": rpm under which the tether may come apart,
#    "kn": its pull at the starting rpm (it goes with rpm²), "residual": the pull the
#    brake's tensioner still holds once it is stopped, "release": that tensioner's switch,
#    "brake": {"switch", "cool", "rate": rpm/s it takes off, "slip": s braked dry before
#     its rollers slip for good, "rollers": [pieces]},
#    "rcs": {"switch", "rate": rpm/s, "fuel": [volumes it burns], "use": m³/s, "live": a
#     piece that must be powered},
#    "segments": [the tether's pieces], "worn": the worn segment, "strands": [left, of],
#    "pods": [what the pods carry: thrown, it is knocked about]}
#   The pair keeps turning on its own. Braked with its cooling on it slows; braked dry
#   it slows too but heats, and after "slip" s the rollers slip for good: from then on
#   only the B pod's RCS can stop it (powered, with propellant). A tether segment cut or
#   freed while the pair still turns: both pods are thrown off along the tangent (what
#   they carry is knocked about). Cut while the tether still pulls (the tensioner on):
#   it whips, and if its worn segment is still in it the whole tether parts.
# Saved: the rpm, the brake's heat, whether it slipped, whether the pods were thrown,
# whether the tether parted.

const THROW_KEEP := 0.5
const WHIP_KEEP := 0.7
const SNAP_KEEP := 0.2
const PULL_MIN := 2.0             # kN under which a cut is quiet

var game
var world
var cfg := {}
var rpm := 0.0
var heat := 0.0
var slipped := false
var thrown := false
var snapped := false


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("tether", {})
	rpm = float(cfg.get("rpm", 0.0))


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"rpm": rpm, "heat": heat, "slipped": slipped, "thrown": thrown, "snapped": snapped}


func load_state(d: Dictionary) -> void:
	rpm = float(d.get("rpm", rpm))
	heat = float(d.get("heat", 0.0))
	slipped = bool(d.get("slipped", false))
	thrown = bool(d.get("thrown", false))
	snapped = bool(d.get("snapped", false))


func spinning() -> bool:
	return rpm > float(cfg.get("safe", 0.1)) and not thrown


func pull() -> float:
	if snapped:
		return 0.0
	var r0: float = maxf(0.01, float(cfg.get("rpm", 2.0)))
	var k: float = float(cfg.get("kn", 40.0)) * pow(rpm / r0, 2.0) if not thrown else 0.0
	if game.sys.on(str(cfg.get("release", ""))):
		k += float(cfg.get("residual", 8.0))
	return k


# the brake's temperature, °C
func temp() -> float:
	return 20.0 + heat * 30.0


# what the worn segment has left (of its strands), or all of them
func strands() -> float:
	var st: Array = cfg.get("strands", [7, 7])
	var w = world.tag(str(cfg.get("worn", "")))
	return float(st[0]) if w != null and not w.gone and not snapped else float(st[1])


func unsafe() -> Array:
	var out: Array = []
	if spinning():
		out.append("tether turning %.2f rpm" % rpm)
	elif pull() > PULL_MIN:
		out.append("tether pulling %d kN" % int(pull()))
	return out


func _fuel() -> float:
	var t := 0.0
	for v in cfg.get("rcs", {}).get("fuel", []):
		if game.sys.fvol.has(v):
			t += float(game.sys.fvol[v].amount)
	return t


func rcs_ready() -> bool:
	var rc: Dictionary = cfg.get("rcs", {})
	var lp = world.tag(str(rc.get("live", "")))
	return lp != null and not lp.gone and game.sys.piece_volts(lp) > 1.0 and _fuel() > 0.05


func _physics_process(dt: float) -> void:
	if not active() or game == null or game.paused_sim or game.state != "play" or thrown:
		return
	var s = game.sys
	var b: Dictionary = cfg.get("brake", {})
	var braking: bool = s.on(str(b.get("switch", ""))) and not slipped and rpm > 0.0
	if braking:
		rpm -= float(b.get("rate", 0.025)) * dt
		if s.on(str(b.get("cool", ""))):
			heat = maxf(0.0, heat - 0.5 * dt)
		else:
			heat += dt
			if heat > float(b.get("slip", 6.0)):
				_slip()
	else:
		heat = maxf(0.0, heat - 0.2 * dt)
	var rc: Dictionary = cfg.get("rcs", {})
	if s.on(str(rc.get("switch", ""))) and rpm > 0.0 and rcs_ready():
		rpm -= float(rc.get("rate", 0.012)) * dt
		var burn: float = float(rc.get("use", 0.004)) * dt
		for v in rc.get("fuel", []):
			if s.fvol.has(v) and s.fvol[v].amount > 0.0:
				var take := minf(burn, float(s.fvol[v].amount))
				s.fvol[v].amount -= take
				burn -= take
	rpm = maxf(0.0, rpm)


func _slip() -> void:
	slipped = true
	var lost := 0.0
	for t in cfg.get("brake", {}).get("rollers", []):
		var q = world.tag(str(t))
		if q == null or q.gone or q.cls != "equip" or not q.intact:
			continue
		var before: float = q.cond
		game._dent(q, minf(q.cond, 0.5), "dv_brake_slip")
		lost += (before - q.cond) * q.value
	var c = world.tag(str(cfg.get("brake", {}).get("rollers", [""])[0]))
	var at: Vector2 = world.frame(c) * Geom.centroid(c.poly) if c != null else game.drone.global_position
	game.incident("brake_slip", "")
	game.say("brake_slip", at, "")
	game.note_loss("loss_brake_slip", "", lost)
	game.sfx.play("deny")


func _knock(tags: Array, keep: float, reason: String) -> float:
	var lost := 0.0
	for t in tags:
		var q = world.tag(str(t))
		if q == null or q.gone or q.cls != "equip" or not q.intact:
			continue
		var before: float = q.cond
		game._dent(q, minf(q.cond, keep), reason)
		lost += (before - q.cond) * q.value
	return lost


func _parted(p) -> void:
	var segs: Array = cfg.get("segments", [])
	if not segs.has(p.tag):
		return
	var at: Vector2 = world.frame(p) * Geom.centroid(p.poly)
	if spinning():
		thrown = true
		var lost := _knock(cfg.get("pods", []), THROW_KEEP, "dv_pods_thrown")
		game.incident("pods_thrown", p.tag)
		game.say("pods_thrown", at, p.tag)
		game.note_loss("loss_pods_thrown", p.tag, lost)
		game.shake(1.0)
		game.sfx.play("snap")
		rpm = 0.0
		return
	if snapped or pull() <= PULL_MIN:
		return
	var worn = world.tag(str(cfg.get("worn", "")))
	if worn != null and not worn.gone and worn.intact:
		snapped = true
		var lost := _knock(segs, SNAP_KEEP, "dv_tether_snap")
		game.incident("tb_parted", p.tag)
		game.say("tb_parted", at, p.tag)
		game.note_loss("loss_tether_snap", p.tag, lost)
		game.shake(0.8)
		game.sfx.play("snap")
		return
	# a sound tether still pulling: the cut ends whip into what hangs on them
	var near: Array = []
	var i := segs.find(p.tag)
	for k in [i - 1, i, i + 1]:
		if k >= 0 and k < segs.size():
			near.append(segs[k])
	near.append_array(cfg.get("dressing", {}).get(p.tag, []))
	var lw := _knock(near, WHIP_KEEP, "dv_tether_whip")
	snapped = true
	game.incident("tether_whip", p.tag)
	game.say("tether_whip", at, p.tag)
	game.note_loss("loss_tether_whip", p.tag, lw)
	game.shake(0.5)


func on_cut(p) -> void:
	if active():
		_parted(p)


func on_freed(b) -> void:
	if not active():
		return
	for q in b.pieces:
		_parted(q)
