extends SceneTree
# Roadmap 2.4 acceptance, the second half: every trap can be found before it
# bites. For each of the ten traps, on contracts that carry it (seeds 1..n):
#   found   — a measurement or inspection a player can make, on something in
#             sight and in reach, shows what the paperwork does not;
#   bites   — on the same ship, doing the obvious thing without looking
#             first leads to the accident (an incident on the books);
#   order   — the finding comes before the accident (the first incident is
#             logged after the finding).
# godot --headless --path . --fixed-fps 60 -s tests/trap_check.gd -- [n=3] [trap=<id>]

const M := 48.0
const BOT := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
var g
var fails := 0
var checks := 0
var finished := false
var n := 3
var only := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("n="):
			n = int(a.substr(2))
		elif a.begins_with("trap="):
			only = a.substr(5)
	_run()


func _process(_dt: float) -> bool:
	return finished


func _frames(k: int) -> void:
	for i in k:
		await process_frame


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("    [%s] %s" % ["PASS" if ok else "FAIL", what])


func _spawn(trap: String, seed: int, kit: Dictionary = {}) -> void:
	if g != null:
		g.queue_free()
		await _frames(2)
	var o := Market.offer_for(seed, {"rep": 30, "done": 5}, 1)
	o.traps = [trap]
	o.kit = kit
	# a ship that keeps the trap (draw again if this one threw it away)
	var tries := 0
	while not ContractValidator.check(Variant.make(Ship.load_data("gr7"), o)).ok and tries < 20:
		o.variant = int(o.variant) + 1
		tries += 1
	Game.contract = o
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = BOT.duplicate()
	root.add_child(scene)
	g = scene
	await _frames(3)


func c(id: String) -> Dictionary:
	var ct = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": ct, "pos": g.world.ctrl_world(ct)}


func measure(id: String) -> Dictionary:
	g.do_measure(c(id))
	return g.sys.readings[id]


func inspect(p) -> Dictionary:
	var at: Vector2 = g.world.frame(p) * Geom.centroid(p.poly)
	g.do_measure({"kind": "inspect", "piece": p, "pos": at})
	return g.sys.readings.get("P:%d" % p.id, {})


func volts_of(p) -> float:
	return float(g.sys.readings.get("P:%d/V" % p.id, {}).get("val", 0.0))


# what the player can reach: not inside a room nobody has opened
func visible(p) -> bool:
	return not g.world.room_hidden(p.room) or p.body != null


func open_room(room: String) -> void:
	g.world.reveal(room, g.world.rooms[room].from)


func cut(p, kerf: Array) -> void:
	var pl := PackedVector2Array()
	for q in kerf:
		pl.append(q * M)
	g.cut_kerf(p, pl)


func cut_through(p) -> void:
	var bb := Geom.bbox(g.world.world_poly(p))
	g.cut_kerf(p, PackedVector2Array([bb.position + Vector2(-4, bb.size.y * 0.5), bb.end + Vector2(4, -bb.size.y * 0.5)]))


func wait_sim(sec: float) -> void:
	Engine.time_scale = 8.0
	var t0: float = g.sys.time
	while g.sys.time - t0 < sec:
		await process_frame
	Engine.time_scale = 1.0


func first_incident() -> float:
	return g.incidents[0][0] if not g.incidents.is_empty() else INF


