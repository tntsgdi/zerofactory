class_name Dock
extends Node2D

const Smelter = preload("res://scripts/smelter.gd")
const CanvasBatch = preload("res://scripts/canvas_batch.gd")
# The vacuum dock around the ship: girders, the four clamp arms, the three
# recovery mouths (equipment bay, metal furnace, hazard bay), the debris net,
# the drone bay and the hose masts. Recovery mouths pull in whatever drifts
# close, judge it, and either swallow it or spit it back out.

const BASE_ZONES := {
	"equip": {"pos": Vector2(14.0, -8.4), "face": Vector2(0, 1), "w": 4.2},
	"metal": {"pos": Vector2(21.0, 7.7), "face": Vector2(0, -1), "w": 4.6},
	"hazard": {"pos": Vector2(43.6, 6.9), "face": Vector2(0, -1), "w": 3.2},
}
static var NET := Vector2(2.8, 8.3)
const BAY := Vector2(-5.0, -6.0)
# The berth's length (roadmap 4.1): the standard berth's floor ends at 50 m;
# the extension (a career purchase) takes it to EXTENDED. Everything along
# the berth follows its end: the hazard bay and the far mast stay at the far
# end, the trough runs on to it, the equipment bay and the furnace move to the
# middle third, the boom reaches further. Set once per contract (configure).
const STANDARD := 50.0
const EXTENDED := 88.0
# the berth's lengths a career can buy, each needing the one before
# (fleet expansion 2026-10-19: PT-34 and the R2 fleet are 96-138 m; ARK-01, roadmap 6.1, ~600 m)
const TIERS := [[50.0, ""], [88.0, "berth88"], [120.0, "berth120"], [200.0, "berth200"], [620.0, "berth620"]]


# the longest berth a career has paid for (m)
static func owned(upgrades: Dictionary) -> float:
	var best := STANDARD
	for t in TIERS:
		if t[1] == "" or upgrades.has(t[1]):
			best = maxf(best, float(t[0]))
	return best


# the berth a ship takes: what has been paid for, or longer if the ship needs it
# (a developer's or a test's contract may bring a ship the career couldn't take)
static func length_for(ship_len: float, upgrades: Dictionary) -> float:
	var x := owned(upgrades)
	for t in TIERS:
		if ship_len <= float(t[0]) - 6.0:
			return maxf(x, float(t[0]))
	return maxf(x, float(TIERS[-1][0]))


# the facility that makes a berth long enough for a ship ("" if the standard one is)
static func needs(ship_len: float) -> String:
	for t in TIERS:
		if ship_len <= float(t[0]) - 6.0:
			return str(t[1])
	return str(TIERS[-1][1])
static var floor_end := STANDARD
static var ZONES := BASE_ZONES.duplicate(true)
static var MASTS: Array = [Vector2(5.0, -10.0), Vector2(23.0, -10.0), Vector2(38.0, 6.6)]
# semi-open berth: a floor platform, a tower on the left with an arm reaching
# over the ship; the top and the right are open to space, held only by a
# tractor field that eases strays back in
static var FLOOR_Y := 9.0
static var FLOOR_X1 := 50.0
const TOWER_X := -7.4
static var ARM_X1 := 27.5
static var BOUNDS := Rect2(-6.8, -15.0, 63.0, 24.0)
const FIELD := 3.4
const CATCH := 1.3
# the furnace reaches further for scrap that has been let go (aim and throw):
# whole equipment, hazards and whatever the grapple still holds only feel the
# small field. Along the bottom of the berth runs a scrap trough: scrap that
# drops into it rides a conveyor to the furnace (design/体验打磨定案.md §6)
const SCRAP_FIELD := 7.0
static var TROUGH_Y := 8.2          # m: the trough's lip; below it a body is in the trough
const TROUGH_X0 := 5.5
static var TROUGH_X1 := 40.5        # stops short of the hazard mouth
const CONVEY := 7.0                 # m/s along the trough
const SUCK_H := 2.6                 # m: how far above the lip the trough's suction reaches
const SUCK_ACC := 420.0             # px/s² at the lip
const RAIL_SPEED := 4.0             # m/s: the movable furnace mouth along its rail
static var metal_x := 21.0          # where the furnace mouth sits (it moves only with the rail upgrade)
static var metal_home := 21.0       # where it sits at the start
var mouth_target := 21.0
# The equipment bays run on a ceiling rail along the boom and on past it
# (P.5, player 2026-10-17: "the equipment mouth is too far away"): the mouth key
# slides the nearest one to over the drone. Free from the start.
const EQUIP_RAIL_X0 := 0.5          # m: the rail's near end (clear of the drone bay)
const EQUIP_GAP := 7.0              # m: two bays on the rail keep this far apart
const EQUIP_SPEED := 9.0            # m/s along the rail
static var RAIL_Y := -10.0          # m: the rail, under the boom
static var equip_x := {}            # bay id -> where it sits on the rail (m); a bay not in it is at home
var equip_goal := {}


static func equip_rail_x1() -> float:
	return FLOOR_X1 - 3.5


# How tall the berth is (fleet expansion 2026-10-19): it was laid out for ships within
# about -8.6 / +7.0 m of the keel line; a taller one (PT-34's bridge and radar, its
# belly gun) lifts the boom, the rail and the equipment bays above it and drops the
# floor, the trough, the furnace and the hazard bay below it, by what it needs
# beyond that and a margin. The ships that always fitted see no change.
const FIT_TOP := -8.6
const FIT_BOTTOM := 7.0
const FIT_MARGIN := 0.8
static var LIFT := 0.0              # m the top of the berth was lifted
static var DROP := 0.0              # m the bottom was dropped


# lay the berth out for a floor ending at x (m), for a ship reaching from top to
# bottom (m, y down; 0 / 0 for one that fits the berth as it always was)
static func configure(x: float, top: float = 0.0, bottom: float = 0.0) -> void:
	configure_shape(x, lift_for(top), drop_for(bottom))


# how far the top is lifted / the bottom dropped for a ship reaching to top / bottom (m)
static func lift_for(top: float) -> float:
	return maxf(0.0, FIT_TOP - top + FIT_MARGIN) if top < FIT_TOP else 0.0


static func drop_for(bottom: float) -> float:
	return maxf(0.0, bottom - FIT_BOTTOM + FIT_MARGIN) if bottom > FIT_BOTTOM else 0.0


# the berth laid out by its length and how far its top is lifted and its bottom dropped
# (the berth growing for a tall ship goes through these in between: berth_build.gd)
static func configure_shape(x: float, lift: float, drop: float) -> void:
	floor_end = x
	var d := x - STANDARD
	FLOOR_X1 = x
	LIFT = lift
	DROP = drop
	FLOOR_Y = 9.0 + DROP
	TROUGH_Y = 8.2 + DROP
	NET = Vector2(2.8, 8.3 + DROP)
	RAIL_Y = -10.0 - LIFT
	BUFFER = Rect2(-6.0, -14.2 - LIFT, 8.0, 3.8)
	BOUNDS = Rect2(-6.8, -15.0 - LIFT, 63.0 + d, 24.0 + LIFT + DROP)
	TROUGH_X1 = 40.5 + d
	ARM_X1 = 27.5 + d * 0.6
	ZONES = BASE_ZONES.duplicate(true)
	ZONES.hazard.pos += Vector2(d, DROP)
	ZONES.equip.pos += Vector2(d * 0.45, -LIFT)
	equip_x.clear()
	ZONES.metal.pos += Vector2(d * 0.45, DROP)
	metal_home = ZONES.metal.pos.x
	MASTS = [Vector2(5.0, RAIL_Y), Vector2(23.0 + d * 0.45, RAIL_Y), Vector2(38.0 + d, 6.6 + DROP)]
	if d > 0.0:
		MASTS.append(Vector2(23.0 + d * 1.1, RAIL_Y))


# the second equipment bay (roadmap 4.4, "more ports"): over the berth's far
# end, so a long ship's stern half has an equipment mouth near it too. It takes
# what the first takes; "kind" says which mouth it stands for.
static func add_port2() -> void:
	ZONES["equip2"] = {"pos": Vector2(FLOOR_X1 - 10.0, -8.4 - LIFT), "face": Vector2(0, 1), "w": 4.2, "kind": "equip"}
	equip_x.erase("equip2")


# what a mouth takes: "equip", "metal" or "hazard" (a second bay stands for the first)
static func kind(id: String) -> String:
	return ZONES[id].get("kind", id) if ZONES.has(id) else id


# of the mouths that take k, the one nearest a point (px)
static func nearest(k: String, from: Vector2) -> String:
	var best := k
	var bd := INF
	for id in ZONES:
		if kind(id) != k:
			continue
		var d := zpos(id).distance_to(from)
		if d < bd:
			bd = d
			best = id
	return best


# the buffer platform (roadmap 4.4): a parking deck over the berth's near end,
# on top of the boom, where the tractor field holds whatever is let go on it
# until it is fetched (clear of the boom: what rests on it never touches it)
static var BUFFER := Rect2(-6.0, -14.2, 8.0, 3.8)


func in_buffer(b) -> bool:
	if game == null or not game.has_upgrade("buffer") or not is_instance_valid(b):
		return false
	return BUFFER.has_point((b.global_transform * b.center_of_mass) / Geom.M)


# the middle of the berth, where the overview looks
static func centre() -> Vector2:
	return Vector2((TOWER_X + FLOOR_X1) * 0.5, -2.0)

var game: Game
var world: World
var zone_state := {}       # id -> {"glow": float, "busy": float, "reject": float, "eat": float}
var swallowing: Array = [] # [body, zone, t, start_pos, start_rot]
var conveying: Array = []  # bodies riding the trough to the furnace
var debris: Array = []     # [pos, vel, t, poly, rot, spin, value, trail]
var hoses := {}            # port id -> {"pts": [], "prev": [], "mast": Vector2, "t": float}
var clamps: Array = []     # Vector2 in metres: where each dock clamp grips the ship (from the ship file)
var clamp_t: Array = []
var field_glow: Array = []  # [point on the field edge, strength]
var bounds_body: StaticBody2D
var font: Font
var font_b: Font
var add_node: Node2D
var static_node: Node2D
var clamp_node: Node2D
var _zh := Txt.zh
var _clamp_drawn: Array = []
var _clamp_n := -1
var _clamp_last = null
var _clamp_js: Array = []
var _was_busy := true
var mouth_nodes := {}
var _mouth_drawn := {}
var overlay_node: Node2D
var t := 0.0
var suck_glow := 0.0        # lit while the suction draws something down
var suck_x := 0.0
# the furnace under the floor (scripts/smelter.gd): the mouth feeds it, it melts, taps, casts
var smelter = preload("res://scripts/smelter.gd").new()
# and the line before it: press, shredder, hammer mill, magnets (scripts/scrapline.gd)
var scrapline = preload("res://scripts/scrapline.gd").new()
var furnace_node: Node2D
var furnace_text_node: Node2D
var _text_sig := []
# far out (the whole ship in view) the berth's girders lose their rivets and bracing, which
# are under a pixel there and cost the wide view milliseconds a frame to render
const FAR_ZOOM := 0.5
var _far := false
var draw_now := true        # this frame redraws the moving layers
var prof_draw := [0, 0, 0, 0]   # usec in the plant's drawing (smelter, line, flush, frames): tests/dock_perf.gd
var _frame_n := 0
var _sb = null              # the batch the static layer is being drawn into
var _ab = null              # the batch the light layer is being drawn into
var furnace_x := -INF       # m: where the furnace stands (its own rails: it moves only when the berth is rebuilt)
# the ships alongside that take what the mouths recovered (scripts/salvage_ships.gd)
var ships
# the debris net's load cell, its dump gate and the little baler under it
var net_load := 0.0         # t in the net now
var net_bales := 0
var net_dump := -1.0        # < 0 idle, else 0..1 through a dump-and-bale cycle
var net_bale_x := -INF      # m: a bale on its belt to the furnace chute
var _net_bale_t := 0.0
const NET_DUMP_AT := 0.06   # t: the net is emptied at this load


func _init() -> void:
	metal_x = metal_home
	mouth_target = metal_home
	_equip_home()
	z_index = -1
	z_as_relative = false
	font = Fonts.get_font("Regular")
	font_b = Fonts.get_font("Medium")
	for k in ZONES:
		zone_state[k] = {"glow": 0.0, "busy": 0.0, "reject": 0.0, "eat": 0.0}
	bounds_body = StaticBody2D.new()
	bounds_body.collision_layer = 4
	bounds_body.collision_mask = 0
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.4
	bounds_body.physics_material_override = pm
	add_child(bounds_body)
	_bounds()
	add_node = Node2D.new()
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_node.material = m
	add_node.z_index = 8
	add_node.z_as_relative = false
	add_node.draw.connect(_draw_add)
	add_child(add_node)
	# the berth itself never changes: drawn once, under everything that moves
	static_node = Node2D.new()
	static_node.show_behind_parent = true
	static_node.draw.connect(_draw_static)
	add_child(static_node)
	clamp_node = Node2D.new()
	clamp_node.show_behind_parent = true
	clamp_node.draw.connect(_draw_clamps)
	add_child(clamp_node)
	furnace_node = Node2D.new()
	furnace_node.show_behind_parent = true
	furnace_node.draw.connect(_draw_furnace)
	add_child(furnace_node)
	# the plant's text (labels, callouts, read-outs) on a layer of its own, redrawn only when
	# what it says or where it stands changes: shaping it every frame cost milliseconds
	furnace_text_node = Node2D.new()
	furnace_text_node.show_behind_parent = true
	furnace_text_node.draw.connect(_draw_furnace_text)
	add_child(furnace_text_node)
	ships = preload("res://scripts/salvage_ships.gd").new()
	ships.dock = self
	add_child(ships)
	overlay_node = Node2D.new()
	overlay_node.draw.connect(_draw_overlay)
	add_child(overlay_node)


