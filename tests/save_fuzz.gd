extends SceneTree
# Roadmap 1.3 acceptance. Random hands work the ship (like fuzz.gd); at 10
# random moments the game is saved, thrown away and loaded into a fresh game,
# and every piece, joint, line, control, room, system value, accident, reading
# and book entry is compared. Then the main save is damaged on purpose and the
# game must come back from the .bak file.
# tools/run_test.sh tests/save_fuzz.gd --fixed-fps 60 -- [seed]

const M := 48.0
var game
var frame := 0
var rng := RandomNumberGenerator.new()
var bot := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "dash": false, "brake": false}
var target := Vector2.ZERO
var moments: Array = []
var pending := {}          # snapshot taken at save time, waiting for the load
var wait := 0
var fails := 0
var checks := 0
var stage := "fuzz"
var snap_x := {}


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	rng.seed = int(a[0]) if a.size() > 0 else 11
	SaveGame.path = "user://zp_test_fuzz_save.json"
	SaveGame.allow_test = true
	for ext in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.path + ext))
	# migration: a v1 save gains the v2 fields, a save from the future is refused
	var m1 := SaveGame.migrate({"version": 1, "world": {}, "sys": {}, "game": {}})
	var m_ok: bool = int(m1.get("version", 0)) == SaveGame.VERSION and m1.sys.has("leaks") and m1.game.has("debris") and SaveGame.migrate({"version": 99, "world": {}, "sys": {}, "game": {}}).is_empty()
	print("migration v1 -> v%d: %s" % [SaveGame.VERSION, "OK" if m_ok else "FAIL"])
	if not m_ok:
		fails += 1
	for i in 10:
		moments.append(rng.randi_range(60, 2400))
	moments.sort()
	root.add_child(preload("res://tests/test_window.gd").new())
	_spawn(false)


func _spawn(load_it: bool) -> void:
	SaveGame.load_requested = load_it
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene


func _snap() -> Dictionary:
	var w = game.world
	var s = game.sys
	var out := {}
	var pieces := {}
	var taken := {}
	for sw in game.dock.swallowing:
		taken[sw[0]] = Transform2D(sw[4], sw[3])
	for id in w.order:
		var p = w.pieces[id]
		if p.gone:
			continue
		# a body going down a recovery mouth is saved where the mouth took it
		var c: Vector2 = taken[p.body] * Geom.centroid(p.poly) if taken.has(p.body) else p.center_world()
		pieces[id] = {"kind": p.kind, "tag": p.tag, "cls": p.cls, "intact": p.intact, "open": p.door_open, "haz": p.hazard,
			"dest": p.dest, "free": p.body != null, "n": p.poly.size(), "area": Geom.area(p.poly), "c": c,
			"mass": p.mass, "cond": p.cond, "temp": p.temp, "contam": p.contam, "seen": p.seen, "val": p.value}
	out.pieces = pieces
	var joints := {}
	for j in w.joints:
		if j.alive:
			joints[j.id] = [j.a, j.b, j.type]
	out.joints = joints
	var lines := {}
	for id in w.lines:
		var l = w.lines[id]
		lines[id] = [l.alive, l.a, l.b]
	out.lines = lines
	var ctrls := {}
	for id in w.ctrls:
		var c = w.ctrls[id]
		ctrls[id] = [c.state, c.piece]
	out.ctrls = ctrls
	var rooms := {}
	for n in w.rooms:
		rooms[n] = w.rooms[n].revealed
	out.rooms = rooms
	var vols := {}
	for k in s.vols:
		vols[k] = s.vols[k].n
	out.vols = vols
	out.flags = [s.VC01, s.VF01, s.VE1, s.VE2, s.G_running, s.KG, s.KB, s.aux, s.discharge, s.g_remote]
	out.nums = {"bat": s.bat, "cap": s.cap, "nav": s.nav_bat, "fuel": s.fuel, "fline": s.fuel_line, "cool": s.cool, "coolb": s.cool_broken,
		"T": s.loop_T, "frec": s.fuel_recovered, "crec": s.cool_recovered, "grec": s.gas_recovered, "glost": s.gas_lost, "flost": s.fluid_lost}
	var hoses := {}
	for k in s.hoses:
		hoses[k] = s.hoses[k].mode
	out.hoses = hoses
	var readings := {}
	for k in s.readings:
		readings[k] = [s.readings[k].text, s.readings[k].kind]
	out.readings = readings
	var lk := []
	for l in s.links:
		lk.append("%s-%s:%d" % [l[0], l[1], int(l[2])])
	lk.sort()
	out.links = lk
	out.leaks = s.leaks.size()
	out.clouds = s.clouds.size()
	out.blown = s.blown.keys()
	out.books = {"ie": game.income_equip, "im": game.income_metal, "ih": game.income_hazard, "loss": game.losses, "lines": game.loss_lines.size(),
		"bb": game.bb_ok, "gen": game.gen_ok, "ledger": game.ledger.size(), "hp": game.drone.integrity, "alive": game.drone.alive,
		"tool": game.tools.tool, "mode": game.tools.hose_mode, "reveals": game.reveal_count}
	out.debris = game.dock.debris.size() + game.dock.swallowing.size()
	return out


