class_name SpecialAuthor
# The seven special courses' practice rigs (design/新手教程与图鉴定案.md, 2026-10-20):
# one small rig per family of mechanism, each built from the ships' own modules so a
# course behaves exactly like the ships that need it. tools/ship_export.gd runs it as
# sp_<family> and writes ships/sp_<family>.json; the course is ships/sp_<family>_course.json
# (tools/authoring/sp_course.py). Metres, y down; the rig stands on a 12.8 m floor at
# x 14.6–27.4 clamped to the berth, open above.

const K = preload("res://tools/authoring/kit.gd")

static var variant := "energy"


static func build(world) -> void:
	K.begin(world, "SP-" + variant.to_upper())
	var floor_p = K.plate("RIG-F", K.R(14.6, 1.8, 27.4, 2.3), {"density": 1.6, "barrier": false, "cut_speed": 200.0, "name_key": "p_sp_floor"})
	floor_p.set_meta("rig", true)
	world.add_joint(floor_p, null, "clamp", K.p(16.0, 2.25)).set_meta("tag", "CL-01")
	world.add_joint(floor_p, null, "clamp", K.p(26.0, 2.25)).set_meta("tag", "CL-02")
	# the rig's own supply: a battery onto a small switchboard
	var swb = _on_floor("SWB", "swb", 15.0, 16.0, 0.3, {"mass": 0.3, "value": 3000.0, "fragile": 0.4, "name_key": "p_swb"})
	var bat = _on_floor("BAT", "battery", 16.2, 17.0, 1.0, {"mass": 0.3, "value": 2500.0, "fragile": 0.4, "hazard": "battery", "name_key": "p_battery"})
	K.line("pb", "cable", "power", "BAT", Vector2(16.6, 1.0), "SWB", Vector2(16.0, 1.0))
	K.ctrl("K-B", "switch", swb, Vector2(15.3, 0.6), {"target": "K-B", "state": true})
	K.ctrl("E-B", "test", swb, Vector2(15.7, 0.6), {"medium": "volt", "target": "bus"})
	match variant:
		"energy":
			_energy()
		"cryo":
			_cryo()
		"fluid":
			_fluid()
		"atmos":
			_atmos()
		"load":
			_load()
		"precise":
			_precise()
		"isolate":
			_isolate()


# a piece standing on the rig floor, bolted down at both ends
static func _on_floor(tag: String, art: String, x0: float, x1: float, top: float, opts: Dictionary):
	var pc = K.equip(tag, art, K.rect(x0, top, x1, 1.8), opts)
	var fl = K.by_tag["RIG-F"]
	K.bolt(pc, fl, x0 + 0.12, 1.8)
	K.bolt(pc, fl, x1 - 0.12, 1.8)
	return pc


# ---------------------------------------------------------------- stored energy
# a superconducting coil with its quench protection, cryoplant and helium dewar;
# a flywheel still spinning with its brake, the brake's cooling and a tachometer

static func _energy() -> void:
	var qps = _on_floor("QPS", "console", 17.4, 18.4, 0.6, {"mass": 0.3, "value": 9000.0, "fragile": 0.5, "name_key": "p_fx_qps_console"})
	var cb = _on_floor("CB", "coldbox", 18.8, 19.8, -0.6, {"mass": 1.2, "value": 30000.0, "fragile": 0.4, "name_key": "p_fx_coldbox"})
	var he = _on_floor("HE", "sphere_tank", 20.0, 20.8, 1.0, {"mass": 0.4, "value": 6000.0, "name_key": "p_fx_dewar"})
	var sup = _on_floor("TC-S", "grav_support", 21.2, 22.6, 1.45, {"cls": "metal", "dest": "metal", "mass": 0.2, "cut_speed": 200.0, "name_key": "p_fx_coil_support"})
	var coil = K.equip("TC-1", "tf_coil", K.rect(21.4, -1.4, 22.4, 1.45), {"mass": 1.6, "value": 70000.0, "fragile": 0.5, "name_key": "p_fx_tf_coil"})
	K.bolt(coil, sup, 21.6, 1.45)
	K.bolt(coil, sup, 22.2, 1.45)
	var dr = _on_floor("DR", "dump_res", 23.0, 24.2, 0.8, {"mass": 0.5, "value": 6000.0, "name_key": "p_fx_dump_res"})
	K.line("pq", "cable", "power", "SWB", Vector2(15.5, 0.3), "QPS", Vector2(17.9, 0.6), [Vector2(15.5, 0.0), Vector2(17.9, 0.0)])
	K.line("pc", "cable", "power", "SWB", Vector2(15.8, 0.3), "CB", Vector2(19.0, -0.6), [Vector2(15.8, -0.2), Vector2(19.0, -0.2)])
	K.line("pd", "cable", "power", "QPS", Vector2(18.2, 0.6), "DR", Vector2(23.6, 0.8), [Vector2(18.2, 0.4), Vector2(23.6, 0.4)])
	K.line("he-1", "pipe", "he", "CB", Vector2(19.5, -0.6), "TC-1", Vector2(21.4, -1.0), [Vector2(19.5, -1.0)])
	K.line("he-d", "pipe", "he", "HE", Vector2(20.4, 1.0), "CB", Vector2(19.8, 1.2), [Vector2(20.4, 0.9), Vector2(19.9, 0.9), Vector2(19.9, 1.2)])
	K.ctrl("DUMP", "switch", qps, Vector2(17.6, 0.85), {"target": "DUMP", "state": false})
	K.ctrl("FIELD", "probe", qps, Vector2(17.9, 0.85), {"medium": "field_pct", "target": "coils"})
	K.ctrl("COILT", "probe", qps, Vector2(18.2, 0.85), {"medium": "coil_temp", "target": "coils"})
	K.ctrl("PHE", "port", he, Vector2(20.4, 1.2), {"medium": "coolant", "target": "lhe"})
	# the flywheel
	var fw = _on_floor("FW-1", "flywheel_rotor", 24.6, 25.8, 0.2, {"mass": 1.5, "value": 30000.0, "fragile": 0.45, "name_key": "p_flywheel"})
	var brk = _on_floor("BRK-1", "brake", 25.9, 26.4, 1.2, {"mass": 0.1, "value": 2500.0, "name_key": "p_wheel_brake"})
	var fwp = _on_floor("FWP", "panel", 26.5, 27.2, 0.4, {"mass": 0.08, "value": 1500.0, "name_key": "p_sp_fw_panel"})
	K.ctrl("BR-1", "switch", fwp, Vector2(26.7, 0.7), {"target": "BR-1", "state": false})
	K.ctrl("CV-1", "switch", fwp, Vector2(27.0, 0.7), {"target": "CV-1", "state": false})
	K.ctrl("RPM-1", "probe", fwp, Vector2(26.85, 1.1), {"medium": "rpm", "target": "FW-1"})


# ---------------------------------------------------------------- cryogenics
# a liquid hydrogen tank boiling off, its relief valve frozen shut, its cryocooler;
# a dilution refrigerator still at millikelvin with its chip, gas handling and table