var stern := Vector2(42.0, 0.0)   # m: where the tug pushes, the ship's aft end


# the floor, the tower and the boom as walls (the berth's length set by configure)
func _bounds() -> void:
	for ch in bounds_body.get_children():
		ch.queue_free()
	var M := Geom.M
	var segs := [[Vector2(TOWER_X, FLOOR_Y) * M, Vector2(FLOOR_X1, FLOOR_Y) * M], [Vector2(TOWER_X + 0.6, RAIL_Y - 2.6) * M, Vector2(TOWER_X + 0.6, FLOOR_Y) * M], [Vector2(TOWER_X, RAIL_Y) * M, Vector2(ARM_X1, RAIL_Y) * M]]
	for s in segs:
		var cs := CollisionShape2D.new()
		var sh := SegmentShape2D.new()
		sh.a = s[0]
		sh.b = s[1]
		cs.shape = sh
		bounds_body.add_child(cs)


func set_ship(ship: Dictionary) -> void:
	# the berth as configured for this contract
	for k in ZONES:
		if not zone_state.has(k):
			zone_state[k] = {"glow": 0.0, "busy": 0.0, "reject": 0.0, "eat": 0.0}
	for k in zone_state.keys():
		if not ZONES.has(k):
			zone_state.erase(k)
	# Mouths retain their commands when idle. Keep the same draw order:
	# moving trough, each mouth, then hoses/debris and other foreground items.
	for id in mouth_nodes.keys():
		if not ZONES.has(id):
			mouth_nodes[id].queue_free()
			mouth_nodes.erase(id)
	for id in ZONES:
		if not mouth_nodes.has(id):
			var node := Node2D.new()
			node.draw.connect(_mouth_batched.bind(id, node))
			add_child(node)
			move_child(node, overlay_node.get_index())
			mouth_nodes[id] = node
		mouth_nodes[id].queue_redraw()
	_mouth_drawn.clear()
	metal_x = metal_home
	mouth_target = metal_home
	_equip_home()
	_bounds()
	if static_node != null:
		static_node.queue_redraw()
	# the tug sits right behind whatever ship this is
	var x1 := -INF
	var y0 := INF
	var y1 := -INF
	for pd in ship.get("pieces", []):
		for q in pd.get("poly", []):
			x1 = maxf(x1, q[0])
			y0 = minf(y0, q[1])
			y1 = maxf(y1, q[1])
	if x1 > -INF:
		stern = Vector2(x1 + 0.4, (y0 + y1) * 0.5)
	clamps = []
	clamp_t = []
	for c in ship.get("clamps", []):
		clamps.append(Vector2(c[0], c[1]))
		clamp_t.append(0.0)
	_clamp_drawn = []


static func zpos(id: String) -> Vector2:
	if id == "metal":
		return Vector2(metal_x, ZONES.metal.pos.y) * Geom.M
	if equip_x.has(id):
		return Vector2(equip_x[id], ZONES[id].pos.y) * Geom.M
	return ZONES[id].pos * Geom.M


static func inside(id: String) -> Vector2:
	return zpos(id) - ZONES[id].face * 1.1 * Geom.M


# the rail upgrade: the furnace mouth runs along the trough to under x (m)
func move_mouth(x: float) -> void:
	mouth_target = clampf(x, TROUGH_X0 + 2.5, TROUGH_X1 - 2.5)


# every equipment bay back at its home on the rail
func _equip_home() -> void:
	equip_x.clear()
	for id in ZONES:
		if kind(id) == "equip":
			equip_x[id] = ZONES[id].pos.x
	equip_goal = equip_x.duplicate()


# the mouth key: the equipment bay nearest x (m) slides along its rail to x,
# stopping at the rail's ends and short of the other bay
func move_equip(x: float) -> void:
	for id in ZONES:
		if kind(id) == "equip" and not equip_x.has(id):
			equip_x[id] = ZONES[id].pos.x
			equip_goal[id] = equip_x[id]
	var best := ""
	for id in equip_x:
		if best == "" or absf(equip_x[id] - x) < absf(equip_x[best] - x):
			best = id
	if best == "":
		return
	var lo := EQUIP_RAIL_X0
	var hi := equip_rail_x1()
	for id in equip_x:
		if id == best:
			continue
		var ox: float = equip_goal.get(id, equip_x[id])
		if ox < equip_x[best]:
			lo = maxf(lo, ox + EQUIP_GAP)
		else:
			hi = minf(hi, ox - EQUIP_GAP)
	equip_goal[best] = clampf(x, lo, maxf(lo, hi))


# ---------------------------------------------------------------- per frame

func _physics_process(dt: float) -> void:
	if game == null or game.paused_sim:
		return
	for b in world.bodies.duplicate():
		if not is_instance_valid(b) or b.capture != null:
			continue
		b.rejected_t = maxf(0.0, b.rejected_t - dt)
		var com: Vector2 = b.global_transform * b.center_of_mass
		var held: bool = game.tools.held_body == b
		var scrap := is_scrap(b)
		# scrap rides the belt the moment any of it touches it, even on the
		# grapple (which lets go); anything else is lifted back out
		if scrap and touches_trough(b, com):
			if held:
				game.tools.release_grab(false)
			_start_convey(b)
			continue
		if not held and in_trough(com):
			if b.rejected_t <= 0.0:
				b.rejected_t = 1.5
				b.apply_central_impulse(Vector2(0, -260.0) * b.mass)
				game.say("trough_only_scrap", com)
		# scrap let go over the trough is drawn down onto the belt
		if scrap and not held:
			var k := suction(com)
			if k > 0.0:
				b.apply_central_force(Vector2(0.0, (SUCK_ACC * k + 90.0) * b.mass))
				b.linear_velocity.x *= exp(-2.0 * dt)
				suck_glow = 1.0
				suck_x = com.x
		# parked on the buffer platform: held still until something fetches it
		if not held and b.get_meta("arm", false) == false and in_buffer(b):
			b.linear_velocity *= exp(-5.0 * dt)
			b.angular_velocity *= exp(-5.0 * dt)
			continue
		# the tractor field eases strays back in over the open edges
		var pull := field_pull(com)
		if pull != Vector2.ZERO:
			b.apply_central_force(pull * b.mass)
			b.linear_velocity *= exp(-0.8 * dt)
		for id in ZONES:
			var zp := zpos(id)
			var d := zp - com
			var dist := d.length()
			var reach := SCRAP_FIELD if id == "metal" and scrap and not held else FIELD
			if dist > reach * Geom.M or b.rejected_t > 0.0:
				continue
			zone_state[id].glow = 1.0
			var k := 1.0 - dist / (reach * Geom.M)
			# scrap let go near the furnace is drawn in hard: a throw in its general direction is enough
			var pullk := 2.6 if id == "metal" and scrap and not held else 1.0
			b.apply_central_force(d.normalized() * b.mass * (220.0 * k + 40.0) * pullk)
			b.linear_velocity *= exp(-1.6 * k * dt * pullk)
			var catch_r: float = (CATCH * 1.5 if id == "metal" and scrap else CATCH)
			if dist < catch_r * Geom.M:
				var verdict: Dictionary = game.judge(b, kind(id))
				if verdict.ok:
					_start_swallow(b, id)
				else:
					b.rejected_t = 2.2
					zone_state[id].reject = 1.0
					b.apply_central_impulse(-ZONES[id].face * b.mass * 380.0 + Vector2(randf_range(-60, 60), 0) * b.mass)
					game.on_reject(b, id, verdict)
				break


func _process(dt: float) -> void:
	t += dt
	if absf(metal_x - mouth_target) > 0.001:
		metal_x = move_toward(metal_x, mouth_target, RAIL_SPEED * dt)
		zone_state["metal"].glow = 1.0
	for id in equip_goal:
		if equip_x.has(id) and absf(equip_x[id] - equip_goal[id]) > 0.001:
			equip_x[id] = move_toward(equip_x[id], equip_goal[id], EQUIP_SPEED * dt)
			if zone_state.has(id):
				zone_state[id].glow = 1.0
	for id in zone_state:
		var z: Dictionary = zone_state[id]
		z.glow = maxf(0.0, z.glow - dt * 2.0)
		z.reject = maxf(0.0, z.reject - dt * 1.6)
		z.eat = maxf(0.0, z.eat - dt * 1.4)
	_step_convey(dt)
	_step_swallow(dt)
	_step_debris(dt)
	_step_hoses(dt)
	if furnace_x == -INF:
		furnace_x = metal_home
	var far: bool = game.cam_zoom() < FAR_ZOOM
	if far != _far:
		_far = far
		static_node.queue_redraw()
	# the berth rebuilt longer: the furnace rolls along its foundation rails to the new middle
	furnace_x = move_toward(furnace_x, metal_home, maxf(3.0, absf(metal_home - furnace_x) * 0.8) * dt)
	smelter.X = furnace_x
	smelter.step(dt)
	scrapline.X = furnace_x
	scrapline.game = game
	scrapline.smelter = smelter
	scrapline.step(dt)
	ships.game = game
	ships.step(dt)
	_step_net(dt)
	# far out and nothing moving that matters: the ambient motion (belt, lamps, the plant)
	# is redrawn every third frame only; up close, or with hoses, debris or a tug, every frame
	_frame_n += 1
	var calm := _far and hoses.is_empty() and debris.is_empty() and conveying.is_empty() and swallowing.is_empty() and not game.state in ["intro", "towout", "build"]
	draw_now = not calm or _frame_n % 3 == 0
	if _furnace_seen():
		# the plant's slow motion (the melt stirring, the coil's current, the pumps) at half
		# the frame rate; tapping, pressing and shredding at the full
		var plant_busy: bool = smelter.phase in ["tilt", "pour", "back"] or scrapline.busy() > 0 or not scrapline.frags.is_empty() or not scrapline.fines.is_empty()
		if draw_now and (plant_busy or _frame_n % 2 == 0):
			furnace_node.queue_redraw()
		var sig := [furnace_x, FLOOR_Y, metal_x, roundf(game.cam_zoom() * 20.0), Txt.zh, roundf(smelter.tilt * 40.0), roundf(smelter.hood * 20.0), int(t * 4.0)]
		if sig != _text_sig:
			_text_sig = sig
			furnace_text_node.queue_redraw()
	suck_glow = maxf(0.0, suck_glow - dt * 2.0)
	for g in field_glow:
		g[1] -= dt * 2.5
	field_glow = field_glow.filter(func(g): return g[1] > 0.0)
	# the clamp joints picked out once (a ship's joints only ever die, or come back whole
	# with a load): scanning every joint each frame cost a big ship milliseconds
	var jlast = world.joints.back() if not world.joints.is_empty() else null
	if world.joints.size() != _clamp_n or jlast != _clamp_last:
		_clamp_n = world.joints.size()
		_clamp_last = jlast
		_clamp_js = world.joints.filter(func(j): return j.type == "clamp")
	for i in clamps.size():
		var alive := false
		for j in _clamp_js:
			if j.alive and absf(j.pos.x / Geom.M - clamps[i].x) < 0.3:
				alive = true
		clamp_t[i] = move_toward(clamp_t[i], 0.0 if alive else 1.0, dt / 0.8)
	if Txt.zh != _zh:
		_zh = Txt.zh
		static_node.queue_redraw()
		queue_redraw()
	# the moving parts only redraw while something moves
	var busy := not hoses.is_empty() or not debris.is_empty() or game.state == "intro"
	for id in zone_state:
		var z: Dictionary = zone_state[id]
		if z.glow > 0.0 or z.reject > 0.0 or z.eat > 0.0:
			busy = true
	if clamp_t != _clamp_drawn:
		_clamp_drawn = clamp_t.duplicate()
		clamp_node.queue_redraw()
	for id in mouth_nodes:
		var st: Dictionary = zone_state[id]
		var want := _wanted(id)
		var signature := [zpos(id), st.glow, st.reject, st.eat, st.busy, want, Txt.zh, int(game.cam_zoom() * 8.0)]
		if st.glow > 0.0 or st.reject > 0.0 or st.eat > 0.0 or st.busy > 0.0 or want or signature != _mouth_drawn.get(id, []):
			mouth_nodes[id].queue_redraw()
			_mouth_drawn[id] = signature
	# the belt, buffer, hoses and lamps: every frame up close, every third far out when calm
	_was_busy = busy
	if draw_now:
		overlay_node.queue_redraw()
		queue_redraw()
		add_node.queue_redraw()


