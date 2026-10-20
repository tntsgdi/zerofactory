extends Node2D
# Habitat rings still turning when the ship came in (ARK-01 "Voyager",
# design/ships/ARK-01_远航者_设计稿.md 4-5: "both rings at about 3 rpm: take the
# ring's loads off, despin the two together with the hub's motor-brakes, lock the
# bearing, only then the transfer airlock"). Seen side-on a ring turns out of the
# picture: its spin is a state, drawn as the ring's ellipse sliding round.
# A ship file's "rings":
#   {"rings": {ring: {"rpm": at the start, "area": [[x0, y0, x1, y1] m, ...] what
#     turns with it, "hub": [x, y] m, "radius": m, "bus": the ring's distribution
#     (its loads are on while that has power), "slip": the slip ring (piece),
#     "brakes": [motor-brake switches], "brake_pieces": {switch: piece}, "cool": the
#     brakes' cooling switch, "cap": the brake capacitor (an isolated "cap" supply in
#     "power", its dump the discharge control), "lock": the bearing lock switch,
#     "rollers": [bearing pieces], "airlocks": [the transfer airlocks' door controls],
#     "decel": rpm/s one brake takes off, "shock": {"doors": {door control: [the ring
#     room, the room on its far side, [the glass]]}, "kpa": the difference that
#     breaks it}}},
#    "safe": rpm under which a ring counts as still, "torque": rpm apart the two may
#    be while either is braked, "torque_t": s past that before the berth's clamps
#    are overloaded, "hits": [what the twist damages], "cap_k": charge a brake puts
#    into its capacitor per rpm taken off, "heat_k": heat per rpm braked dry}
#   A brake slows its ring only while the ring's loads are off (the motor-brake
#   drives back into a live ring bus: held on, the slip ring burns) and while its
#   capacitor has room; braking charges the capacitor, dumped by its discharge
#   control. Braked with the cooling off, the brakes heat and at the top burn out.
#   One ring braked while the other still turns: the hull is twisted, and past
#   "torque_t" the berth's clamps are overloaded (what "hits" names is damaged).
#   The bearing locked while the ring still turns: it seizes (rollers and spokes
#   damaged), the ring stops dead. Until its bearing is locked the transfer
#   airlocks stay shut, and anything cut free of a turning ring is thrown off.
#   A ring room's door opened onto a far lower pressure: the shock breaks its glass.
# Saved: each ring's rpm and brake heat, which bearings are locked, which brakes
# and slip rings burnt, whether the hull was twisted, which panes broke.

const FLING_KEEP := 0.4
const SEIZE_KEEP := 0.5
const TWIST_KEEP := 0.6
const SHOCK_KEEP := 0.25

var game
var world
var cfg := {}
var rpm := {}
var heat := {}
var locked := {}
var burnt := {}
var slip_burnt := {}
var twisted := false
var broken := {}
var members := {}         # ring -> {piece id: true}: what turns with it
var _load_t := {}
var _warn_t := {}
var _tq_t := 0.0
var _was := {}
var _doors := {}
var _phase := {}


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("rings", {})
	z_index = 40
	for r in cfg.get("rings", {}):
		var e: Dictionary = cfg.rings[r]
		rpm[r] = float(e.get("rpm", 3.0))
		heat[r] = 0.0
		_phase[r] = randf()
		var set := {}
		for id in world.order:
			var p = world.pieces[id]
			var c: Vector2 = Geom.centroid(p.poly) / Geom.M
			for a in e.get("area", []):
				if c.x >= float(a[0]) and c.x <= float(a[2]) and c.y >= float(a[1]) and c.y <= float(a[3]):
					set[p.id] = true
					break
		members[r] = set
		_was[e.get("lock", "")] = false
		for d in e.get("shock", {}).get("doors", {}):
			_doors[d] = false


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"rpm": rpm, "heat": heat, "locked": locked.keys(), "burnt": burnt.keys(), "slip": slip_burnt.keys(), "twisted": twisted, "broken": broken.keys()}


func load_state(d: Dictionary) -> void:
	for r in d.get("rpm", {}):
		rpm[str(r)] = float(d.rpm[r])
	for r in d.get("heat", {}):
		heat[str(r)] = float(d.heat[r])
	for r in d.get("locked", []):
		locked[str(r)] = true
		_was[str(cfg.rings.get(str(r), {}).get("lock", ""))] = true
	for t in d.get("burnt", []):
		burnt[str(t)] = true
	for r in d.get("slip", []):
		slip_burnt[str(r)] = true
	twisted = bool(d.get("twisted", false))
	for t in d.get("broken", []):
		broken[str(t)] = true