static func _cryo() -> void:
	var tk = _on_floor("TK-1", "cryotank", 17.4, 20.4, 0.2, {"mass": 1.2, "value": 12000.0, "fragile": 0.3, "name_key": "p_sp_lh2_tank"})
	var rv = K.equip("RV-1", "relief", K.rect(18.7, -0.35, 19.1, 0.2), {"mass": 0.04, "value": 1800.0, "name_key": "p_hg_relief"})
	K.bolt(rv, tk, 18.8, 0.2)
	K.bolt(rv, tk, 19.0, 0.2)
	var cry = _on_floor("CRY-1", "cold_box_h2", 21.0, 22.0, -0.6, {"mass": 1.0, "value": 22000.0, "fragile": 0.4, "name_key": "p_hg_cryocooler"})
	K.line("pk", "cable", "power", "SWB", Vector2(15.8, 0.3), "CRY-1", Vector2(21.2, -0.6), [Vector2(15.8, -0.9), Vector2(21.2, -0.9)])
	K.line("cr1", "pipe", "t1", "CRY-1", Vector2(21.0, 0.6), "TK-1", Vector2(20.4, 0.6))
	K.ctrl("PT-1", "port", tk, Vector2(17.7, 0.5), {"medium": "coolant", "target": "t1"})
	K.ctrl("TP-1", "probe", tk, Vector2(18.2, 0.5), {"medium": "tank_kpa", "target": "TK-1"})
	K.ctrl("VT-1", "probe", rv, Vector2(18.8, -0.15), {"medium": "valve_temp", "target": "TK-1"})
	K.ctrl("RVH-1", "switch", rv, Vector2(19.0, -0.15), {"target": "RVH-1", "state": false})
	# the dilution refrigerator: its stages hung on a post, the chip under the mixing chamber
	var post = _on_floor("DF-P", "pipe", 23.2, 23.4, -1.8, {"cls": "metal", "dest": "metal", "mass": 0.15, "cut_speed": 220.0, "name_key": "p_sp_post"})
	post.set_meta("rig", true)
	var ys := [-1.6, -1.0, -0.4]
	var names := ["STG-50K", "STG-4K", "STG-MXC"]
	for i in 3:
		var stg = K.equip(names[i], "dr_stage", K.rect(23.4, ys[i], 25.4, ys[i] + 0.22), {"mass": 0.08, "value": 6000.0, "fragile": 0.5, "name_key": "p_qc_stage_" + ["50k", "4k", "mxc"][i]})
		K.bolt(stg, post, 23.45, ys[i] + 0.11)
	# (the chip hangs under the mixing chamber's outer end: it comes out sideways)
	var chip = K.equip("QPU", "qpu", K.rect(24.9, -0.18, 25.4, 0.2), {"mass": 0.03, "value": 120000.0, "fragile": 0.9, "name_key": "p_qc_qpu"})
	K.bolt(chip, K.by_tag["STG-MXC"], 25.0, -0.18)
	K.bolt(chip, K.by_tag["STG-MXC"], 25.3, -0.18)
	_on_floor("VI", "iso_table", 23.6, 25.4, 1.3, {"mass": 0.4, "value": 8000.0, "name_key": "p_qc_vit"})
	var ptc = _on_floor("PTC", "screw_comp", 25.7, 27.2, 0.6, {"mass": 0.5, "value": 14000.0, "name_key": "p_qc_compressor"})
	var ghs = _on_floor("GHS", "ghs", 22.3, 23.1, 0.0, {"mass": 0.3, "value": 26000.0, "fragile": 0.4, "name_key": "p_qc_ghs"})
	K.line("pp", "cable", "power", "SWB", Vector2(15.6, 0.3), "PTC", Vector2(26.4, 0.6), [Vector2(15.6, -2.2), Vector2(26.4, -2.2)])
	K.ctrl("CIRC", "switch", ghs, Vector2(22.5, 0.3), {"target": "CIRC", "state": true})
	K.ctrl("PT", "switch", ghs, Vector2(22.9, 0.3), {"target": "PT", "state": true})
	K.ctrl("HEAT", "switch", ghs, Vector2(22.5, 0.7), {"target": "HEAT", "state": false})
	K.ctrl("VI-LOCK", "switch", ghs, Vector2(22.9, 0.7), {"target": "VI-LOCK", "state": false})
	K.ctrl("MXT", "probe", ghs, Vector2(22.5, 1.1), {"medium": "stage", "target": "STG-MXC"})
	K.ctrl("MIXP", "port", ghs, Vector2(22.9, 1.1), {"medium": "gas", "target": "MIX"})


# ---------------------------------------------------------------- fluids under pressure
# a drill string of three stands under its top drive, still wound up with torque and
# full of mud under pressure, its slips and the driller's console;
# two propellant tanks cross-connected to a manifold, their nitrogen pressurisation,
# the main pump that draws the manifold