# acceleration the field gives at a point (zero well inside the berth)
func field_pull(p: Vector2) -> Vector2:
	var M := Geom.M
	var inner := Rect2((BOUNDS.position + Vector2(0.0, 2.0)) * M, (BOUNDS.size - Vector2(2.5, 2.0)) * M)
	if inner.has_point(p):
		return Vector2.ZERO
	var c := inner.get_center()
	var q := Vector2(clampf(p.x, inner.position.x, inner.end.x), clampf(p.y, inner.position.y, inner.end.y))
	var depth := p.distance_to(q)
	if field_glow.size() < 40:
		field_glow.append([q, 1.0])
	return (q - p).normalized() * (60.0 + depth * 1.6) + (c - p).normalized() * 10.0


# scrap: nothing whole to save and nothing dangerous in it
func is_scrap(b) -> bool:
	for p in b.pieces:
		if p.cls == "equip" and p.intact:
			return false
		if game.sys.dest_of(p) == "hazard":
			return false
	return true


static func in_trough(com: Vector2) -> bool:
	var x := com.x / Geom.M
	return com.y > TROUGH_Y * Geom.M and x > TROUGH_X0 and x < TROUGH_X1


# any of the body's outline at or over the belt (inside the trough's length)
func touches_trough(b, com: Vector2) -> bool:
	var M := Geom.M
	if com.y < (TROUGH_Y - 12.0) * M:
		return false
	var lip := TROUGH_Y * M - 2.0
	for p in b.pieces:
		for v in world.world_poly(p):
			if v.y > lip and v.x > TROUGH_X0 * M and v.x < TROUGH_X1 * M:
				return true
	return false


# how hard the suction over the trough pulls at a point: 1 at the lip, 0 at SUCK_H above it
static func suction(com: Vector2) -> float:
	var x := com.x / Geom.M
	if x < TROUGH_X0 or x > TROUGH_X1:
		return 0.0
	var h := TROUGH_Y - com.y / Geom.M
	if h < 0.0 or h > SUCK_H:
		return 0.0
	return 1.0 - h / SUCK_H


# the point on the trough straight below p (where to push scrap down to)
static func trough_below(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x / Geom.M, TROUGH_X0 + 0.5, TROUGH_X1 - 0.5), TROUGH_Y + 0.3) * Geom.M


func _start_convey(b) -> void:
	b.capture = "trough"
	b.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	b.set_deferred("freeze", true)
	b.collision_layer = 0
	b.collision_mask = 0
	conveying.append(b)
	game.sfx.play("clank", b.global_position, 0.6)


func _step_convey(dt: float) -> void:
	var M := Geom.M
	var mouth := zpos("metal")
	for b in conveying.duplicate():
		if not is_instance_valid(b):
			conveying.erase(b)
			continue
		var com_off: Vector2 = b.global_transform.basis_xform(b.center_of_mass)
		var com: Vector2 = b.global_position + com_off
		var lane := (TROUGH_Y + 0.45) * M
		var nx := move_toward(com.x, mouth.x, CONVEY * M * dt)
		var ny := move_toward(com.y, lane, CONVEY * M * dt)
		b.global_position = Vector2(nx, ny) - com_off
		b.rotation = lerp_angle(b.rotation, 0.0, 1.0 - exp(-3.0 * dt))
		if absf(nx - mouth.x) < 0.4 * M:
			conveying.erase(b)
			swallowing.append([b, "metal", 0.0, b.global_position, b.rotation])
			b.capture = "metal"
			zone_state["metal"].busy = 1.0
			game.on_swallow_start(b, "metal")


func _start_swallow(b, id: String) -> void:
	b.capture = id
	b.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	b.set_deferred("freeze", true)
	b.collision_layer = 0
	b.collision_mask = 0
	if game.tools.held_body == b:
		game.tools.release_grab(false)
	swallowing.append([b, id, 0.0, b.global_position, b.rotation])
	zone_state[id].busy = 1.0
	game.on_swallow_start(b, id)


func _step_swallow(dt: float) -> void:
	var done: Array = []
	for s in swallowing:
		var b = s[0]
		if not is_instance_valid(b):
			done.append(s)
			continue
		s[2] += dt
		var k: float = clampf(s[2] / 0.55, 0.0, 1.0)
		var e := Pal.ease_in(k)
		var tgt := inside(s[1])
		var com_off: Vector2 = b.global_transform.basis_xform(b.center_of_mass)
		b.global_position = (s[3] as Vector2).lerp(tgt - com_off, e)
		b.rotation = s[4] + e * 0.9 * (1.0 if int(s[3].x) % 2 == 0 else -1.0)
		b.view.scale = Vector2.ONE * lerpf(1.0, 0.25, e)
		b.view.position = b.center_of_mass * (1.0 - b.view.scale.x)
		b.heat_view.scale = b.view.scale
		b.heat_view.position = b.view.position
		var zid: String = s[1]
		if randf() < 0.6:
			var mouth := zpos(zid)
			var col := Pal.heat(0.9, 2.0) if zid == "metal" else (Pal.tint(Pal.FLUID, 0.8, 1.4) if zid == "hazard" else Pal.ink(0.8, 1.4))
			game.fx.sparks(mouth + Vector2(randf_range(-40, 40), 0), -ZONES[zid].face, 2, col, 200.0, 0.35, 0.5)
		if k >= 1.0:
			done.append(s)
			zone_state[zid].eat = 1.0
			if kind(zid) == "metal":
				var polys: Array = []
				var kinds: Array = []
				var com: Vector2 = b.global_transform * b.center_of_mass
				for p in b.pieces:
					var pp := PackedVector2Array()
					for q in world.world_poly(p):
						pp.append((q - com) / Geom.M)
					polys.append(pp)
					kinds.append(p.kind if p.cls == "metal" else "equip")
				scrapline.take(polys, b.total_mass(), kinds, metal_x)
			elif kind(zid) == "equip":
				var ev := 0.0
				for p in b.pieces:
					ev += game.piece_value(p, "equip")
				ships.add_equip(b, ev, float(equip_x.get(zid, ZONES[zid].pos.x)))
			elif kind(zid) == "hazard":
				var hv := 0.0
				for p in b.pieces:
					hv += game.piece_value(p, "hazard")
				ships.add_hazard(b, hv)
				for p in b.pieces:
					if game.sys.dest_of(p) == "hazard":
						smelter.flare()
						break
			game.on_swallowed(b, zid)
	for s in done:
		swallowing.erase(s)


# Small cut-offs: no physics, they are blown along the dock floor into the net.
func add_debris(poly_world: PackedVector2Array, vel: Vector2, value: float) -> void:
	var c := Geom.centroid(poly_world)
	var local := PackedVector2Array()
	for q in poly_world:
		local.append(q - c)
	debris.append([c, vel, 0.0, local, 0.0, randf_range(-5, 5), value, []])


func _step_debris(dt: float) -> void:
	var net := NET * Geom.M
	var arrived: Array = []
	for d in debris:
		d[2] += dt
		var to: Vector2 = net - d[0]
		var steer := 0.0 if d[2] < 0.45 else clampf((d[2] - 0.45) * 2.0, 0.0, 1.0)
		var want: Vector2 = to.normalized() * minf(900.0, 260.0 + d[2] * 300.0)
		d[1] = (d[1] as Vector2).lerp(want, steer * (1.0 - exp(-4.0 * dt)))
		d[0] += d[1] * dt
		d[4] += d[5] * dt
		var tr: Array = d[7]
		tr.push_front(d[0])
		while tr.size() > 10:
			tr.pop_back()
		if to.length() < 40.0 and d[2] > 0.5:
			arrived.append(d)
	for d in arrived:
		debris.erase(d)
		game.fx.flash(net, 30.0, 0.25, Pal.ink(0.4, 1.2))
		# thin plate offcuts: about 25 kg a square metre
		var area := 0.0
		var poly: PackedVector2Array = d[3]
		for i in poly.size():
			area += poly[i].cross(poly[(i + 1) % poly.size()])
		net_load += absf(area) * 0.5 / (Geom.M * Geom.M) * 0.025
		game.on_debris_in(d[6], net)


# ---------------------------------------------------------------- hoses

func hose_attach(port_id: String, port_pos: Vector2) -> void:
	var best: Vector2 = MASTS[0] * Geom.M
	for m in MASTS:
		if (m * Geom.M).distance_to(port_pos) < best.distance_to(port_pos):
			best = m * Geom.M
	var n := 22
	var pts: Array = []
	for i in n:
		pts.append(best)
	hoses[port_id] = {"pts": pts, "prev": pts.duplicate(), "mast": best, "t": 0.0}


func hose_detach(port_id: String) -> void:
	hoses.erase(port_id)


func _step_hoses(dt: float) -> void:
	for id in hoses:
		var h: Dictionary = hoses[id]
		h.t += dt
		var c = world.ctrls.get(id)
		if c == null:
			continue
		var end: Vector2 = world.ctrl_world(c)
		var pts: Array = h.pts
		var prev: Array = h.prev
		var n := pts.size()
		var reach := Pal.ease_out(h.t / 0.45)
		var tip: Vector2 = (h.mast as Vector2).lerp(end, reach)
		var seg := maxf(6.0, (h.mast as Vector2).distance_to(end) * 1.12 / (n - 1))
		for i in range(1, n - 1):
			var p: Vector2 = pts[i]
			var v: Vector2 = (p - prev[i]) * 0.94
			prev[i] = p
			pts[i] = p + v + Vector2(0, 30.0) * dt * dt
		pts[0] = h.mast
		pts[n - 1] = tip
		for it in 6:
			for i in n - 1:
				var a: Vector2 = pts[i]
				var b: Vector2 = pts[i + 1]
				var d := b - a
				var l := d.length()
				if l < 0.001:
					continue
				var diff := (l - seg) / l * 0.5
				if i > 0:
					pts[i] = a + d * diff
				if i + 1 < n - 1:
					pts[i + 1] = b - d * diff
			pts[0] = h.mast
			pts[n - 1] = tip


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var cb = CanvasBatch.new(self)
	_trough_live(cb)
	cb.flush()


func _draw_overlay() -> void:
	var ov = CanvasBatch.new(overlay_node)
	_draw_overlay_body(ov)
	ov.flush()


func _draw_overlay_body(ov) -> void:
	if game != null and game.has_upgrade("buffer"):
		_buffer(ov)
	if game != null:
		for r in game.keepout:
			_keepout(r, ov)
	# hoses
	for id in hoses:
		var pts := PackedVector2Array(hoses[id].pts)
		ov.draw_polyline(pts, Pal.ink(0.55), 3.4, true)
		ov.draw_polyline(pts, Color(0.05, 0.05, 0.06), 1.4, true)
	# the tug that brings GR-7 in
	var tug := tug_pos()
	if tug != Vector2.INF:
		_tug(tug, ov)
	_furnace_strip(ov)
	_net_detail(ov)
	# debris on its way to the net
	for d in debris:
		var tr := Transform2D(d[4], d[0])
		var poly: PackedVector2Array = tr * (d[3] as PackedVector2Array)
		if Geom.valid(poly):
			ov.draw_colored_polygon(poly, Color(0.09, 0.093, 0.1))
		var cl := poly.duplicate()
		if cl.size() > 0:
			cl.append(poly[0])
			ov.draw_polyline(cl, Pal.ink(0.6), 1.0, true)


func _draw_static() -> void:
	var ci = CanvasBatch.new(static_node)
	_sb = ci
	_draw_static_body(ci)
	ci.flush()
	_sb = null


