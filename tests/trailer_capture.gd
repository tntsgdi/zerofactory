extends SceneTree
# Off-screen footage for the trailer and the website (Movie Maker, no window focus).
# bash G:/CODE/videos/zeropressure-trailer/capture.sh <scene>...  (Movie Maker, 1080p, 30 fps)
# Scenes: survey berth cut hyper fire mud water furnace bot interior wide. Prints
# "CAP_START <frame>" when the shot proper begins, so the setup can be trimmed off.
# English text, no HUD unless "hud". Test saves only.

const M := 48.0
var g: Node
var frame := 0
var hud := false
var scene := "wide"


func _initialize() -> void:
	Txt.test_zh = false
	Txt.zh = false
	Career.path = "user://zp_test_trailer_career.json"
	SaveGame.path = "user://zp_test_trailer_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	var a := OS.get_cmdline_user_args()
	scene = a[0] if a.size() > 0 else "wide"
	hud = a.has("hud")
	# run through G:/CODE/videos/zeropressure-trailer/capture.sh: a shadow project that
	# opens the window off-screen at 1080p, without focus
	DisplayServer.window_set_mouse_passthrough(PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]))
	root.size = Vector2i(1920, 1080)
	_run.call_deferred()


func _process(_dt: float) -> bool:
	frame += 1
	if g != null and is_instance_valid(g) and g.hud != null and not hud:
		g.hud.visible = false
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _start() -> void:
	print("CAP_START ", frame)


func _game(ship: String, cine := false) -> void:
	Game.contract = {}
	Game.start_ship = ship
	Game.cine_in_tests = cine
	g = load("res://scenes/main.tscn").instantiate()
	if not cine:
		g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	current_scene = g
	await _frames(10)
	if not cine:
		var w := 0
		while str(g.state) != "play" and w < 60 * 30:
			await process_frame
			w += 1


func _reveal() -> void:
	for n in g.world.rooms:
		g.world.reveal(n, g.world.rooms[n].bbox.get_center())


func _look(at_m: Vector2, zoom: float, settle: int = 40) -> void:
	g.cam_override = at_m * M
	g.zoom_override = zoom
	await _frames(settle)


func _centre(p) -> Vector2:
	return g.world.frame(p) * Geom.centroid(p.poly)


# the drone's laser along a path (world px), the drone hovering just off it
func _beam(path: Array, secs: float, off := Vector2(0, -2.6)) -> void:
	g.tools.set_tool(2)
	var n := int(secs * 30.0)
	for i in n:
		var k: float = float(i) / maxf(1.0, n - 1)
		var seg: float = k * (path.size() - 1)
		var a: int = mini(int(seg), path.size() - 2)
		var at: Vector2 = (path[a] as Vector2).lerp(path[a + 1], seg - a)
		g.drone.global_position = g.drone.global_position.lerp(at + off * M, 0.12)
		g.drone.linear_velocity = Vector2.ZERO
		g.bot.aim = at
		g.bot.lmb = true
		await process_frame
	g.bot.lmb = false