func ring_of(p) -> String:
	for r in members:
		if members[r].has(p.id):
			return r
	return ""


func turning(r: String) -> bool:
	return float(rpm.get(r, 0.0)) > float(cfg.get("safe", 0.05)) and not locked.has(r)


# the ring's own loads still have power (its distribution live, from anywhere)
func loads_live(r: String) -> bool:
	var p = world.tag(str(cfg.rings[r].get("bus", "")))
	return p != null and not p.gone and game.sys.piece_volts(p) > 1.0


func brakes_on(r: String) -> int:
	var n := 0
	var e: Dictionary = cfg.rings[r]
	for b in e.get("brakes", []):
		if game.sys.on(str(b)) and not burnt.has(b) and _piece_ok(str(e.get("brake_pieces", {}).get(b, ""))):
			n += 1
	return n


func cap_charge(r: String) -> float:
	var c: String = cfg.rings[r].get("cap", "")
	return float(game.sys.iso.get(c, {}).get("charge", 0.0))


func temp(r: String) -> float:
	return 30.0 + float(heat.get(r, 0.0)) * 290.0


# what still has to be made safe
func unsafe() -> Array:
	var out: Array = []
	for r in cfg.get("rings", {}):
		if turning(r):
			out.append("ring %s %.2f rpm" % [r, rpm[r]])
		elif not locked.has(r):
			out.append("ring %s unlocked" % r)
		if cap_charge(r) > 0.05:
			out.append("ring %s brake cap %d%%" % [r, int(cap_charge(r) * 100.0)])
	return out


func _piece_ok(t: String) -> bool:
	if t == "":
		return true
	var p = world.tag(t)
	return p != null and not p.gone and p.intact


func _hub(r: String) -> Vector2:
	var h: Array = cfg.rings[r].get("hub", [0.0, 0.0])
	return Vector2(float(h[0]), float(h[1])) * Geom.M


func _say_every(key: String, r: String, at: Vector2, every: float = 6.0) -> void:
	var k := key + r
	if game.playtime - float(_warn_t.get(k, -99.0)) < every:
		return
	_warn_t[k] = game.playtime
	game.say(key, at, r)


func _physics_process(dt: float) -> void:
	if not active() or game == null or game.paused_sim or game.state != "play":
		return
	var s = game.sys
	var braking := false
	for r in cfg.rings:
		var e: Dictionary = cfg.rings[r]
		_phase[r] = fposmod(float(_phase[r]) + float(rpm[r]) / 60.0 * dt, 1.0)
		# the bearing lock
		var lk: String = e.get("lock", "")
		var lon: bool = s.on(lk)
		if lon and not _was.get(lk, false):
			_lock(r)
		elif not lon and _was.get(lk, false):
			locked.erase(r)
		_was[lk] = lon
		var n := brakes_on(r)
		var cool: bool = s.on(str(e.get("cool", "")))
		if n > 0 and turning(r):
			if loads_live(r):
				_say_every("ring_loads_live", r, _hub(r))
				_load_t[r] = float(_load_t.get(r, 0.0)) + dt
				if _load_t[r] > 8.0 and not slip_burnt.has(r):
					_slip_burn(r)
			else:
				var c: String = e.get("cap", "")
				var ch := cap_charge(r)
				if ch >= 0.999:
					_say_every("ring_cap_full", r, _hub(r))
				else:
					braking = true
					var dr: float = minf(float(rpm[r]), float(e.get("decel", 0.03)) * n * dt)
					rpm[r] = float(rpm[r]) - dr
					if s.iso.has(c):
						s.iso[c].charge = minf(1.0, ch + dr * float(cfg.get("cap_k", 0.18)))
					if not cool:
						heat[r] = float(heat[r]) + dr * float(cfg.get("heat_k", 0.55))
						_say_every("ring_brake_dry", r, _hub(r), 10.0)
						if heat[r] >= 1.0:
							_burn(r)
		if n == 0 or not turning(r):
			_load_t[r] = maxf(0.0, float(_load_t.get(r, 0.0)) - dt)
		heat[r] = maxf(0.0, float(heat[r]) - dt * (0.03 if cool else 0.004))
		if float(rpm[r]) <= float(cfg.get("safe", 0.05)) * 0.5:
			rpm[r] = 0.0 if n > 0 or locked.has(r) else rpm[r]
		# a ring door opened onto a far lower pressure
		var sh: Dictionary = e.get("shock", {})
		for d in sh.get("doors", {}):
			var dc = world.ctrls.get(d)
			var dp = world.tag(str(dc.target)) if dc != null else null
			var open: bool = dp != null and dp.door_open
			if open and not _doors.get(d, false):
				var en: Array = sh.doors[d]
				var pa: float = s.P(str(en[0])) if s.vols.has(str(en[0])) else 0.0
				var pb: float = s.P(str(en[1])) if s.vols.has(str(en[1])) else 0.0
				if absf(pa - pb) > float(sh.get("kpa", 30.0)):
					_shock(d, en[2])
			_doors[d] = open
	# the two rings braked apart twist the hull
	var rs: Array = cfg.rings.keys()
	if rs.size() >= 2:
		var diff := absf(float(rpm[rs[0]]) - float(rpm[rs[1]]))
		if braking and diff > float(cfg.get("torque", 0.6)):
			_tq_t += dt
			_say_every("ring_torque", "", _hub(rs[0]).lerp(_hub(rs[1]), 0.5), 8.0)
			if _tq_t > float(cfg.get("torque_t", 6.0)) and not twisted:
				_twist()
		elif diff <= float(cfg.get("torque", 0.6)):
			_tq_t = maxf(0.0, _tq_t - dt)
	queue_redraw()