func _draw_static_body(ci) -> void:
	var M := Geom.M
	# the berth's back wall: a dark bay behind the ship, ribbed, its number painted big
	var low := -5.0 - LIFT
	var wall := PackedVector2Array([Vector2(TOWER_X + 0.6, RAIL_Y) * M, Vector2(ARM_X1, RAIL_Y) * M, Vector2(ARM_X1 + 4.0, low) * M,
		Vector2(FLOOR_X1 - 6.0, low) * M, Vector2(FLOOR_X1 - 2.0, FLOOR_Y) * M, Vector2(TOWER_X + 0.6, FLOOR_Y) * M])
	ci.draw_colored_polygon(wall, Color(0.015, 0.017, 0.021, 0.92))
	var wx := TOWER_X + 6.0
	while wx < FLOOR_X1 - 6.0:
		var top := RAIL_Y if wx <= ARM_X1 else (low if wx >= ARM_X1 + 4.0 else lerpf(RAIL_Y, low, (wx - ARM_X1) / 4.0))
		ci.draw_rect(Rect2(Vector2(wx - 0.18, top) * M, Vector2(0.36 * M, (FLOOR_Y - top) * M)), Color(0.017, 0.019, 0.024))
		ci.draw_line(Vector2(wx - 0.18, top) * M, Vector2(wx - 0.18, FLOOR_Y) * M, Pal.ink(0.07), 1.0)
		wx += 6.0
	for sy in [-5.0, 2.0]:
		ci.draw_line(Vector2(TOWER_X + 0.6, sy) * M, Vector2(FLOOR_X1 - 6.0 + (sy + 5.0) / 14.0 * 4.0, sy) * M, Pal.ink(0.05), 1.0)
	# a strip of small lit ports high on the wall
	var px := TOWER_X + 2.0
	while px < ARM_X1 - 1.0:
		ci.draw_rect(Rect2(Vector2(px, RAIL_Y + 0.7) * M, Vector2(0.2 * M, 0.2 * M)), Pal.ink(0.07))
		px += 1.2
	var wcl := wall.duplicate()
	wcl.append(wall[0])
	ci.draw_polyline(wcl, Pal.ink(0.16), 1.2, true)
	ci.draw_string(font_b, Vector2(TOWER_X + 1.2, 2.6) * M, "07", HORIZONTAL_ALIGNMENT_LEFT, -1, int(4.4 * M), Pal.ink(0.035))
	# the berth: floor platform with legs into the dark, the tower, the arm
	_truss(Rect2(TOWER_X * M, FLOOR_Y * M, (FLOOR_X1 - TOWER_X) * M, 0.6 * M))
	for lx in [-2.0, 10.0, 22.0, 34.0, 46.0]:
		var l0 := Vector2(lx * M, (FLOOR_Y + 0.6) * M)
		ci.draw_line(l0, l0 + Vector2(-0.8 * M, 5.0 * M), Pal.ink(0.18), 1.4)
		ci.draw_line(l0 + Vector2(0.6 * M, 0), l0 + Vector2(1.4 * M, 5.0 * M), Pal.ink(0.18), 1.4)
	_truss_v(Rect2(TOWER_X * M, (RAIL_Y - 2.6) * M, 0.6 * M, (FLOOR_Y - RAIL_Y + 2.6) * M))
	_truss(Rect2(TOWER_X * M, (RAIL_Y - 0.6) * M, (ARM_X1 - TOWER_X) * M, 0.6 * M))
	ci.draw_line(Vector2(TOWER_X + 0.6, RAIL_Y + 4.0) * M, Vector2(TOWER_X + 6.0, RAIL_Y) * M, Pal.ink(0.22), 2.0)
	ci.draw_rect(Rect2((ARM_X1 - 0.3) * M, (RAIL_Y - 0.8) * M, 0.5 * M, 1.0 * M), Color(0.07, 0.073, 0.082))
	ci.draw_rect(Rect2((ARM_X1 - 0.3) * M, (RAIL_Y - 0.8) * M, 0.5 * M, 1.0 * M), Pal.ink(0.5), false, 1.2)
	ci.draw_rect(Rect2((FLOOR_X1 - 0.2) * M, (FLOOR_Y - 0.3) * M, 0.5 * M, 1.2 * M), Color(0.07, 0.073, 0.082))
	ci.draw_rect(Rect2((FLOOR_X1 - 0.2) * M, (FLOOR_Y - 0.3) * M, 0.5 * M, 1.2 * M), Pal.ink(0.5), false, 1.2)

	# the scrap trough along the floor, into the furnace
	var tl := Vector2(TROUGH_X0, TROUGH_Y) * M
	var tr := Vector2(TROUGH_X1, TROUGH_Y) * M
	var th := (FLOOR_Y - TROUGH_Y) * M
	ci.draw_rect(Rect2(tl, Vector2(tr.x - tl.x, th)), Color(0.03, 0.032, 0.036))
	ci.draw_rect(Rect2(tl + Vector2(0, th - 5), Vector2(tr.x - tl.x, 5)), Color(0.06, 0.063, 0.07))
	ci.draw_line(tl - Vector2(0, 2), tr - Vector2(0, 2), Pal.ink(0.55), 2.0)
	ci.draw_line(tl + Vector2(0, 3), tr + Vector2(0, 3), Pal.ink(0.14), 1.0)
	for e in [tl, tr]:
		ci.draw_line(e - Vector2(0, 6), e + Vector2(0, th), Pal.ink(0.55), 2.0)
	# its sign at the left end
	var sr := Rect2(tl + Vector2(1.7 * M, -44), Vector2(206, 30))
	ci.draw_rect(sr, Color(0.035, 0.037, 0.042, 0.94))
	ci.draw_rect(Rect2(sr.position, Vector2(4, sr.size.y)), Pal.heat(0.9, 1.1))
	ci.draw_string(font_b, sr.position + Vector2(14, 21), game.txt("trough"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.9))
	# the open ends: striped, so the edge of the berth reads at a glance
	_stripes(Rect2((FLOOR_X1 - 2.2) * M, FLOOR_Y * M + 3, 2.0 * M, 0.6 * M - 6))
	_stripes(Rect2((ARM_X1 - 2.0) * M, (RAIL_Y - 0.6) * M + 3, 1.6 * M, 0.6 * M - 6))
	# the equipment bays' rail: under the boom, and on past it on a slim girder
	var rx0 := (EQUIP_RAIL_X0 - 2.6) * M
	var rx1 := (equip_rail_x1() + 2.6) * M
	if rx1 > (ARM_X1 + 0.2) * M:
		var hx := ARM_X1 + 4.0
		while hx < rx1 / M - 0.5:
			ci.draw_line(Vector2(hx, RAIL_Y - 0.4) * M, Vector2(hx, BOUNDS.position.y + 1.0) * M, Pal.ink(0.1), 1.4)
			ci.draw_circle(Vector2(hx, RAIL_Y - 0.4) * M, 2.0, Pal.ink(0.3))
			hx += 6.0
		_truss(Rect2((ARM_X1 + 0.2) * M, (RAIL_Y - 0.4) * M, rx1 - (ARM_X1 + 0.2) * M, 0.4 * M))
	ci.draw_line(Vector2(rx0, RAIL_Y * M + 2), Vector2(rx1, RAIL_Y * M + 2), Pal.ink(0.5), 2.0)
	ci.draw_line(Vector2(rx0, RAIL_Y * M + 5), Vector2(rx1, RAIL_Y * M + 5), Pal.ink(0.16), 1.0)
	for ex in [rx0, rx1]:
		ci.draw_rect(Rect2(ex - 3, RAIL_Y * M - 2, 6, 10), Pal.heat(0.6, 1.1))
	# the berth's own plate on the tower: its number, and whose it is
	var pr := Rect2((TOWER_X + 0.9) * M, 5.0 * M, 8.0 * M, 1.4 * M)
	ci.draw_rect(pr, Color(0.035, 0.037, 0.042, 0.96))
	ci.draw_rect(Rect2(pr.position, Vector2(5, pr.size.y)), Pal.heat(0.9, 1.1))
	ci.draw_rect(pr, Pal.ink(0.25), false, 1.0)
	ci.draw_string(font_b, pr.position + Vector2(18, 40), "BERTH 07", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Pal.ink(0.92))
	var company: String = str(Career.data.get("company", "")) if game != null and game.career() else ""
	ci.draw_string(font, pr.position + Vector2(190, 40), (company + "  ·  " if company != "" and company != "BERTH 07" else "") + "SALVAGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.ink(0.55))
	# debris net
	var nc := NET * M
	var net_pts := PackedVector2Array()
	for i in 17:
		var a := lerpf(PI * 1.05, PI * 1.95, i / 16.0)
		net_pts.append(nc + Vector2(cos(a) * 78.0, -sin(a) * 30.0 + 30.0))
	ci.draw_colored_polygon(net_pts, Color(0.04, 0.042, 0.048))
	for i in range(1, 16):
		ci.draw_line(net_pts[i], nc + Vector2((i - 8) * 3.0, 58), Pal.ink(0.12), 1.0)
	for ring in [0.4, 0.7]:
		var rp := PackedVector2Array()
		for q in net_pts:
			rp.append(nc + Vector2(0, 30) + (q - nc - Vector2(0, 30)) * ring)
		ci.draw_polyline(rp, Pal.ink(0.12), 1.0, true)
	ci.draw_polyline(net_pts, Pal.ink(0.7), 2.4, true)
	_net_detail(ci, true)
	for e in [net_pts[0], net_pts[16]]:
		ci.draw_circle(e, 4.0, Pal.ink(0.7))
	var cap := 0.5 if game != null and game.has_upgrade("net05") else 0.1
	var nr := Rect2(nc + Vector2(-98, -42), Vector2(196, 30))
	ci.draw_rect(nr, Color(0.035, 0.037, 0.042, 0.94))
	ci.draw_rect(Rect2(nr.position, Vector2(4, nr.size.y)), Pal.ink(0.8))
	ci.draw_string(font_b, nr.position + Vector2(14, 21), game.txt("net") + "  ≤ %.1f t" % cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.9))
	# drone bay
	var bc := BAY * M
	var hr := Rect2(bc + Vector2(-100, -48), Vector2(100, 96))
	ci.draw_rect(hr, Color(0.05, 0.053, 0.06))
	ci.draw_polyline(PackedVector2Array([bc + Vector2(0, -48), bc + Vector2(-100, -48), bc + Vector2(-100, 48), bc + Vector2(0, 48)]), Pal.ink(0.7), 2.0, true)
	# the launch pad: the drone's outline painted on it (nose to the door), with landing marks
	var pc := bc + Vector2(-46, 0)
	var pad := PackedVector2Array()
	for v in preload("res://scripts/drone_art.gd").ARROW:
		pad.append(pc + (v as Vector2) * 1.25)
	pad.append(pad[0])
	ci.draw_polyline(pad, Pal.ink(0.3), 1.4, true)
	for i in 4:
		var d := Vector2.from_angle(TAU * i / 4.0)
		ci.draw_line(pc + d * 34.0, pc + d * 42.0, Pal.ink(0.4), 2.0)
	# the door rails at the open side
	ci.draw_line(bc + Vector2(0, -48), bc + Vector2(0, -36), Pal.ink(0.7), 3.0)
	ci.draw_line(bc + Vector2(0, 48), bc + Vector2(0, 36), Pal.ink(0.7), 3.0)
	var br := Rect2(bc + Vector2(-100, -86), Vector2(160, 30))
	ci.draw_rect(br, Color(0.035, 0.037, 0.042, 0.94))
	ci.draw_rect(Rect2(br.position, Vector2(4, br.size.y)), Pal.tint(Pal.AIR, 0.9, 1.1))
	ci.draw_string(font_b, br.position + Vector2(14, 21), game.txt("dk_bay"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.9))
	# hose masts (two on the arm, one on a pylon from the floor)
	var pyl: Vector2 = MASTS[2] * M
	_truss_v(Rect2(pyl.x - 0.25 * M, pyl.y, 0.5 * M, FLOOR_Y * M - pyl.y))
	var pump2: bool = game != null and game.has_upgrade("pump2")
	for m in MASTS:
		var mp: Vector2 = m * M
		ci.draw_rect(Rect2(mp + Vector2(-14, -16), Vector2(28, 22)), Color(0.06, 0.063, 0.07))
		ci.draw_rect(Rect2(mp + Vector2(-14, -16), Vector2(28, 22)), Pal.ink(0.6), false, 1.4)
		# the hose reel
		ci.draw_arc(mp + Vector2(0, -5), 7.0, 0.0, TAU, 16, Pal.ink(0.55), 1.4, true)
		for sp in 3:
			ci.draw_line(mp + Vector2(0, -5), mp + Vector2(0, -5) + Vector2.from_angle(TAU * sp / 3.0) * 7.0, Pal.ink(0.35), 1.0)
		ci.draw_string(font, mp + Vector2(18, 0), game.txt("dk_mast"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.45))
		if pump2:
			# the high-flow pump: a second, bigger housing with an impeller ring
			ci.draw_rect(Rect2(mp + Vector2(12, -18), Vector2(22, 22)), Color(0.07, 0.073, 0.082))
			ci.draw_rect(Rect2(mp + Vector2(12, -18), Vector2(22, 22)), Pal.ink(0.6), false, 1.4)
			ci.draw_arc(mp + Vector2(23, -7), 7.0, 0.0, TAU, 16, Pal.ink(0.55), 1.2, true)
			ci.draw_line(mp + Vector2(10, -6), mp + Vector2(12, -6), Pal.ink(0.5), 2.0)