static func _fluid() -> void:
	var mast = _on_floor("DM", "", 16.9, 17.2, -5.2, {"cls": "metal", "dest": "metal", "mass": 0.5, "cut_speed": 200.0, "name_key": "p_sp_mast"})
	mast.set_meta("rig", true)
	var td = K.equip("TD", "top_drive", K.rect(17.5, -5.6, 18.3, -4.4), {"mass": 0.6, "value": 18000.0, "name_key": "p_dr_top_drive"})
	K.bolt(td, mast, 17.2, -5.0)
	var tops := [-4.4, -3.0, -1.6]
	var names := ["J-1", "J-2", "BHA"]
	var prev = td
	for k in 3:
		var y0: float = tops[k]
		var y1: float = y0 + 1.4 if k < 2 else 1.4
		var st = K.equip(names[k], "pipe" if k < 2 else "bha", K.rect(17.75, y0, 18.05, y1), {"mass": 0.4 if k < 2 else 0.8, "value": 4000.0 if k < 2 else 30000.0, "fragile": 0.3, "cut_speed": 110.0, "name_key": "p_dr_stand" if k < 2 else "p_dr_bha"})
		K.bolt(st, prev, 17.9, y0)
		var gd = K.plate("G-%d" % (k + 1), K.R(17.2, y0 + 0.5, 17.75, y0 + 0.7), {"density": 1.2, "barrier": false, "cut_speed": 220.0, "name_key": "p_dr_guide"}, "fixture")
		gd.set_meta("rig", true)
		K.bolt(gd, mast, 17.2, y0 + 0.6, "weld")
		K.bolt(st, gd, 17.75, y0 + 0.6)
		prev = st
	var rt = _on_floor("RT", "rotary_table", 17.2, 18.6, 1.4, {"mass": 0.8, "value": 12000.0, "name_key": "p_dr_rotary"})
	K.bolt(prev, rt, 17.9, 1.4)
	var drl = _on_floor("DRL", "console", 19.0, 20.0, 0.4, {"mass": 0.3, "value": 8000.0, "fragile": 0.4, "name_key": "p_dr_driller"})
	K.ctrl("TQB", "switch", drl, Vector2(19.2, 0.65), {"target": "TQB", "state": false})
	K.ctrl("TQ", "probe", drl, Vector2(19.5, 0.65), {"medium": "torque", "target": "string"})
	K.ctrl("MUDP", "probe", drl, Vector2(19.8, 0.65), {"medium": "mudp", "target": "string"})
	K.ctrl("SLIP-1", "switch", drl, Vector2(19.3, 1.05), {"target": "SLIP-1", "state": false})
	K.ctrl("SLIP-2", "switch", drl, Vector2(19.7, 1.05), {"target": "SLIP-2", "state": false})
	var stp = _on_floor("STP", "standpipe", 20.3, 20.9, -1.2, {"mass": 0.3, "value": 6000.0, "name_key": "p_dr_standpipe"})
	K.ctrl("PMUD", "port", stp, Vector2(20.35, 0.6), {"medium": "water", "target": "mud"})
	K.line("m1", "pipe", "mud", "STP", Vector2(20.6, -1.2), "TD", Vector2(18.3, -5.0), [Vector2(20.6, -5.0)])
	K.line("pr", "cable", "power", "SWB", Vector2(15.4, 0.3), "DRL", Vector2(19.5, 0.4), [Vector2(15.4, -0.1), Vector2(19.5, -0.1)])
	# the cross-connected tanks, on a rack; the manifold, its pump; the nitrogen bank
	var rack = _on_floor("TR", "", 21.4, 21.6, -2.9, {"cls": "metal", "dest": "metal", "mass": 0.3, "cut_speed": 200.0, "name_key": "p_sp_rack"})
	rack.set_meta("rig", true)
	var ty := [[-2.8, -1.6], [-1.3, -0.1]]
	for i in 2:
		var tk = K.equip("T-%d" % (i + 1), "fueltank", K.rect(21.6, ty[i][0], 23.8, ty[i][1]), {"mass": 0.6, "value": 9000.0, "fragile": 0.3, "hazard": "fuel_tank", "name_key": "p_fueltank"})
		K.bolt(tk, rack, 21.7, ty[i][0] + 0.2)
		K.bolt(tk, rack, 21.7, ty[i][1] - 0.2)
		K.ctrl("TV-%d" % (i + 1), "port", tk, Vector2(23.0, ty[i][0] + 0.15), {"medium": "gas", "target": "TU-%d" % (i + 1)})
	var xm = _on_floor("XM", "manifold", 24.2, 25.6, 0.5, {"mass": 0.3, "value": 5000.0, "name_key": "p_cross_manifold"})
	K.ctrl("XV-1", "switch", xm, Vector2(24.5, 0.8), {"target": "XV-1", "state": false})
	K.ctrl("XV-2", "switch", xm, Vector2(24.9, 0.8), {"target": "XV-2", "state": false})
	var nb = _on_floor("NB", "sphere_tank", 24.3, 25.1, -0.6, {"mass": 0.3, "value": 4000.0, "name_key": "p_n2_sphere"})
	K.ctrl("PV-1", "valve", nb, Vector2(24.5, -0.3), {"target": "PV-1", "state": true})
	K.ctrl("PV-2", "valve", nb, Vector2(24.9, -0.3), {"target": "PV-2", "state": true})
	var pm = _on_floor("PUMP-M", "pump", 25.8, 27.2, 0.9, {"mass": 0.5, "value": 9000.0, "fragile": 0.4, "name_key": "p_pump"})
	K.ctrl("PR", "port", pm, Vector2(26.5, 1.2), {"medium": "fuel", "target": "xm"})
	K.line("b1", "pipe", "xm", "T-1", Vector2(23.8, -2.2), "XM", Vector2(24.4, 0.5), [Vector2(24.4, -2.2)])
	K.line("b2", "pipe", "xm", "T-2", Vector2(23.8, -0.7), "XM", Vector2(24.7, 0.5), [Vector2(24.7, -0.7)])
	K.line("bm", "pipe", "xm", "XM", Vector2(25.6, 1.0), "PUMP-M", Vector2(25.8, 1.2), [Vector2(25.7, 1.0), Vector2(25.7, 1.2)])
	K.line("pm", "cable", "power", "SWB", Vector2(15.7, 0.3), "PUMP-M", Vector2(26.8, 0.9), [Vector2(15.7, -3.2), Vector2(26.8, -3.2)])


# ---------------------------------------------------------------- atmosphere, fire, contamination
# a culture bay at 45 % oxygen, its grow lamp inside; an avionics bay under a bolted
# carbon-fibre panel; a furnace core shut down at 760 °C on its heat-exchange loop

# a small sealed box of plates (x0..x1, y0..y1 its outside), the top one given its own tag
static func _box(room: String, x0: float, y0: float, x1: float, y1: float, top_tag: String, top_opts: Dictionary, top_bolted: bool):
	var W := {"density": 1.4, "barrier": true, "cut_speed": 220.0, "name_key": "k_hull"}
	var t := 0.2
	var lft = K.plate(room + "-L", K.R(x0, y0 + t, x0 + t, y1 - t), W)
	var rgt = K.plate(room + "-R", K.R(x1 - t, y0 + t, x1, y1 - t), W)
	var bot = K.plate(room + "-B", K.R(x0, y1 - t, x1, y1), W)
	var top_o: Dictionary = W.duplicate()
	top_o.merge(top_opts, true)
	var top = K.plate(top_tag, K.R(x0, y0, x1, y0 + t), top_o)
	for q in [lft, rgt, bot]:
		q.set_meta("rig", true)
	K.bolt(lft, bot, x0 + 0.1, y1 - 0.25, "weld")
	K.bolt(rgt, bot, x1 - 0.1, y1 - 0.25, "weld")
	K.bolt(bot, K.by_tag["RIG-F"], x0 + 0.3, y1, "weld")
	K.bolt(bot, K.by_tag["RIG-F"], x1 - 0.3, y1, "weld")
	var ft := "bolt" if top_bolted else "weld"
	for x in [x0 + 0.1, x1 - 0.1]:
		K.bolt(top, lft if x < (x0 + x1) * 0.5 else rgt, x, y0 + 0.15, ft)
	if top_bolted:
		K.bolt(top, lft, x0 + 0.1, y0 + 0.05)
		K.bolt(top, rgt, x1 - 0.1, y0 + 0.05)
	K.w.add_room(room, K.R(x0 + t, y0 + t, x1 - t, y1 - t))
	return top