# a door into a ring's transfer airlock stays shut until the bearing is locked
func blocks_door(c, at: Vector2) -> bool:
	if not active():
		return false
	for r in cfg.rings:
		if (cfg.rings[r].get("airlocks", []) as Array).has(c.id) and not locked.has(r):
			game.say("ta_turning", at, r)
			game.sfx.play("deny")
			game.hint("ta_turning")
			return true
	return false


func _lock(r: String) -> void:
	if locked.has(r):
		return
	locked[r] = true
	if float(rpm[r]) <= float(cfg.get("safe", 0.05)):
		rpm[r] = 0.0
		game.say("ring_locked", _hub(r), r)
		return
	# locked turning: the bearing seizes
	var e: Dictionary = cfg.rings[r]
	var lost := 0.0
	var hit: Array = e.get("rollers", []).duplicate()
	hit.append_array(e.get("seize_hits", []))
	for t in hit:
		var q = world.tag(str(t))
		if q == null or q.gone or q.cls != "equip" or not q.intact:
			continue
		var before: float = q.cond
		game._dent(q, minf(q.cond, SEIZE_KEEP), "dv_bearing_seized")
		lost += (before - q.cond) * q.value
	rpm[r] = 0.0
	game.incident("bearing_seized", r)
	game.say("bearing_seized", _hub(r), r)
	game.note_loss("loss_bearing_seized", r, lost)
	game.shake(1.0)
	game.sfx.play("snap")


func _burn(r: String) -> void:
	var e: Dictionary = cfg.rings[r]
	var lost := 0.0
	for b in e.get("brakes", []):
		if not game.sys.on(str(b)) or burnt.has(b):
			continue
		burnt[b] = true
		var q = world.tag(str(e.get("brake_pieces", {}).get(b, "")))
		if q != null and not q.gone and q.intact:
			var before: float = q.cond
			game._dent(q, minf(q.cond, 0.3), "dv_brake_burn")
			lost += (before - q.cond) * q.value
	heat[r] = 0.6
	game.incident("ring_brake_burn", r)
	game.say("ring_brake_burn", _hub(r), r)
	game.note_loss("loss_brake_burn", r, lost)


func _slip_burn(r: String) -> void:
	slip_burnt[r] = true
	var q = world.tag(str(cfg.rings[r].get("slip", "")))
	var lost := 0.0
	var at := _hub(r)
	if q != null and not q.gone and q.intact:
		at = world.frame(q) * Geom.centroid(q.poly)
		var before: float = q.cond
		game._dent(q, minf(q.cond, 0.2), "dv_slip_arc")
		lost = (before - q.cond) * q.value
	game.incident("slip_arc", r)
	game.say("slip_arc", at, r)
	game.note_loss("loss_slip_arc", r, lost)
	game.fx.arc(at, at + Vector2(30, -20), 0.3, 0.8)
	game.fx.flash(at, 120.0, 0.3, Pal.tint(Pal.VOLT, 1.0, 2.0))
	game.sfx.play("arc")


