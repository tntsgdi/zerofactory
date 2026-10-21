extends SceneTree
# The furnace under the scrap mouth (2026-10-20): its heat balance run on its
# own (charging, melting, a full tap cycle into the ingot line, the bunker never
# holding the mouth up), then stills in the berth: melting, tapping, the wide
# view with the mouth above it. Test saves only.
# tools/run_test.sh tests/furnace_shot.gd -- [en]

const Cap = preload("res://tests/cap.gd")
const Smelter = preload("res://scripts/smelter.gd")
var game
var frame := 0
var fails := 0
var shots: Array = []


func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	Txt.test_zh = not OS.get_cmdline_user_args().has("en")
	Txt.zh = Txt.test_zh
	SaveGame.path = "user://zp_test_furnace_save.json"
	Career.path = "user://zp_test_furnace_career.json"
	_sim()
	root.add_child(preload("res://tests/test_window.gd").new())
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2(21 * 48, 0), "lmb": false, "move": Vector2.ZERO}
	root.add_child(game)


# the plant on its own, stepped at 0.1 s
func _sim() -> void:
	var s = Smelter.new()
	s.m_l = 6.0
	s.T = 1600.0
	s.bunker = 0.0
	s.charge(30.0, s.X + 8.0)
	var tmin := INF
	var tmax := -INF
	var phases := {}
	var melted0: float = s.m_l
	var cast0: int = s.ingot_no
	for i in 36000:
		s.step(0.1)
		tmin = minf(tmin, s.T)
		tmax = maxf(tmax, s.T)
		phases[s.phase] = true
	check(s.bunker + s.yard < 1.0, "30 t charged melt down within the hour (%.1f t left)" % (s.bunker + s.yard))
	check(phases.has("tilt") and phases.has("pour") and phases.has("back"), "a full tap cycle ran: %s" % [phases.keys()])
	check(s.ingot_no - cast0 >= 20, "ingots cast: %d" % (s.ingot_no - cast0))
	check(tmin > 1500.0 and tmax <= 1660.0, "the melt stays liquid and under 1660 °C (%.0f..%.0f)" % [tmin, tmax])
	check(s.m_l >= Smelter.HEEL - 0.01 and s.m_l <= Smelter.CAP + 0.01, "the bath stays between the heel and the cap (%.1f t)" % s.m_l)
	var w: float = s.water_out()
	check(w > Smelter.T_IN and w < 60.0, "coil water out %.1f °C" % w)
	check(absf(s.skin_mm() - 29.0) < 6.0, "skin depth %.1f mm at %.0f Hz" % [s.skin_mm(), s.freq()])
	check(absf(s.g_load() - 1.36) < 0.2, "spin holds the melt at %.2f g" % s.g_load())
	# a big ship's worth arriving at once never stops anything: the overflow waits in the yard
	s.charge(400.0, s.X)
	for i in 30:
		s.step(0.1)
	check(s.bunker <= Smelter.BUNKER_CAP + 0.01 and s.yard > 300.0, "400 t at once: bunker %.0f t, yard %.0f t" % [s.bunker, s.yard])
	print("throughput check: %.1f t melted in an hour" % (s.m_l - melted0 + (s.ingot_no - cast0) * Smelter.INGOT))


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 40:
		return false
	var d = game.dock
	var sm = d.smelter
	var F: float = Dock.FLOOR_Y
	var fx: float = d.furnace_x
	if frame == 40:
		check(Dock.ZONES.metal.w == 4.6 and Dock.SCRAP_FIELD == 7.0, "the mouth on the floor is as wide and pulls as far as before")
		sm.phase = "melt"
		sm.m_l = 9.0
		sm.m_s = 0.5
		sm.T = 1570.0
		sm.bunker = 22.0
		game.drone.global_position = Vector2(fx - 4.0, F - 3.0) * 48.0
		game.drone.linear_velocity = Vector2.ZERO
	if frame < 160:
		game.cam_override = Vector2(fx + 1.0, F + 5.5) * 48.0
		game.zoom_override = 1.25
		if frame == 159:
			Cap.save(root, "res://tests/out/furnace_melt.png")
		return false
	if frame == 160:
		# a tonne of hull plate into the press, a frame with its wiring into the shredder
		var plate := PackedVector2Array([Vector2(-3.0, -0.9), Vector2(3.0, -0.9), Vector2(3.0, 0.9), Vector2(-3.0, 0.9)])
		var frame_l := PackedVector2Array([Vector2(-0.8, -0.7), Vector2(0.8, -0.7), Vector2(0.8, -0.4), Vector2(-0.4, -0.4), Vector2(-0.4, 0.7), Vector2(-0.8, 0.7)])
		var box := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.6, 0.0), Vector2(0.6, 0.5), Vector2(0.0, 0.5)])
		d.scrapline.take([plate], 1.0, ["hull"], fx)
		d.scrapline.take([frame_l, box], 0.6, ["rib", "equip"], fx)
	if frame < 700:
		game.cam_override = Vector2(fx - 1.5, F + 3.4) * 48.0
		game.zoom_override = 0.95
		var pr = d.scrapline.press
		if pr != null and int(pr.ph) == 2 and float(pr.pt) > 0.7 and not shots.has("press"):
			shots.append("press")
			Cap.save(root, "res://tests/out/furnace_press.png")
		var sh = d.scrapline.shred
		if sh != null and float(sh.pt) > 1.4 and not shots.has("shred"):
			shots.append("shred")
			Cap.save(root, "res://tests/out/furnace_shred.png")
		if d.scrapline.fines.size() > 40 and not shots.has("fines"):
			shots.append("fines")
			Cap.save(root, "res://tests/out/furnace_fines.png")
		return false
	if frame == 700:
		check(shots.has("press") and shots.has("shred") and shots.has("fines"), "the plate was pressed, the frame shredded to powder: %s" % [shots])
		check(d.scrapline.pucks_made >= 1 and d.scrapline.shredded > 0.5, "a puck made (%d), %.1f t shredded" % [d.scrapline.pucks_made, d.scrapline.shredded])
		check(d.scrapline.nonferrous > 0.0, "the drum threw off %.0f kg of non-ferrous" % d.scrapline.nonferrous)
		# straight to the end of a heat: full and hot
		sm.m_l = Smelter.CAP
		sm.m_s = 0.0
		sm.T = Smelter.T_TAP + 1.0
		sm.phase = "heat"
		Engine.time_scale = 4.0
	if frame < 1200:
		game.cam_override = Vector2(fx + 2.5, F + 6.8) * 48.0
		game.zoom_override = 1.25
		if sm.phase == "pour" and sm.m_l < Smelter.CAP - 3.0 and not shots.has("pour"):
			shots.append("pour")
			Engine.time_scale = 1.0
			Cap.save(root, "res://tests/out/furnace_tap.png")
			check(sm.tilt >= Smelter.TILT_MAX - 0.001 and sm.hood >= 1.0 and sm.gate > 0.5, "tapping: hood aside, tilted %.0f°, gate open" % rad_to_deg(sm.tilt))
			frame = 1200
		return false
	if frame == 1201:
		Engine.time_scale = 1.0
		check(shots.has("pour"), "the furnace reached tapping")
	if frame < 1300:
		game.cam_override = Vector2(fx + 1.0, F + 3.0) * 48.0
		game.zoom_override = 0.6
		if frame == 1299:
			Cap.save(root, "res://tests/out/furnace_wide.png")
		return false
	print("furnace_shot: %d failures" % fails)
	quit(1 if fails > 0 else 0)
	return true