static func _atmos() -> void:
	# the oxygen-rich culture bay under its bolted lid
	var oxt = _box("OX", 17.4, -1.6, 19.8, 1.8, "OX-T", {"name_key": "p_sp_ox_lid", "density": 0.8}, true)
	var lamp = K.equip("GL-1", "growlamp", K.rect(17.6, -1.3, 19.6, -0.9), {"mass": 0.1, "value": 3500.0, "fragile": 0.6, "name_key": "p_grow_lamp", "room": "OX"})
	K.bolt(lamp, K.by_tag["OX-L"], 17.65, -1.1)
	K.bolt(lamp, K.by_tag["OX-R"], 19.55, -1.1)
	var tray = K.equip("PL-1", "plants", K.rect(17.8, 0.6, 19.4, 1.6), {"mass": 0.2, "value": 1500.0, "fragile": 0.5, "name_key": "p_ark_plant_tray", "room": "OX"})
	K.bolt(tray, K.by_tag["OX-B"], 18.2, 1.6)
	K.bolt(tray, K.by_tag["OX-B"], 19.2, 1.6)
	K.ctrl("G-OX", "port", oxt, Vector2(17.8, -1.65), {"medium": "gas", "target": "OX"})
	K.ctrl("O2-1", "probe", oxt, Vector2(18.2, -1.65), {"medium": "o2", "target": "OX"})
	# the avionics bay under its carbon-fibre lid (four bolts)
	var hc = _box("AV", 20.8, -0.6, 23.4, 1.8, "HC-1", {"name_key": "p_st_composite", "cut_speed": 200.0}, true)
	var con = K.equip("AV-C", "console", K.rect(21.2, 0.4, 22.4, 1.6), {"mass": 0.2, "value": 9000.0, "fragile": 0.5, "name_key": "p_st_controls", "room": "AV"})
	K.bolt(con, K.by_tag["AV-B"], 21.4, 1.6)
	K.bolt(con, K.by_tag["AV-B"], 22.2, 1.6)
	K.ctrl("FM-1", "probe", K.by_tag["AV-L"], Vector2(20.75, 0.6), {"medium": "fume", "target": "AV"})
	K.ctrl("G-AV", "port", K.by_tag["AV-L"], Vector2(20.75, 1.1), {"medium": "gas", "target": "AV"})
	# the furnace core on its cooling loop
	var core = _on_floor("CORE", "arc_furnace", 24.0, 25.6, 0.0, {"mass": 1.8, "value": 40000.0, "fragile": 0.3, "name_key": "p_furnace_core"})
	var hx = _on_floor("HX-1", "hx", 25.9, 27.2, 0.9, {"mass": 0.4, "value": 6000.0, "name_key": "p_heat_exchanger"})
	K.line("l1", "pipe", "loop", "HX-1", Vector2(25.9, 1.1), "CORE", Vector2(25.6, 0.4), [Vector2(25.75, 1.1), Vector2(25.75, 0.4)])
	K.line("l2", "pipe", "loop", "HX-1", Vector2(26.2, 0.9), "CORE", Vector2(25.0, 0.0), [Vector2(26.2, -0.3), Vector2(25.0, -0.3)])
	K.line("ph", "cable", "power", "SWB", Vector2(15.9, 0.3), "HX-1", Vector2(26.8, 0.9), [Vector2(15.9, -2.4), Vector2(26.8, -2.4)])
	K.ctrl("CT-1", "probe", core, Vector2(24.3, 0.3), {"medium": "core", "target": "CORE"})
	K.ctrl("PL", "port", hx, Vector2(26.9, 1.2), {"medium": "coolant", "target": "loop"})


# ---------------------------------------------------------------- loads and motion
# a folded arm held on its pivot by two locking pins and a charged accumulator;
# a crate locked onto its rail behind a gate

static func _load() -> void:
	var ab = _on_floor("AB", "hpu", 17.4, 18.4, 0.6, {"mass": 0.4, "value": 5000.0, "name_key": "p_hpu"})
	var arm = K.equip("ARM-1", "arm", K.rect(18.4, -0.2, 21.0, 0.8), {"mass": 0.6, "value": 14000.0, "fragile": 0.4, "name_key": "p_sp_arm"})
	K.bolt(arm, ab, 18.42, 0.64, "lock", "PIN-1")
	K.bolt(arm, ab, 18.42, 0.78, "lock", "PIN-2")
	K.bolt(arm, ab, 18.42, 0.72, "bolt", "PIV-1")
	K.ctrl("G-ACC", "port", ab, Vector2(17.6, 0.9), {"medium": "gas", "target": "ACC"})
	K.ctrl("TN-1", "probe", ab, Vector2(18.0, 0.9), {"medium": "tension", "target": "PIV-1"})
	# the rail and its crate, the gate at the rail's end, the lock panel
	for x in [21.8, 26.0]:
		var post = _on_floor("RP-%d" % (1 if x < 22.0 else 2), "", x, x + 0.2, 0.7, {"cls": "metal", "dest": "metal", "mass": 0.1, "cut_speed": 220.0, "name_key": "p_sp_post"})
		post.set_meta("rig", true)
	var rail = K.plate("RL-1", K.R(21.6, 0.55, 26.4, 0.7), {"density": 1.2, "barrier": false, "cut_speed": 200.0, "name_key": "k_rail"}, "rail")
	K.bolt(rail, K.by_tag["RP-1"], 21.9, 0.7, "weld")
	K.bolt(rail, K.by_tag["RP-2"], 26.1, 0.7, "weld")
	var box = K.equip("BOX-1", "crate", K.rect(22.0, -0.6, 24.0, 0.55), {"mass": 0.6, "value": 8000.0, "fragile": 0.5, "name_key": "p_crate"})
	K.bolt(box, rail, 22.4, 0.55, "lock")
	K.bolt(box, rail, 23.6, 0.55, "lock")
	var gp = _on_floor("GP", "", 26.5, 26.7, 0.6, {"cls": "metal", "dest": "metal", "mass": 0.1, "cut_speed": 220.0, "name_key": "p_sp_post"})
	gp.set_meta("rig", true)
	var gate = K.plate("GATE", K.R(26.5, -0.9, 26.7, 0.6), {"density": 1.2, "barrier": false, "cut_speed": 200.0, "door": true, "open_dir": Vector2(0, -1.6) * Geom.M, "name_key": "p_sp_gate"}, "door")
	K.bolt(gate, gp, 26.6, 0.58, "weld")
	K.door("GATE")
	var rpn = _on_floor("RPN", "panel", 24.6, 25.4, 1.0, {"mass": 0.06, "value": 1200.0, "name_key": "p_sp_rail_panel"})
	K.ctrl("LK-1", "switch", rpn, Vector2(25.0, 1.3), {"target": "LK-1", "state": true})


# ---------------------------------------------------------------- precision parts
# two primary mirror segments (inner and outer ring) on their actuators, the mirror
# control cabinet with the ring locks and the roll-down dust cover, an instrument
# welded on beside them; a small hall under a viewing pane that holds its pressure