func _draw_clamps() -> void:
	var M := Geom.M
	var ink := Pal.ink(0.32)
	for i in clamps.size():
		var x: float = clamps[i].x * M
		var k: float = Pal.ease_io(clamp_t[i])
		var top := lerpf(clamps[i].y * M, 7.6 * M, k)
		clamp_node.draw_rect(Rect2(x - 7, top + 10, 14, FLOOR_Y * M - top - 10), Color(0.07, 0.073, 0.082))
		clamp_node.draw_rect(Rect2(x - 7, top + 10, 14, FLOOR_Y * M - top - 10), ink, false, 1.2)
		for yy in range(int(top + 22), int(FLOOR_Y * M), 18):
			clamp_node.draw_line(Vector2(x - 7, yy), Vector2(x + 7, yy + 9), Pal.ink(0.12), 1.0)
		var open := k * 9.0
		clamp_node.draw_polyline(PackedVector2Array([Vector2(x - 16 - open, top + 2), Vector2(x - 16 - open, top + 12), Vector2(x + 16 + open, top + 12), Vector2(x + 16 + open, top + 2)]), Pal.ink(0.75), 2.0, true)
		clamp_node.draw_string(font, Vector2(x + 12, top + 34), "CL-0%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.4))


# the tug's acceleration along x (px/s², + to the right), from how it moves
func tug_accel() -> float:
	if game == null or not game.state in ["intro", "towout"]:
		return 0.0
	var h := 1.0 / 60.0
	var tt: float = game.state_t
	return (_tug_x(tt + h) - 2.0 * _tug_x(tt) + _tug_x(tt - h)) / (h * h)


func _tug_x(tt: float) -> float:
	if game.state == "towout":
		return game.ship_offset * pow(clampf(tt / game.TOW_T, 0.0, 1.0), 3.0) + stern.x * Geom.M
	var x: float = game.ship_offset * (1.0 - Pal.ease_io(clampf(tt / 3.4, 0.0, 1.0))) + stern.x * Geom.M
	if tt > 3.4:
		x += pow(tt - 3.4, 2.0) * 900.0
	return x


func tug_pos() -> Vector2:
	if game != null and game.state == "towout":
		return Vector2(world.position.x + stern.x * Geom.M, stern.y * Geom.M)
	if game == null or game.state != "intro":
		return Vector2.INF
	var tt: float = game.state_t
	var x: float = world.position.x + stern.x * Geom.M
	if tt > 3.4:
		x += pow(tt - 3.4, 2.0) * 900.0
	return Vector2(x, stern.y * Geom.M)


func _tug(p: Vector2, ci) -> void:
	var M := Geom.M
	var hull := PackedVector2Array([p + Vector2(0.2 * M, -0.9 * M), p + Vector2(4.6 * M, -1.3 * M), p + Vector2(6.0 * M, -0.6 * M), p + Vector2(6.0 * M, 0.6 * M), p + Vector2(4.6 * M, 1.3 * M), p + Vector2(0.2 * M, 0.9 * M)])
	ci.draw_colored_polygon(hull, Color(0.07, 0.073, 0.082))
	var cl := hull.duplicate()
	cl.append(hull[0])
	ci.draw_polyline(cl, Pal.ink(0.8), 1.4, true)
	ci.draw_line(p + Vector2(0.0, -0.7 * M), p + Vector2(0.0, 0.7 * M), Pal.ink(0.9), 3.0)
	ci.draw_rect(Rect2(p + Vector2(2.0 * M, -0.5 * M), Vector2(1.6 * M, 1.0 * M)), Pal.ink(0.3), false, 1.0)
	ci.draw_string(font, p + Vector2(2.1 * M, -0.6 * M), "TUG-04", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.5))


# the buffer platform: a grated deck with tractor emitters along its edge
func _buffer(ci) -> void:
	var r := Rect2(BUFFER.position * Geom.M, BUFFER.size * Geom.M)
	var deck := Rect2(Vector2(r.position.x, r.end.y - 10.0), Vector2(r.size.x, 10.0))
	ci.draw_rect(deck, Color(0.06, 0.064, 0.072))
	ci.draw_rect(deck, Pal.ink(0.45), false, 1.4)
	var x := deck.position.x + 8.0
	while x < deck.end.x - 4.0:
		ci.draw_line(Vector2(x, deck.position.y + 2.0), Vector2(x, deck.end.y - 2.0), Pal.ink(0.2), 1.0)
		x += 12.0
	for i in 6:
		var ex := r.position.x + (i + 0.5) / 6.0 * r.size.x
		var a := 0.12 + 0.06 * sin(t * 3.0 + i)
		ci.draw_line(Vector2(ex, deck.position.y), Vector2(ex, r.position.y), Pal.tint(Pal.AIR, a, 1.2), 1.0)
		ci.draw_circle(Vector2(ex, deck.position.y - 2.0), 2.4, Pal.tint(Pal.AIR, 0.6, 1.3))
	ci.draw_rect(r, Pal.tint(Pal.AIR, 0.18), false, 1.0)
	ci.draw_string(font_b, r.position + Vector2(8, 18), game.txt("dk_buffer"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.tint(Pal.AIR, 0.75, 1.1))


# a keep-out zone the operator set: no machine goes in
func _keepout(r: Rect2, ci) -> void:
	ci.draw_rect(r, Pal.heat(0.05, 1.0))
	var n := int(r.size.x / 24.0)
	for i in n + 1:
		var x0 := r.position.x + i * 24.0
		ci.draw_line(Vector2(x0, r.position.y), Vector2(x0 - 10.0, r.position.y + 10.0), Pal.heat(0.45, 1.2), 2.0)
		ci.draw_line(Vector2(x0, r.end.y - 10.0), Vector2(x0 - 10.0, r.end.y), Pal.heat(0.45, 1.2), 2.0)
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position])
	for i in 4:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var L := a.distance_to(b)
		var k := 0.0
		while k < L:
			ci.draw_line(a.lerp(b, k / L), a.lerp(b, minf(k + 10.0, L) / L), Pal.heat(0.7, 1.3), 1.6)
			k += 18.0
	ci.draw_string(font_b, r.position + Vector2(8, 28), game.txt("dk_keepout"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.heat(0.85, 1.3))


# ---------------------------------------------------------------- the recovery mouths
# Three mouths, three looks, one way of reading them: the colour says what it
# takes (white: whole equipment, heat: scrap, green: hazards), the sign beside
# it says it in words with an icon, the lamp on the sign says whether it is
# ready, taking something in, or has just refused something, and while the
# drone carries something a mouth wants, that mouth's catch zone lights up.

static func zone_col(id: String, a: float = 1.0, k: float = 1.0) -> Color:
	match id:
		"metal": return Pal.heat(a, k)
		"hazard": return Pal.tint(Pal.FLUID, a, k)
	return Pal.ink(a, k)


# what the drone is carrying belongs in this mouth
func _wanted(id: String) -> bool:
	var b = game.tools.held_body
	if b == null or not is_instance_valid(b) or game.hud == null:
		return false
	return game.hud._zone_for(b) == id


func _mouth_batched(id: String, node: Node2D) -> void:
	var cb = CanvasBatch.new(node)
	_mouth(id, cb)
	cb.flush()


func _mouth(id: String, ci) -> void:
	var M := Geom.M
	var z: Dictionary = ZONES[id]
	var st: Dictionary = zone_state[id]
	var c: Vector2 = zpos(id)
	var f: Vector2 = z.face                 # from the mouth out into the berth
	var side := Vector2(-f.y, f.x)
	var hw: float = z.w * 0.5 * M
	var depth := 1.7 * M
	var col := zone_col(id, 0.85)
	if st.reject > 0.0:
		col = col.lerp(Pal.heat(1.0, 1.5), st.reject)
	var want := _wanted(id)
	# the catch zone, while the drone carries something for this mouth
	if want:
		var reach: float = (SCRAP_FIELD if id == "metal" else FIELD) * M
		var pulse := 0.5 + 0.5 * sin(t * 4.0)
		ci.draw_circle(c, reach, zone_col(id, 0.035 + 0.025 * pulse))
		var n := 48
		for i in n:
			if i % 2 == 0:
				ci.draw_arc(c, reach, TAU * i / n + t * 0.2, TAU * (i + 1) / n + t * 0.2, 4, zone_col(id, 0.55), 2.0, true)
	# the housing: a funnel from a wide lip down to a narrow throat
	var lip := hw + 26.0
	var throat_w := hw * 0.55
	var hous := PackedVector2Array([c + side * lip, c - side * lip, c - side * throat_w - f * depth, c + side * throat_w - f * depth])
	ci.draw_colored_polygon(hous, Color(0.05, 0.053, 0.06))
	# depth: bands that get darker toward the throat
	for i in 5:
		var e := (i + 1) / 6.0
		var wl := lerpf(lip, throat_w, e)
		ci.draw_line(c + side * wl - f * depth * e, c - side * wl - f * depth * e, zone_col(id, 0.05 + 0.1 * st.glow + 0.25 * st.eat * (1.0 - e)), 1.0)
	var outline := hous.duplicate()
	outline.append(hous[0])
	ci.draw_polyline(outline, col, 2.0, true)
	# the lip: a heavy rim with lamps that chase inward while it takes something in
	ci.draw_line(c + side * (lip + 8), c - side * (lip + 8), col, 4.0)
	var lamps := 7
	for i in lamps:
		var u := (i + 0.5) / lamps * 2.0 - 1.0
		var p := c + side * u * lip + f * 4.0
		var on := 0.25
		if st.eat > 0.0 or st.glow > 0.0:
			on = 0.35 + 0.65 * maxf(0.0, sin(t * 10.0 - absf(u) * 4.0))
		elif want:
			on = 0.4 + 0.4 * sin(t * 4.0)
		ci.draw_circle(p, 2.6, zone_col(id, on, 1.3))
	match kind(id):
		"equip":
			# the trolley it hangs from on the rail, wheels turning while it moves
			var ty := RAIL_Y * M + 4.0
			var moving: bool = equip_goal.has(id) and equip_x.has(id) and absf(equip_x[id] - equip_goal[id]) > 0.001
			ci.draw_rect(Rect2(Vector2(c.x - 0.75 * M, ty), Vector2(1.5 * M, 10)), Color(0.07, 0.073, 0.082))
			ci.draw_rect(Rect2(Vector2(c.x - 0.75 * M, ty), Vector2(1.5 * M, 10)), col, false, 1.4)
			for wx in [-0.5, 0.5]:
				var wc := Vector2(c.x + wx * M, ty)
				ci.draw_circle(wc, 5.0, Color(0.05, 0.053, 0.06))
				ci.draw_arc(wc, 5.0, 0.0, TAU, 12, col, 1.4, true)
				var sp := c.x / 5.0
				ci.draw_line(wc, wc + Vector2(cos(sp), sin(sp)) * 4.0, col, 1.2)
			if moving:
				ci.draw_circle(Vector2(c.x, ty + 5), 2.6, Pal.heat(0.6 + 0.4 * sin(t * 12.0), 1.6))
			# padded cradle arms either side, guide rails down the throat
			for s in [-1.0, 1.0]:
				var a0: Vector2 = c + side * s * (lip + 4.0)
				var a1: Vector2 = a0 + f * 26.0 - side * s * 10.0
				ci.draw_line(a0, a1, col, 3.0, true)
				ci.draw_circle(a1, 5.0, Color(0.05, 0.053, 0.06))
				ci.draw_arc(a1, 5.0, 0.0, TAU, 14, col, 1.6, true)
				ci.draw_line(c + side * s * hw * 0.5, c + side * s * throat_w * 0.6 - f * depth * 0.9, Pal.ink(0.25), 1.2)
			_equip_detail(id, c, f, side, lip, throat_w, depth, st, ci)
		"metal":
			# a grate across the throat, glowing with what melts below
			var gy := c - f * depth * 0.62
			var gw := lerpf(lip, throat_w, 0.62)
			for i in 7:
				var u2 := (i + 0.5) / 7.0 * 2.0 - 1.0
				ci.draw_line(gy + side * u2 * gw - f * 6.0, gy + side * u2 * gw + f * 6.0, Pal.heat(0.6 + 0.3 * sin(t * 3.0 + i), 1.3), 2.0)
			ci.draw_line(gy + side * gw, gy - side * gw, Pal.heat(0.5, 1.2), 1.4)
		"hazard":
			# hazard stripes along the lip, and two doors that slide apart when it opens
			var open: float = clampf(maxf(st.glow, st.eat) + (0.6 if want else 0.0), 0.0, 1.0)
			for i in 10:
				var u3 := float(i) / 10.0 * 2.0 - 1.0
				var p0 := c + side * u3 * lip - f * 6.0
				ci.draw_line(p0, p0 + side * 10.0 - f * 8.0, Pal.tint(Pal.FLUID, 0.5, 1.0), 3.0)
			for s in [-1.0, 1.0]:
				var dw: float = lip * (1.0 - open) * 0.95
				var d0: Vector2 = c - f * 16.0 + side * s * lip
				ci.draw_line(d0, d0 - side * s * dw, Pal.tint(Pal.FLUID, 0.75, 1.0), 4.0)
	_sign(id, c, f, side, lip, st, ci)


# the sign beside a mouth: an icon, the name, what goes in, and a status lamp
func _sign(id: String, c: Vector2, f: Vector2, side: Vector2, lip: float, st: Dictionary, ci) -> void:
	var sz := Vector2(262, 66)
	# beside the mouth, on the side with room (the hazard bay is at the berth's end)
	# the hazard bay sits at the berth's end: its sign goes straight above it
	var above := id == "hazard"
	var at: Vector2 = (c + Vector2(-sz.x * 0.5, -2.3 * Geom.M - sz.y)) if above else (c + Vector2(lip + 40.0, -sz.y * 0.5) + f * 1.2 * Geom.M)
	var r := Rect2(at, sz)
	ci.draw_rect(r, Color(0.035, 0.037, 0.042, 0.94))
	ci.draw_rect(Rect2(r.position, Vector2(4, r.size.y)), zone_col(id, 0.95, 1.1))
	ci.draw_rect(r, zone_col(id, 0.35), false, 1.0)
	if above:
		ci.draw_line(Vector2(r.get_center().x, r.end.y), c - Vector2(0, 26), zone_col(id, 0.35), 1.0)
	else:
		ci.draw_line(Vector2(r.position.x, r.get_center().y), c + Vector2(lip + 8.0, 0), zone_col(id, 0.35), 1.0)
	_icon(id, r.position + Vector2(30, 33), ci)
	ci.draw_string(font_b, r.position + Vector2(58, 28), game.txt("zone_" + kind(id)), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Pal.ink(0.95))
	ci.draw_string(font, r.position + Vector2(58, 50), game.txt("zone_" + kind(id) + "_d"), HORIZONTAL_ALIGNMENT_LEFT, sz.x - 66, 13, Pal.ink(0.6))
	# status
	var key := "dk_ready"
	var lc := Pal.tint(Pal.FLUID, 0.9, 1.3)
	if st.reject > 0.0:
		key = "dk_refused"
		lc = Pal.heat(0.6 + 0.4 * sin(t * 18.0), 1.5)
	elif st.eat > 0.0 or st.busy > 0.0:
		key = "dk_taking"
		lc = Pal.ink(0.6 + 0.4 * sin(t * 12.0), 1.4)
	var sw := font.get_string_size(game.txt(key), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	ci.draw_circle(Vector2(r.end.x - 14, r.position.y + 14), 4.0, lc)
	ci.draw_string(font, Vector2(r.end.x - 24 - sw, r.position.y + 18), game.txt(key), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.6))


func _icon(id: String, p: Vector2, ci) -> void:
	var col := zone_col(id, 0.95, 1.2)
	match kind(id):
		"equip":
			# a crate with a check
			ci.draw_rect(Rect2(p - Vector2(13, 11), Vector2(26, 22)), col, false, 1.8)
			ci.draw_polyline(PackedVector2Array([p + Vector2(-6, 0), p + Vector2(-1, 5), p + Vector2(7, -5)]), col, 2.0, true)
		"metal":
			# a flame over a hopper
			ci.draw_polyline(PackedVector2Array([p + Vector2(-12, 4), p + Vector2(-6, 13), p + Vector2(6, 13), p + Vector2(12, 4)]), col, 1.8, true)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -14), p + Vector2(7, -2), p + Vector2(3, 4), p + Vector2(-3, 4), p + Vector2(-7, -2)]), col)
		"hazard":
			# a warning diamond
			ci.draw_polyline(PackedVector2Array([p + Vector2(0, -14), p + Vector2(14, 0), p + Vector2(0, 14), p + Vector2(-14, 0), p + Vector2(0, -14)]), col, 1.8, true)
			ci.draw_line(p + Vector2(0, -6), p + Vector2(0, 3), col, 2.4)
			ci.draw_circle(p + Vector2(0, 8), 1.8, col)