func _near(a: float, b: float, rel: float, absol: float) -> bool:
	return absf(a - b) <= maxf(absol, absf(a) * rel)


func _compare(a: Dictionary, b: Dictionary, label: String) -> int:
	var bad: Array = []
	for id in a.pieces:
		if not b.pieces.has(id):
			# swallowed or burnt in the frames between save and check is not a save error
			continue
		var pa: Dictionary = a.pieces[id]
		var pb: Dictionary = b.pieces[id]
		for k in ["kind", "tag", "cls", "intact", "open", "haz", "dest", "free", "n", "contam", "seen"]:
			if pa[k] != pb[k]:
				bad.append("piece %d %s %s != %s" % [id, k, pa[k], pb[k]])
		if not _near(pa.area, pb.area, 0.01, 2.0):
			bad.append("piece %d area %.0f != %.0f" % [id, pa.area, pb.area])
		if not _near(pa.mass, pb.mass, 0.01, 0.001):
			bad.append("piece %d mass" % id)
		if not _near(pa.val, pb.val, 0.001, 0.5) or not _near(pa.cond, pb.cond, 0.001, 0.002):
			bad.append("piece %d value/cond" % id)
		var tol: float = 30.0 if pa.free else 2.0
		if (pa.c as Vector2).distance_to(pb.c) > tol:
			bad.append("piece %d moved %.1f px" % [id, (pa.c as Vector2).distance_to(pb.c)])
		if not _near(pa.temp, pb.temp, 0.05, 3.0):
			bad.append("piece %d temp %.1f != %.1f" % [id, pa.temp, pb.temp])
	for id in b.pieces:
		if not a.pieces.has(id):
			bad.append("piece %d appeared" % id)
	if a.joints != b.joints:
		bad.append("joints differ (%d vs %d)" % [a.joints.size(), b.joints.size()])
	for k in ["lines", "ctrls", "rooms", "flags", "hoses", "leaks", "clouds", "debris"]:
		if a[k] != b[k]:
			bad.append("%s differ: %s vs %s" % [k, a[k], b[k]])
	if a.blown.size() != b.blown.size():
		bad.append("blown differ")
	for k in a.vols:
		if not _near(a.vols[k], b.vols[k], 0.04, 1.0):
			bad.append("gas %s %.1f != %.1f" % [k, a.vols[k], b.vols[k]])
	for k in a.nums:
		if not _near(a.nums[k], b.nums[k], 0.03, 0.02 if k != "T" else 2.0):
			bad.append("%s %.3f != %.3f" % [k, a.nums[k], b.nums[k]])
	if a.readings.keys() != b.readings.keys():
		bad.append("reading keys differ")
	for k in a.books:
		var va = a.books[k]
		var vb = b.books[k]
		if typeof(va) == TYPE_FLOAT:
			if not _near(va, vb, 0.001, 0.5):
				bad.append("book %s %s != %s" % [k, va, vb])
		elif va != vb:
			bad.append("book %s %s != %s" % [k, va, vb])
	checks += 1
	if bad.is_empty():
		print("%s: OK  (%d pieces, %d joints, %d readings, %d leaks, %d free bodies)" % [label, a.pieces.size(), a.joints.size(), a.readings.size(), a.leaks, game.world.bodies.size()])
		return 0
	print("%s: %d MISMATCHES" % [label, bad.size()])
	print("   links before ", a.links, "
   links after  ", b.links)
	for l in bad.slice(0, 12):
		print("   ", l)
	return 1


func _hands() -> void:
	if frame % 90 == 1:
		var side := rng.randi_range(0, 3)
		var p := Vector2(rng.randf_range(0, 34), rng.randf_range(-6.4, -4.7)) * M
		if side == 1:
			p = Vector2(rng.randf_range(0, 34), rng.randf_range(4.7, 6.4)) * M
		elif side == 2:
			p = Vector2(rng.randf_range(33.5, 44), rng.randf_range(-5, 5)) * M
		elif side == 3:
			var names := ["A", "B", "C", "D", "E"]
			var n: String = names[rng.randi() % 5]
			game.world.reveal(n, game.world.rooms[n].from)
			p = game.world.rooms[n].from
		game.drone.global_position = p
		game.drone.linear_velocity = Vector2.ZERO
		game.drone.reset_physics_interpolation()
		game.tools.set_tool(rng.randi_range(1, 5))
	if frame % 12 == 0:
		target = game.drone.global_position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(10, 190)
	bot.aim = bot.aim.lerp(target, 0.2)
	if frame % 7 == 0:
		bot.lmb = rng.randf() < 0.6
	if frame % 30 == 0:
		bot.move = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) if rng.randf() < 0.5 else Vector2.ZERO