static func _precise() -> void:
	var mb = _on_floor("MB", "", 20.6, 20.9, -3.0, {"cls": "metal", "dest": "metal", "mass": 0.3, "cut_speed": 200.0, "name_key": "p_sp_backing"})
	mb.set_meta("rig", true)
	var segs := [["PM-2", -2.4, -0.8, "PA-2"], ["PM-1", -0.7, 0.9, "PA-1"]]
	for sg in segs:
		var pm = K.equip(sg[0], "mirror", K.rect(20.9, sg[1], 21.3, sg[2]), {"mass": 0.3, "value": 60000.0, "fragile": 0.9, "name_key": "p_ob_segment"})
		K.bolt(pm, mb, 20.95, sg[1] + 0.2)
		K.bolt(pm, mb, 20.95, sg[2] - 0.2)
		var pa = K.equip(sg[3], "actuator", K.rect(20.1, (sg[1] + sg[2]) * 0.5 - 0.15, 20.6, (sg[1] + sg[2]) * 0.5 + 0.15), {"mass": 0.04, "value": 3000.0, "name_key": "p_ob_actuator"})
		K.bolt(pa, mb, 20.55, (sg[1] + sg[2]) * 0.5)
	var rl = K.equip("ROLL", "reel", K.rect(20.95, -3.0, 21.45, -2.5), {"mass": 0.05, "value": 2500.0, "name_key": "p_ob_cover_roller"})
	K.bolt(rl, mb, 20.95, -2.75)
	var mcc = _on_floor("MCC", "swb", 23.6, 24.4, 0.2, {"mass": 0.3, "value": 9000.0, "name_key": "p_ob_mcc"})
	K.ctrl("LK-1", "switch", mcc, Vector2(23.75, 0.5), {"target": "LK-1", "state": false})
	K.ctrl("LK-2", "switch", mcc, Vector2(24.0, 0.5), {"target": "LK-2", "state": false})
	K.ctrl("CVR", "switch", mcc, Vector2(24.25, 0.5), {"target": "CVR", "state": false})
	K.ctrl("OPT", "probe", mcc, Vector2(24.0, 0.9), {"medium": "optics", "target": "mirror"})
	K.line("pc", "cable", "power", "SWB", Vector2(15.8, 0.3), "MCC", Vector2(24.0, 0.2), [Vector2(15.8, -0.05), Vector2(24.0, -0.05)])
	K.line("pr", "cable", "power", "MCC", Vector2(24.2, 0.2), "ROLL", Vector2(21.45, -2.75), [Vector2(24.2, -3.2), Vector2(21.6, -3.2), Vector2(21.6, -2.75)])
	# the instrument welded on beside the mirror: cutting it free throws dust
	var ip = _on_floor("IP", "", 23.2, 23.4, -1.6, {"cls": "metal", "dest": "metal", "mass": 0.1, "cut_speed": 220.0, "name_key": "p_sp_post"})
	ip.set_meta("rig", true)
	var ins = K.equip("INS", "spectrograph", K.rect(21.8, -1.1, 23.2, -0.5), {"mass": 0.2, "value": 22000.0, "fragile": 0.5, "name_key": "p_ob_spectro"})
	K.bolt(ins, ip, 23.24, -0.95, "weld")
	K.bolt(ins, ip, 23.24, -0.65, "weld")
	# the viewing hall: its pane is the roof, held by clamping strips
	var W := {"density": 1.4, "barrier": true, "cut_speed": 220.0, "name_key": "k_hull"}
	var lft = K.plate("O-L", K.R(24.8, -0.8, 25.0, 1.6), W)
	var rgt = K.plate("O-R", K.R(26.8, -0.8, 27.0, 1.6), W)
	var bot = K.plate("O-B", K.R(24.8, 1.6, 27.0, 1.8), W)
	for q in [lft, rgt, bot]:
		q.set_meta("rig", true)
	K.bolt(lft, bot, 24.9, 1.55, "weld")
	K.bolt(rgt, bot, 26.9, 1.55, "weld")
	K.bolt(bot, K.by_tag["RIG-F"], 25.1, 1.8, "weld")
	K.bolt(bot, K.by_tag["RIG-F"], 26.7, 1.8, "weld")
	var pane = K.plate("OBS-1", K.R(24.8, -1.0, 27.0, -0.8), {"art": "glass", "barrier": true, "cls": "equip", "dest": "equip", "density": 0.8, "mass": 0.3, "value": 2500.0, "fragile": 0.6, "cut_speed": 260.0, "name_key": "p_obs_glass"})
	for x in [24.9, 25.2, 26.6, 26.9]:
		K.bolt(pane, lft if x < 25.9 else rgt, x, -0.85)
	K.w.add_room("O", K.R(25.0, -0.8, 26.8, 1.6))
	K.ctrl("G-O", "port", lft, Vector2(24.75, 0.4), {"medium": "gas", "target": "O"})


# ---------------------------------------------------------------- isolation and extraction
# a small ship on its cradle behind a bow door, its battery, two cradle locks, the
# winch that draws it out whole; a vault whose lock solenoid has two supplies (the
# bus and its own backup, which feeds back into the bus), its release lever, a box inside