# the scrap trough: a recessed channel along the floor, a belt of slats running
# toward the furnace, arrows on the rail; lit along its length while scrap is carried
func _trough_live(cb) -> void:
	var M := Geom.M
	var mx: float = zpos("metal").x
	var y0 := TROUGH_Y * M
	var y1 := FLOOR_Y * M
	var x0 := TROUGH_X0 * M
	var x1 := TROUGH_X1 * M
	var want := _wanted("metal")
	if want:
		cb.draw_rect(Rect2(x0, y0 - 6, x1 - x0, 6), Pal.heat(0.12 + 0.08 * sin(t * 4.0), 1.2))
	# the suction over the belt: a band that fades upward, chevrons falling into it,
	# brighter while scrap is carried and where it draws something down
	var sh := SUCK_H * M
	var band := 0.05 + (0.07 + 0.04 * sin(t * 4.0) if want else 0.0) + 0.08 * suck_glow
	cb.draw_polygon(PackedVector2Array([Vector2(x0, y0 - sh), Vector2(x1, y0 - sh), Vector2(x1, y0), Vector2(x0, y0)]),
		PackedColorArray([Pal.heat(0.0), Pal.heat(0.0), Pal.heat(band, 1.2), Pal.heat(band, 1.2)]))
	if suck_glow > 0.0:
		cb.draw_texture_rect(game.fx.glow_tex, Rect2(Vector2(suck_x - 1.6 * M, y0 - sh * 0.8), Vector2(3.2 * M, sh)), false, Pal.heat(0.22 * suck_glow, 1.5))
	# chevrons, belt slats and rail arrows: one batched call each (they were
	# ~200 calls a frame)
	var vis := _vis_x()
	var fall := fposmod(t * 0.9, 1.0)
	var chev := PackedVector2Array()
	var chev_c := PackedColorArray()
	var cx := x0 + 2.25 * M + maxf(0.0, floorf((vis.x - x0) / (3.0 * M))) * 3.0 * M
	while cx < minf(x1 - 1.0 * M, vis.y):
		if absf(cx - mx) > 2.6 * M:
			for j in 2:
				var u := fposmod(fall + j * 0.5, 1.0)
				var cy := y0 - sh * (1.0 - u) + 4.0
				var cc := Pal.heat((0.10 + (0.30 if want else 0.0)) * sin(u * PI), 1.3)
				chev.append_array([Vector2(cx - 6, cy - 4), Vector2(cx, cy + 2), Vector2(cx, cy + 2), Vector2(cx + 6, cy - 4)])
				chev_c.append_array([cc, cc])
		cx += 3.0 * M
	if not chev.is_empty():
		cb.draw_multiline_colors(chev, chev_c, 1.4, true)
	var ph := fposmod(t * CONVEY * M, 24.0)
	var slats := PackedVector2Array()
	var x := x0 + 6.0 + maxf(0.0, floorf((vis.x - x0) / 24.0) - 1.0) * 24.0
	while x < minf(x1 - 6.0, vis.y + 24.0):
		var px := x + (ph if x < mx else -ph)
		if px > x0 + 2.0 and px < x1 - 2.0 and absf(px - mx) > 1.4 * M:
			slats.append_array([Vector2(px, y0 + 8), Vector2(px, y1 - 6)])
		x += 24.0
	if not slats.is_empty():
		cb.draw_multiline(slats, Pal.ink(0.16), 2.0)
	# arrows on the rail, every few metres, pointing to the furnace
	var arrows := PackedVector2Array()
	var ax := x0 + 1.5 * M + maxf(0.0, floorf((vis.x - x0) / (3.0 * M))) * 3.0 * M
	while ax < minf(x1 - 1.0 * M, vis.y):
		if absf(ax - mx) > 2.6 * M:
			var d := 1.0 if ax < mx else -1.0
			var ay := y0 + 4.0
			arrows.append_array([Vector2(ax - 5.0 * d, ay - 5), Vector2(ax + 3.0 * d, ay), Vector2(ax + 3.0 * d, ay), Vector2(ax - 5.0 * d, ay + 5)])
		ax += 3.0 * M
	if not arrows.is_empty():
		cb.draw_multiline(arrows, Pal.heat(0.55 if want else 0.3, 1.2), 1.6, true)


# a plated girder: a lit top edge, a shadowed bottom, posts and diagonals, rivets at the nodes
# The trusses are long: drawn piece by piece they made over a thousand draw
# calls a frame (a line, a line, a dot, a dot... every change of kind a new
# batch). Now each truss gathers its posts, braces and rivets and draws each
# kind once (2026-10-18 performance work).
func _truss(r: Rect2) -> void:
	var ci = _sb if _sb != null else static_node
	ci.draw_rect(r, Color(0.052, 0.055, 0.062))
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.22)), Color(0.075, 0.079, 0.088))
	ci.draw_rect(Rect2(Vector2(r.position.x, r.end.y - r.size.y * 0.18), Vector2(r.size.x, r.size.y * 0.18)), Color(0.04, 0.042, 0.048))
	var posts := PackedVector2Array()
	var braces := PackedVector2Array()
	var rivets_top := PackedVector2Array()
	var rivets_bot := PackedVector2Array()
	var x := r.position.x
	var k := 0
	while x < r.end.x:
		var nx := minf(x + r.size.y, r.end.x)
		posts.append_array([Vector2(x, r.position.y), Vector2(x, r.end.y)])
		if k % 2 == 0:
			braces.append_array([Vector2(x, r.position.y), Vector2(nx, r.end.y)])
		else:
			braces.append_array([Vector2(x, r.end.y), Vector2(nx, r.position.y)])
		rivets_top.append(Vector2(x, r.position.y + 3))
		rivets_bot.append(Vector2(x, r.end.y - 3))
		x = nx
		k += 1
	if not _far:
		ci.draw_multiline(posts, Pal.ink(0.12), 1.0)
		ci.draw_multiline(braces, Pal.ink(0.16), 1.2)
		_dots(ci, rivets_top, 1.4, Pal.ink(0.35))
		_dots(ci, rivets_bot, 1.4, Pal.ink(0.25))
	ci.draw_line(r.position, Vector2(r.end.x, r.position.y), Pal.ink(0.6), 1.6)
	ci.draw_line(Vector2(r.position.x, r.end.y), r.end, Pal.ink(0.28), 1.2)


func _truss_v(r: Rect2) -> void:
	var ci = _sb if _sb != null else static_node
	ci.draw_rect(r, Color(0.052, 0.055, 0.062))
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x * 0.22, r.size.y)), Color(0.075, 0.079, 0.088))
	var posts := PackedVector2Array()
	var braces := PackedVector2Array()
	var rivets := PackedVector2Array()
	var y := r.position.y
	var k := 0
	while y < r.end.y:
		var ny := minf(y + r.size.x, r.end.y)
		posts.append_array([Vector2(r.position.x, y), Vector2(r.end.x, y)])
		if k % 2 == 0:
			braces.append_array([Vector2(r.position.x, y), Vector2(r.end.x, ny)])
		else:
			braces.append_array([Vector2(r.end.x, y), Vector2(r.position.x, ny)])
		rivets.append(Vector2(r.position.x + 3, y))
		y = ny
		k += 1
	if not _far:
		ci.draw_multiline(posts, Pal.ink(0.12), 1.0)
		ci.draw_multiline(braces, Pal.ink(0.16), 1.2)
		_dots(ci, rivets, 1.4, Pal.ink(0.35))
	ci.draw_line(r.position, Vector2(r.position.x, r.end.y), Pal.ink(0.6), 1.6)
	ci.draw_line(Vector2(r.end.x, r.position.y), r.end, Pal.ink(0.28), 1.2)


# many small round dots of one colour in one call (hexagons, as small as these are)
static func _dots(ci, at: PackedVector2Array, rad: float, col: Color) -> void:
	if at.is_empty() or (ci is RefCounted and ci.no_shapes):
		return
	var pts := PackedVector2Array()
	var idx := PackedInt32Array()
	for c in at:
		var b := pts.size()
		pts.append(c)
		for j in 6:
			pts.append(c + Vector2.from_angle(TAU * j / 6.0) * rad)
		for j in 6:
			idx.append_array([b, b + 1 + j, b + 1 + (j + 1) % 6])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, PackedColorArray([col]))


# diagonal warning stripes over a band (heat on dark)
func _stripes(r: Rect2, a: float = 0.55) -> void:
	var ci = _sb if _sb != null else static_node
	ci.draw_rect(r, Color(0.03, 0.03, 0.03))
	var x := r.position.x - r.size.y
	var i := 0
	while x < r.end.x:
		if i % 2 == 0:
			var pts := PackedVector2Array([Vector2(x, r.end.y), Vector2(x + r.size.y, r.position.y), Vector2(x + r.size.y + 10, r.position.y), Vector2(x + 10, r.end.y)])
			for j in pts.size():
				pts[j] = Vector2(clampf(pts[j].x, r.position.x, r.end.x), pts[j].y)
			ci.draw_colored_polygon(pts, Pal.heat(a, 1.0))
		x += 10
		i += 1


func _draw_trough(ci) -> void:
	var M := Geom.M
	var mx: float = zpos("metal").x
	var y := (TROUGH_Y + 0.4) * M
	var x := TROUGH_X0 * M + 20.0
	var ph := fposmod(t * CONVEY * M * 0.25, 40.0)
	while x < TROUGH_X1 * M - 10.0:
		var px := x + (ph if x < mx else -ph)
		var dirx := 1.0 if px < mx else -1.0
		if absf(px - mx) > 30.0:
			ci.draw_line(Vector2(px - 5.0 * dirx, y - 6), Vector2(px + 3.0 * dirx, y), Pal.heat(0.25, 1.2), 1.4)
			ci.draw_line(Vector2(px + 3.0 * dirx, y), Vector2(px - 5.0 * dirx, y + 6), Pal.heat(0.25, 1.2), 1.4)
		x += 40.0


