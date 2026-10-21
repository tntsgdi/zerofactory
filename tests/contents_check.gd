extends SceneTree
# What containers really hold (scripts/contents.gd): every one the ship files left
# empty is filled and gets a port; the measuring tool reads what is in it; a charged
# bottle is still equipment (it leaves charged), its gas can be drawn off at its port;
# cut, a fire bottle bursts and its CO₂ goes into the room, an oxygen cabinet enriches
# the room's air, a mud tank and a water tank let their liquid go, a hydrogen sample
# cylinder is a fuel cloud; oxygen let out in vacuum lets fuel burn there; VT-80's
# oxidiser tank is loaded to its fuel's mixture ratio.
# godot --headless --path . --fixed-fps 60 -s tests/contents_check.gd

const M := 48.0
var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_contents_save.json"
	SaveGame.allow_test = true
	Career.path = "user://zp_test_contents_career.json"
	_run()


func _process(_dt: float) -> bool:
	return finished


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _game(ship: String):
	Game.contract = {}
	Game.start_ship = ship
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(3)
	var w := 0
	while str(g.state) != "play" and w < 60 * 40:
		await process_frame
		w += 1
	g.drone.global_position = Vector2(-60.0, -60.0) * M
	g.drone.linear_velocity = Vector2.ZERO
	return g


func _done(g) -> void:
	g.queue_free()
	await _frames(2)


# the first piece of this kind the ship has
func _of(g, name_key: String):
	for id in g.world.order:
		var p = g.world.pieces[id]
		if not p.gone and p.name_key == name_key and p.body == null:
			return p
	return null


func _centre(g, p) -> Vector2:
	return g.world.frame(p) * Geom.centroid(p.poly)


# a short kerf into it, as the beam would make one
func _cut(g, p) -> void:
	var c := _centre(g, p)
	var bb := Geom.bbox(g.world.world_poly(p))
	g.cut_kerf(p, PackedVector2Array([c - Vector2(bb.size.x * 0.3, 0), c + Vector2(bb.size.x * 0.3, 0)]))