# things random hands rarely manage: readings, a hose, a leak, a blowout
func _events() -> void:
	var w = game.world
	match frame:
		40:
			for id in ["P-C01", "GAS-AB", "E-D01"]:
				var c = w.ctrls.get(id)
				if c != null and w.ctrl_alive(c):
					if c.hidden_room != "":
						w.reveal(c.hidden_room, w.ctrl_world(c))
					game.do_measure({"kind": "ctrl", "ctrl": c, "pos": w.ctrl_world(c)})
		130:
			var c2 = w.ctrls.get("GAS-AB")
			if c2 != null and w.ctrl_alive(c2):
				game.do_hose({"kind": "ctrl", "ctrl": c2, "pos": w.ctrl_world(c2)})
		400:
			var tank = w.tag("T-F01")
			if tank != null and not tank.gone:
				game._leak("fuel", "fuel_tank", tank.center_world(), tank)
			var pump = w.tag("CP-E")
			if pump != null and not pump.gone:
				game._leak("coolant", "cool", pump.center_world(), pump)


func _process(_dt: float) -> bool:
	frame += 1
	if wait > 0:
		wait -= 1
		if wait == 0:
			match stage:
				"loaded":
					stage = "fuzz"
				"recover":
					_finish()
					return true
		return false
	if stage == "fuzz":
		_events()
		_hands()
		if game.state == "ending":
			# the bot finished the ship: nothing more to save
			moments = []
		if not moments.is_empty() and frame >= moments[0]:
			moments.pop_front()
			_save_and_reload()
		elif moments.is_empty() and stage == "fuzz":
			_damage_test()
	return false


func _save_and_reload() -> void:
	bot.lmb = false
	if game.tools.cutting:
		game.tools._finish_cut()
	SaveGame.save(game)
	pending = _snap()
	game.queue_free()
	game = null
	_spawn(true)
	# the loaded game has run _ready and nothing else: compare before any sim step
	fails += _compare(pending, _snap(), "moment %d (frame %d)" % [checks + 1, frame])
	stage = "loaded"
	wait = 2


func _damage_test() -> void:
	bot.lmb = false
	if game.tools.cutting:
		game.tools._finish_cut()
	SaveGame.save(game)
	snap_x = _snap()
	# a newer save that then gets torn in half on disk
	SaveGame.save(game)
	var f := FileAccess.open(SaveGame.path, FileAccess.READ_WRITE)
	var n := f.get_length()
	f.seek(n / 2)
	f.store_string("\u0000\u0000garbage")
	f.close()
	game.queue_free()
	game = null
	_spawn(true)
	var ok := SaveGame.recovered
	fails += _compare(snap_x, _snap(), "damaged save -> backup")
	print("recovered flag: ", ok)
	if not ok:
		fails += 1
	stage = "recover"
	wait = 30


func _finish() -> void:
	for ext in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.path + ext))
	print("SAVE %s  (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
