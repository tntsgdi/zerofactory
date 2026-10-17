extends SceneTree
# FR-26's cryogenic cargo (scripts/cryo.gd). With its chillers running a tank
# stays at -163 °C; with the power off it warms, slowly (the user's call); a
# jacket that has let air in warms it ten times faster, and pumping the jacket
# back down slows it again. Warm enough, the relief valve lifts and cargo goes
# to space; frozen shut (psv_stuck), the tank ruptures instead. The heater left
# on (heater_live) warms its tank until its own supply is switched off. Cut
# while it still holds its vapour, a tank bursts; cut along a marked line while
# it still holds liquid, it is ruined and the spray freezes what stands near.
# Drawn off (liquid, then vapour), it comes apart along its lines into parts
# the grapple takes. Test files only.
# godot --headless --path . --fixed-fps 60 -s tests/cryo_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_cryo_save.json"
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


func _game(job: Dictionary = {}) -> Node:
	Game.contract = job
	Game.start_ship = "fr26"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _c(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _incident(g, kind: String) -> bool:
	for i in g.incidents:
		if i[1] == kind:
			return true
	return false


func _seconds(s: float) -> void:
	Engine.time_scale = 4.0
	await _frames(int(s * 60.0 / 4.0))
	Engine.time_scale = 1.0


func _job(trap: String) -> Dictionary:
	var job := Market.offer_for(41, {"rep": 30, "done": 6, "upgrades": {"berth88": 1}}, 1, "full", "fr26")
	job.traps = [trap]
	job.dev = true
	return job


func _power_off(g) -> void:
	g.do_wrench(_c(g, "K-FC"))
	g.do_wrench(_c(g, "K-BA"))


func _parts(g, tag: String) -> Array:
	var out: Array = []
	for id in g.world.order:
		var q = g.world.pieces[id]
		if not q.gone and (q.tag == tag or q.tag.begins_with(tag + "-")):
			out.append(q)
	return out


func _run() -> void:
	print("CRYO: kept cold, and left to warm")
	var g = await _game()
	await _frames(3)
	g.do_measure(_c(g, "TT-1"))
	var r: Dictionary = g.sys.readings.get("TT-1", {})
	check(absf(float(r.get("val", 0.0)) + 163.0) < 0.5 and str(r.get("text", "")).find("°C") >= 0, "the probe reads the cargo (%s)" % r.get("text", "?"))
	await _seconds(60.0)
	check(absf(g.cryo.temp("T-1") + 163.0) < 0.01, "with the chillers running it stays at -163 °C")
	_power_off(g)
	await _seconds(120.0)
	var dT: float = g.cryo.temp("T-1") + 163.0
	check(dT > 0.2 and dT < 0.6 and g.sys.P("TV1") < 225.0, "power off: it warms, slowly (%.2f °C in two minutes, %.0f kPa)" % [dT, g.sys.P("TV1")])
	g.queue_free()
	await _frames(2)

	print("CRYO: a jacket that has let air in")
	g = await _game(_job("jacket_loss"))
	await _frames(3)
	var tk: String = g.ship.variant.targets.jacket_loss
	var n: String = tk.trim_prefix("T-")
	var other: String = "T-1" if tk != "T-1" else "T-2"
	check(g.sys.P("J" + n) > 15.0 and g.cryo.temp(tk) > g.cryo.temp(other) + 3.0, "%s: its jacket at %.0f kPa, the cargo %.1f °C warmer than %s's" % [tk, g.sys.P("J" + n), g.cryo.temp(tk) - g.cryo.temp(other), other])
	_power_off(g)
	var t0: float = g.cryo.temp(tk)
	await _seconds(30.0)
	var fast: float = g.cryo.temp(tk) - t0
	check(fast > 1.0, "power off: it warms fast (%.1f °C in 30 s)" % fast)
	g.do_hose(_c(g, "JP-" + n))
	var kk := 0
	while g.sys.P("J" + n) > 2.0 and kk < 60:
		await _seconds(1.0)
		kk += 1
	var t1: float = g.cryo.temp(tk)
	await _seconds(30.0)
	var slow: float = g.cryo.temp(tk) - t1
	check(g.sys.P("J" + n) < 5.0 and slow < fast * 0.2, "the jacket pumped back down (%.1f kPa): slow again (%.2f °C in 30 s)" % [g.sys.P("J" + n), slow])
	g.queue_free()
	await _frames(2)

	print("CRYO: the relief valve")
	g = await _game()
	await _frames(3)
	_power_off(g)
	g.cryo.tanks["T-1"].T = -152.5
	var l0: float = g.sys.fluid("lng1")
	await _seconds(20.0)
	check(g.cryo.tanks["T-1"].get("lifting", false) and g.sys.fluid("lng1") < l0 and g.sys.P("TV1") < 320.0 and not _incident(g, "tank_rupture"),
		"warm enough, it lifts: cargo to space (%.3f of %.3f left), the tank held at %.0f kPa" % [g.sys.fluid("lng1"), l0, g.sys.P("TV1")])
	g.queue_free()
	await _frames(2)

	print("CRYO: a relief valve frozen shut")
	g = await _game(_job("psv_stuck"))
	await _frames(3)
	tk = g.ship.variant.targets.psv_stuck
	n = tk.trim_prefix("T-")
	g.do_measure(_c(g, "VP-" + n))
	var kp := float(g.sys.readings["VP-" + n].val)
	check(kp > 300.0 and g.cryo.tanks[tk].stuck, "%s reads %.0f kPa, over its 300 kPa valve, and nothing vents" % [tk, kp])
	_power_off(g)
	var l1: float = g.losses
	g.cryo.tanks[tk].T = g.cryo.tanks[tk].T + 4.0
	await _seconds(10.0)
	check(_incident(g, "tank_rupture") and g.losses >= l1 + 25000.0 and g.sys.fluid("lng" + n) == 0.0, "warmed on: it ruptures ($%d, the cargo gone)" % int(g.losses - l1))
	g.queue_free()
	await _frames(2)

	print("CRYO: the heater left on")
	g = await _game(_job("heater_live"))
	await _frames(3)
	tk = g.ship.variant.targets.heater_live
	g.do_measure(_c(g, "E-HT"))
	check(float(g.sys.readings["E-HT"].val) > 30.0, "its test point reads %s" % g.sys.readings["E-HT"].text)
	var h0: float = g.cryo.temp(tk)
	await _seconds(20.0)
	check(g.cryo.temp(tk) > h0 + 0.5, "%s warms even with the chillers running (+%.1f °C)" % [tk, g.cryo.temp(tk) - h0])
	g.do_wrench(_c(g, "K-HT"))
	await _seconds(20.0)
	var h1: float = g.cryo.temp(tk)
	await _seconds(20.0)
	check(g.cryo.temp(tk) <= h1, "its own supply switched off: it stops (the chillers pull it back)")
	g.queue_free()
	await _frames(2)

	print("CRYO: cut too soon")
	g = await _game()
	await _frames(3)
	var t3 = g.world.tag("T-3")
	var sg: Array = t3.get_meta("segments")[0]
	g.cut_kerf(t3, PackedVector2Array([Vector2(sg[0], sg[1]) * Geom.M, Vector2(sg[2], sg[3]) * Geom.M]))
	await _frames(3)
	check(_incident(g, "burst") and not g.world.tag("T-3").intact, "under its vapour, along its own line: it bursts, ruined")
	g.queue_free()
	await _frames(2)
	g = await _game()
	await _frames(3)
	g.sys.vols["TV2"].n = 0.0
	g.cryo.tanks["T-2"].ruptured = true          # hold the vapour down for this one: only the liquid left
	var t2 = g.world.tag("T-2")
	sg = t2.get_meta("segments")[0]
	g.cut_kerf(t2, PackedVector2Array([Vector2(sg[0], -2.4) * Geom.M, Vector2(sg[0], -1.0) * Geom.M]))
	await _frames(3)
	check(_incident(g, "leak") and not g.world.tag("T-2").intact, "still holding liquid: ruined, the cargo sprays out")
	var frozen := 0
	for id in g.world.order:
		var q = g.world.pieces[id]
		if not q.gone and q.cls == "equip" and q.cond < 0.99 and q.tag != "T-2":
			frozen += 1
	check(frozen > 0, "and it freezes what stands near (%d pieces)" % frozen)
	g.queue_free()
	await _frames(2)

	print("CRYO: drawn off, then taken apart")
	g = await _game()
	await _frames(3)
	var rec0: float = g.sys.fluid_value()
	g.do_hose(_c(g, "LP-1"))
	g.do_hose(_c(g, "VP-1"))
	var k := 0
	while (g.sys.fluid("lng1") > 0.01 or g.sys.P("TV1") > 1.0) and k < 240:
		await _seconds(1.0)
		k += 1
	check(g.sys.fluid("lng1") <= 0.01 and g.sys.P("TV1") <= 1.0 and g.sys.fluid_value() > rec0 + 14000.0,
		"the cargo pumped off ($%d) and the vapour after it, in %d s" % [int(g.sys.fluid_value() - rec0), k])
	t3 = g.world.tag("T-1")
	var v0: float = t3.value
	for s in t3.get_meta("segments").duplicate():
		var on = g.world.piece_at(Vector2((s[0] + s[2]) * 0.5, (s[1] + s[3]) * 0.5) * Geom.M, ["equip"])
		g.cut_kerf(on, PackedVector2Array([Vector2(s[0], s[1]) * Geom.M, Vector2(s[2], s[3]) * Geom.M]))
		await _frames(3)
	var parts := _parts(g, "T-1")
	var vsum := 0.0
	var heaviest := 0.0
	var whole := true
	for q in parts:
		vsum += q.value
		whole = whole and q.intact
		heaviest = maxf(heaviest, q.mass)
	check(parts.size() == 3 and whole and heaviest < 3.0 and vsum > 0.78 * v0 and not _incident(g, "burst") and not _incident(g, "equip_cut"),
		"empty, cut along its lines: three whole parts, the heaviest %.1f t, $%d of $%d (a tenth off for each cut)" % [heaviest, int(vsum), int(v0)])
	g.queue_free()
	await _frames(2)
	print("CRYO %s" % ("PASS" if fails == 0 else "FAIL"))
	finished = true