func _twist() -> void:
	twisted = true
	var lost := 0.0
	for t in cfg.get("hits", []):
		var q = world.tag(str(t))
		if q == null or q.gone or q.cls != "equip" or not q.intact:
			continue
		var before: float = q.cond
		game._dent(q, minf(q.cond, TWIST_KEEP), "dv_ring_twist")
		lost += (before - q.cond) * q.value
	game.incident("ring_twist", "")
	game.say("ring_twist", game.drone.global_position + Vector2(0, -60), "")
	game.note_loss("loss_ring_twist", "", lost)
	game.shake(1.2)
	game.sfx.play("snap")


func _shock(door: String, panes: Array) -> void:
	var lost := 0.0
	var at: Vector2 = world.ctrl_world(world.ctrls[door])
	for t in panes:
		var q = world.tag(str(t))
		if q == null or q.gone or broken.has(t) or not q.intact:
			continue
		broken[t] = true
		at = world.frame(q) * Geom.centroid(q.poly)
		var before: float = q.value * clampf(q.cond, 0.0, 1.0)
		q.intact = false
		q.cond = minf(q.cond, SHOCK_KEEP)
		lost += before - q.value * q.cond
		game.fx.burst_shards(at, 10, 200.0, Pal.ink(0.8), 5.0)
	game.incident("ring_shock", door)
	game.say("ring_shock", at, door)
	game.note_loss("loss_ring_shock", door, lost)
	game.shake(0.7)
	world.redraw_all()


# ---------------------------------------------------------------- cut and freed

func on_freed(b) -> void:
	if not active():
		return
	for r in members:
		if not turning(r):
			continue
		var hit := false
		for q in b.pieces:
			if members[r].has(q.id):
				hit = true
				break
		if not hit:
			continue
		_fling(b, r)
		return


# thrown off the turning ring: out of the picture along its rim, which seen side-on
# is away from the axis (scaled down: the drone has to be able to catch it again)
func _fling(b, r: String) -> void:
	var e: Dictionary = cfg.rings[r]
	var hub := _hub(r)
	var at: Vector2 = b.global_transform * b.center_of_mass
	var out := 1.0 if at.y > hub.y else -1.0
	var v: float = float(rpm[r]) * TAU / 60.0 * float(e.get("radius", 100.0)) * 0.35
	b.linear_velocity = Vector2(randf_range(-0.15, 0.15), out) * v * Geom.M
	b.angular_velocity = randf_range(-2.0, 2.0)
	var lost := 0.0
	var tags: Array = []
	for q in b.pieces:
		if q.cls != "equip" or not q.intact:
			continue
		var before: float = q.cond
		game._dent(q, minf(q.cond, FLING_KEEP), "dv_ring_fling")
		lost += (before - q.cond) * q.value
		tags.append(q.tag)
	game.incident("ring_fling", r)
	game.say("ring_fling", at, r)
	game.note_loss("loss_ring_fling", ",".join(tags.slice(0, 3)), lost)
	game.shake(0.5)


# ---------------------------------------------------------------- drawing

# the ring seen side-on: a thin ellipse through its two rim modules, its dashes
# sliding round while it turns; streaks off the rim modules as long as it does
func _draw() -> void:
	if not active():
		return
	var M := Geom.M
	for r in cfg.rings:
		var e: Dictionary = cfg.rings[r]
		var c := _hub(r)
		var rad: float = float(e.get("radius", 100.0)) * M
		var wx: float = float(e.get("half_width", 9.0)) * M
		var k: float = clampf(float(rpm[r]) / 3.0, 0.0, 1.0)
		var dashes := PackedVector2Array()
		var n := 72
		for i in n:
			if i % 2 == 1:
				continue
			var a0: float = TAU * (float(i) / n + float(_phase[r]))
			var a1: float = TAU * (float(i + 1) / n + float(_phase[r]))
			dashes.append(c + Vector2(cos(a0) * wx, sin(a0) * rad))
			dashes.append(c + Vector2(cos(a1) * wx, sin(a1) * rad))
		draw_multiline(dashes, Pal.ink(0.05 + 0.12 * k), 1.2)
		if k > 0.01:
			for side in [-1.0, 1.0]:
				var arc := PackedVector2Array()
				for j in 13:
					var a: float = -0.5 + j / 12.0
					arc.append(c + Vector2(side * (wx + 2.0 * M + 18.0 * M * (1.0 - absf(a))), a * rad * 1.5))
				draw_polyline(arc, Pal.heat(0.12 + 0.25 * k, 1.3), 1.6, true)