static func _isolate() -> void:
	var H := {"density": 1.0, "barrier": false, "cut_speed": 200.0, "name_key": "p_sp_small_hull"}
	for c in [[21.8, 22.4, "CR-1"], [24.2, 24.8, "CR-2"]]:
		var cr = _on_floor(c[2], "", c[0], c[1], 1.3, {"cls": "metal", "dest": "metal", "mass": 0.1, "cut_speed": 220.0, "name_key": "p_sp_cradle"})
		cr.set_meta("rig", true)
	var bot = K.plate("SS-H1", K.R(21.6, 1.1, 25.0, 1.3), H)
	var top = K.plate("SS-H2", K.R(21.6, -0.6, 25.0, -0.4), H)
	var nose = K.plate("SS-N", K.R(25.0, -0.6, 25.5, 1.3), H)
	var tail = K.plate("SS-T", K.R(21.4, -0.6, 21.6, 1.3), H)
	K.bolt(bot, tail, 21.65, 1.2, "weld")
	K.bolt(bot, nose, 24.95, 1.2, "weld")
	K.bolt(top, tail, 21.65, -0.5, "weld")
	K.bolt(top, nose, 24.95, -0.5, "weld")
	K.bolt(bot, K.by_tag["CR-1"], 22.1, 1.3)
	K.bolt(bot, K.by_tag["CR-2"], 24.5, 1.3)
	var sb = K.equip("SS-BAT", "battery", K.rect(21.8, 0.5, 22.5, 1.1), {"mass": 0.1, "value": 2500.0, "hazard": "battery", "name_key": "p_battery"})
	K.bolt(sb, bot, 21.9, 1.1)
	K.bolt(sb, bot, 22.4, 1.1)
	var se = K.equip("SS-ENG", "engine_s", K.rect(22.7, 0.2, 24.6, 1.1), {"mass": 0.3, "value": 9000.0, "name_key": "p_sp_small_engine"})
	K.bolt(se, bot, 22.9, 1.1)
	K.bolt(se, bot, 24.4, 1.1)
	K.ctrl("SK", "switch", sb, Vector2(22.15, 0.75), {"target": "SK", "state": true})
	var gp = _on_floor("BP", "", 25.9, 26.1, 1.6, {"cls": "metal", "dest": "metal", "mass": 0.05, "cut_speed": 220.0, "name_key": "p_sp_post"})
	gp.set_meta("rig", true)
	var bow = K.plate("BOW", K.R(25.9, -0.9, 26.1, 1.6), {"density": 1.2, "barrier": false, "cut_speed": 200.0, "door": true, "open_dir": Vector2(0, -2.7) * Geom.M, "name_key": "p_sp_bow_door"}, "door")
	K.bolt(bow, gp, 26.0, 1.62, "weld")
	K.door("BOW")
	var wch = _on_floor("WCH", "reel", 26.4, 27.2, 1.0, {"mass": 0.2, "value": 4000.0, "name_key": "p_sp_winch"})
	K.line("pw", "cable", "power", "SWB", Vector2(15.6, 0.3), "WCH", Vector2(26.8, 1.0), [Vector2(15.6, -1.4), Vector2(26.8, -1.4)])
	var np = _on_floor("NP", "panel", 20.6, 21.2, 0.2, {"mass": 0.06, "value": 1200.0, "name_key": "p_sp_cradle_panel"})
	K.ctrl("CL-1", "switch", np, Vector2(20.75, 0.5), {"target": "CL-1", "state": true})
	K.ctrl("CL-2", "switch", np, Vector2(21.05, 0.5), {"target": "CL-2", "state": true})
	K.ctrl("WINCH", "switch", np, Vector2(20.9, 0.9), {"target": "WINCH", "state": false})
	# the vault: its door, the lock solenoid on two supplies, the backup, the release
	var W := {"density": 1.4, "barrier": true, "cut_speed": 120.0, "name_key": "k_hull"}
	var vl = K.plate("V-L", K.R(17.0, -2.6, 17.2, 0.0), W)
	var vt = K.plate("V-T", K.R(17.0, -2.8, 20.0, -2.6), W)
	var vb = K.plate("V-B", K.R(17.0, 0.0, 20.0, 0.2), W)
	for q in [vl, vt, vb]:
		q.set_meta("rig", true)
	K.bolt(vl, vt, 17.1, -2.65, "weld")
	K.bolt(vl, vb, 17.1, 0.05, "weld")
	var vpost = _on_floor("V-P", "", 17.0, 17.2, 0.2, {"cls": "metal", "dest": "metal", "mass": 0.1, "cut_speed": 220.0, "name_key": "p_sp_post"})
	vpost.set_meta("rig", true)
	K.bolt(vb, vpost, 17.1, 0.18, "weld")
	var vd = K.plate("VD-1", K.R(19.8, -2.6, 20.0, 0.0), {"art": "vault", "density": 2.0, "barrier": true, "cut_speed": 30.0, "door": true, "open_dir": Vector2(0, -2.7) * Geom.M, "name_key": "p_vault_door"}, "door")
	K.bolt(vd, vb, 19.9, -0.02, "weld")
	K.door("VD-1")
	var box = K.equip("SDB-1", "safe_deposit", K.rect(17.4, -2.2, 19.4, 0.0), {"mass": 0.5, "value": 15000.0, "fragile": 0.3, "name_key": "p_safe_box"})
	K.bolt(box, vl, 17.25, -1.3)
	K.bolt(box, vb, 18.4, 0.02)
	var ls = _on_floor("LS-1", "swb", 20.2, 20.5, 0.6, {"mass": 0.1, "value": 3000.0, "name_key": "p_lock_solenoid"})
	var lb = _on_floor("LB", "battery", 17.4, 18.2, 1.0, {"mass": 0.2, "value": 2000.0, "hazard": "battery", "name_key": "p_sp_lock_backup"})
	var mrp = _on_floor("MRP", "panel", 18.4, 19.0, 0.6, {"mass": 0.05, "value": 1200.0, "name_key": "p_sp_release_panel"})
	K.line("la", "cable", "power", "SWB", Vector2(16.0, 0.6), "LS-1", Vector2(20.2, 0.9), [Vector2(16.2, 0.6), Vector2(16.2, 0.4), Vector2(20.1, 0.4), Vector2(20.1, 0.9)])
	K.line("lb", "cable", "power", "LB", Vector2(18.0, 1.0), "LS-1", Vector2(20.3, 0.6), [Vector2(18.0, 0.45), Vector2(20.3, 0.45)])
	K.ctrl("K-LB", "switch", lb, Vector2(17.8, 1.3), {"target": "K-LB", "state": true})
	K.ctrl("E-L", "test", ls, Vector2(20.35, 1.1), {"medium": "volt", "target": "LS-1"})
	K.ctrl("MR-1", "switch", mrp, Vector2(18.7, 0.9), {"target": "MR-1", "state": false})


# ---------------------------------------------------------------- the ship file's sections

