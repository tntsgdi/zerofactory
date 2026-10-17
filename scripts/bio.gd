class_name Bio
extends Node
# Biological contamination (first on MED-47, design/ships/MED-47_缄默_设计稿.md).
# The ship file's "bio" section:
#   rooms  {room: index}   how contaminated a room's air starts (1 = an isolation
#                           room as its patient left it). The gas solver carries it
#                           with the air between rooms, to space with vented air, and
#                           the recovery hose's filter takes it out (Systems.bio).
#   items  {tag: {"seal": control}}   biohazard pieces: waste boxes, filters, the waste
#                           tank. Each has a seal control; sealed, it goes to the
#                           hazard mouth like any hazard. Moved unsealed, or cut at all,
#                           it spills into the air of the room it is in.
# A room that started clean and whose air goes above THRESHOLD contaminates every
# whole piece of equipment in it: a quarter of its value goes (decontamination).
# The isolation rooms that start dirty were built for it: their own fittings are
# not marked down (they were never going to be sold as clean).

const THRESHOLD := 0.08          # index in a room's air that marks what is in it
const SPILL := 1.6               # index a spilt box adds to the room it is in
const LOSS := 4000.0             # cleanup charged for a spill

var game
var world
var items := {}                  # tag -> {"seal": ctrl id}
var sealed := {}                 # tag -> true
var spilt := {}                  # tag -> true
var dirty_from_start := {}       # rooms that started above THRESHOLD
var t := 0.0


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	var b: Dictionary = ship.get("bio", {})
	items = b.get("items", {}).duplicate(true)
	var rooms: Dictionary = b.get("rooms", {})
	for r in rooms:
		if float(rooms[r]) >= THRESHOLD:
			dirty_from_start[r] = true


func active() -> bool:
	return not items.is_empty() or not dirty_from_start.is_empty()


func save_state() -> Dictionary:
	return {"sealed": sealed.keys(), "spilt": spilt.keys(), "air": game.sys.bio.duplicate(), "vented": game.sys.bio_vented}


func load_state(d: Dictionary) -> void:
	sealed = {}
	for k in d.get("sealed", []):
		sealed[k] = true
	spilt = {}
	for k in d.get("spilt", []):
		spilt[k] = true
	if d.has("air"):
		game.sys.bio = d.air.duplicate()
	game.sys.bio_vented = float(d.get("vented", 0.0))


func is_item(p) -> bool:
	return p != null and items.has(p.tag)


func is_sealed(tag: String) -> bool:
	return sealed.has(tag)


# the seal control: the lid locked down, the bag closed
func seal(tag: String) -> bool:
	if not items.has(tag) or spilt.has(tag):
		return false
	sealed[tag] = true
	return true


# a piece came loose: an unsealed biohazard among it spills where it is
func on_freed(b) -> void:
	for p in b.pieces:
		if is_item(p) and not sealed.has(p.tag) and not spilt.has(p.tag):
			_spill(p)


# the laser went into it: sealed or not, it is open now
func on_cut(p) -> void:
	if is_item(p) and not spilt.has(p.tag):
		_spill(p)


func _spill(p) -> void:
	spilt[p.tag] = true
	var at: Vector2 = world.frame(p) * Geom.centroid(p.poly)
	var room: String = world.room_at(at)
	if room == "":
		room = p.room
	if room != "" and not world.rooms.has(room):
		room = ""
	if room != "":
		game.sys.bio_add(room, SPILL)
	else:
		# out in the open: it settles on what is close by
		_mark_near(at, 3.0 * Geom.M)
	game.incident("bio", p.tag)
	game.say("bio_spill", at + Vector2(0, -40), p.tag)
	game.lose("loss_bio", LOSS, at + Vector2(0, -60))
	game.sfx.play("deny")


func _physics_process(dt: float) -> void:
	if game == null or game.state != "play" or game.paused_sim or not active():
		return
	t += dt
	if t < 0.5:
		return
	t = 0.0
	for room in game.sys.bio:
		if dirty_from_start.has(room):
			continue
		if game.sys.bio_index(room) > THRESHOLD:
			_mark_room(room)


func _mark_room(room: String) -> void:
	var names: Array = []
	var at := Vector2.ZERO
	for id in world.order:
		var q = world.pieces[id]
		if q.gone or q.room != room or q.cls != "equip" or not q.intact or q.contam or items.has(q.tag):
			continue
		q.contam = true
		game.note_loss("dv_bio", q.tag, q.value * clampf(q.cond, 0.0, 1.0) * 0.25)
		names.append(q.tag)
		at = world.frame(q) * Geom.centroid(q.poly)
	if not names.is_empty():
		game.incident("bio_spread", room)
		game.say("bio_contam", at + Vector2(0, -50), ", ".join(names.slice(0, 4)))


func _mark_near(at: Vector2, r: float) -> void:
	var names: Array = []
	for id in world.order:
		var q = world.pieces[id]
		if q.gone or q.cls != "equip" or not q.intact or q.contam or items.has(q.tag):
			continue
		if (world.frame(q) * Geom.centroid(q.poly)).distance_to(at) < r:
			q.contam = true
			game.note_loss("dv_bio", q.tag, q.value * clampf(q.cond, 0.0, 1.0) * 0.25)
			names.append(q.tag)
	if not names.is_empty():
		game.say("bio_contam", at + Vector2(0, -50), ", ".join(names.slice(0, 4)))