# the strip of the berth the camera sees (canvas pixels, with a margin): the lamps,
# belt slats and arrows along a 620 m berth were ~600 calls a frame drawn whole
func _vis_x() -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return Vector2(-INF, INF)
	var inv := get_global_transform_with_canvas().affine_inverse()
	var r := vp.get_visible_rect()
	var a: Vector2 = inv * r.position
	var b: Vector2 = inv * r.end
	return Vector2(minf(a.x, b.x) - 80.0, maxf(a.x, b.x) + 80.0)


const FLOODS := [9.5, 19.0]      # m along the boom: lamps that light the ship from above


func _draw_lights() -> void:
	var M := Geom.M
	var tex: Texture2D = game.fx.glow_tex
	# floodlights: a soft cone down onto the ship, a bright head on the boom
	for fx_ in FLOODS:
		var hp := Vector2(fx_, RAIL_Y + 0.1) * M
		# the cone fades out downwards (bright at the lamp, nothing by the hull's far side)
		var cone := PackedVector2Array([hp + Vector2(-10, 0), hp + Vector2(10, 0), hp + Vector2(3.2 * M, 8.0 * M), hp + Vector2(-3.2 * M, 8.0 * M)])
		var cc := PackedColorArray([Pal.ink(0.045, 1.2), Pal.ink(0.045, 1.2), Pal.ink(0.0), Pal.ink(0.0)])
		_ab.draw_polygon(cone, cc)
		_ab.draw_texture_rect(tex, Rect2(hp - Vector2(26, 14), Vector2(52, 28)), false, Pal.ink(0.5, 1.6))
		_ab.draw_circle(hp, 3.0, Pal.ink(0.95, 2.0))
	# marker lights along the deck edge and under the boom, chasing slowly toward the furnace
	var mx: float = zpos("metal").x / M
	var vis := _vis_x() / M
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var x := maxf(TOWER_X + 1.0, TOWER_X + 1.0 + floorf((vis.x - TOWER_X - 1.0) / 2.0) * 2.0)
	while x < minf(FLOOR_X1 - 0.5, vis.y):
		var ph := fposmod(t * 0.8 - absf(x - mx) * 0.08, 1.0)
		var a := 0.15 + 0.55 * pow(1.0 - ph, 6.0)
		_lamp(pts, cols, idx, Vector2(x, FLOOR_Y) * M + Vector2(0, -2), 2.2, Pal.heat(a, 1.6))
		x += 2.0
	x = maxf(TOWER_X + 1.0, TOWER_X + 1.0 + floorf((vis.x - TOWER_X - 1.0) / 3.0) * 3.0)
	while x < minf(ARM_X1 - 0.5, vis.y):
		var a2 := 0.12 + 0.12 * sin(t * 1.5 + x)
		_lamp(pts, cols, idx, Vector2(x, RAIL_Y) * M + Vector2(0, 2), 1.8, Pal.ink(a2, 1.6))
		x += 3.0
	if not idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(_ab.get_canvas_item(), idx, pts, cols)


func _draw_add() -> void:
	_ab = CanvasBatch.new(add_node)
	_draw_add_body()
	_ab.flush()
	_ab = null


func _draw_add_body() -> void:
	_draw_lights()
	var tex: Texture2D = game.fx.glow_tex
	var M := Geom.M
	# beacons on the open ends of the arm and the platform, and the field corners
	var blink := 0.5 + 0.5 * sin(t * 2.4)
	for bp in [Vector2(ARM_X1, RAIL_Y - 0.3), Vector2(FLOOR_X1, FLOOR_Y + 0.3)]:
		_ab.draw_texture_rect(tex, Rect2(bp * M - Vector2(18, 18), Vector2(36, 36)), false, Pal.heat(0.25 + 0.6 * blink, 1.8))
		_ab.draw_circle(bp * M, 2.5, Pal.heat(0.6 + 0.4 * blink, 2.0))
	var fr := Rect2((BOUNDS.position + Vector2(0.0, 2.0)) * M, (BOUNDS.size - Vector2(2.5, 2.0)) * M)
	var fb := 0.5 + 0.5 * sin(t * 1.3 + 1.0)
	for cp in [fr.position, Vector2(fr.end.x, fr.position.y), Vector2(fr.end.x, fr.end.y)]:
		_ab.draw_texture_rect(tex, Rect2(cp - Vector2(12, 12), Vector2(24, 24)), false, Pal.ink(0.12 + 0.2 * fb, 1.3))
	# the field lights up where something leans on it
	for g in field_glow:
		var a: float = g[1]
		_ab.draw_texture_rect(tex, Rect2(g[0] - Vector2(60, 60), Vector2(120, 120)), false, Pal.tint(Pal.AIR, 0.18 * a, 1.2))
	for id in ZONES:
		var st: Dictionary = zone_state[id]
		var c := zpos(id)
		var f: Vector2 = ZONES[id].face
		var throat := c - f * 1.0 * Geom.M
		var col := Pal.heat(1.0, 1.6) if id == "metal" else (Pal.tint(Pal.FLUID, 1.0, 1.2) if id == "hazard" else Pal.ink(1.0, 1.2))
		var base := 0.16 if id == "metal" else 0.06
		var a: float = base + 0.25 * st.glow + 0.7 * st.eat
		var r: float = 70.0 + 50.0 * st.eat
		_ab.draw_texture_rect(tex, Rect2(throat - Vector2(r * 1.6, r), Vector2(r * 3.2, r * 2.0)), false, Color(col.r, col.g, col.b, a))
		if id == "metal":
			# the furnace always breathes
			var br := 0.08 + 0.05 * sin(t * 2.1)
			_ab.draw_texture_rect(tex, Rect2(throat - Vector2(90, 40), Vector2(180, 80)), false, Pal.heat(br, 1.4))
	if _furnace_seen():
		smelter.draw_add(_ab, FLOOR_Y, tex)
	var tug := tug_pos()
	if tug != Vector2.INF:
		# its burn follows its real acceleration (player 2026-10-18: speeding up
		# blows backwards, slowing down is a reverse burn): the main engine at the
		# back pushes the ship in, the forward-facing retros either side of the
		# bow stop it, and then pull the tug away
		var ax := tug_accel()
		var fl := 0.8 + 0.2 * sin(t * 50.0)
		var main := clampf(-ax / 2400.0, 0.0, 1.0)
		var retro := clampf(ax / 2400.0, 0.0, 1.0)
		if main > 0.03:
			var base := tug + Vector2(6.0 * Geom.M, 0)
			_ab.draw_colored_polygon(PackedVector2Array([base + Vector2(0, -16), base + Vector2(90 * fl * (0.4 + 0.6 * main), 0), base + Vector2(0, 16)]), Pal.heat(0.6 * main, 1.8))
			_ab.draw_texture_rect(tex, Rect2(base - Vector2(40, 40), Vector2(80, 80)), false, Pal.heat(0.5 * main, 1.6))
		if retro > 0.03:
			for s: float in [-1.0, 1.0]:
				var rb := tug + Vector2(1.2 * Geom.M, 1.0 * Geom.M * s)
				var ln := 60.0 * fl * (0.4 + 0.6 * retro)
				_ab.draw_colored_polygon(PackedVector2Array([rb + Vector2(0, -7), rb + Vector2(-ln, 3.0 * s), rb + Vector2(0, 7)]), Pal.heat(0.6 * retro, 1.8))
				_ab.draw_texture_rect(tex, Rect2(rb - Vector2(24, 24), Vector2(48, 48)), false, Pal.heat(0.45 * retro, 1.6))
	for d in debris:
		var tr: Array = d[7]
		if tr.size() >= 2:
			_ab.draw_polyline(PackedVector2Array(tr), Pal.ink(0.25, 1.2), 2.0, true)


# ---------------------------------------------------------------- the furnace below the mouth

# any of the furnace plant in the camera's view
func _furnace_seen() -> bool:
	var vp := get_viewport()
	if vp == null:
		return true
	var inv := get_global_transform_with_canvas().affine_inverse()
	var r := vp.get_visible_rect()
	var a: Vector2 = inv * r.position
	var b: Vector2 = inv * r.end
	var view := Rect2(a, b - a).abs()
	var M := Geom.M
	return view.intersects(Rect2(Vector2(furnace_x - 13.0, FLOOR_Y) * M, Vector2(31.0, 11.0) * M))


func _draw_furnace() -> void:
	if not _furnace_seen():
		return
	var z: float = game.cam_zoom() if game != null else 1.0
	var tx := func(k: String) -> String: return Txt.t(k)
	var cb = CanvasBatch.new(furnace_node)
	cb.no_text = true
	var t0 := Time.get_ticks_usec()
	smelter.draw(cb, FLOOR_Y, metal_x, font, font_b, z, tx)
	var t1 := Time.get_ticks_usec()
	scrapline.draw(cb, FLOOR_Y, metal_x, font, font_b, z, tx)
	var t2 := Time.get_ticks_usec()
	cb.flush()
	prof_draw[0] += t1 - t0
	prof_draw[1] += t2 - t1
	prof_draw[2] += Time.get_ticks_usec() - t2
	prof_draw[3] += 1


func _draw_furnace_text() -> void:
	if not _furnace_seen():
		return
	var z: float = game.cam_zoom() if game != null else 1.0
	var tx := func(k: String) -> String: return Txt.t(k)
	var cb = CanvasBatch.new(furnace_text_node)
	cb.no_shapes = true
	smelter.draw(cb, FLOOR_Y, metal_x, font, font_b, z, tx)
	scrapline.draw(cb, FLOOR_Y, metal_x, font, font_b, z, tx)
	cb.flush()


# under the furnace mouth's sign: the melt and the bunker at a glance
func _furnace_strip(ci) -> void:
	if not ZONES.has("metal"):
		return
	var M := Geom.M
	var c: Vector2 = zpos("metal")
	var lip: float = ZONES.metal.w * 0.5 * M + 26.0
	var at: Vector2 = c + Vector2(lip + 40.0, -33.0) + ZONES.metal.face * 1.2 * M
	var r := Rect2(at + Vector2(0, 70), Vector2(262, 22))
	ci.draw_rect(r, Color(0.035, 0.037, 0.042, 0.9))
	ci.draw_rect(Rect2(r.position, Vector2(4, r.size.y)), Smelter.glow_col(smelter.T))
	var s := Txt.t("fu_quick") % [int(round(smelter.T)), smelter.bunker + smelter.yard, Txt.t(smelter.state_key())]
	ci.draw_string(font, r.position + Vector2(12, 16), s, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16, 12, Pal.ink(0.7))