static func meta() -> Dictionary:
	var d := {
		"id": "sp_" + variant,
		"name": "SP-" + variant.to_upper(),
		"title": ["专项训练件 · " + _cls_zh(), "SPECIAL COURSE RIG · " + variant.to_upper()],
		"length": 12.8,
		"clamps": [[16.0, 2.3], [26.0, 2.3]],
		"room_names": {},
		"gas": {"rooms": {}, "vessels": {}, "valves": [], "value": 0.0},
		"power": {
			"bus": "SWB",
			"sources": [{"piece": "BAT", "kind": "battery", "volts": 48.0, "local_volts": 48.0, "cable": "pb", "switch": "K-B", "charge": 1.0, "drain": 0.0}],
			"lamps": {},
		},
		"fluids": {"volumes": {}, "value": {"coolant": 50.0}},
		"ctrls_cfg": {},
		"labels": {},
		"procedures": {},
		"blueprint": {},
		"training": true,
	}
	match variant:
		"energy":
			d.value = {"total": 160000.0, "metal": 3000.0}
			d.fluids.volumes["lhe"] = {"fluid": "coolant", "amount": 0.2, "full": 0.2, "piece": "HE", "leak": 0.1, "port": "PHE", "look": "lhe"}
			d.fluids.volumes["he_l"] = {"fluid": "coolant", "amount": 0.01, "full": 0.01, "nets": ["he"], "leak": 0.3, "look": "lhe"}
			d["supercon"] = {"coils": {"TC-1": {"fix": ["TC-S"], "line": "he-1", "next": []}}, "dump": "DUMP", "tau": 6.0, "plant": "CB",
				"he": "lhe", "he_min": 0.03, "T0": 4.5, "Tc": 9.0, "warm": 0.5, "cool": 0.5, "safe": 0.05, "reach": 3.0, "boil": 0.25}
			d["flywheel"] = {"wheels": {"FW-1": {"rpm": 3000.0, "brake": "BR-1", "cool": "CV-1", "caliper": "BRK-1", "near": ["BRK-1", "FWP"]}},
				"safe": 300.0, "decel": 250.0, "burn": 8.0}
			d.procedures = {
				"TC-1": [
					{"do": "operate", "ctrl": "DUMP"},
					{"do": "wait", "until": {"mod": ["magnets", "field", "<", 4.0]}, "max": 60.0},
					{"do": "free", "piece": "TC-1"},
					{"do": "deliver", "piece": "TC-1", "zone": "equip"},
				],
				"FW-1": [
					{"do": "operate", "ctrl": "CV-1"},
					{"do": "operate", "ctrl": "BR-1"},
					{"do": "wait", "until": {"mod": ["flywheel", "max_rpm", "<", 250.0]}, "max": 60.0},
					{"do": "free", "piece": "FW-1"},
					{"do": "deliver", "piece": "FW-1", "zone": "equip"},
				],
			}
		"cryo":
			d.value = {"total": 240000.0, "metal": 3000.0}
			d.gas = {"rooms": {}, "vessels": {"MIX": {"V": 0.02, "kpa": 80.0}}, "valves": [], "value": 4000.0}
			d.fluids.volumes["t1"] = {"fluid": "coolant", "amount": 0.3, "full": 0.4, "nets": ["t1"], "piece": "TK-1", "leak": 0.3, "port": "PT-1", "look": "lh2", "pump": [0.03, 0.03]}
			d["boiloff"] = {"tanks": {"TK-1": {"vol": "t1", "valve": "RV-1", "line": "cr1", "rate": 4.0, "frozen": true, "heater": "RVH-1", "look": "lh2", "centre": [18.9, 1.0], "shell": ["TK-1"]}},
				"plant": ["CRY-1"], "P0": 420.0, "floor": 300.0, "relief": 600.0, "reseat": 560.0, "burst": 700.0, "cool": 2.0, "draw": 6.0, "vent": 0.004, "thaw": 6.0, "reach": 3.0, "radius": 1.2}
			d["dilution"] = {"stages": {"STG-50K": 50.0, "STG-4K": 4.0, "STG-MXC": 0.012}, "order": ["STG-50K", "STG-4K", "STG-MXC"], "chip": "QPU",
				"pt": "PT", "compressor": "PTC", "circ": "CIRC", "heater": "HEAT", "mix": "MIX", "mix_safe": 20.0, "warm": 1.0, "heat_k": 4.0,
				"shock_T": 30.0, "brittle_T": 250.0, "isolation": {"lock": "VI-LOCK", "radius": 4.0, "knock": 0.25}}
			d.procedures = {
				"TK-1": [
					{"do": "operate", "ctrl": "RVH-1"},
					{"do": "hose", "ctrl": "PT-1"},
					{"do": "wait", "until": {"fluid": ["t1", "<", 0.02]}, "max": 90.0},
					{"do": "free", "piece": "TK-1"},
					{"do": "deliver", "piece": "TK-1", "zone": "equip"},
				],
				"QPU": [
					{"do": "operate", "ctrl": "CIRC"},
					{"do": "hose", "ctrl": "MIXP"},
					{"do": "wait", "until": {"P": ["MIX", "<", 15.0]}, "max": 60.0},
					{"do": "operate", "ctrl": "PT"},
					{"do": "wait", "until": {"stage": ["STG-MXC", ">", 35.0]}, "max": 90.0},
					{"do": "operate", "ctrl": "HEAT"},
					{"do": "wait", "until": {"stage": ["STG-MXC", ">", 255.0]}, "max": 90.0},
					{"do": "operate", "ctrl": "VI-LOCK"},
					{"do": "free", "piece": "QPU"},
					{"do": "deliver", "piece": "QPU", "zone": "equip"},
				],
			}
		"fluid":
			d.value = {"total": 127000.0, "metal": 3000.0}
			d.fluids.volumes["mud"] = {"fluid": "water", "look": "mud", "amount": 0.3, "full": 0.4, "nets": ["mud"], "piece": "STP", "port": "PMUD", "leak": 0.3, "pump": [0.04, 0.02]}
			d.fluids.volumes["t1"] = {"fluid": "fuel", "amount": 0.3, "full": 0.4, "piece": "T-1", "leak": 0.2, "hazard": 0.01}
			d.fluids.volumes["t2"] = {"fluid": "fuel", "amount": 0.12, "full": 0.4, "piece": "T-2", "leak": 0.2, "hazard": 0.01}
			d.fluids.volumes["xm"] = {"fluid": "fuel", "amount": 0.0, "full": 0.05, "nets": ["xm"], "port": "PR", "leak": 0.3, "pump": [0.1, 0.005]}
			d.fluids.value = {"coolant": 50.0, "water": 20.0, "fuel": 60.0}
			d.gas = {"rooms": {}, "vessels": {"TU-1": {"V": 0.2, "kpa": 300.0}, "TU-2": {"V": 0.2, "kpa": 300.0}, "NB": {"V": 0.1, "kpa": 1500.0}},
				"valves": [{"ctrl": "PV-1", "a": "NB", "b": "TU-1", "g": 5.0}, {"ctrl": "PV-2", "a": "NB", "b": "TU-2", "g": 5.0}], "value": 600.0}
			d["drillstring"] = {"stands": ["J-1", "J-2", "BHA"], "slips": ["SLIP-1", "SLIP-2"], "bleed": "TQB", "tau": 5.0, "mud": "mud", "mud_safe": 0.05,
				"kpa": 3200.0, "floor": [16.5, -6.0, 21.2, 1.8], "whip": 0.4, "spray": 0.6, "reach": 4.0}
			d["tanknet"] = {"tanks": {"T-1": {"vol": "t1", "valve": "XV-1", "cap": 0.4, "ullage": "TU-1", "pv": "PV-1"}, "T-2": {"vol": "t2", "valve": "XV-2", "cap": 0.4, "ullage": "TU-2", "pv": "PV-2"}},
				"manifold": "xm", "mcap": 0.05, "pump": "PUMP-M", "port": "PR", "flow": 0.5, "hold": ["TV-1", "TV-2"], "bank": "NB"}
			d.procedures = {
				"J-1": [
					{"do": "operate", "ctrl": "TQB"},
					{"do": "wait", "until": {"mod": ["drillstring", "torque_pct", "<", 4.0]}, "max": 60.0},
					{"do": "hose", "ctrl": "PMUD"},
					{"do": "wait", "until": {"fluid": ["mud", "<", 0.01]}, "max": 60.0},
					{"do": "operate", "ctrl": "SLIP-1"},
					{"do": "operate", "ctrl": "SLIP-2"},
					{"do": "free", "piece": "J-1"},
					{"do": "deliver", "piece": "J-1", "zone": "equip"},
				],
				"T-1": [
					{"do": "operate", "ctrl": "XV-1"},
					{"do": "operate", "ctrl": "XV-2"},
					{"do": "hose", "ctrl": "PR"},
					{"do": "wait", "until": {"mod": ["tanknet", "fuel_left", "<", 0.015]}, "max": 120.0},
					{"do": "free", "piece": "T-1"},
					{"do": "deliver", "piece": "T-1", "zone": "equip"},
				],
			}
		"atmos":
			d.value = {"total": 70000.0, "metal": 3000.0}
			d.room_names = {"OX": "room_sp_ox", "AV": "room_sp_av"}
			d.gas = {"rooms": {"OX": 100.0, "AV": 100.0}, "vessels": {}, "valves": [], "value": 800.0}
			d.fluids.volumes["loop"] = {"fluid": "coolant", "amount": 0.2, "full": 0.2, "nets": ["loop"], "leak": 0.3, "port": "PL", "pump": [0.04, 0.02]}
			d["atmos"] = {"o2": {"OX": 0.45}, "glass": []}
			d["composite"] = {"prefixes": ["HC"], "fume": 1.0, "rate": 0.05, "floor": 0.55, "electronics": ["console", "nav", "nav_rack", "panel", "swb"], "fog": {}, "fog_at": 1.5}
			d["furnace"] = {"T0": 760.0, "cool": 20.0, "core": "CORE", "crit": 350.0, "idle": 0.1, "loop": "loop", "loop_min": 0.6, "pumps": ["HX-1"], "safe": 150.0}
			d.procedures = {
				"OX-T": [
					{"do": "hose", "ctrl": "G-OX"},
					{"do": "wait", "until": {"P": ["OX", "<", 5.0]}, "max": 90.0},
				],
				"HC-1": [
					{"do": "hose", "ctrl": "G-AV"},
					{"do": "wait", "until": {"P": ["AV", "<", 5.0]}, "max": 90.0},
					{"do": "free", "piece": "HC-1"},
					{"do": "deliver", "piece": "HC-1", "zone": "metal"},
				],
				"CORE": [
					{"do": "wait", "until": {"mod": ["furnace", "core_temp", "<", 140.0]}, "max": 90.0},
					{"do": "hose", "ctrl": "PL"},
					{"do": "wait", "until": {"fluid": ["loop", "<", 0.01]}, "max": 60.0},
					{"do": "free", "piece": "CORE"},
					{"do": "deliver", "piece": "CORE", "zone": "equip"},
				],
			}
		"load":
			d.value = {"total": 36000.0, "metal": 3000.0}
			d.gas = {"rooms": {}, "vessels": {"ACC": {"V": 0.02, "kpa": 300.0}}, "valves": [], "value": 100.0}
			d["preloads"] = {"PIV-1": {"pins": ["PIN-1", "PIN-2"], "vessel": "ACC", "kpa": 30.0, "piece": "ARM-1", "push": [0.8, -0.6], "kn": 40.0}}
			d["rails"] = {"R": {"lock": "LK-1", "boxes": ["BOX-1"], "rails": ["RL-1"], "out": [1.5, 0.0], "doors": ["GATE"]}}
			d.procedures = {
				"ARM-1": [
					{"do": "hose", "ctrl": "G-ACC"},
					{"do": "wait", "until": {"P": ["ACC", "<", 20.0]}, "max": 60.0},
					{"do": "free", "piece": "ARM-1"},
					{"do": "deliver", "piece": "ARM-1", "zone": "equip"},
				],
				"BOX-1": [
					{"do": "operate", "ctrl": "GATE"},
					{"do": "operate", "ctrl": "LK-1"},
					{"do": "wait", "until": {}, "max": 4.0},
					{"do": "deliver", "piece": "BOX-1", "zone": "equip"},
				],
			}
		"precise":
			d.value = {"total": 171000.0, "metal": 3000.0}
			d.room_names = {"O": "room_sp_obs"}
			d.gas = {"rooms": {"O": 60.0}, "vessels": {}, "valves": [], "value": 300.0}
			d["optics"] = {"segments": {"PM-1": {"ring": 1, "half": "U", "act": "PA-1"}, "PM-2": {"ring": 2, "half": "U", "act": "PA-2"}},
				"locks": {"1": "LK-1", "2": "LK-2"}, "mcc": "MCC", "radius": 4.0, "dust": 0.08, "dust_min": 0.35,
				"cover": {"roller": "ROLL", "switch": "CVR", "len": 3.9, "time": 3.0}}
			d["liner"] = {"pods": {}, "glazing": {"room": "O", "panes": ["OBS-1"], "kpa": 20.0}}
			d.procedures = {
				# (INS is welded on: the course has the laser free it, with the cover down)
				"PM-2": [
					{"do": "operate", "ctrl": "LK-1"},
					{"do": "operate", "ctrl": "LK-2"},
					{"do": "free", "piece": "PM-2"},
					{"do": "deliver", "piece": "PM-2", "zone": "equip"},
				],
				"OBS-1": [
					{"do": "hose", "ctrl": "G-O"},
					{"do": "wait", "until": {"P": ["O", "<", 5.0]}, "max": 60.0},
					{"do": "free", "piece": "OBS-1"},
					{"do": "deliver", "piece": "OBS-1", "zone": "equip"},
				],
			}
		"isolate":
			d.value = {"total": 76500.0, "metal": 3000.0, "bonus": 30000.0}
			d.power.isolated = [{"piece": "LB", "switch": "K-LB", "volts": 220.0, "charge": 0.95}]
			d["nested"] = {"pieces": ["SS-H1", "SS-H2", "SS-N", "SS-T", "SS-BAT", "SS-ENG"], "hull": ["SS-H1", "SS-H2", "SS-N", "SS-T"], "room": "",
				"battery": "SK", "fuel": "", "locks": ["CL-1", "CL-2"], "door": "BOW", "door_ctrl": "BOW", "winch": "WINCH", "winch_piece": "WCH",
				"bonus": 30000.0, "lurch_keep": 0.5, "lurch_dent": 0.5, "exit": [6.0, 0.0], "time": 5.0, "hold": ""}
			d["vaults"] = {"VD-1": {"locks": ["LS-1"], "release": "MR-1"}}
			d.procedures = {
				"SS-ENG": [
					{"do": "operate", "ctrl": "SK"},
					{"do": "operate", "ctrl": "CL-1"},
					{"do": "operate", "ctrl": "CL-2"},
					{"do": "operate", "ctrl": "BOW"},
					{"do": "operate", "ctrl": "WINCH"},
					{"do": "wait", "until": {"mod": ["nested", "is_out", ">", 0.5]}, "max": 10.0},
				],
				"SDB-1": [
					{"do": "operate", "ctrl": "K-B"},
					{"do": "operate", "ctrl": "K-LB"},
					{"do": "operate", "ctrl": "MR-1"},
					{"do": "operate", "ctrl": "VD-1"},
					{"do": "free", "piece": "SDB-1"},
					{"do": "deliver", "piece": "SDB-1", "zone": "equip"},
				],
			}
	return d


static func _cls_zh() -> String:
	return {"energy": "储能", "cryo": "低温", "fluid": "流体压力", "atmos": "气氛、火与污染", "load": "受力与运动", "precise": "精密件", "isolate": "隔离与取出"}.get(variant, variant)
