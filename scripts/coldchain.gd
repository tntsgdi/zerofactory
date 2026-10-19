extends Node
# A cold chain that has to hold (R2 fleet, CL-104 "Frost Store": "the three cold
# holds must be kept at temperature until the cargo is out; shutting the
# refrigeration down is not the first step"). A ship file's "cold" section:
#   {"rooms": {room: °C it is kept at}, "chillers": {piece: [rooms]}, "plant": piece,
#    "supply": socket control, "warm": °C/s, "thaw": °C, "keep": value kept when
#    thawed, "cargo": {room: [tags]}}
#   A room is held at its temperature while its chiller and the plant both have
#   power, or while the berth's temporary cooling is plugged into the supply
#   socket; otherwise it warms. Past "thaw" the cargo in it has thawed: it keeps
#   only "keep" of its value, for good.
#   A "cold" probe reads a room's temperature.
# Saved: the rooms' temperatures, which have thawed.

var game
var world
var cfg := {}
var temp := {}                # room -> °C
var thawed := {}              # room -> true


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("cold", {})
	for r in cfg.get("rooms", {}):
		temp[r] = float(cfg.rooms[r])


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"temp": temp.duplicate(), "thawed": thawed.keys()}


func load_state(d: Dictionary) -> void:
	for r in d.get("temp", {}):
		temp[r] = float(d.temp[r])
	for r in d.get("thawed", []):
		thawed[str(r)] = true


func room_temp(room: String) -> float:
	return float(temp.get(room, 20.0))


func supplied() -> bool:
	var s: String = cfg.get("supply", "")
	return s != "" and world.ctrls.has(s) and world.ctrls[s].state


func _powered(tag: String) -> bool:
	var p = world.tag(tag)
	return p != null and not p.gone and p.intact and game.sys.piece_volts(p) > 1.0


# what keeps a room cold right now
func held(room: String) -> bool:
	if supplied():
		return true
	if not _powered(cfg.get("plant", "")):
		return false
	for ch in cfg.get("chillers", {}):
		if room in cfg.chillers[ch] and _powered(ch):
			return true
	return false


func _physics_process(dt: float) -> void:
	if not active() or game == null or game.paused_sim or game.state != "play":
		return
	var warm: float = float(cfg.get("warm", 0.05))
	for r in temp:
		var want: float = float(cfg.rooms[r])
		if held(r):
			temp[r] = move_toward(temp[r], want, warm * 4.0 * dt)
		else:
			temp[r] = minf(18.0, temp[r] + warm * dt)
		if not thawed.has(r) and temp[r] > float(cfg.get("thaw", -5.0)):
			_thaw(r)


func _thaw(room: String) -> void:
	thawed[room] = true
	var keep: float = float(cfg.get("keep", 0.45))
	var lost := 0.0
	for t in cfg.get("cargo", {}).get(room, []):
		var p = world.tag(str(t))
		if p == null or p.gone:
			continue
		lost += p.value * (1.0 - keep)
		p.value *= keep
		p.set_meta("thawed", true)
	game.incident("thaw", room)
	var at: Vector2 = world.rooms[room].bbox.get_center() if world.rooms.has(room) else game.drone.global_position
	game.say("cargo_thawed", at, room)
	game.note_loss("loss_thaw", room, lost)