func _run() -> void:
	for trap in Traps.ALL:
		if only != "" and trap != only:
			continue
		print("TRAP %s" % trap)
		for i in n:
			print("  seed %d" % (i + 1))
			await call("_t_" + trap, 101 * (i + 1))
	if g != null:
		g.queue_free()
	print("TRAPS %s  (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	finished = true


# ---------------------------------------------------------------- the ten

func _t_wrong_valve(seed: int) -> void:
	await _spawn("wrong_valve", seed)
	var s = g.sys
	var r1 := measure("P-C01")
	g.do_wrench(c("V-C01"))
	await _frames(20)
	var r2 := measure("P-C01")
	var found_t: float = g.playtime
	var found_n: int = g.incidents.size()
	check(r1.val < 5.0 and r2.val > 50.0, "found: P-C01 reads %s shut, %s with V-C01 open (hold at %.0f kPa)" % [r1.text, r2.text, s.P("C")])
	cut(g.world.piece_at(Vector2(13.9, -3.8) * M, ["hull"]), [Vector2(13.6, -4.3), Vector2(13.6, -3.4)])
	cut(g.world.piece_at(Vector2(13.9, -3.8) * M, ["hull"]), [Vector2(14.4, -4.3), Vector2(14.4, -3.4)])
	await wait_sim(3.0)
	check(g.incidents.any(func(x): return x[1] == "blowout"), "bites: cutting the hold open at %.0f kPa blows it out" % s.P("C") if not g.incidents.is_empty() else "bites: cutting the hold open blows it out")
	check(found_n == 0 and not g.incidents.is_empty(), "found before it bit (no incident yet when it was found)")


func _t_fake_stop(seed: int) -> void:
	await _spawn("fake_stop", seed)
	g.do_wrench(c("G-STOP"))
	g.do_wrench(c("K-G"))
	await wait_sim(60.0)
	# the stern stays hot: the engine bits the loop runs through are in plain sight
	var eng = g.world.tag("ENG-F")
	var r := inspect(eng)
	open_room("D")
	var gen = g.world.tag("G-01")
	inspect(gen)
	var found_t: float = g.playtime
	var found_n: int = g.incidents.size()
	check(visible(eng) and float(r.val) > 60.0 and g.sys.running("G-01") and volts_of(gen) > 300.0, "found: a minute after the remote stop ENG-F reads %s, G-01 reads %d V" % [r.text, int(volts_of(gen))])
	cut_through(gen)
	await _frames(5)
	check(g.incidents.any(func(x): return x[1] == "arc"), "bites: cutting the 'stopped' generator arcs")
	check(found_n == 0 and not g.incidents.is_empty(), "found before it bit (no incident yet when it was found)")


func _t_hidden_tank(seed: int) -> void:
	await _spawn("hidden_tank", seed)
	var tk = g.world.tag("TK-X1")
	check("TK-X1" in g.ship.blueprint.hide, "the drawing does not show TK-X1")
	open_room("C")
	var r := measure("TK-X1")
	var found_t: float = g.playtime
	var found_n: int = g.incidents.size()
	check(visible(tk) and r.val > 200.0, "found: in the open hold, TK-X1's port reads %s" % r.text)
	cut_through(tk)
	await _frames(5)
	check(g.incidents.any(func(x): return x[1] == "burst"), "bites: cutting the undeclared bottle bursts it")
	check(found_n == 0 and not g.incidents.is_empty(), "found before it bit (no incident yet when it was found)")


func _t_live_cargo(seed: int) -> void:
	await _spawn("live_cargo", seed)
	var tg: String = g.ship.variant.targets.live_cargo
	var p = g.world.tag(tg)
	# the ship's own power off first, the way the paperwork says it is safe
	for k in ["K-G", "K-B"]:
		g.do_wrench(c(k))
	open_room("C")
	inspect(p)
	var found_t: float = g.playtime
	var found_n: int = g.incidents.size()
	check(visible(p) and volts_of(p) > 100.0 and not g.sys.bus_live or volts_of(p) > 100.0, "found: %s reads %d V on its own supply" % [tg, int(volts_of(p))])
	# unlock it and haul: the reefer lead tears
	for j in g.world.joints_of(p):
		g.world.kill_joint(j)
	g.on_tear(p, [], g.world.lines_of(p), g.world.frame(p) * Geom.centroid(p.poly))
	await _frames(3)
	check(g.incidents.any(func(x): return x[1] == "arc"), "bites: hauling it off tears a live lead and arcs")
	check(found_n == 0 and not g.incidents.is_empty(), "found before it bit (no incident yet when it was found)")


func _t_welded_hatch(seed: int) -> void:
	await _spawn("welded_hatch", seed)
	var h = g.world.tag("HATCH-1")
	var r := inspect(h)
	var found_t: float = g.playtime
	var found_n: int = g.incidents.size()
	check(visible(h) and str(r.get("inspect", "")).find(Txt.t("j_seam")) >= 0, "found: inspecting HATCH-1 from outside: %s" % r.get("inspect", ""))
	g.do_wrench(c("HATCH-JAM"))
	g.do_wrench(c("PWR-EXT"))
	g.do_wrench(c("HATCH-SW"))
	await _frames(3)
	check(g.incidents.any(func(x): return x[1] == "motor"), "bites: driving the hatch burns the drive out")
	check(found_n == 0 and not g.incidents.is_empty(), "found before it bit (no incident yet when it was found)")


func _t_rerouted_line(seed: int) -> void:
	await _spawn("rerouted_line", seed)
	var roof = g.world.piece_at(Vector2(28.6, -3.8) * M, ["hull"])
	var r := inspect(roof)
	var found_t: float = g.playtime
	var found_n: int = g.incidents.size()
	check(visible(roof) and g.lines_behind(roof) > 0 and str(r.get("inspect", "")).find(Txt.t("j_behind")) >= 0, "found: inspecting the engine room roof: %s" % r.get("inspect", ""))
	# the drawing shows nothing under that roof: cut where the G-01 procedure does
	cut(roof, [Vector2(28.2, -4.3), Vector2(28.2, -3.4)])
	await _frames(5)
	check(g.incidents.any(func(x): return x[1] == "leak"), "bites: cutting where the drawing shows no pipe opens the coolant run")
	check(found_n == 0 and not g.incidents.is_empty(), "found before it bit (no incident yet when it was found)")


func _t_second_source(seed: int) -> void:
	await _spawn("second_source", seed)
	for k in ["G-STOP", "K-G", "K-B", "E-D02"]:
		g.do_wrench(c(k))
	await wait_sim(10.0)
	var r := measure("E-D01")
	var found_t: float = g.playtime
	var found_n: int = g.incidents.size()
	check(r.val > 100.0 and not g.sys.running("G-01"), "found: with G-01 stopped, both switches open and the bleed plugged in, E-D01 still reads %s" % r.text)
	# take a 'dead' lead off the board
	open_room("D")
	var l = g.world.lines["c5"]
	g.do_wrench({"kind": "connector", "line": l, "end": 0, "pos": g.world.line_end_world(l, 0)})
	await _frames(3)
	check(g.incidents.any(func(x): return x[1] == "drone_hit"), "bites: unplugging a lead off the 'dead' board hits the drone")
	check(found_n == 0 and not g.incidents.is_empty(), "found before it bit (no incident yet when it was found)")


func _t_hidden_damage(seed: int) -> void:
	await _spawn("hidden_damage", seed, {"scan_kit": 1})
	var crack = null
	for j in g.world.joints:
		if j.alive and j.type == "crack":
			crack = j
	var rib = g.world.pieces[crack.a]
	open_room("C")
	var r := inspect(rib)
	var found_t: float = g.playtime
	var found_n: int = g.incidents.size()
	check(visible(rib) and str(r.get("inspect", "")).find(Txt.t("j_crack")) >= 0, "found: the precision kit's inspection of the roof plate: %s" % r.get("inspect", ""))
	# free it (its fixings, not the crack) and haul it with the grapple
	var other = g.world.pieces[crack.b if crack.a == rib.id else crack.a]
	for p in [rib, other]:
		for j in g.world.joints_of(p):
			if j.type != "crack":
				g.world.kill_joint(j)
	await _frames(3)
	g.drone.global_position = g.world.frame(rib) * Geom.centroid(rib.poly) + Vector2(-2.0 * M, 0)
	g.tools.tool = 3
	g.tools.held_piece = rib
	g.tools.held_body = rib.body
	g.tools.held_local = Geom.centroid(rib.poly) if rib.body == null else rib.body.global_transform.affine_inverse() * (g.world.frame(rib) * Geom.centroid(rib.poly))
	g.bot.aim = g.drone.global_position + Vector2(-4.0 * M, -1.0 * M)
	g.bot.lmb = true
	g.prev_lmb = true
	await _frames(90)
	g.bot.lmb = false
	check(g.incidents.any(func(x): return x[1] == "snap"), "bites: hauling the plate off snaps it at the crack")
	check(found_n == 0 and not g.incidents.is_empty(), "found before it bit (no incident yet when it was found)")
	g.tools.release_grab(false)


func _t_explosive_cargo(seed: int) -> void:
	await _spawn("explosive_cargo", seed)
	var tg: String = g.ship.variant.targets.explosive_cargo
	var p = g.world.tag(tg)
	open_room("C")
	var r := inspect(p)
	var found_t: float = g.playtime
	var found_n: int = g.incidents.size()
	check(visible(p) and str(r.get("inspect", "")).find(Txt.t("j_explosive")) >= 0 and g.sys.dest_of(p) == "hazard", "found: %s under the stencil '%s': %s" % [tg, g.ship.labels.get(tg, ""), r.get("inspect", "")])
	cut_through(p)
	await _frames(3)
	check(g.incidents.any(func(x): return x[1] == "blast"), "bites: cutting it up for scrap sets it off")
	check(found_n == 0 and not g.incidents.is_empty(), "found before it bit (no incident yet when it was found)")


func _t_fire_system(seed: int) -> void:
	await _spawn("fire_system", seed)
	var fx = g.world.tag("FX-01")
	var r := measure("FX-P")
	var found_t: float = g.playtime
	var found_n: int = g.incidents.size()
	check(visible(fx) and r.val > 200.0, "found: the fire bottle's port reads %s" % r.text)
	cut_through(fx)
	await _frames(3)
	check(g.incidents.any(func(x): return x[1] == "burst"), "bites: cutting the bottle bursts it")
	check(found_n == 0 and not g.incidents.is_empty(), "found before it bit (no incident yet when it was found)")