func _run() -> void:
	match scene:
		"survey":
			await _game("fx70", true)
			if g.state == "build":
				g._end_build()
			g._end_intro()
			await _frames(5)
			g.close_contract()
			_start()
			var w := 0
			while g.state == "survey" and w < 30 * 30:
				await process_frame
				w += 1
			await _frames(30)
		"berth":
			await _game("sa200", true)
			_start()
			var w2 := 0
			while g.state == "build" and w2 < 30 * 60:
				await process_frame
				w2 += 1
			await _frames(30)
		"cut":
			await _game("fx70")
			_reveal()
			# a toroidal field coil and the vessel wall: a long sweeping kerf through the shell
			var best = null
			for id in g.world.order:
				var p = g.world.pieces[id]
				if not p.gone and p.body == null and p.kind == "hull":
					var c := _centre(p)
					if best == null or absf(c.x - 30.0 * M) < absf(_centre(best).x - 30.0 * M):
						best = p
			var c0: Vector2 = _centre(best)
			await _look(c0 / M + Vector2(0, 1.0), 1.5, 50)
			_start()
			var path := [c0 + Vector2(-4.0, -0.2) * M, c0 + Vector2(-1.0, 0.4) * M, c0 + Vector2(2.0, 0.0) * M, c0 + Vector2(4.5, 0.6) * M]
			await _beam(path, 6.0)
			await _frames(60)
		"hyper":
			await _game("vt80")
			_reveal()
			var t1 = g.world.tag("T-1")
			var t2 = g.world.tag("T-2")
			var c1 := _centre(t1)
			var c2 := _centre(t2)
			await _look((c1 + c2) * 0.5 / M + Vector2(0, 1.5), 0.6, 60)
			_start()
			g.drone.global_position = c1 + Vector2(6.0, -6.0) * M
			await _frames(20)
			g.cut_kerf(t1, PackedVector2Array([c1 + Vector2(6.0, -2.0) * M, c1 + Vector2(6.5, 1.0) * M]))
			await _frames(8)
			g.cut_kerf(t2, PackedVector2Array([c2 + Vector2(-6.0, -2.0) * M, c2 + Vector2(-6.5, 1.0) * M]))
			await _frames(30 * 7)
		"fire":
			await _game("vt80")
			_reveal()
			var rp: Vector2 = g.world.rooms["P"].bbox.get_center()
			await _look(rp / M, 1.15, 50)
			for i in 6:
				g.liquids.spill(rp + Vector2(i * 0.9 - 2.4, sin(i * 1.7) * 0.6) * M, Vector2.from_angle(i * 1.1), 0.003, "fuel", 1, 0.0, 0.12, false)
			g.drone.global_position = rp + Vector2(-5.0, -2.0) * M
			_start()
			await _frames(45)
			# the beam swings across the drifting fuel
			await _beam([rp + Vector2(-3.4, 1.2) * M, rp + Vector2(-2.4, 0.0) * M], 1.2, Vector2(-1.6, -1.6))
			await _frames(30 * 5)
		"mud":
			await _game("dr150")
			_reveal()
			g.drillstring.torque = 0.0
			for k in 8:
				g.sys.switch["SLIP-%d" % (k + 1)] = true
			await _look(Vector2(50.0, -22.0), 0.8, 60)
			_start()
			var st = g.world.tag("J-1")
			for j in g.world.joints_of(st):
				g.world.kill_joint(j)
			await _frames(30 * 6)
		"water":
			await _game("bl88")
			_reveal()
			await _look(Vector2(44.0, 0.0), 1.1, 60)
			_start()
			var net = g.world.tag("NET-T")
			g.on_cut_into(net, Geom.bbox(g.world.world_poly(net)).get_center())
			await _frames(30 * 7)
		"furnace":
			await _game("es112")
			var d = g.dock
			var sm = d.smelter
			var fx: float = d.furnace_x
			sm.phase = "melt"
			sm.m_l = 9.0
			sm.m_s = 0.5
			sm.T = 1570.0
			sm.bunker = 22.0
			g.drone.global_position = Vector2(fx - 4.0, Dock.FLOOR_Y - 3.0) * M
			await _look(Vector2(fx + 1.0, Dock.FLOOR_Y + 5.5), 1.15, 60)
			_start()
			var plate := PackedVector2Array([Vector2(-3.0, -0.9), Vector2(3.0, -0.9), Vector2(3.0, 0.9), Vector2(-3.0, 0.9)])
			var frame_l := PackedVector2Array([Vector2(-0.8, -0.7), Vector2(0.8, -0.7), Vector2(0.8, -0.4), Vector2(-0.4, -0.4), Vector2(-0.4, 0.7), Vector2(-0.8, 0.7)])
			var box := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.6, 0.0), Vector2(0.6, 0.5), Vector2(0.0, 0.5)])
			d.scrapline.take([plate], 1.0, ["hull"], fx)
			d.scrapline.take([frame_l, box], 0.6, ["rib", "equip"], fx)
			await _frames(30 * 6)
			# and a tap: the furnace tilts and pours
			sm.m_l = 14.0
			sm.phase = "tilt"
			await _frames(30 * 8)
		"bot":
			await _game("gr7")
			_reveal()
			var Bot = load("res://tests/salvage_bot.gd")
			var bot = Bot.new(g, {"paced": true})
			var bb := Rect2()
			var first := true
			for id in g.world.order:
				var r := Geom.bbox(g.world.pieces[id].poly)
				bb = r if first else bb.merge(r)
				first = false
			_start()
			var n := 0
			while n < 30 * 40:
				if bot.step():
					break
				# the camera rides with the drone, a little wider than play
				g.zoom_override = 0.9
				g.cam_override = g.drone.global_position.lerp(bb.get_center(), 0.35)
				await process_frame
				n += 1
		"interior":
			await _game("ark01")
			_reveal()
			var bb2 := Rect2()
			var first2 := true
			for id in g.world.order:
				var r2 := Geom.bbox(g.world.pieces[id].poly)
				bb2 = r2 if first2 else bb2.merge(r2)
				first2 = false
			await _look(Vector2(bb2.position.x / M + 18.0, bb2.get_center().y / M), 1.0, 60)
			_start()
			var steps := 30 * 16
			for i in steps:
				var k: float = float(i) / steps
				g.cam_override = Vector2(lerpf(bb2.position.x + 18.0 * M, bb2.end.x - 18.0 * M, k), bb2.get_center().y + sin(k * 6.0) * 2.0 * M)
				g.zoom_override = 1.0
				await process_frame
		"still":
			# a big still of a whole ship opened up, for the website (saved, no movie)
			var sid: String = OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "fx70"
			var outp: String = OS.get_cmdline_user_args()[2] if OS.get_cmdline_user_args().size() > 2 else "G:/CODE/videos/zeropressure-trailer/snaps/still.png"
			await _game(sid)
			_reveal()
			var bb4 := Rect2()
			var first4 := true
			for id in g.world.order:
				var r4 := Geom.bbox(g.world.pieces[id].poly)
				bb4 = r4 if first4 else bb4.merge(r4)
				first4 = false
			var vs: Vector2 = Vector2(root.size)
			g.drone.global_position = Vector2(-80.0, -80.0) * M
			await _look(bb4.get_center() / M, minf(vs.x * 0.94 / bb4.size.x, vs.y * 0.9 / bb4.size.y), 90)
			var img: Image = root.get_texture().get_image()
			img.save_png(outp)
			print("STILL ", outp, " ", img.get_size())
		_:
			await _game("fx70")
			_reveal()
			var bb3 := Rect2()
			var first3 := true
			for id in g.world.order:
				var r3 := Geom.bbox(g.world.pieces[id].poly)
				bb3 = r3 if first3 else bb3.merge(r3)
				first3 = false
			await _look(bb3.get_center() / M, 1.6, 40)
			_start()
			var steps2 := 30 * 10
			for i in steps2:
				var k2: float = float(i) / steps2
				g.cam_override = bb3.get_center()
				g.zoom_override = lerpf(1.6, clampf(1700.0 / bb3.size.x, 0.15, 1.0), 1.0 - pow(1.0 - k2, 3.0))
				await process_frame
	print("CAP_DONE ", frame)
	quit()