func _run() -> void:
	print("contents: the ship files")
	var total := 0
	var ports_ok := true
	for f in DirAccess.get_files_at("res://ships/"):
		if not f.ends_with(".json"):
			continue
		var d: Dictionary = Ship.load_data(f.get_basename())
		total += int(d.get("_contents_n", 0))
		var ctrl_ids := {}
		for c in d.get("ctrls", []):
			ctrl_ids[str(c.id)] = c
		for k in d.get("gas", {}).get("vessels", {}):
			var v: Dictionary = d.gas.vessels[k]
			if v.get("contents", false) and not ctrl_ids.has(str(v.piece) + "-V"):
				ports_ok = false
		for k in d.get("fluids", {}).get("volumes", {}):
			var v2: Dictionary = d.fluids.volumes[k]
			if v2.get("contents", false) and not ctrl_ids.has(str(v2.port)):
				ports_ok = false
	check(total > 100, "the containers the ship files left empty are filled (%d of them)" % total)
	check(ports_ok, "every one of them has a port to measure, vent or draw it at")
	var vt: Dictionary = Ship.load_data("vt80")
	var fuel: float = float(vt.fluids.volumes.t1.amount) + float(vt.fluids.volumes.t3.amount)
	check(absf(float(vt.fluids.volumes.t2.amount) - minf(fuel, 3.8)) < 0.25, "VT-80's N2O4 tank is loaded to its MMH's mixture ratio (%.1f m³ for %.1f m³ of MMH)" % [vt.fluids.volumes.t2.amount, fuel])

	print("contents: DR-150's fire bottle")
	var g = await _game("dr150")
	var s = g.sys
	var fb = _of(g, "p_ark_fire_bottle")
	check(fb != null and s.tank_vol(fb) != "" and s.P(s.tank_vol(fb)) > 5000.0, "a fire bottle holds CO2 at %.0f kPa" % (s.P(s.tank_vol(fb)) if fb != null else 0.0))
	g.do_measure({"kind": "piece", "piece": fb, "pos": _centre(g, fb)})
	await _frames(2)
	var rd = s.readings.get("P:%d/C" % fb.id)
	check(rd != null and str(rd.text).find("kPa") >= 0, "measured, it reads its contents (%s)" % (rd.text if rd != null else "nothing"))
	check(s.dest_of(fb) == "equip", "charged and sealed, it still goes to the equipment bay")
	var room: String = g.world.room_at(_centre(g, fb))
	var p0: float = s.P(room) if room != "" else 0.0
	_cut(g, fb)
	await _frames(5)
	check(g.incidents.any(func(i): return i[1] == "burst"), "cut, it bursts")
	if room != "":
		check(s.P(room) > p0 + 0.5, "and its CO2 goes into room %s (%.1f → %.1f kPa)" % [room, p0, s.P(room)])
	await _done(g)

	print("contents: an oxygen cabinet")
	g = await _game("dr150")
	s = g.sys
	var ox = _of(g, "p_o2cab")
	var room2: String = g.world.room_at(_centre(g, ox))
	var o2_before: float = g.combustion.o2_avail(room2)
	_cut(g, ox)
	await _frames(5)
	check(room2 != "" and g.combustion.o2_avail(room2) > o2_before + 1.0, "cut in room %s, its oxygen enriches the air (%.1f → %.1f kg O2)" % [room2, o2_before, g.combustion.o2_avail(room2)])
	await _done(g)

	print("contents: drawn off at its port")
	g = await _game("dr150")
	s = g.sys
	var acc = _of(g, "p_dr_air_receiver")
	var vk: String = s.tank_vol(acc)
	var n0: float = s.vols[vk].n
	var port: String = acc.tag + "-V"
	g.world.reveal(g.world.room_at(_centre(g, acc)), _centre(g, acc))
	g.do_hose({"kind": "ctrl", "ctrl": g.world.ctrls[port], "pos": g.world.ctrl_world(g.world.ctrls[port])})
	await _frames(60 * 20)
	check(s.P(vk) < 60.0 and s.gas_recovered > n0 * 0.5, "a hose on %s draws the receiver's air off (%.0f kPa left)" % [port, s.P(vk)])
	await _done(g)

	print("contents: liquids let go")
	g = await _game("dr150")
	var mt = _of(g, "p_dr_mud_tank")
	var fvk: String = g.sys.fluid_in_piece(mt)
	var m0: float = g.sys.fluid(fvk)
	_cut(g, mt)
	await _frames(60 * 2)
	check(m0 > 0.5 and g.liquids.count("mud") > 3, "a mud tank cut lets its mud out (%.2f m³ aboard, %d globules)" % [m0, g.liquids.count("mud")])
	await _done(g)
	g = await _game("ch110")
	var wt = _of(g, "p_water_tank")
	_cut(g, wt)
	await _frames(60 * 2)
	check(g.liquids.count("water") > 3, "a water tank cut lets its water out (%d globules)" % g.liquids.count("water"))
	await _done(g)

	print("contents: oxygen and hydrogen adrift")
	g = await _game("hg170")
	var cb = g.combustion
	var far := Vector2(-40.0, -30.0) * M
	g.liquids.spill(far, Vector2.ZERO, 0.004, "fuel", 1, 0.0, 0.0, true)
	await _frames(3)
	cb.gas_released("o2", 800.0, far + Vector2(0.5, 0) * M)
	cb.spark(far, 0.5)
	await _frames(60)
	check(cb.burnt_kg > 0.1, "fuel in vacuum burns in the oxygen let out beside it (%.2f kg)" % cb.burnt_kg)
	var b0: float = cb.burnt_kg
	var sc = _of(g, "p_hg_sample_cyl")
	var room3: String = g.world.room_at(_centre(g, sc))
	_cut(g, sc)
	await _frames(30)
	check(room3 == "" or cb.burnt_kg > b0, "a hydrogen sample cylinder cut: its hydrogen burns where there is air (room '%s', %.3f kg)" % [room3, cb.burnt_kg - b0])
	await _done(g)

	print("CONTENTS %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