# ---------------------------------------------------------------- the equipment bay's works
# Not just a funnel (player 2026-10-20): what a whole item meets on its way in: soft-
# capture airbags on the cradle arms, a grounding clamp that touches it first (a
# charged casing would arc), a scan arch (laser profile and backscatter X-ray, for
# damage you can't see), a weighing platform on four load cells in the throat, and
# above it the lift shaft up through the boom to the shuttle that takes it to the
# freighter; the trolley runs a rack on the rail, fed by a cable drag chain.
func _equip_detail(id: String, c: Vector2, f: Vector2, side: Vector2, lip: float, throat_w: float, depth: float, st: Dictionary, ci) -> void:
	var M := Geom.M
	var col := Pal.ink(0.6)
	var on: bool = st.eat > 0.0 or st.busy > 0.0
	# airbags on the cradle arms' tips
	for s in [-1.0, 1.0]:
		var a0: Vector2 = c + side * s * (lip + 4.0)
		var a1: Vector2 = a0 + f * 26.0 - side * s * 10.0
		var bag := 7.0 + (2.0 if on else 0.0)
		ci.draw_circle(a1 - side * s * 4.0, bag, Color(0.32, 0.18, 0.1, 0.85))
		ci.draw_arc(a1 - side * s * 4.0, bag, 0.0, TAU, 14, Pal.heat(0.6, 1.1), 1.0, true)
	# the grounding clamp on its spring arm, touching first
	var g0: Vector2 = c + side * (lip * 0.8) - f * 6.0
	var g1: Vector2 = g0 + f * (18.0 if on else 6.0) - side * 8.0
	ci.draw_line(g0, g1, Pal.tint(Pal.VOLT, 0.8, 1.1), 1.6)
	ci.draw_circle(g1, 2.5, Pal.tint(Pal.VOLT, 0.9, 1.3))
	# the scan arch across the funnel: two emitter heads, the laser fan, the X-ray line sweeping
	var ad := depth * 0.42
	var aw := lerpf(lip, throat_w, 0.42)
	var e0: Vector2 = c - f * ad + side * aw
	var e1: Vector2 = c - f * ad - side * aw
	for e in [e0, e1]:
		ci.draw_rect(Rect2(e - Vector2(5, 5), Vector2(10, 10)), Color(0.08, 0.083, 0.095))
		ci.draw_rect(Rect2(e - Vector2(5, 5), Vector2(10, 10)), col, false, 1.0)
	ci.draw_line(e0, e1, Pal.ink(0.15), 1.0)
	if on:
		var u := fposmod(t * 1.8, 1.0)
		var sy: Vector2 = f * lerpf(-ad * 0.2, ad * 0.9, u)
		ci.draw_line(e0 + sy, e1 + sy, Pal.tint(Pal.AIR, 0.85, 1.8), 1.4)
		for k in 5:
			ci.draw_line(e0, e1 + sy * float(k) / 4.0, Pal.heat(0.25, 1.4), 1.0)
	# the weighing platform in the throat on its four load cells
	var wp: Vector2 = c - f * depth * 0.92
	var ww := throat_w * 0.8
	ci.draw_line(wp + side * ww, wp - side * ww, Pal.ink(0.7), 3.0)
	for k in 4:
		var lc: Vector2 = wp + side * lerpf(-ww, ww, (k + 0.5) / 4.0) - f * 4.0
		ci.draw_rect(Rect2(lc - Vector2(3, 3), Vector2(6, 6)), Pal.tint(Pal.FLUID, 0.7 if on else 0.35, 1.2))
	# the lift shaft from the throat up through the boom to the shuttle track
	var top := Vector2(c.x, (RAIL_Y - 0.75) * M)
	for s in [-1.0, 1.0]:
		ci.draw_line(Vector2(c.x + s * throat_w * 0.5, wp.y), Vector2(c.x + s * throat_w * 0.5, top.y), Pal.ink(0.3), 1.2)
	var car_y: float = lerpf(wp.y, top.y, fposmod(t * 0.7, 1.0)) if on else wp.y
	ci.draw_line(Vector2(c.x - throat_w * 0.45, car_y), Vector2(c.x + throat_w * 0.45, car_y), Pal.ink(0.75), 2.0)
	# the rack on the rail and the trolley's pinion
	var ry := RAIL_Y * M + 2.0
	var rk := PackedVector2Array()
	var x := c.x - 1.4 * M
	while x < c.x + 1.4 * M:
		rk.append_array([Vector2(x, ry - 3.0), Vector2(x + 4.0, ry - 6.0)])
		x += 8.0
	ci.draw_multiline(rk, Pal.ink(0.35), 1.0)
	var pin := Vector2(c.x + 0.55 * M, ry - 3.0)
	ci.draw_arc(pin, 5.0, 0.0, TAU, 10, col, 1.2)
	ci.draw_line(pin, pin + Vector2.from_angle(c.x / 6.0) * 5.0, col, 1.0)
	# the drag chain feeding the trolley from the rail's near end
	var anchor := Vector2((EQUIP_RAIL_X0 - 1.0) * M, ry - 14.0)
	var mid_x := (anchor.x + c.x) * 0.5
	var chain := PackedVector2Array([anchor, Vector2(mid_x, anchor.y)])
	for k in 7:
		var a := -PI * 0.5 + PI * k / 6.0
		chain.append(Vector2(mid_x, anchor.y + 5.0) + Vector2(cos(a), sin(a)) * 5.0 * Vector2(-1, 1))
	chain.append(Vector2(c.x, anchor.y + 10.0))
	ci.draw_polyline(chain, Pal.ink(0.3), 2.0)
	# the labels, when close enough to read
	var za: float = clampf((game.cam_zoom() - 0.8) / 0.3, 0.0, 1.0) if game != null else 0.0
	if za > 0.01:
		var lc2 := Pal.ink(0.55 * za)
		ci.draw_string(font, e1 - side * 14.0 + Vector2(0, -2), Txt.t("eq_scan"), HORIZONTAL_ALIGNMENT_RIGHT if side.x > 0 else HORIZONTAL_ALIGNMENT_LEFT, -1, 10, lc2)
		ci.draw_string(font, Vector2(c.x + lip + 16.0, wp.y + 28.0), Txt.t("eq_weigh"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, lc2)
		ci.draw_string(font, g1 + Vector2(6, 12), Txt.t("eq_ground"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, lc2)
		ci.draw_string(font, Vector2(c.x + throat_w * 0.5 + 6.0, top.y + 14.0), Txt.t("eq_lift"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, lc2)
		ci.draw_string(font, c + side * (lip + 16.0) + f * 40.0, Txt.t("eq_bag"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, lc2)
		ci.draw_string(font, Vector2(c.x - 1.5 * M - 150.0, ry - 10.0), Txt.t("eq_rack"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, lc2)


# ---------------------------------------------------------------- the debris net's works
func _step_net(dt: float) -> void:
	if net_dump < 0.0 and net_load >= NET_DUMP_AT:
		net_dump = 0.0
	if net_dump >= 0.0:
		net_dump += dt / 3.2
		if net_dump >= 1.0:
			net_dump = -1.0
			net_bales += 1
			net_bale_x = NET.x + 1.2
			_net_bale_t = net_load
			net_load = 0.0
	if net_bale_x > -INF:
		net_bale_x += 2.0 * dt
		if net_bale_x >= furnace_x - 0.5:
			net_bale_x = -INF
			smelter.charge(_net_bale_t, furnace_x, 0.2)


# The net (player 2026-10-20: "the debris net needs its real structure"): an aramid
# mesh on a rigid ring held by four tensioning actuators, tractor emitters on the
# ring's ends, load cells under its mounts; when it has taken its load the dump gate
# at the bottom opens into a little baler under the floor whose bales ride a belt
# to the furnace's chute.
func _net_detail(ci, fixed: bool = false) -> void:
	var M := Geom.M
	var nc := NET * M
	var F := FLOOR_Y
	var za: float = clampf((game.cam_zoom() - 0.8) / 0.3, 0.0, 1.0) if game != null else 0.0
	if not fixed:
		_net_moving(ci, nc, F)
		return
	# the mesh: diamonds inside the bowl
	var bowl := PackedVector2Array()
	for i in 17:
		var a := lerpf(PI * 1.05, PI * 1.95, i / 16.0)
		bowl.append(nc + Vector2(cos(a) * 78.0, -sin(a) * 30.0 + 30.0))
	var mesh := PackedVector2Array()
	for k in range(-14, 15):
		for dirn in [-1.0, 1.0]:
			var p0 := nc + Vector2(k * 9.0, 28.0)
			var p1: Vector2 = p0 + Vector2(dirn * 34.0, 34.0)
			var steps := 6
			for q in steps:
				var u0 := float(q) / steps
				var u1 := float(q + 1) / steps
				var m0: Vector2 = p0.lerp(p1, u0)
				var m1: Vector2 = p0.lerp(p1, u1)
				if Geometry2D.is_point_in_polygon((m0 + m1) * 0.5, bowl):
					mesh.append_array([m0, m1])
	if not mesh.is_empty():
		ci.draw_multiline(mesh, Pal.ink(0.13), 1.0)
	# the rigid ring and the four tensioning actuators down to the floor's brackets
	ci.draw_line(bowl[0], bowl[16], Pal.ink(0.75), 3.0)
	for k in 4:
		var at: Vector2 = bowl[2 + k * 4]
		var foot := Vector2(at.x + (k - 1.5) * 6.0, F * M + 4.0)
		ci.draw_line(at, foot, Color(0.12, 0.125, 0.14), 5.0)
		ci.draw_line(at, at.lerp(foot, 0.55), Pal.ink(0.6), 1.6)
		ci.draw_rect(Rect2(foot - Vector2(4, 2), Vector2(8, 4)), Pal.tint(Pal.FLUID, 0.6, 1.1))
	# the tractor emitters on the ring's ends
	for e in [bowl[0], bowl[16]]:
		ci.draw_circle(e, 5.0, Color(0.08, 0.083, 0.095))
	# the chute through the floor, the baler's box, the belt to the furnace, the labels
	var bowl_b := nc + Vector2(0, 60.0)
	var bx0s := (NET.x - 1.2) * M
	var bx1s := (NET.x + 1.2) * M
	var by0s := (F + 0.75) * M
	var by1s := (F + 2.0) * M
	ci.draw_line(bowl_b + Vector2(-8, 4), Vector2(nc.x - 8, by0s), Pal.ink(0.35), 1.2)
	ci.draw_line(bowl_b + Vector2(8, 4), Vector2(nc.x + 8, by0s), Pal.ink(0.35), 1.2)
	ci.draw_rect(Rect2(Vector2(bx0s, by0s), Vector2(bx1s - bx0s, by1s - by0s)), Color(0.05, 0.053, 0.06))
	ci.draw_rect(Rect2(Vector2(bx0s, by0s), Vector2(bx1s - bx0s, by1s - by0s)), Pal.ink(0.55), false, 1.4)
	ci.draw_rect(Rect2(Vector2(bx0s - 1.6 * M, (by0s + by1s) * 0.5 - 8.0), Vector2(0.7 * M, 16.0)), Color(0.08, 0.083, 0.095))
	ci.draw_line(Vector2(bx1s, (F + 0.8) * M + 8.0), Vector2((metal_home - 0.5) * M, (F + 0.8) * M + 8.0), Pal.ink(0.3), 1.2)
	var lc0 := Pal.ink(0.5)
	ci.draw_string(font, bowl[16] + Vector2(10, -6), Txt.t("net_mesh"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, lc0)
	ci.draw_string(font, bowl[16] + Vector2(10, 8), Txt.t("net_ring"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, lc0)
	ci.draw_string(font, bowl[0] + Vector2(-110, -6), Txt.t("net_emit"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, lc0)


# the net's moving parts: the load reading, the dump gate, the baler's ram, the bale on its belt
func _net_moving(ci, nc: Vector2, F: float) -> void:
	var M := Geom.M
	var za: float = clampf((game.cam_zoom() - 0.8) / 0.3, 0.0, 1.0) if game != null else 0.0
	var blink := 0.5 + 0.5 * sin(t * 3.0)
	for e in [nc + Vector2(cos(PI * 1.05) * 78.0, -sin(PI * 1.05) * 30.0 + 30.0), nc + Vector2(cos(PI * 1.95) * 78.0, -sin(PI * 1.95) * 30.0 + 30.0)]:
		ci.draw_circle(e, 2.6, Pal.tint(Pal.AIR, 0.5 + 0.4 * blink, 1.5))
	# the load reading
	ci.draw_string(font, Vector2(nc.x - 2.4 * M - 150.0, (F + 1.35) * M), Txt.t("net_cell") % [net_load, NET_DUMP_AT], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.tint(Pal.FLUID, 0.85, 1.1))
	# the dump gate at the bottom, opening when the load is reached
	var gk := 0.0
	if net_dump >= 0.0:
		gk = clampf(net_dump * 3.0, 0.0, 1.0) * clampf((1.0 - net_dump) * 3.0, 0.0, 1.0)
	var gb := nc + Vector2(0, 60.0)
	for s in [-1.0, 1.0]:
		ci.draw_line(gb + Vector2(s * 10.0, 0), gb + Vector2(s * 10.0, 0) + Vector2.from_angle(PI * 0.5 + s * (PI * 0.5 - gk * 1.2)) * -10.0 * Vector2(-1, 1), Pal.ink(0.7), 2.0)
	# the chute through the floor and the baler under it
	var bx0 := (NET.x - 1.2) * M
	var bx1 := (NET.x + 1.2) * M
	var by0 := (F + 0.75) * M
	var by1 := (F + 2.0) * M
	var ram := 0.0
	if net_dump >= 0.0:
		ram = clampf((net_dump - 0.35) / 0.4, 0.0, 1.0)
		ram = sin(ram * PI)
		# the debris falling in
		for k in 6:
			var u := fposmod(net_dump * 3.0 + k * 0.17, 1.0)
			if net_dump < 0.4:
				ci.draw_rect(Rect2(Vector2(nc.x + (k - 2.5) * 6.0, lerpf(gb.y, by1 - 10.0, u)) - Vector2(2, 2), Vector2(4, 4)), Color(0.36, 0.36, 0.38))
	var rx := lerpf(bx0 + 4.0, bx1 - 22.0, ram)
	ci.draw_rect(Rect2(Vector2(rx, by0 + 4.0), Vector2(6.0, by1 - by0 - 8.0)), Color(0.11, 0.115, 0.13))
	ci.draw_line(Vector2(bx0 - 0.9 * M, (by0 + by1) * 0.5), Vector2(rx, (by0 + by1) * 0.5), Pal.ink(0.75), 3.0)
	# a bale on its belt
	var bey := (F + 0.8) * M
	if net_bale_x > -INF:
		ci.draw_rect(Rect2(Vector2(net_bale_x * M, bey - 3.0), Vector2(12, 11)), Color(0.23, 0.225, 0.23))
		ci.draw_rect(Rect2(Vector2(net_bale_x * M, bey - 3.0), Vector2(12, 11)), Pal.ink(0.6), false, 1.0)
	if za > 0.01:
		ci.draw_string(font, Vector2(bx1 + 6.0, by1 - 4.0), Txt.t("net_baler") % net_bales, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Pal.ink(0.55 * za))



# a small round lamp added to a triangle batch (a hexagon: at this size nobody can tell)
static func _lamp(pts: PackedVector2Array, cols: PackedColorArray, idx: PackedInt32Array, c: Vector2, rad: float, col: Color) -> void:
	var b := pts.size()
	pts.append(c)
	cols.append(col)
	for j in 6:
		pts.append(c + Vector2.from_angle(TAU * j / 6.0) * rad)
		cols.append(col)
	for j in 6:
		idx.append_array([b, b + 1 + j, b + 1 + (j + 1) % 6])
