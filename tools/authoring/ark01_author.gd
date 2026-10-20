class_name Ark01Author
# Authoring script for ARK-01 "Voyager", a ~600 m colony ship
# (design/ships/ARK-01_远航者_设计稿.md v2 and ARK-01_结构图.png, as drawn). Not part
# of the game: tools/ship_export.gd runs it and writes ships/ark01.json.
# Metres, x bow (0) to the nozzles (~608), y down; the spine's axis is y = 0.
#
#   ① the command section 0-50 m: three decks (bridge, data centre, comms and crew),
#      two docking collars below, the long-range dishes on masts above
#   ③ the spine 50-488 m: a pressure tube in twelve segments L1-L12 (bulkheads with
#      doors between), three levels each (the main power trunk above, the maintenance
#      way in the middle, the water and air mains below), and outside it the two
#      chord trusses that carry the tail
#   ② ring A (hub 76-94 m, rim 68-102 m, radius 105) and ④ ring B / farm (hub
#      182-204, rim 168-218, radius 110): each hub rides on the chords on bearing
#      rollers, a transfer airlock up and down into it from the spine; spokes out to
#      the rim modules, three decks each with their floors outward (the top module's
#      furniture stands on its outer wall)
#   ⑤ industry 240-360 m: the workshop hall above the spine (spares racks, six repair
#      bays, engineering), the hangar below (two S-09 shuttles, five work vehicles)
#   ⑥ the power core 385-475 m: the shut-down main reactor above the spine behind its
#      shield, the turbines, the secondary reactor and the distribution centre below,
#      the two great radiator wings
#   ⑦ the tail 488-608 m: keel, the fixing rails, eight propellant spheres, the thrust
#      plate and five engines
# What it asks of you: scripts/rings.gd (both rings still turning: their loads off,
# despun together, the bearings locked before the transfer airlocks open),
# scripts/spine.gd (the tail's weight on the chords: take the weight off before the
# chords), scripts/workday.gd (a job of ten working days), the reactor's dose behind
# its shield (scripts/reactor.gd), the propellant cross-connection (tanknet.gd), the
# cold store (coldchain.gd), the greenhouse glass (liner.gd), five supplies that are
# not quite isolated from each other (the slip rings are breakers).

const K = preload("res://tools/authoring/kit.gd")
const T := 0.6
const SB := [50.0, 86.5, 123.0, 159.5, 196.0, 232.5, 269.0, 305.5, 342.0, 378.5, 415.0, 451.5, 488.0]
const HULL := [Vector2(0, -4), Vector2(6, -12), Vector2(50, -12), Vector2(50, -6), Vector2(488, -6), Vector2(488, 6),
	Vector2(50, 6), Vector2(50, 12), Vector2(6, 12), Vector2(0, 4)]
# the transfer airlocks between the spine and what sits on it: [name, inner x0, x1]
const TAS := [["A", 84.2, 85.8], ["B", 197.2, 198.8], ["I", 270.2, 271.8], ["P", 416.2, 417.8]]
const SPOKES := {"A": [[84.1, 85.9]], "B": [[185.1, 186.9], [199.1, 200.9]]}
const HUBS := {"A": [76.0, 94.0, 17.0], "B": [182.0, 204.0, 18.0]}
const RIMS := {"A": [68.0, 102.0, 96.0, 114.0, -108.0, -102.0], "B": [168.0, 218.0, 100.0, 122.0, -115.0, -108.0]}
const CHORD := [7.4, 8.4]        # |y| of a chord truss: inner face, outer face
const HALL := 9.6                # |y| where the halls on the spine begin
const FLOORK := ["hull", "deck", "beam", "strut", "fixture"]

static var w
static var by_tag := {}
static var n_auto := 0


static func build(world) -> void:
	K.begin(world, "ARK01")
	w = world
	by_tag = K.by_tag
	n_auto = 0
	_hull()
	_bulkheads()
	_decks()
	_chords()
	_hubs()
	_rims()
	_ind()
	_pwr()
	_airlocks()
	_spokes()
	_wings()
	_tail()
	_bridge_fit()
	_spine_fit()
	_hub_fit()
	_spoke_fit()
	_ring_a_fit()
	_ring_b_fit()
	_ind_fit()
	_pwr_fit()
	_tail_fit()
	_lines()
	_controls()
	_rooms()
	_breach()
	K.clamp(1, 42.0, 12.0, 11.7)
	K.clamp(2, 250.0, 36.0, 35.7)
	K.clamp(3, 398.0, 32.0, 31.7)
	_weigh()


static func rooms_only(world) -> void:
	K.begin(world, "ARK01")
	w = world
	_rooms()


# ---------------------------------------------------------------- helpers

static func _auto(prefix: String) -> String:
	n_auto += 1
	return "%s%d" % [prefix, n_auto]


static func _circle(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var out: Array = []
	for i in n:
		out.append(c + Vector2.from_angle(TAU * (i + 0.5) / n) * r)
	return K.mp(out)


# a closed outline as a ring of plates, t thick, each about `step` long; holes
# [[edge, s0, s1, opts]] (s along the edge from its start, m) become their own
# plate with those opts (a hatch, a pane...)
static func _shell(prefix: String, pts: Array, t: float, step: float, holes: Array, base: Dictionary) -> void:
	var splits := {}
	var specials := {}
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		var L := a.distance_to(b)
		var hs: Array = holes.filter(func(h): return int(h[0]) == i)
		hs.sort_custom(func(p, q): return float(p[1]) < float(q[1]))
		var cuts: Array = []
		for h in hs:
			cuts.append(float(h[1]))
			cuts.append(float(h[2]))
		var n := maxi(1, int(round(L / step)))
		for k in range(1, n):
			var s: float = L * k / n
			var ok := true
			for h in hs:
				if s > float(h[1]) - 0.9 and s < float(h[2]) + 0.9:
					ok = false
			if ok:
				cuts.append(s)
		cuts.sort()
		var fr: Array = []
		for s in cuts:
			if s > 0.05 and s < L - 0.05:
				fr.append(s / L)
		if not fr.is_empty():
			splits[i] = fr
		for h in hs:
			# the plate that starts at the hole: one past every cut before it
			var k := 1 if float(h[1]) > 0.05 else 0
			for s in cuts:
				if s < float(h[1]) - 0.01 and s > 0.05:
					k += 1
			specials["%d:%d" % [i, k]] = h[3]
	K.ring(pts, t, splits, specials, base, prefix)


# a rectangle's outline as _shell takes it (top, right, bottom, left)
static func _rect(x0: float, y0: float, x1: float, y1: float) -> Array:
	return [Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]


# where along a rectangle's edge a span of x (top/bottom) lies, as _shell's s
static func _top(x0: float, a: float, b: float) -> Array:
	return [a - x0, b - x0]


static func _bot(x1: float, a: float, b: float) -> Array:
	return [x1 - b, x1 - a]


static func _hatch(tag: String, open_dir: Vector2) -> Dictionary:
	return {"kind": "hatch", "door": true, "tag": tag, "open_dir": open_dir * Geom.M, "cut_speed": 200.0}


static func _glass(tag: String) -> Dictionary:
	return {"cls": "equip", "dest": "equip", "art": "glass", "mass": 0.3, "value": 3200.0, "fragile": 0.6, "density": 0.8, "cut_speed": 260.0, "name_key": "p_ark_glass", "tag": tag}


static func _weld(a, b, x: float, y: float) -> void:
	K.bolt(a, b, x, y, "weld")


static func _plate(tag: String, x0: float, y0: float, x1: float, y1: float, kind: String, opts: Dictionary):
	var o := {"density": 1.6, "barrier": false, "cut_speed": 160.0}
	o.merge(opts, true)
	return K.plate(tag if tag != "" else _auto("AS"), K.R(x0, y0, x1, y1), o, kind)


# The catalogue: what each kind of equipment is (art, t, $, fragile, name key, more)
const CAT := {
	"bed": ["bed", 0.12, 1800.0, 0.3, "p_ark_bed", {}],
	"locker": ["locker", 0.15, 900.0, 0.2, "p_ark_locker", {}],
	"desk": ["console", 0.1, 1400.0, 0.3, "p_ark_desk", {}],
	"chair": ["seat", 0.05, 600.0, 0.3, "p_ark_chair", {}],
	"shelf": ["cabinet", 0.08, 700.0, 0.2, "p_ark_shelf", {}],
	"effects": ["cargo", 0.05, 500.0, 0.3, "p_ark_effects", {}],
	"galley": ["module", 0.6, 9000.0, 0.4, "p_ark_galley", {}],
	"fridge": ["freezer", 0.3, 4000.0, 0.4, "p_ark_fridge", {}],
	"dispenser": ["water", 0.1, 1200.0, 0.3, "p_ark_dispenser", {}],
	"table": ["cabinet", 0.15, 800.0, 0.2, "p_ark_table", {}],
	"screen": ["screen", 0.05, 2500.0, 0.6, "p_ark_screen", {}],
	"study": ["console", 0.12, 3000.0, 0.4, "p_ark_study", {}],
	"medbed": ["op_table", 0.3, 16000.0, 0.5, "p_ark_medbed", {}],
	"medmon": ["monitor", 0.06, 9000.0, 0.6, "p_ark_medmon", {}],
	"medcab": ["cabinet", 0.15, 7000.0, 0.4, "p_ark_medcab", {}],
	"o2cab": ["o2cab", 0.2, 2500.0, 0.3, "p_ark_o2cab", {}],
	"airmach": ["env", 0.9, 22000.0, 0.4, "p_ark_airmach", {}],
	"pump": ["pump", 0.4, 5000.0, 0.3, "p_ark_pump", {}],
	"filter": ["filter", 0.2, 3000.0, 0.3, "p_ark_filter", {}],
	"o2tank": ["gastank", 0.8, 6000.0, 0.3, "p_ark_o2tank", {"hazard": "gas_tank"}],
	"n2tank": ["gastank", 0.8, 5000.0, 0.3, "p_ark_n2tank", {"hazard": "gas_tank"}],
	"ringdist": ["swb", 0.5, 9000.0, 0.4, "p_ark_ring_dist", {}],
	"ringbat": ["battery", 1.4, 14000.0, 0.4, "p_ark_ring_battery", {"hazard": "battery"}],
	"panel": ["panel", 0.1, 1500.0, 0.3, "p_ark_panel", {}],
	"tray": ["plants", 0.25, 2200.0, 0.5, "p_ark_plant_tray", {}],
	"growlamp": ["overhead", 0.05, 900.0, 0.4, "p_grow_lamp", {}],
	"irrpump": ["pump", 0.3, 4500.0, 0.3, "p_nutrient_pump", {}],
	"irrctl": ["panel", 0.08, 3500.0, 0.4, "p_ark_irr_ctrl", {}],
	"foodmod": ["module", 1.6, 26000.0, 0.4, "p_ark_food_module", {}],
	"process": ["cabinet", 0.4, 6000.0, 0.3, "p_ark_process", {}],
	"chiller": ["freezer", 0.7, 12000.0, 0.4, "p_ark_chiller", {}],
	"frozen": ["cargo", 0.4, 6500.0, 0.4, "p_ark_frozen_food", {}],
	"watertank": ["water", 1.2, 7000.0, 0.3, "p_ark_water_tank", {}],
	"waterpump": ["pump", 0.5, 6000.0, 0.3, "p_water_pump", {}],
	"lifesup": ["env", 1.0, 24000.0, 0.4, "p_life_support", {}],
	"backgen": ["gen", 2.4, 30000.0, 0.3, "p_ark_backup_gen", {}],
	"helm": ["console", 0.25, 12000.0, 0.5, "p_ark_helm", {}],
	"command": ["screen", 0.3, 34000.0, 0.6, "p_ark_command", {}],
	"navtable": ["nav", 0.3, 18000.0, 0.5, "p_ark_nav_table", {}],
	"overhead": ["overhead", 0.05, 2000.0, 0.4, "p_ark_overhead", {}],
	"rack": ["nav_rack", 0.5, 28000.0, 0.5, "p_data_rack", {}],
	"archive": ["vault", 0.8, 40000.0, 0.3, "p_data_archive", {}],
	"rackcool": ["env", 0.6, 9000.0, 0.4, "p_ark_rack_cooler", {}],
	"ups": ["battery", 1.0, 12000.0, 0.4, "p_ups", {"hazard": "battery"}],
	"dist": ["swb", 0.4, 6000.0, 0.4, "p_power_board", {}],
	"comms": ["nav_rack", 0.4, 22000.0, 0.5, "p_ark_comms", {}],
	"transmit": ["cabinet", 0.6, 26000.0, 0.4, "p_ark_transmitter", {}],
	"amp": ["aux", 0.3, 9000.0, 0.4, "p_ark_amp", {}],
	"dockctl": ["console", 0.2, 8000.0, 0.4, "p_ark_dock_ctrl", {}],
	"bunk": ["bunk", 0.2, 1500.0, 0.3, "p_crew_bunk", {}],
	"suit": ["suit", 0.1, 5000.0, 0.4, "p_ark_suit", {}],
	"vdr": ["blackbox", 0.2, 20000.0, 0.3, "p_voyage_recorder", {}],
	"localdist": ["swb", 0.5, 7000.0, 0.4, "p_ark_local_dist", {}],
	"lowdist": ["panel", 0.2, 3500.0, 0.3, "p_ark_low_dist", {}],
	"junction": ["panel", 0.08, 1200.0, 0.3, "p_junction", {}],
	"lift": ["lift", 1.2, 18000.0, 0.4, "p_lift_car", {}],
	"emerg": ["locker", 0.15, 2000.0, 0.3, "p_ark_emerg_locker", {}],
	"mainpump": ["pump", 0.6, 7000.0, 0.3, "p_ark_main_pump", {}],
	"valves": ["panel", 0.2, 3000.0, 0.3, "p_main_valves", {}],
	"l6bat": ["battery", 1.6, 16000.0, 0.4, "p_standby_battery", {"hazard": "battery"}],
	"airplant": ["env", 1.2, 20000.0, 0.4, "p_air_plant", {}],
	"watertreat": ["water", 1.0, 15000.0, 0.3, "p_water_treat", {}],
	"reel": ["reel", 0.6, 3500.0, 0.2, "p_ark_cable_reel", {}],
	"bench": ["cabinet", 0.4, 5000.0, 0.3, "p_workbench", {}],
	"drill": ["cabinet", 0.3, 4000.0, 0.3, "p_drill", {}],
	"toolwall": ["locker", 0.2, 3500.0, 0.3, "p_tool_wall", {}],
	"crate": ["cargo", 0.5, 3000.0, 0.3, "p_cargo_box", {}],
	"busbar": ["panel", 0.3, 4000.0, 0.3, "p_ark_busbar", {}],
	"roller": ["drum", 0.6, 7000.0, 0.3, "p_ark_roller", {}],
	"despin": ["brake", 1.2, 26000.0, 0.4, "p_ark_despin", {}],
	"brakectl": ["cabinet", 0.3, 9000.0, 0.4, "p_ark_brake_ctrl", {}],
	"bcap": ["cap", 0.8, 14000.0, 0.4, "p_ark_brake_cap", {"hazard": "cap"}],
	"slip": ["drum", 0.9, 30000.0, 0.4, "p_ark_slip_ring", {}],
	"seal": ["guard", 0.6, 18000.0, 0.4, "p_ark_rotary_seal", {}],
	"hubdist": ["swb", 0.5, 8000.0, 0.4, "p_ark_hub_dist", {}],
	"platform": ["lift", 0.8, 9000.0, 0.3, "p_ark_spoke_platform", {}],
	"bcool": ["pump", 0.5, 6000.0, 0.3, "p_brake_cooler", {}],
	"sensor": ["panel", 0.05, 1500.0, 0.4, "p_pos_sensor", {}],
	"spokelift": ["lift", 0.9, 14000.0, 0.4, "p_ark_spoke_lift", {}],
	"sparebox": ["cargo", 1.2, 9000.0, 0.3, "p_ark_spares_box", {}],
	"arm": ["arm", 1.4, 32000.0, 0.4, "p_ark_repair_arm", {}],
	"material": ["cabinet", 0.4, 3500.0, 0.2, "p_ark_material", {}],
	"engcon": ["console", 0.3, 14000.0, 0.5, "p_ark_eng_console", {}],
	"lathe": ["cabinet", 1.8, 22000.0, 0.3, "p_lathe", {}],
	"weldgas": ["gastank", 0.3, 1500.0, 0.3, "p_weld_gas", {"hazard": "gas_tank"}],
	"cockpit": ["console", 0.3, 20000.0, 0.5, "p_cockpit_console", {}],
	"shengine": ["eng_core", 1.5, 40000.0, 0.3, "p_ark_shuttle_engine", {}],
	"shfuel": ["fueltank", 0.9, 6000.0, 0.3, "p_ark_shuttle_fuel", {"hazard": "fuel_tank"}],
	"shbat": ["battery", 0.7, 8000.0, 0.4, "p_ark_shuttle_battery", {"hazard": "battery"}],
	"shavionics": ["nav", 0.2, 16000.0, 0.5, "p_ark_shuttle_avionics", {}],
	"vehicle": ["module", 1.8, 22000.0, 0.3, "p_ark_vehicle", {}],
	"charger": ["panel", 0.3, 4000.0, 0.3, "p_ark_charger", {}],
	"hoist": ["hook", 0.4, 6000.0, 0.3, "p_ark_hoist", {}],
	"core": ["reactor", 2.9, 220000.0, 0.2, "p_reactor_core", {"hazard": "rad"}],
	"vessel": ["armor", 2.2, 30000.0, 0.2, "p_ark_vessel", {}],
	"crd": ["drum", 0.8, 24000.0, 0.3, "p_ark_crd", {}],
	"pcp": ["pump", 2.0, 45000.0, 0.3, "p_core_pump", {}],
	"hx": ["module", 2.6, 50000.0, 0.3, "p_heat_exchanger", {}],
	"przr": ["gastank", 1.2, 15000.0, 0.3, "p_ark_pressurizer", {"hazard": "gas_tank"}],
	"shield": ["armor", 2.8, 12000.0, 0.1, "p_rad_shield", {}],
	"rcon": ["console", 0.4, 30000.0, 0.5, "p_ark_reactor_console", {}],
	"rodpanel": ["panel", 0.15, 6000.0, 0.4, "p_ark_rod_panel", {}],
	"dosemon": ["monitor", 0.06, 4000.0, 0.5, "p_dose_probe", {}],
	"turbine": ["gen", 2.8, 70000.0, 0.3, "p_ark_turbine", {}],
	"generator": ["gen", 2.6, 60000.0, 0.3, "p_generator", {}],
	"secreact": ["reactor", 2.4, 120000.0, 0.2, "p_ark_secondary_reactor", {}],
	"switchgear": ["swb", 0.9, 20000.0, 0.4, "p_ark_switchgear", {}],
	"dcmain": ["swb", 1.2, 30000.0, 0.4, "p_ark_dc_main", {}],
	"dccap": ["cap", 1.2, 25000.0, 0.4, "p_cap_bank", {"hazard": "cap"}],
	"auxbat": ["battery", 2.6, 35000.0, 0.4, "p_ark_aux_battery", {"hazard": "battery"}],
	"dccon": ["console", 0.4, 18000.0, 0.5, "p_ark_dc_console", {}],
	"tcc": ["cabinet", 0.5, 14000.0, 0.4, "p_ark_turbine_ctrl", {}],
	"prop": ["sphere_tank", 2.8, 30000.0, 0.3, "p_prop_tank", {}],
	"tailpump": ["pump", 1.2, 20000.0, 0.3, "p_main_pump", {}],
	"manifold": ["module", 1.4, 18000.0, 0.3, "p_cross_manifold", {}],
	"engine": ["eng_core", 2.9, 90000.0, 0.3, "p_engine", {}],
	"nozzle": ["nozzle", 2.2, 30000.0, 0.3, "p_thrust_chamber", {}],
	"rcs": ["rcs_quad", 0.3, 9000.0, 0.3, "p_rcs", {}],
	"dish": ["radar", 2.6, 60000.0, 0.4, "p_ark_main_dish", {}],
	"subdish": ["radar", 0.8, 18000.0, 0.4, "p_ark_sub_dish", {}],
	"dock": ["dock", 1.6, 14000.0, 0.3, "p_dock_ring", {}],
	"xfmr": ["swb", 0.9, 9000.0, 0.3, "p_ark_transformer", {}],
	"relay": ["nav_rack", 0.15, 6000.0, 0.5, "p_ark_comm_relay", {}],
	"firebottle": ["gastank", 0.15, 1200.0, 0.3, "p_ark_fire_bottle", {"hazard": "gas_tank"}],
	"emlight": ["battery", 0.08, 1500.0, 0.4, "p_ark_emerg_light", {"hazard": "battery"}],
	"sensornode": ["nav", 0.12, 7000.0, 0.5, "p_ark_sensor_node", {}],
	"robotdock": ["uav", 0.4, 15000.0, 0.4, "p_ark_maint_robot", {}],
	"callpanel": ["panel", 0.05, 1200.0, 0.4, "p_ark_lift_call", {}],
	"ductfan": ["pump", 0.35, 4500.0, 0.3, "p_ark_duct_fan", {}],
	"trap": ["filter", 0.12, 1600.0, 0.3, "p_ark_condensate_trap", {}],
	"hxsmall": ["module", 0.6, 8000.0, 0.3, "p_heat_exchanger", {}],
	"ecctank": ["water", 1.6, 9000.0, 0.3, "p_ark_ecc_tank", {}],
	"rodstore": ["vault", 1.8, 16000.0, 0.2, "p_ark_rod_store", {}],
	"cranebeam": ["grating", 0.6, 0.0, 0.2, "p_crane_rail", {"cls": "metal", "dest": "metal"}],
	"lubeskid": ["pump", 1.4, 14000.0, 0.3, "p_ark_lube_skid", {}],
	"oiltank": ["fueltank", 1.0, 3000.0, 0.3, "p_ark_lube_tank", {"hazard": "fuel_tank"}],
	"condenser": ["module", 2.4, 38000.0, 0.3, "p_ark_condenser", {}],
	"fwpump": ["pump", 1.1, 16000.0, 0.3, "p_ark_feed_pump", {}],
	"dosing": ["cabinet", 0.4, 7000.0, 0.3, "p_ark_chem_dosing", {}],
	"decon": ["filter", 0.5, 8000.0, 0.3, "p_decon", {}],
	"toolcart": ["module", 0.4, 6000.0, 0.3, "p_tool_cart", {}],
	"fuelcart": ["fueltank", 0.9, 5000.0, 0.3, "p_ark_fuel_cart", {"hazard": "fuel_tank"}],
	"batcart": ["battery", 0.8, 7000.0, 0.4, "p_ark_battery_cart", {"hazard": "battery"}],
	"partsrack": ["cabinet", 0.5, 8000.0, 0.3, "p_parts_rack", {}],
	"stand": ["ladder", 0.3, 0.0, 0.2, "p_ark_work_stand", {"cls": "metal", "dest": "metal"}],
	"n2cart": ["gastank", 0.4, 2000.0, 0.3, "p_ark_n2_cart", {"hazard": "gas_tank"}],
	"lamp": ["lamp", 0.04, 0.0, 0.3, "p_lamp", {"cls": "metal", "dest": "metal", "cut_speed": 260.0}],
	"ladder": ["ladder", 0.1, 0.0, 0.2, "p_stairs", {"cls": "metal", "dest": "metal"}],
	"post": ["grating", 0.2, 0.0, 0.2, "p_ark_rack_post", {"cls": "metal", "dest": "metal"}],
}


# a piece of the catalogue at a rectangle
static func E(tag: String, kind: String, x0: float, y0: float, x1: float, y1: float, room: String, more: Dictionary = {}):
	var c: Array = CAT[kind]
	var o := {"mass": c[1], "value": c[2], "fragile": c[3], "name_key": c[4], "room": room}
	o.merge(c[5], true)
	o.merge(more, true)
	if tag == "":
		tag = _auto(kind.to_upper().left(4) + "-")
	return K.equip(tag, c[0], K.rect(x0, y0, x1, y1), o)


# a row of equipment along a floor (or a ceiling: up the other way), left to right
# from x0; items [tag, kind, width, height, {more}] (a width alone in an item is a gap).
# up -1: the floor is below (y grows down), +1: a top ring module's (floors outward).
# keep: [[x0, x1], ...] the row must leave clear (hatches). Returns the pieces.
static func _row(room: String, floor_y: float, up: float, x0: float, x1: float, items: Array, keep: Array = []) -> Array:
	var out: Array = []
	var x := x0
	for it in items:
		if it is float or it is int:
			x += float(it)
			continue
		var wd: float = it[2]
		var h: float = it[3]
		for kp in keep:
			if x < float(kp[1]) + 0.2 and x + wd > float(kp[0]) - 0.2:
				x = float(kp[1]) + 0.25
		if x + wd > x1 + 0.001:
			push_warning("ARK01 row %s: %s does not fit (%.1f + %.1f > %.1f)" % [room, it[0], x, wd, x1])
			continue
		var y_a: float = floor_y + up * 0.05
		var y_b: float = floor_y + up * (0.05 + h)
		var more: Dictionary = it[4] if it.size() > 4 else {}
		var p = E(it[0], it[1], x, minf(y_a, y_b), x + wd, maxf(y_a, y_b), room, more)
		for bx in [x + minf(0.3, wd * 0.25), x + wd - minf(0.3, wd * 0.25)]:
			K.bolt(p, K.at(bx, floor_y - up * 0.15, FLOORK), bx, floor_y)
		out.append(p)
		x += wd + float(more.get("gap", 0.35))
	return out


# a lamp under a ceiling at y (up as for _row: the ceiling is on the other side)
static func _lamp(tag: String, x: float, ceil_y: float, up: float, room: String) -> void:
	var ya := ceil_y - up * 0.05
	var yb := ceil_y - up * 0.21
	var l = E(tag, "lamp", x - 0.28, minf(ya, yb), x + 0.28, maxf(ya, yb), room)
	K.bolt(l, K.at(x, ceil_y + up * 0.15, FLOORK), x, ceil_y)


# ---------------------------------------------------------------- the hull: command section and spine

static func _hull() -> void:
	var holes: Array = []
	# the bow windows over the bridge
	holes.append([0, 2.0, 5.0, _glass("WIN-1")])
	holes.append([0, 6.0, 9.0, _glass("WIN-2")])
	# the transfer airlocks' hatches in the spine's top and bottom
	for ta in TAS:
		holes.append([3, ta[1] - 50.0, ta[2] - 50.0, _hatch("HT-T%sU" % ta[0], Vector2(1.8, 0))])
		holes.append([5, 488.0 - ta[2], 488.0 - ta[1], _hatch("HT-T%sL" % ta[0], Vector2(1.8, 0))])
	# the docking collars' hatches in the command section's floor
	holes.append([7, 50.0 - 16.8, 50.0 - 15.2, _hatch("HT-DK1", Vector2(1.8, 0))])
	holes.append([7, 50.0 - 34.8, 50.0 - 33.2, _hatch("HT-DK2", Vector2(1.8, 0))])
	_shell("HS", HULL, T, 6.0, holes, {"density": 1.6, "barrier": true, "cut_speed": 210.0, "name_key": "p_ark_hull"})
	# the windows sit in glazing bars: the wrench undoes them
	for t in ["WIN-1", "WIN-2"]:
		for j in w.joints_of(by_tag[t]):
			j.type = "bolt"


# the bulkheads across the spine: L-k's forward wall, a door in its middle level
static func _bulkheads() -> void:
	var B := {"density": 1.5, "barrier": true, "cut_speed": 200.0, "name_key": "p_ark_bulkhead"}
	for k in 12:
		var x: float = SB[k]
		var u = _plate("BH%d-U" % k, x - 0.3, -5.4, x + 0.3, -1.7, "hull", B)
		var d = K.plate("D-%d" % k, K.R(x - 0.3, -1.7, x + 0.3, 1.7), {"density": 1.4, "barrier": true, "cut_speed": 190.0, "door": true,
			"open_dir": Vector2(0, -3.0) * Geom.M, "name_key": "p_ark_spine_door"}, "door")
		var l = _plate("BH%d-L" % k, x - 0.3, 1.7, x + 0.3, 5.4, "hull", B)
		_weld(u, K.at(x, -5.7, ["hull"]), x, -5.4)
		_weld(l, K.at(x, 5.7, ["hull"]), x, 5.4)
		_weld(u, d, x, -1.7)
		_weld(l, d, x, 1.7)


# the spine's two decks a segment (and the command section's two), a well at one end of each
static func _decks() -> void:
	var D := {"density": 0.9, "barrier": false, "cut_speed": 230.0, "name_key": "p_deck"}
	for k in 12:
		var x0: float = SB[k] + 0.3
		var x1: float = SB[k + 1] - (0.3 if k < 11 else 0.6)
		for y in [-2.0, 1.7]:
			# the well alternates ends so the levels connect in a zigzag
			var fwd: bool = (k % 2 == 0) == (y < 0.0)
			var a := x0 + (2.6 if fwd else 0.0)
			var b := x1 - (0.0 if fwd else 2.6)
			var dk = _plate("DK%d%s" % [k + 1, "U" if y < 0.0 else "L"], a, y, b, y + 0.3, "deck", D)
			if fwd:
				_weld(dk, K.at(x1 + 0.15, y + 0.15, ["hull"]), x1, y + 0.15)
			else:
				_weld(dk, K.at(x0 - 0.15, y + 0.15, ["hull"]), x0, y + 0.15)
	# the command section: the bridge deck and the comms deck
	for y in [-4.15, 3.85]:
		var dk = _plate("DK0%s" % ("U" if y < 0.0 else "L"), 1.0, y, 46.9, y + 0.3, "deck", D)
		_weld(dk, K.at(0.35, y + 0.15, ["hull"]), 1.0, y + 0.15)


# the two chord trusses along the spine (what carries the tail), on posts off the tube;
# a segment's chord stops at the walls of a transfer airlock in it
const CHORDS := [[50.0, 83.6], [86.4, 123.0], [123.0, 159.5], [159.5, 196.6], [199.4, 232.5], [232.5, 269.6],
	[272.4, 305.5], [305.5, 342.0], [342.0, 378.5], [378.5, 415.6], [418.4, 451.5], [451.5, 488.0]]


static func _chords() -> void:
	var C := {"density": 2.2, "barrier": false, "cut_speed": 120.0}
	for side in [-1.0, 1.0]:
		var prev = null
		for k in 12:
			var a: float = CHORDS[k][0]
			var b: float = CHORDS[k][1]
			var y0: float = side * CHORD[0]
			var y1: float = side * CHORD[1]
			var ch = _plate("C%s-%d" % ["T" if side < 0.0 else "B", k + 1], a, minf(y0, y1), b, maxf(y0, y1), "beam",
				C.merged({"name_key": "p_top_chord" if side < 0.0 else "p_bottom_chord"}))
			if prev != null and absf(float(CHORDS[k - 1][1]) - a) < 0.05:
				_weld(prev, ch, a, side * 7.9)
			prev = ch
			# posts off the tube, two a segment
			for f in [0.22, 0.78]:
				var px: float = a + (b - a) * f
				var po = _plate("", px - 0.3, minf(side * 6.0, side * CHORD[0]), px + 0.3, maxf(side * 6.0, side * CHORD[0]), "strut", {"name_key": "p_post"})
				_weld(po, ch, px, side * CHORD[0])
				_weld(po, K.at(px, side * 5.7, ["hull"]), px, side * 6.0)


# ---------------------------------------------------------------- the ring hubs, airlocks, spokes, rims

static func _hubs() -> void:
	var H := {"density": 1.7, "barrier": true, "cut_speed": 190.0, "name_key": "p_ark_hub_shell"}
	for r in HUBS:
		var x0: float = HUBS[r][0]
		var x1: float = HUBS[r][1]
		var hy: float = HUBS[r][2]
		var ta: Array = TAS[0] if r == "A" else TAS[1]
		for side in ["U", "L"]:
			var holes: Array = []
			var i := 0
			for sp in SPOKES[r]:
				i += 1
				if side == "U":
					holes.append([0, sp[0] - x0, sp[1] - x0, _hatch("HT-S%sU%dH" % [r, i], Vector2(1.8, 0))])
				else:
					holes.append([2, x1 - sp[1], x1 - sp[0], _hatch("HT-S%sL%dH" % [r, i], Vector2(1.8, 0))])
			if side == "U":
				holes.append([2, x1 - ta[2], x1 - ta[1], _hatch("HT-T%sU2" % r, Vector2(1.8, 0))])
				_shell("HH%sU" % r, _rect(x0, -hy, x1, -HALL), T, 6.0, holes, H)
			else:
				holes.append([0, ta[1] - x0, ta[2] - x0, _hatch("HT-T%sL2" % r, Vector2(1.8, 0))])
				_shell("HH%sL" % r, _rect(x0, HALL, x1, hy), T, 6.0, holes, H)
		# the bearing rollers between the hub and the chords it rides on
		var xs: Array = [77.6, 80.6, 89.4, 92.4] if r == "A" else [183.8, 187.6, 191.4, 202.4]
		var n := 0
		for side in [-1.0, 1.0]:
			for x in xs:
				n += 1
				var c := Vector2(x, side * 9.0)
				var ro = K.equip("BR%s-%d" % [r, n], "drum", K.rect(x - 0.55, c.y - 0.55, x + 0.55, c.y + 0.55),
					{"mass": 0.6, "value": 7000.0, "fragile": 0.3, "name_key": "p_ark_roller"}, _circle(c, 0.55, 10))
				K.bolt(ro, K.at(x, side * 9.9, ["hull"]), x, side * 9.6)
				K.bolt(ro, K.at(x, side * 7.9, ["beam"]), x, side * 8.4)


# the transfer airlocks: a short pressure tube from the spine up (and down) into what
# sits on it, its two walls also where the chords end
static func _airlocks() -> void:
	var A := {"density": 1.8, "barrier": true, "cut_speed": 180.0, "name_key": "p_ark_airlock_wall"}
	for ta in TAS:
		var a: float = ta[1]
		var b: float = ta[2]
		for side in [-1.0, 1.0]:
			for wx in [[a - 0.6, a], [b, b + 0.6]]:
				var y0: float = side * 6.0
				var y1: float = side * HALL
				var wl = _plate("TW%s%s%d" % [ta[0], "U" if side < 0.0 else "L", 0 if wx[0] < a else 1], wx[0], minf(y0, y1), wx[1], maxf(y0, y1), "hull", A)
				var cx: float = (wx[0] + wx[1]) * 0.5
				# probed on the wall's far side from the hatch (the ring's plates are trapezoids)
				var px: float = wx[0] + 0.1 if wx[0] < a else wx[1] - 0.1
				_weld(wl, K.at(px, side * 5.7, ["hull"]), cx, side * 6.0)
				_weld(wl, K.at(px, side * 9.9, ["hull"]), cx, side * HALL)
				var chx: float = wx[0] if wx[0] < a else wx[1]
				var ch = K.at(chx + (-0.2 if wx[0] < a else 0.2), side * 7.9, ["beam"])
				if ch != null:
					_weld(wl, ch, chx, side * 7.9)


static func _spokes() -> void:
	var S := {"density": 1.4, "barrier": true, "cut_speed": 200.0, "name_key": "p_ark_spoke_wall"}
	for r in SPOKES:
		var hy: float = HUBS[r][2]
		var ry: float = RIMS[r][2]
		var i := 0
		for sp in SPOKES[r]:
			i += 1
			for side in [-1.0, 1.0]:
				var nm := "SP%s%s%d" % [r, "U" if side < 0.0 else "L", i]
				for wx in [[sp[0] - 0.6, sp[0]], [sp[1], sp[1] + 0.6]]:
					var n := maxi(1, int(round((ry - hy) / 10.0)))
					var prev = null
					var cx: float = (wx[0] + wx[1]) * 0.5
					var px: float = wx[0] + 0.1 if wx[0] < sp[0] else wx[1] - 0.1
					for k in n:
						var ya: float = hy + (ry - hy) * k / n
						var yb: float = hy + (ry - hy) * (k + 1) / n
						var pc = _plate("%s-%s%d" % [nm, "W" if wx[0] < sp[0] else "E", k], wx[0], minf(side * ya, side * yb), wx[1], maxf(side * ya, side * yb), "hull", S)
						if prev == null:
							_weld(pc, K.at(px, side * (hy - 0.3), ["hull"]), cx, side * hy)
						else:
							_weld(prev, pc, cx, side * ya)
						prev = pc
					_weld(prev, K.at(px, side * (ry + 0.3), ["hull"]), cx, side * ry)


const GLASS_B := [[173.5, 177.3], [181.1, 184.9], [188.7, 192.5], [196.3, 200.1], [203.9, 207.7]]


static func _rims() -> void:
	var R := {"density": 1.6, "barrier": true, "cut_speed": 200.0, "name_key": "p_ark_rim_hull"}
	var D := {"density": 0.9, "barrier": false, "cut_speed": 230.0, "name_key": "p_deck"}
	for r in RIMS:
		var x0: float = RIMS[r][0]
		var x1: float = RIMS[r][1]
		var ya: float = RIMS[r][2]
		var yb: float = RIMS[r][3]
		for side in ["U", "L"]:
			var holes: Array = []
			var i := 0
			for sp in SPOKES[r]:
				i += 1
				if side == "U":
					holes.append([2, x1 - sp[1], x1 - sp[0], _hatch("HT-S%sU%dR" % [r, i], Vector2(1.8, 0))])
				else:
					holes.append([0, sp[0] - x0, sp[1] - x0, _hatch("HT-S%sL%dR" % [r, i], Vector2(1.8, 0))])
			# ring B's greenhouses: glass in the outer wall between the rack columns
			if r == "B":
				var k := 0
				for g in GLASS_B:
					k += 1
					if side == "U":
						holes.append([0, g[0] - x0, g[1] - x0, _glass("GL-U%d" % k)])
					else:
						holes.append([2, x1 - g[1], x1 - g[0], _glass("GL-L%d" % k)])
			if side == "U":
				_shell("HR%sU" % r, _rect(x0, -yb, x1, -ya), T, 5.0, holes, R)
			else:
				_shell("HR%sL" % r, _rect(x0, ya, x1, yb), T, 5.0, holes, R)
			if r == "B":
				for k2 in GLASS_B.size():
					for j in w.joints_of(by_tag["GL-%s%d" % [side, k2 + 1]]):
						j.type = "bolt"
			# the two decks, a well at alternate ends
			var sg := -1.0 if side == "U" else 1.0
			var di := 0
			for d in [RIMS[r][4], RIMS[r][5]]:
				di += 1
				var dy: float = absf(d) * sg
				var left := di == 1
				var a := x0 + T + (0.0 if left else 2.6)
				var b := x1 - T - (2.6 if left else 0.0)
				var dk = _plate("DR%s%s%d" % [r, side, di], a, dy - 0.15, b, dy + 0.15, "deck", D)
				if left:
					_weld(dk, K.at(x0 + 0.3, dy, ["hull"]), x0 + T, dy)
				else:
					_weld(dk, K.at(x1 - 0.3, dy, ["hull"]), x1 - T, dy)


# ring A's breach: a plate of the top module's outer wall gone (it came in like that)
static func _breach() -> void:
	var p = K.at(91.0, -113.7, ["hull"])
	if p != null:
		w.remove_piece(p)


# ---------------------------------------------------------------- industry and power

static func _hall_posts(xs: Array) -> void:
	for side in [-1.0, 1.0]:
		for x in xs:
			var po = _plate("", x - 0.3, minf(side * CHORD[1], side * HALL), x + 0.3, maxf(side * CHORD[1], side * HALL), "strut", {"name_key": "p_post"})
			_weld(po, K.at(x, side * 7.9, ["beam"]), x, side * CHORD[1])
			_weld(po, K.at(x, side * 9.9, ["hull"]), x, side * HALL)


static func _ind() -> void:
	var H := {"density": 1.6, "barrier": true, "cut_speed": 200.0, "name_key": "p_ark_hall_hull"}
	var D := {"density": 0.9, "barrier": false, "cut_speed": 230.0, "name_key": "p_deck"}
	_shell("HIU", _rect(240.0, -42.0, 360.0, -HALL), T, 6.0, [[2, 360.0 - 271.8, 360.0 - 270.2, _hatch("HT-TIU2", Vector2(1.8, 0))]], H)
	_shell("HIL", _rect(240.0, HALL, 360.0, 36.0), T, 6.0, [
		[0, 270.2 - 240.0, 271.8 - 240.0, _hatch("HT-TIL2", Vector2(1.8, 0))],
		[2, 360.0 - 340.0, 360.0 - 300.0, {"kind": "door", "door": true, "tag": "HD-1", "open_dir": Vector2(0, 7.0) * Geom.M, "cut_speed": 170.0, "name_key": "p_ark_hangar_door"}],
	], H)
	for d in [[-31.6, true], [-20.8, false]]:
		var a: float = 240.6 + (0.0 if d[1] else 3.0)
		var b: float = 359.4 - (3.0 if d[1] else 0.0)
		var dk = _plate("DI%d" % (1 if d[1] else 2), a, d[0] - 0.15, b, d[0] + 0.15, "deck", D)
		_weld(dk, K.at(240.3 if d[1] else 359.7, d[0], ["hull"]), 240.6 if d[1] else 359.4, d[0])
	_hall_posts([246.0, 258.0, 284.0, 296.0, 318.0, 330.0, 346.0, 354.0])


static func _pwr() -> void:
	var H := {"density": 2.0, "barrier": true, "cut_speed": 170.0, "name_key": "p_ark_core_hull"}
	var D := {"density": 0.9, "barrier": false, "cut_speed": 230.0, "name_key": "p_deck"}
	_shell("HPU", _rect(385.0, -34.0, 475.0, -HALL), T, 6.0, [[2, 475.0 - 417.8, 475.0 - 416.2, _hatch("HT-TPU2", Vector2(1.8, 0))]], H)
	_shell("HPL", _rect(385.0, HALL, 475.0, 32.0), T, 6.0, [[0, 416.2 - 385.0, 417.8 - 385.0, _hatch("HT-TPL2", Vector2(1.8, 0))]], H)
	var g1 = _plate("DP1", 385.6, -22.15, 421.0, -21.85, "deck", D)
	_weld(g1, K.at(385.3, -22.0, ["hull"]), 385.6, -22.0)
	var g2 = _plate("DP2", 444.0, 20.85, 474.4, 21.15, "deck", D)
	_weld(g2, K.at(474.7, 21.0, ["hull"]), 474.4, 21.0)
	_hall_posts([390.0, 402.0, 425.0, 437.0, 449.0, 461.0, 470.0])


# the radiator wings off the power core, four rows of three panels each way, wider out
static func _wings() -> void:
	var P := {"density": 0.45, "barrier": false, "cut_speed": 240.0, "art": "radiator", "name_key": "p_radiator_fin"}
	for side in [-1.0, 1.0]:
		var nm := "U" if side < 0.0 else "L"
		var root_y: float = side * (34.0 if side < 0.0 else 32.0)
		var sp = _plate("WSP-%s" % nm, 396.0, minf(root_y, root_y + side * 1.2), 464.0, maxf(root_y, root_y + side * 1.2), "beam", {"density": 2.0, "name_key": "p_spar"})
		for x in [400.0, 430.0, 460.0]:
			_weld(sp, K.at(x, root_y - side * 0.3, ["hull"]), x, root_y)
		var y0: float = root_y + side * 1.2
		var prev_row: Array = []
		for r in 4:
			var ya: float = y0 + side * 19.5 * r
			var yb: float = y0 + side * 19.5 * (r + 1)
			var xa0: float = 396.0 - 2.5 * r
			var xa1: float = 464.0 + 2.5 * r
			var xb0: float = 396.0 - 2.5 * (r + 1)
			var xb1: float = 464.0 + 2.5 * (r + 1)
			var row: Array = []
			for c in 3:
				var q := K.mp([Vector2(lerpf(xa0, xa1, c / 3.0), ya), Vector2(lerpf(xa0, xa1, (c + 1) / 3.0), ya),
					Vector2(lerpf(xb0, xb1, (c + 1) / 3.0), yb), Vector2(lerpf(xb0, xb1, c / 3.0), yb)])
				var o: Dictionary = P.duplicate()
				o.tag = "RAD-%s%d%d" % [nm, r + 1, c + 1]
				var pn = K.plate(o.tag, q, o, "hull")
				var mx: float = lerpf(xa0, xa1, (c + 0.5) / 3.0)
				if r == 0:
					_weld(pn, sp, mx, ya)
				else:
					_weld(pn, prev_row[c], mx, ya)
				if c > 0:
					var bx: float = lerpf(lerpf(xa0, xa1, c / 3.0), lerpf(xb0, xb1, c / 3.0), 0.5)
					_weld(pn, row[c - 1], bx, (ya + yb) * 0.5)
				row.append(pn)
			prev_row = row


# ---------------------------------------------------------------- the tail

const TANK_X := [491.5, 513.5, 535.5, 557.5]
const ENG_Y := [-20.0, -10.0, 0.0, 10.0, 20.0]


static func _tail() -> void:
	var B := {"density": 2.2, "barrier": false, "cut_speed": 120.0}
	var kx := [488.0, 512.5, 537.0, 561.5, 586.0]
	var prev = null
	for i in 4:
		var kl = _plate("KL-%d" % (i + 1), kx[i], -2.0, kx[i + 1], 2.0, "beam", B.merged({"name_key": "p_keel"}))
		if prev == null:
			_weld(kl, K.at(487.7, 0.0, ["hull"]), 488.0, 0.0)
		else:
			_weld(prev, kl, kx[i], 0.0)
		prev = kl
	var thr = _plate("THR", 586.0, -30.0, 590.0, 30.0, "beam", B.merged({"name_key": "p_ark_thrust_plate", "density": 2.4}))
	_weld(thr, prev, 586.0, 0.0)
	# the fixing rails over and under the tanks, from the spine's aft corners to the thrust plate
	for side in [-1.0, 1.0]:
		var nm := "U" if side < 0.0 else "L"
		var po = _plate("FP-%s" % nm, 488.2, minf(side * 6.0, side * 27.4), 488.8, maxf(side * 6.0, side * 27.4), "beam", B.merged({"name_key": "p_ark_fixing_beam"}))
		_weld(po, K.at(487.7, side * 5.8, ["hull"]), 488.2, side * 6.0)
		var pr = po
		for i in 4:
			var xa: float = kx[i] + (0.8 if i == 0 else 0.0)
			var rl = _plate("FR-%s%d" % [nm, i + 1], xa, minf(side * 27.4, side * 28.6), kx[i + 1], maxf(side * 27.4, side * 28.6), "beam", B.merged({"name_key": "p_ark_fixing_beam"}))
			_weld(rl, pr, xa, side * 28.0)
			pr = rl
		_weld(pr, thr, 586.0, side * 28.0)
		# the tanks' posts off the keel (the tanks themselves are fitted with the tail's equipment)
		for i in 4:
			var cx: float = TANK_X[i] + 9.0
			var st = _plate("TP-%s%d" % [nm, i + 1], cx - 0.4, minf(side * 2.0, side * 8.4), cx + 0.4, maxf(side * 2.0, side * 8.4), "strut", {"name_key": "p_tank_hanger"})
			_weld(st, K.at(cx, side * 1.7, ["beam"]), cx, side * 2.0)


# ---------------------------------------------------------------- ① the command section

static func _bridge_fit() -> void:
	# the bridge: six stations facing the bow windows, the command terminal behind them
	var top: Array = []
	for i in 6:
		top.append(["HELM-%d" % (i + 1), "helm", 1.6, 1.3])
		top.append(["", "chair", 0.9, 1.3])
	top.append_array([["CAPT", "chair", 1.0, 1.4], ["CMD", "command", 3.0, 2.2, {"mandatory": true}], ["NAV-T", "navtable", 2.4, 1.1],
		["CHART", "screen", 1.4, 1.6], ["VDR", "vdr", 0.8, 0.6, {"mandatory": true}], ["", "suit", 0.8, 1.9], ["", "locker", 0.9, 1.9], ["", "o2cab", 0.8, 1.4]])
	_row("BR", -4.15, -1.0, 3.2, 46.6, top)
	_row("BR", -11.4, 1.0, 8.0, 46.0, [["", "overhead", 1.6, 0.5], 4.0, ["", "overhead", 1.6, 0.5], 4.0, ["", "overhead", 1.6, 0.5], 6.0, ["", "overhead", 1.6, 0.5]])
	_lamp("LAMP-BR1", 14.0, -11.4, -1.0, "BR")
	_lamp("LAMP-BR2", 34.0, -11.4, -1.0, "BR")
	# the data centre: the ship's records in eight racks and the archive
	var mid: Array = []
	for i in 8:
		mid.append(["DR-%d" % (i + 1), "rack", 1.4, 3.4])
	mid.append_array([["ARCH", "archive", 2.4, 3.0], ["", "rackcool", 2.0, 2.6], ["BAT-BR", "ups", 1.8, 2.0], ["BR-DIST", "dist", 1.4, 2.8], ["", "panel", 0.8, 1.0], ["", "effects", 0.6, 0.5]])
	_row("BR", 3.85, -1.0, 2.0, 46.6, mid)
	_row("BR", -3.85, 1.0, 4.0, 46.0, [["", "junction", 0.8, 0.5], 9.0, ["", "junction", 0.8, 0.5], 9.0, ["", "junction", 0.8, 0.5]])
	_lamp("LAMP-BR3", 12.0, -3.85, -1.0, "BR")
	_lamp("LAMP-BR4", 32.0, -3.85, -1.0, "BR")
	# comms and the crew's ready room over the docking collars
	_row("BR", 11.4, -1.0, 7.6, 49.0, [["COM-R", "comms", 1.4, 3.0], ["TX", "transmit", 1.6, 2.4], ["AMP", "amp", 1.2, 1.6], ["DKC-1", "dockctl", 1.6, 1.3],
		["", "bunk", 2.2, 1.6], ["", "bunk", 2.2, 1.6], ["", "locker", 0.9, 1.9], ["", "locker", 0.9, 1.9], ["", "suit", 0.8, 1.9], ["", "suit", 0.8, 1.9],
		["DKC-2", "dockctl", 1.6, 1.3], ["", "o2cab", 0.8, 1.4], ["", "effects", 0.6, 0.5], ["", "panel", 0.8, 1.0]], [[15.2, 16.8], [33.2, 34.8]])
	_lamp("LAMP-BR5", 24.0, 4.15, -1.0, "BR")
	# outside: the docking collars, the dishes on their masts, thrusters at the bow
	for d in [["DK-1", 16.0], ["DK-2", 34.0]]:
		var dk = E(d[0], "dock", d[1] - 1.6, 12.05, d[1] + 1.6, 13.45, "")
		K.bolt(dk, K.at(d[1] - 1.3, 11.8, ["hull"]), d[1] - 1.3, 12.0)
		K.bolt(dk, K.at(d[1] + 1.3, 11.8, ["hull"]), d[1] + 1.3, 12.0)
	var m1 = _plate("MAST-1", 29.7, -19.0, 30.3, -12.0, "strut", {"name_key": "p_array_mast"})
	_weld(m1, K.at(30.0, -11.7, ["hull"]), 30.0, -12.0)
	var dm = E("DISH-M", "dish", 25.0, -22.0, 35.0, -19.05, "")
	K.bolt(dm, m1, 29.85, -19.0)
	K.bolt(dm, m1, 30.15, -19.0)
	var m2 = _plate("MAST-2", 43.7, -16.0, 44.3, -12.0, "strut", {"name_key": "p_array_mast"})
	_weld(m2, K.at(44.0, -11.7, ["hull"]), 44.0, -12.0)
	var ds = E("DISH-S", "subdish", 42.0, -18.0, 46.0, -16.05, "")
	K.bolt(ds, m2, 43.85, -16.0)
	K.bolt(ds, m2, 44.15, -16.0)
	for r in [["RCS-5", -13.05, -12.05, -11.7, -12.0], ["RCS-6", 12.05, 13.05, 11.7, 12.0]]:
		var rc = E(r[0], "rcs", 9.0, r[1], 10.4, r[2], "")
		K.bolt(rc, K.at(9.3, r[3], ["hull"]), 9.3, r[4])
		K.bolt(rc, K.at(10.1, r[3], ["hull"]), 10.1, r[4])


# ---------------------------------------------------------------- ③ the spine, segment by segment

# what each segment holds beyond its distribution, emergency locker and valve block
const SEGFIT := {
	1: {"up": [["COMJ-1", "comms", 1.0, 2.6]], "mid": [["", "suit", 0.8, 1.9], ["", "suit", 0.8, 1.9]], "low": [["", "crate", 1.4, 1.2]]},
	2: {"up": [["HA-F", "dist", 1.4, 2.8]], "mid": [["", "locker", 0.9, 1.9], ["", "crate", 1.2, 1.0]], "low": [["", "pump", 1.6, 1.4]]},
	3: {"up": [["", "busbar", 1.0, 1.6]], "mid": [["LIFT-1", "lift", 2.2, 2.6], ["", "bench", 2.4, 1.1], ["", "drill", 0.8, 1.4], ["", "toolwall", 1.6, 2.4]]},
	4: {"mid": [["", "crate", 1.4, 1.2], ["", "crate", 1.4, 1.2], ["", "crate", 1.4, 1.2], ["", "suit", 0.8, 1.9]], "low": [["", "filter", 1.0, 1.6]]},
	5: {"up": [["HB-F", "dist", 1.4, 2.8]], "mid": [["", "medcab", 1.2, 1.8], ["", "o2cab", 0.8, 1.4]]},
	6: {"up": [["JB-6", "junction", 1.0, 1.2]], "low": [["BAT-L6", "l6bat", 2.0, 2.2]], "mid": [["", "emerg", 0.9, 1.9]]},
	7: {"up": [["IND-F", "dist", 1.4, 2.8]], "low": [["AIR-7", "airplant", 2.4, 2.6]]},
	8: {"mid": [["LIFT-2", "lift", 2.2, 2.6]], "low": [["WT-8", "watertreat", 2.2, 2.4]]},
	9: {"mid": [["", "reel", 1.6, 1.6], ["", "reel", 1.6, 1.6], ["", "reel", 1.6, 1.6], ["", "crate", 1.4, 1.2]]},
	10: {"up": [["", "busbar", 1.0, 1.6], ["", "busbar", 1.0, 1.6]], "low": [["", "pump", 1.6, 1.4]]},
	11: {"up": [["PWR-F", "dist", 1.4, 2.8]], "low": [["", "filter", 1.0, 1.6], ["", "valves", 1.0, 1.2]]},
	12: {"up": [["TL-F", "dist", 1.4, 2.8]], "low": [["", "valves", 1.0, 1.2], ["", "pump", 1.6, 1.4]]},
}


static func _seg_wells(k: int) -> Dictionary:
	var a: float = SB[k - 1] + 0.3
	var b: float = SB[k] - (0.3 if k < 12 else 0.6)
	var odd := (k - 1) % 2 == 0
	# _decks: the upper deck's well is forward on odd segments, the lower one's aft
	return {"a": a, "b": b, "up": [a, a + 2.6] if odd else [b - 2.6, b], "low": [b - 2.6, b] if odd else [a, a + 2.6]}


static func _seg_hatches(k: int) -> Array:
	var out: Array = []
	for ta in TAS:
		if ta[1] > SB[k - 1] and ta[2] < SB[k]:
			out.append([ta[1], ta[2]])
	return out


static func _spine_fit() -> void:
	for k in range(1, 13):
		var room := "L%d" % k
		var wl := _seg_wells(k)
		var a: float = wl.a + 0.3
		var b: float = wl.b - 0.3
		var fit: Dictionary = SEGFIT.get(k, {})
		var hatches := _seg_hatches(k)
		# the upper level: the main trunk's distribution, its junctions overhead
		var up: Array = [["L%d-D" % k, "localdist", 1.4, 2.8]]
		up.append_array(fit.get("up", []))
		up.append_array([["", "junction", 0.8, 0.6], ["", "panel", 0.8, 1.0], 3.0, ["", "relay", 0.8, 2.0], ["", "firebottle", 0.5, 1.4], 4.0,
			["", "xfmr" if k % 2 == 1 else "sensornode", 1.6 if k % 2 == 1 else 0.8, 2.2 if k % 2 == 1 else 1.2], 5.0, ["", "emlight", 0.6, 0.5], ["", "junction", 0.8, 0.6]])
		_row(room, -2.0, -1.0, a, b, up, [wl.up])
		_row(room, -5.4, 1.0, a + 4.0, b, [["", "junction", 0.8, 0.5], 8.0, ["", "junction", 0.8, 0.5], 8.0, ["", "junction", 0.8, 0.5]], hatches)
		# the maintenance way: emergency lockers and oxygen, the lift where there is one
		var mid: Array = [["", "emerg", 0.9, 1.9], ["", "o2cab", 0.8, 1.4], ["", "callpanel", 0.5, 0.6]]
		mid.append_array(fit.get("mid", []))
		mid.append_array([4.0, ["", "robotdock", 1.2, 0.8], ["", "firebottle", 0.5, 1.4], 5.0, ["", "sensornode", 0.8, 1.2], 4.0, ["", "emlight", 0.6, 0.5]])
		_row(room, 1.7, -1.0, a + 1.0, b, mid, [wl.low])
		_lamp("LAMP-L%d" % k, (wl.a + wl.b) * 0.5, -1.7, -1.0, room)
		# the lower level: the water and air mains' valve block, a main pump every other
		# segment, the backup harness's distribution forward of the break
		var low: Array = [["VB-%d" % k, "valves", 1.0, 1.2]]
		if k % 2 == 1:
			low.append(["PMP-L%d" % k, "mainpump", 1.8, 1.6])
		else:
			low.append(["", "filter", 1.0, 1.6])
		if k <= 6:
			low.append(["L%d-LD" % k, "lowdist", 1.0, 1.8])
		low.append_array(fit.get("low", []))
		low.append_array([3.0, ["", "ductfan", 1.4, 1.2], ["", "trap", 0.6, 0.8], 4.0, ["", "hxsmall" if k % 2 == 0 else "filter", 1.6 if k % 2 == 0 else 1.0, 1.4], 5.0, ["", "trap", 0.6, 0.8]])
		_row(room, 5.4, -1.0, a + 0.5, b, low, hatches)
		_row(room, 2.0, 1.0, a + 6.0, b, [["", "junction", 0.8, 0.5], 12.0, ["", "junction", 0.8, 0.5]], [wl.low])


# ---------------------------------------------------------------- ② ④ the hubs and spokes

static func _hub_fit() -> void:
	# ring A's hub: two motor-brakes above, two below; the brakes' control, capacitor
	# and cooling above; the slip ring, the hub's distribution and the rotary seal below
	_row("HAU", -10.2, -1.0, 76.9, 93.4, [["DSP-A1", "despin", 2.4, 2.2], ["BCTL-A", "brakectl", 1.2, 2.0], ["BCAP-A", "bcap", 1.4, 1.8],
		["BCOOL-A", "bcool", 1.4, 1.2], ["DSP-A2", "despin", 2.4, 2.2], ["", "sensor", 0.5, 0.4]], [[84.2, 85.8]])
	_row("HAU", -16.4, 1.0, 81.9, 93.4, [["SPL-AU1", "platform", 1.6, 1.0], ["", "junction", 0.8, 0.5]], [[84.1, 85.9]])
	_lamp("LAMP-HAU", 79.0, -16.4, -1.0, "HAU")
	_row("HAL", 16.4, -1.0, 76.9, 93.4, [["DSP-A3", "despin", 2.4, 2.2], ["SR-A", "slip", 1.6, 1.6], ["HA-DIST", "hubdist", 1.4, 2.8],
		["SEAL-A", "seal", 1.6, 1.4], ["DSP-A4", "despin", 2.4, 2.2], ["SPL-AL1", "platform", 1.6, 1.0]], [[84.1, 85.9]])
	_row("HAL", 10.2, 1.0, 87.0, 93.4, [["", "junction", 0.8, 0.5], ["", "sensor", 0.5, 0.4]], [[84.2, 85.8]])
	_lamp("LAMP-HAL", 79.0, 10.2, -1.0, "HAL")
	# ring B's, four spokes' roots
	_row("HBU", -10.2, -1.0, 182.9, 203.4, [["DSP-B1", "despin", 2.4, 2.2], ["BCTL-B", "brakectl", 1.2, 2.0], ["BCAP-B", "bcap", 1.4, 1.8],
		["BCOOL-B", "bcool", 1.4, 1.2], ["DSP-B2", "despin", 2.4, 2.2], ["", "sensor", 0.5, 0.4], ["", "panel", 0.8, 1.0]], [[197.2, 198.8]])
	_row("HBU", -17.4, 1.0, 183.0, 203.4, [["SPL-BU1", "platform", 1.6, 1.0], ["", "junction", 0.8, 0.5], 8.0, ["SPL-BU2", "platform", 1.6, 1.0]], [[185.1, 186.9], [199.1, 200.9]])
	_lamp("LAMP-HBU", 193.0, -17.4, -1.0, "HBU")
	_row("HBL", 17.4, -1.0, 182.9, 203.4, [["", "sensor", 0.5, 0.4], ["DSP-B3", "despin", 2.4, 2.2], ["SR-B", "slip", 1.6, 1.6], ["HB-DIST", "hubdist", 1.4, 2.8],
		["SEAL-B", "seal", 1.6, 1.4], ["DSP-B4", "despin", 2.4, 2.2], ["SPL-BL2", "platform", 1.6, 1.0]], [[185.1, 186.9], [199.1, 200.9]])
	_row("HBL", 10.2, 1.0, 183.0, 196.8, [["", "junction", 0.8, 0.5], 6.0, ["", "junction", 0.8, 0.5]], [[197.2, 198.8]])
	_lamp("LAMP-HBL", 193.0, 10.2, -1.0, "HBL")


# each spoke: its lift car halfway out, bolted to the west wall's guide
static func _spoke_fit() -> void:
	for r in SPOKES:
		var hy: float = HUBS[r][2]
		var ry: float = RIMS[r][2]
		var i := 0
		for sp in SPOKES[r]:
			i += 1
			for side in [-1.0, 1.0]:
				var nm := "%s%s%d" % [r, "U" if side < 0.0 else "L", i]
				var ym: float = side * (hy + ry) * 0.5
				var car = E("SLIFT-" + nm, "spokelift", sp[0] + 0.05, ym - 1.1, sp[1] - 0.05, ym + 1.1, "S" + nm)
				K.bolt(car, K.at(sp[0] - 0.3, ym - 0.7, ["hull"]), sp[0], ym - 0.7)
				K.bolt(car, K.at(sp[0] - 0.3, ym + 0.7, ["hull"]), sp[0], ym + 0.7)
				for f in [0.25, 0.75]:
					var yl: float = side * lerpf(hy, ry, f)
					var ld = E("", "ladder", sp[1] - 0.45, yl - 2.0, sp[1] - 0.05, yl + 2.0, "S" + nm)
					K.bolt(ld, K.at(sp[1] + 0.3, yl - 1.5, ["hull"]), sp[1], yl - 1.5)
					K.bolt(ld, K.at(sp[1] + 0.3, yl + 1.5, ["hull"]), sp[1], yl + 1.5)


# ---------------------------------------------------------------- ② ring A's rim modules

# three cabins along an outer layer, partitions hung from its ceiling, each a bed, a
# desk and chair, a locker and the colonists' belongings; a shelf over the bed
static func _cabins(room: String, floor_y: float, ceil_y: float, up: float, x0: float, x1: float, keep: Array, pre: String) -> void:
	var wd := (x1 - x0) / 3.0
	for c in 3:
		var a := x0 + wd * c
		_row(room, floor_y, up, a + 0.4, a + wd - 0.3, [["%s-BED%d" % [pre, c + 1], "bed", 2.1, 0.7], ["", "desk", 1.4, 0.9], ["", "chair", 0.7, 1.0],
			["", "locker", 0.9, 1.9], ["", "effects", 0.6, 0.5], ["", "effects", 0.5, 0.4]], keep)
		_row(room, ceil_y, -up, a + 0.4, a + wd - 0.3, [["", "shelf", 1.2, 0.5]])
		_lamp("", a + wd * 0.6, ceil_y, up, room)
		if c > 0:
			# the partition hangs from the ceiling and stops a doorway short of the floor
			var py0: float = ceil_y - up * 0.0
			var py1: float = floor_y + up * 2.1
			var pt = _plate("", a - 0.1, minf(py0, py1), a + 0.1, maxf(py0, py1), "strut", {"name_key": "p_ark_partition", "density": 0.8})
			_weld(pt, K.at(a, ceil_y + up * 0.15, ["deck"]), a, ceil_y)


static func _ring_a_fit() -> void:
	# the top module (its floors outward: up the screen)
	_cabins("RAU", -113.4, -108.15, 1.0, 68.6, 101.4, [[87.4, 92.3]], "RAU")
	_row("RAU", -107.85, 1.0, 69.0, 98.6, [["GAL-A", "galley", 3.0, 1.1], ["", "fridge", 1.0, 1.9], ["", "dispenser", 0.6, 1.2],
		["", "chair", 0.6, 1.0], ["", "table", 1.8, 0.8], ["", "chair", 0.6, 1.0], ["", "chair", 0.6, 1.0], ["", "table", 1.8, 0.8], ["", "chair", 0.6, 1.0],
		["", "chair", 0.6, 1.0], ["", "table", 1.8, 0.8], ["", "chair", 0.6, 1.0], ["", "locker", 0.9, 1.9], ["", "o2cab", 0.8, 1.4], ["", "effects", 0.6, 0.5]])
	_row("RAU", -102.15, -1.0, 74.0, 101.0, [["", "screen", 1.6, 0.9], 6.0, ["", "shelf", 1.4, 0.5]])
	_lamp("LAMP-RAU", 80.0, -102.15, 1.0, "RAU")
	_lamp("", 92.0, -102.15, 1.0, "RAU")
	_row("RAU", -101.85, 1.0, 71.6, 101.0, [["AIR-A", "airmach", 2.4, 2.4], ["", "pump", 1.6, 1.4], ["", "filter", 1.0, 1.6], ["", "o2cab", 0.9, 1.6],
		["O2-A", "o2tank", 1.2, 2.0], ["N2-A", "n2tank", 1.2, 2.0], ["RA-DU", "ringdist", 1.4, 2.8], ["", "panel", 0.8, 1.0], ["", "emerg", 0.9, 1.9]])
	_row("RAU", -96.6, -1.0, 72.0, 101.0, [["", "junction", 0.8, 0.5], 4.0, ["", "junction", 0.8, 0.5]], [[84.1, 85.9]])
	_lamp("", 78.0, -96.6, 1.0, "RAU")
	# the bottom module
	_cabins("RAL", 113.4, 108.15, -1.0, 68.6, 101.4, [], "RAL")
	_row("RAL", 107.85, -1.0, 69.0, 98.6, [["", "study", 1.4, 1.0], ["", "chair", 0.6, 1.0], ["", "study", 1.4, 1.0], ["", "chair", 0.6, 1.0],
		["", "study", 1.4, 1.0], ["", "chair", 0.6, 1.0], ["", "study", 1.4, 1.0], ["", "chair", 0.6, 1.0], ["", "shelf", 1.2, 1.8], 1.0,
		["MED-B", "medbed", 2.2, 0.9], ["", "medcab", 1.2, 1.8], ["", "o2cab", 0.8, 1.4], ["", "locker", 0.9, 1.9], ["", "medcab", 1.2, 1.8]])
	_row("RAL", 102.15, 1.0, 74.0, 101.0, [["", "screen", 1.6, 0.9], 10.0, ["MED-M", "medmon", 0.9, 0.6]])
	var pt = _plate("", 84.9, 102.15, 85.1, 104.6, "strut", {"name_key": "p_ark_partition", "density": 0.8})
	_weld(pt, K.at(85.0, 102.0, ["deck"]), 85.0, 102.15)
	_lamp("LAMP-RAL", 78.0, 102.15, -1.0, "RAL")
	_lamp("", 92.0, 102.15, -1.0, "RAL")
	_row("RAL", 101.85, -1.0, 71.6, 101.0, [["RA-DIST", "ringdist", 1.4, 2.8], ["BAT-RA", "ringbat", 2.0, 2.2], ["", "panel", 0.8, 1.0], ["", "pump", 1.6, 1.4],
		["", "filter", 1.0, 1.6], ["", "emerg", 0.9, 1.9], ["", "o2cab", 0.8, 1.4]])
	_row("RAL", 96.6, 1.0, 72.0, 101.0, [["", "junction", 0.8, 0.5], 4.0, ["", "junction", 0.8, 0.5]], [[84.1, 85.9]])
	_lamp("", 78.0, 96.6, -1.0, "RAL")


# ---------------------------------------------------------------- ④ ring B: the farm

const COLS_B := [170.0, 177.6, 185.2, 192.8, 200.4, 208.0]


# the greenhouse: six columns of four trays on their posts, a grow lamp over each, the
# irrigation pump and its controller at the aft end
static func _greenhouse(room: String, floor_y: float, ceil_y: float, up: float, pre: String) -> void:
	var c := 0
	for x in COLS_B:
		c += 1
		var pa: float = floor_y + up * 0.05
		var pb: float = ceil_y - up * 0.05
		var po = E("", "post", x, minf(pa, pb), x + 0.25, maxf(pa, pb), room)
		K.bolt(po, K.at(x + 0.12, floor_y - up * 0.15, FLOORK), x + 0.12, floor_y)
		K.bolt(po, K.at(x + 0.12, ceil_y + up * 0.15, FLOORK), x + 0.12, ceil_y)
		for t in 4:
			var ya: float = floor_y + up * (0.1 + 1.45 * t)
			var yb: float = floor_y + up * (0.1 + 1.45 * t + 1.2)
			var tr = E("%s-T%d%d" % [pre, c, t + 1], "tray", x + 0.3, minf(ya, yb), x + 3.1, maxf(ya, yb), room)
			K.bolt(tr, po, x + 0.25, (ya + yb) * 0.5)
			if t == 0:
				K.bolt(tr, K.at(x + 2.8, floor_y - up * 0.15, FLOORK), x + 2.8, floor_y)
		_row(room, ceil_y, -up, x + 0.3, x + 3.2, [["", "growlamp", 2.8, 0.3]])
	_row(room, floor_y, up, 211.6, 217.2, [["IRR-%s" % pre, "irrpump", 1.6, 1.4], ["", "irrctl", 0.8, 1.2], ["", "o2cab", 0.8, 1.4]])
	_lamp("", 214.0, ceil_y, up, room)


static func _ring_b_fit() -> void:
	# the top module
	_greenhouse("RBU", -121.4, -115.15, 1.0, "GU")
	_row("RBU", -114.85, 1.0, 169.0, 214.4, [["FM-1", "foodmod", 4.0, 3.0], ["FM-2", "foodmod", 4.0, 3.0], ["FM-3", "foodmod", 4.0, 3.0], ["", "process", 2.4, 1.0],
		["", "process", 2.4, 1.0], ["", "crate", 1.4, 1.2], ["", "crate", 1.4, 1.2], ["", "shelf", 1.2, 1.8], ["", "panel", 0.8, 1.0], ["", "locker", 0.9, 1.9]])
	_lamp("LAMP-RBU", 180.0, -108.15, 1.0, "RBU")
	_lamp("", 204.0, -108.15, 1.0, "RBU")
	_row("RBU", -107.85, 1.0, 171.6, 217.0, [["WT-1", "watertank", 2.4, 3.0], ["WT-2", "watertank", 2.4, 3.0], ["WP-U", "waterpump", 1.6, 1.4], ["", "filter", 1.0, 1.8],
		["LS-B", "lifesup", 2.6, 2.6], ["O2-B", "o2tank", 1.2, 2.0], ["", "pump", 1.6, 1.4], ["RB-DU", "ringdist", 1.4, 2.8], ["", "o2cab", 0.9, 1.6], ["", "emerg", 0.9, 1.9]])
	_row("RBU", -100.6, -1.0, 172.0, 217.0, [["", "junction", 0.8, 0.5], 8.0, ["", "junction", 0.8, 0.5]], [[185.1, 186.9], [199.1, 200.9]])
	_lamp("", 178.0, -100.6, 1.0, "RBU")
	_lamp("", 210.0, -100.6, 1.0, "RBU")
	# the bottom module, the cold store in its middle layer
	_greenhouse("RBL", 121.4, 115.15, -1.0, "GL")
	_row("RBL", 114.85, -1.0, 172.0, 199.6, [["FM-4", "foodmod", 4.0, 3.0], ["FM-5", "foodmod", 4.0, 3.0], ["", "process", 2.4, 1.0], ["", "crate", 1.4, 1.2],
		["", "crate", 1.4, 1.2], ["", "shelf", 1.2, 1.8], ["", "locker", 0.9, 1.9], ["", "panel", 0.8, 1.0]])
	_cold_store()
	_lamp("LAMP-RBL", 180.0, 108.15, -1.0, "RBL")
	_lamp("", 196.0, 108.15, -1.0, "RBL")
	_row("RBL", 107.85, -1.0, 171.6, 217.0, [["RB-DIST", "ringdist", 1.4, 2.8], ["BAT-RB", "ringbat", 2.0, 2.2], ["GEN-RB", "backgen", 2.8, 2.4], ["WT-3", "watertank", 2.4, 3.0],
		["WT-4", "watertank", 2.4, 3.0], ["WP-L", "waterpump", 1.6, 1.4], ["CHL-PLANT", "chiller", 1.6, 1.8], ["", "panel", 0.8, 1.0], ["", "emerg", 0.9, 1.9]])
	_row("RBL", 100.6, 1.0, 172.0, 217.0, [["", "junction", 0.8, 0.5], 8.0, ["", "junction", 0.8, 0.5]], [[185.1, 186.9], [199.1, 200.9]])
	_lamp("", 178.0, 100.6, -1.0, "RBL")
	_lamp("", 210.0, 100.6, -1.0, "RBL")


const CS_X := [200.0, 212.0]


# the cold store: its own sealed box in ring B's bottom module, frozen stores inside,
# the chiller on its ceiling
static func _cold_store() -> void:
	var C := {"density": 1.2, "barrier": true, "cut_speed": 210.0, "name_key": "p_hold_wall"}
	var x0 := CS_X[0]
	var x1 := CS_X[1]
	var y0 := 108.3
	var y1 := 114.7
	_shell("HCS", _rect(x0, y0, x1, y1), 0.6, 3.0, [[3, 1.4, 3.6, {"kind": "door", "door": true, "tag": "D-CS", "open_dir": Vector2(0, -2.4) * Geom.M, "cut_speed": 190.0}]], C)
	for x in [x0 + 1.0, x1 - 1.0]:
		K.bolt(K.at(x, y1 - 0.1, ["hull"]), K.at(x, 114.95, ["deck"]), x, y1)
		K.bolt(K.at(x, y0 + 0.1, ["hull"]), K.at(x, 108.05, ["deck"]), x, y0)
	_row("CS", y1 - 0.6, -1.0, x0 + 0.9, x1 - 0.7, [["FOOD-1", "frozen", 1.4, 1.4], ["FOOD-2", "frozen", 1.4, 1.4], ["FOOD-3", "frozen", 1.4, 1.4], ["FOOD-4", "frozen", 1.4, 1.4],
		["FOOD-5", "frozen", 1.4, 1.4]])
	_row("CS", y0 + 0.6, 1.0, x0 + 3.0, x1 - 0.7, [["CHL-CS", "chiller", 2.0, 1.0]])


# ---------------------------------------------------------------- ⑤ industry

static func _ind_fit() -> void:
	# the spares store: six racks of three tiers, two containers a tier
	var n := 0
	for i in 6:
		var x0: float = 242.0 + i * 18.5
		var p0 = E("", "post", x0, -41.35, x0 + 0.25, -31.8, "INDU")
		var p1 = E("", "post", x0 + 4.95, -41.35, x0 + 5.2, -31.8, "INDU")
		for po in [p0, p1]:
			var px: float = Geom.centroid(po.poly).x / Geom.M
			K.bolt(po, K.at(px, -31.6, ["deck"]), px, -31.75)
			K.bolt(po, K.at(px, -41.7, ["hull"]), px, -41.4)
		for t in 3:
			var fy: float = -31.75 - 3.1 * t
			var base = null
			if t > 0:
				base = _plate("", x0 + 0.25, fy, x0 + 4.95, fy + 0.15, "deck", {"density": 0.8, "name_key": "p_bay_shelf"})
				K.bolt(base, p0, x0 + 0.25, fy + 0.07)
				K.bolt(base, p1, x0 + 4.95, fy + 0.07)
			for c in 2:
				n += 1
				var cx: float = x0 + 0.35 + c * 2.3
				var bx = E("SPB-%d" % n, "sparebox", cx, fy - 0.05 - 2.6, cx + 2.1, fy - 0.05, "INDU")
				for bxx in [cx + 0.4, cx + 1.7]:
					K.bolt(bx, base if base != null else K.at(bxx, fy + 0.15, ["deck"]), bxx, fy)
		# the aisle beside it: materials and a crate
		if i < 5:
			_row("INDU", -31.75, -1.0, x0 + 6.0, x0 + 17.5, [["", "material", 1.2, 2.4], ["", "crate", 1.4, 1.2], ["", "crate", 1.4, 1.2], 4.0, ["", "material", 1.2, 2.4]], [[356.4, 359.4]])
	_row("INDU", -41.4, 1.0, 250.0, 356.0, [["HST-U1", "hoist", 1.0, 1.4], 30.0, ["HST-U2", "hoist", 1.0, 1.4], 30.0, ["HST-U3", "hoist", 1.0, 1.4]])
	for x in [250.0, 280.0, 310.0, 340.0]:
		_lamp("LAMP-IU" if x == 250.0 else "", x + 6.0, -41.4, -1.0, "INDU")
	# the six repair bays: an arm over a bench, tools beside it
	for i in 6:
		var bx0: float = 245.0 + i * 19.0
		var extra: Array = [["LATHE-1", "lathe", 3.0, 1.6]] if i == 2 else ([["", "drill", 0.8, 1.4]] if i % 2 == 0 else [["", "material", 1.2, 2.4]])
		var items: Array = [["BENCH-%d" % (i + 1), "bench", 2.4, 1.1], ["", "toolwall", 1.6, 2.4]]
		items.append_array(extra)
		items.append(["", "crate", 1.2, 1.0])
		_row("INDU", -20.95, -1.0, bx0, bx0 + 17.0, items, [[240.6, 243.6]])
		_row("INDU", -31.45, 1.0, bx0, bx0 + 3.0, [["ARM-%d" % (i + 1), "arm", 1.6, 3.2]], [[356.4, 359.4]])
		_lamp("", bx0 + 9.0, -31.45, -1.0, "INDU")
	# engineering on the lowest level, over the spine
	_row("INDU", -10.2, -1.0, 241.0, 359.0, [["ENG-C1", "engcon", 1.8, 1.3], ["ENG-C2", "engcon", 1.8, 1.3], ["ENG-C3", "engcon", 1.8, 1.3], ["IND-D", "dist", 1.4, 2.8],
		["", "panel", 0.8, 1.0], ["", "panel", 0.8, 1.0], ["WG-1", "weldgas", 0.6, 1.6], ["WG-2", "weldgas", 0.6, 1.6], ["", "bench", 2.4, 1.1], ["", "toolwall", 1.6, 2.4],
		["", "suit", 0.8, 1.9], ["", "suit", 0.8, 1.9], ["", "o2cab", 0.8, 1.4], 6.0, ["", "material", 1.2, 2.4], ["", "material", 1.2, 2.4], ["", "crate", 1.4, 1.2],
		["", "drill", 0.8, 1.4], 8.0, ["", "locker", 0.9, 1.9], ["", "locker", 0.9, 1.9], ["", "emerg", 0.9, 1.9]], [[270.2, 271.8]])
	for x in [255.0, 290.0, 325.0]:
		_lamp("", x, -20.65, -1.0, "INDU")
	# the hangar: the two shuttles, the work vehicles on their chargers, hoists overhead
	_shuttle(1, 243.4)
	_shuttle(2, 262.4)
	_row("INDL", 35.4, -1.0, 281.0, 299.4, [["VEH-1", "vehicle", 3.2, 1.8], ["CHG-1", "charger", 0.8, 1.4], ["VEH-2", "vehicle", 3.2, 1.8], ["CHG-2", "charger", 0.8, 1.4],
		["HDC", "dockctl", 1.4, 1.2], ["", "locker", 0.9, 1.9]])
	_row("INDL", 35.4, -1.0, 340.8, 359.2, [["VEH-3", "vehicle", 3.2, 1.8], ["CHG-3", "charger", 0.8, 1.4], ["VEH-4", "vehicle", 3.2, 1.8], ["CHG-4", "charger", 0.8, 1.4],
		["VEH-5", "vehicle", 3.2, 1.8], ["CHG-5", "charger", 0.8, 1.4], ["", "crate", 1.2, 1.0]])
	var m1 = _plate("DIL1", 240.6, 21.85, 298.0, 22.15, "deck", {"density": 0.9, "barrier": false, "cut_speed": 230.0, "name_key": "p_ark_mezzanine"})
	_weld(m1, K.at(240.3, 22.0, ["hull"]), 240.6, 22.0)
	var m2 = _plate("DIL2", 342.0, 21.85, 359.4, 22.15, "deck", {"density": 0.9, "barrier": false, "cut_speed": 230.0, "name_key": "p_ark_mezzanine"})
	_weld(m2, K.at(359.7, 22.0, ["hull"]), 359.4, 22.0)
	_row("INDL", 21.85, -1.0, 241.0, 297.6, [["", "partsrack", 1.4, 2.6], ["", "partsrack", 1.4, 2.6], ["", "shengine", 2.6, 2.2, {"name_key": "p_ark_spare_engine"}], ["", "toolwall", 1.6, 2.4],
		["", "bench", 2.4, 1.1], ["", "material", 1.2, 2.4], ["", "crate", 1.4, 1.2], ["", "crate", 1.4, 1.2], ["", "locker", 0.9, 1.9], ["", "suit", 0.8, 1.9], ["", "suit", 0.8, 1.9],
		["", "n2cart", 0.8, 1.6], ["", "partsrack", 1.4, 2.6], ["", "engcon", 1.8, 1.3], ["", "panel", 0.8, 1.0], ["", "o2cab", 0.8, 1.4], ["", "emerg", 0.9, 1.9]])
	_row("INDL", 21.85, -1.0, 342.4, 359.0, [["", "partsrack", 1.4, 2.6], ["", "partsrack", 1.4, 2.6], ["", "material", 1.2, 2.4], ["", "crate", 1.4, 1.2], ["", "toolwall", 1.6, 2.4], ["", "locker", 0.9, 1.9]])
	_row("INDL", 35.4, -1.0, 259.6, 262.3, [["", "stand", 1.0, 2.4], ["", "toolcart", 1.2, 1.0]])
	_row("INDL", 35.4, -1.0, 278.5, 280.9, [["", "fuelcart", 1.0, 1.4], ["", "batcart", 1.0, 1.0]])
	_row("INDL", 10.2, 1.0, 248.0, 356.0, [["HST-L1", "hoist", 1.0, 1.4], 18.0, ["HST-L2", "hoist", 1.0, 1.4], 30.0, ["HST-L3", "hoist", 1.0, 1.4]], [[270.2, 271.8]])
	var li := 0
	for x in [252.0, 290.0, 320.0, 350.0]:
		li += 1
		_lamp("LAMP-IL" if li == 1 else "", x, 10.2, -1.0, "INDL")


# an S-09 class shuttle parked in the hangar: a thin hull round its cockpit, avionics,
# seats, battery, fuel and engine, on skids bolted to the hangar floor
static func _shuttle(k: int, x: float) -> void:
	var nm := "SH%d" % k
	var y0 := 29.2
	var y1 := 34.3
	_shell("H%s" % nm, [Vector2(x, y0 + 1.0), Vector2(x + 2.0, y0), Vector2(x + 16.0, y0), Vector2(x + 16.0, y1), Vector2(x, y1)], 0.2, 4.0, [],
		{"density": 0.9, "barrier": false, "cut_speed": 230.0, "name_key": "p_ark_shuttle_hull"})
	_row("INDL", y1 - 0.2, -1.0, x + 0.8, x + 15.8, [[nm + "-CP", "cockpit", 1.6, 1.2], [nm + "-AV", "shavionics", 1.0, 1.4], ["", "chair", 0.7, 1.0], ["", "chair", 0.7, 1.0],
		[nm + "-B", "shbat", 1.2, 1.2], [nm + "-F", "shfuel", 2.4, 1.6], [nm + "-E", "shengine", 2.6, 2.2]])
	for sx in [x + 3.0, x + 13.0]:
		var sk = _plate("", sx - 0.3, y1, sx + 0.3, 35.35, "strut", {"name_key": "p_leg"})
		_weld(sk, K.at(sx, y1 - 0.1, ["hull"]), sx, y1)
		K.bolt(sk, K.at(sx, 35.6, ["hull"]), sx, 35.4)


# ---------------------------------------------------------------- ⑥ the power core

static func _pwr_fit() -> void:
	# forward, under the gallery: the reactor's console and its rod locks, out of its line
	_row("PWRU", -10.2, -1.0, 386.0, 420.8, [["RCON", "rcon", 2.0, 1.4], ["RODP", "rodpanel", 1.0, 1.6], ["", "tcc", 1.4, 2.2], ["", "suit", 0.8, 1.9],
		["", "suit", 0.8, 1.9], ["", "emerg", 0.9, 1.9], ["", "panel", 0.8, 1.0], ["", "o2cab", 0.8, 1.4], 4.0, ["", "locker", 0.9, 1.9]], [[416.2, 417.8]])
	_row("PWRU", -21.85, 1.0, 388.0, 420.0, [["DOSE-M", "dosemon", 0.9, 0.6], 8.0, ["", "junction", 0.8, 0.5]])
	_row("PWRU", -22.15, -1.0, 386.2, 420.8, [["", "rack", 1.4, 3.4], ["", "rack", 1.4, 3.4], ["", "screen", 1.4, 1.6], ["", "panel", 0.8, 1.0], ["", "effects", 0.6, 0.5]])
	_lamp("LAMP-PU", 395.0, -33.4, -1.0, "PWRU")
	_lamp("", 410.0, -21.85, -1.0, "PWRU")
	# the shield between the core and the forward end
	var sh = E("SHIELD", "shield", 424.0, -33.35, 425.2, -10.25, "PWRU")
	K.bolt(sh, K.at(424.6, -10.0, ["hull"]), 424.6, -10.2)
	K.bolt(sh, K.at(424.6, -33.6, ["hull"]), 424.6, -33.4)
	# the main reactor on its pedestal: the vessel in four parts round the core, the rod drives on top
	var ped = _plate("PED", 437.0, -18.0, 445.0, -10.25, "strut", {"density": 2.0, "name_key": "p_core_cradle"})
	_weld(ped, K.at(441.0, -10.0, ["hull"]), 441.0, -10.2)
	var vb = E("VS-B", "vessel", 436.0, -19.4, 446.0, -18.05, "PWRU")
	K.bolt(vb, ped, 438.0, -18.0)
	K.bolt(vb, ped, 444.0, -18.0)
	var vl = E("VS-L", "vessel", 436.0, -25.6, 437.4, -19.45, "PWRU")
	var vr = E("VS-R", "vessel", 444.6, -25.6, 446.0, -19.45, "PWRU")
	K.bolt(vl, vb, 436.7, -19.4)
	K.bolt(vr, vb, 445.3, -19.4)
	var vt = E("VS-T", "vessel", 436.0, -27.0, 446.0, -25.65, "PWRU")
	K.bolt(vt, vl, 436.7, -25.6)
	K.bolt(vt, vr, 445.3, -25.6)
	var core = E("CORE-M", "core", 438.5, -25.2, 443.5, -19.6, "PWRU")
	K.bolt(core, vb, 439.5, -19.45)
	K.bolt(core, vb, 442.5, -19.45)
	for i in 4:
		var cx := 437.2 + i * 1.6
		var crd = E("CRD-%d" % (i + 1), "crd", cx, -29.05, cx + 1.2, -27.05, "PWRU")
		K.bolt(crd, vt, cx + 0.3, -27.0)
		K.bolt(crd, vt, cx + 0.9, -27.0)
	_row("PWRU", -10.2, -1.0, 448.0, 474.0, [["PCP-1", "pcp", 2.4, 2.2], ["PCP-2", "pcp", 2.4, 2.2], ["HX-1", "hx", 4.6, 4.4], ["HX-2", "hx", 4.6, 4.4],
		["PRZ", "przr", 1.6, 3.2], ["", "panel", 0.8, 1.0]])
	_row("PWRU", -33.4, 1.0, 448.0, 474.0, [["", "junction", 0.8, 0.5], 6.0, ["", "junction", 0.8, 0.5]])
	_lamp("", 432.0, -33.4, -1.0, "PWRU")
	_lamp("", 460.0, -33.4, -1.0, "PWRU")
	# the aft gallery over the pumps: the emergency core cooling tanks and the I&C racks
	var g3 = _plate("DP3", 448.0, -22.15, 474.4, -21.85, "deck", {"density": 0.9, "barrier": false, "cut_speed": 230.0, "name_key": "p_deck"})
	_weld(g3, K.at(474.7, -22.0, ["hull"]), 474.4, -22.0)
	_row("PWRU", -22.15, -1.0, 449.5, 474.0, [["ECC-1", "ecctank", 2.4, 3.0], ["ECC-2", "ecctank", 2.4, 3.0], ["", "rack", 1.4, 3.4], ["", "rack", 1.4, 3.4],
		["", "rack", 1.4, 3.4], ["", "decon", 1.2, 2.0], ["", "dosing", 1.2, 1.8], ["", "panel", 0.8, 1.0], ["", "suit", 0.8, 1.9]])
	_row("PWRU", -21.85, 1.0, 449.0, 474.0, [["", "junction", 0.8, 0.5], 4.0, ["", "trap", 0.6, 0.8], 4.0, ["", "junction", 0.8, 0.5]])
	_lamp("", 462.0, -21.85, -1.0, "PWRU")
	# the overhead crane that lifts the shield and the vessel's sections
	var cb = E("CRANE-P", "cranebeam", 427.0, -33.35, 473.0, -32.85, "PWRU")
	for x in [430.0, 470.0]:
		K.bolt(cb, K.at(x, -33.7, ["hull"]), x, -33.4)
	var ht = E("HST-P", "hoist", 440.0, -32.8, 441.2, -31.2, "PWRU")
	K.bolt(ht, cb, 440.6, -32.85)
	_row("PWRU", -22.15, -1.0, 400.0, 420.8, [["", "rodstore", 2.4, 3.0], ["", "toolwall", 1.6, 2.4], ["", "locker", 0.9, 1.9], ["", "suit", 0.8, 1.9]])
	# below the spine: the turbines and generators, the secondary reactor, the
	# distribution centre and the auxiliary grid's batteries under the aft gallery
	_row("PWRL", 31.4, -1.0, 386.0, 474.0, [["TG-1", "turbine", 5.4, 3.6], ["GEN-1", "generator", 4.6, 3.4], ["TG-2", "turbine", 5.4, 3.6], ["GEN-2", "generator", 4.6, 3.4],
		["TCC", "tcc", 1.4, 2.2], ["SEC-R", "secreact", 4.0, 4.0], ["SG-1", "switchgear", 1.6, 3.2], ["SG-2", "switchgear", 1.6, 3.2], ["SG-3", "switchgear", 1.6, 3.2],
		["SG-4", "switchgear", 1.6, 3.2], ["SG-5", "switchgear", 1.6, 3.2], ["DC", "dcmain", 2.4, 3.4], ["CAP-DC", "dccap", 2.0, 2.4], 13.0,
		["AUX-1", "auxbat", 2.4, 2.6], ["AUX-2", "auxbat", 2.4, 2.6], ["AUX-3", "auxbat", 2.4, 2.6], ["DCC", "dccon", 1.8, 1.3], ["", "emerg", 0.9, 1.9], ["", "panel", 0.8, 1.0]])
	_row("PWRL", 20.85, -1.0, 446.0, 474.0, [["", "screen", 1.4, 1.6], ["", "panel", 0.8, 1.0], ["", "rack", 1.4, 3.4], ["", "locker", 0.9, 1.9], ["", "suit", 0.8, 1.9]])
	_row("PWRL", 10.2, 1.0, 390.0, 440.0, [["", "junction", 0.8, 0.5], 10.0, ["", "junction", 0.8, 0.5]], [[416.2, 417.8]])
	var g4 = _plate("DP4", 385.6, 20.85, 428.0, 21.15, "deck", {"density": 0.9, "barrier": false, "cut_speed": 230.0, "name_key": "p_deck"})
	_weld(g4, K.at(385.3, 21.0, ["hull"]), 385.6, 21.0)
	_row("PWRL", 20.85, -1.0, 386.2, 427.6, [["LUBE-1", "lubeskid", 2.4, 1.8], ["", "oiltank", 1.4, 2.0], ["COND-1", "condenser", 4.0, 3.0], ["FWP-1", "fwpump", 1.8, 1.6],
		["FWP-2", "fwpump", 1.8, 1.6], ["", "dosing", 1.2, 1.8], ["", "crate", 1.4, 1.2], ["", "partsrack", 1.4, 2.6], ["", "toolwall", 1.6, 2.4], ["", "panel", 0.8, 1.0]])
	_row("PWRL", 21.15, 1.0, 388.0, 427.0, [["", "junction", 0.8, 0.5], 10.0, ["", "trap", 0.6, 0.8], 10.0, ["", "junction", 0.8, 0.5]])
	_lamp("", 410.0, 21.15, -1.0, "PWRL")
	_lamp("LAMP-PL", 400.0, 10.2, -1.0, "PWRL")
	_lamp("", 430.0, 10.2, -1.0, "PWRL")
	_lamp("", 460.0, 21.15, -1.0, "PWRL")


# ---------------------------------------------------------------- ⑦ the tail

static func _tail_fit() -> void:
	for side in [-1.0, 1.0]:
		var nm := "U" if side < 0.0 else "L"
		for i in 4:
			var tx: float = TANK_X[i]
			var cx := tx + 9.0
			var n := i + 1 + (0 if side < 0.0 else 4)
			var ya: float = side * 8.45
			var yb: float = side * 27.35
			var tk = E("PT-%d" % n, "prop", tx, minf(ya, yb), tx + 18.0, maxf(ya, yb), "")
			K.bolt(tk, by_tag["TP-%s%d" % [nm, i + 1]], cx, side * 8.4)
			K.bolt(tk, K.at(cx, side * 27.8, ["beam"]), cx, side * 27.4)
	var tl = E("TL-D", "dist", 489.2, -4.85, 490.6, -2.05, "")
	K.bolt(tl, by_tag["KL-1"], 489.5, -2.0)
	K.bolt(tl, by_tag["KL-1"], 490.3, -2.0)
	var pm = E("PMAN", "manifold", 578.0, -4.85, 583.6, -2.05, "")
	K.bolt(pm, by_tag["KL-4"], 578.6, -2.0)
	K.bolt(pm, by_tag["KL-4"], 583.0, -2.0)
	var pp = E("PMP-T", "tailpump", 578.0, 2.05, 581.0, 4.05, "")
	K.bolt(pp, by_tag["KL-4"], 578.5, 2.0)
	K.bolt(pp, by_tag["KL-4"], 580.5, 2.0)
	for i in 5:
		var c: float = ENG_Y[i]
		var en = E("ENG-%d" % (i + 1), "engine", 590.05, c - 2.5, 598.0, c + 2.5, "")
		K.bolt(en, by_tag["THR"], 590.0, c - 1.8)
		K.bolt(en, by_tag["THR"], 590.0, c + 1.8)
		var nz = E("NOZ-%d" % (i + 1), "nozzle", 598.05, c - 3.4, 608.0, c + 3.4, "")
		K.bolt(nz, en, 598.0, c - 1.5)
		K.bolt(nz, en, 598.0, c + 1.5)
	for r in [["RCS-1", 586.2, -31.05, -30.05, "THR", -30.0], ["RCS-2", 586.2, 30.05, 31.05, "THR", 30.0]]:
		var rc = E(r[0], "rcs", r[1], r[2], r[1] + 3.6, r[3], "")
		K.bolt(rc, by_tag[r[4]], r[1] + 0.6, r[5])
		K.bolt(rc, by_tag[r[4]], r[1] + 3.0, r[5])
	for r in [["RCS-3", "FR-U2", -29.65, -28.65, -28.6], ["RCS-4", "FR-L2", 28.65, 29.65, 28.6]]:
		var rc2 = E(r[0], "rcs", 520.0, r[2], 523.6, r[3], "")
		K.bolt(rc2, by_tag[r[1]], 520.6, r[4])
		K.bolt(rc2, by_tag[r[1]], 523.0, r[4])


# ---------------------------------------------------------------- lines

static func _cen(tag: String) -> Vector2:
	return Geom.centroid(by_tag[tag].poly) / Geom.M


static func _c(id: String, a: String, b: String, via: Array = []) -> void:
	if not by_tag.has(a) or not by_tag.has(b):
		push_warning("ARK01 cable %s: no %s" % [id, a if not by_tag.has(a) else b])
		return
	K.line(id, "cable", "power", a, _cen(a), b, _cen(b), via)


static func _p(id: String, net: String, a: String, b: String, via: Array = []) -> void:
	if not by_tag.has(a) or not by_tag.has(b):
		push_warning("ARK01 pipe %s: no %s" % [id, a if not by_tag.has(a) else b])
		return
	K.line(id, "pipe", net, a, _cen(a), b, _cen(b), via)


static func _lines() -> void:
	var V := func(x, y): return Vector2(x, y)
	# the distribution centre and what hangs off it
	for i in 3:
		_c("pa%d" % (i + 1), "AUX-%d" % (i + 1), "DC")
	_c("pcap", "CAP-DC", "DC")
	for i in 5:
		_c("dg%d" % (i + 1), "DC", "SG-%d" % (i + 1))
	_c("r1", "SG-1", "RCON", [V.call(417.0, 25.0), V.call(417.0, -13.0)])
	_c("r2", "SG-2", "TCC")
	_c("r3", "SG-3", "L11-D", [V.call(417.0, 25.0), V.call(417.0, -3.6)])
	_c("r4", "SG-4", "PCP-1", [V.call(417.0, 25.0), V.call(417.0, -13.0), V.call(449.0, -13.0)])
	_c("r4b", "PCP-1", "PCP-2")
	_c("r5", "SG-5", "LAMP-PL")
	_c("r5b", "SG-5", "LAMP-PU", [V.call(417.0, 25.0), V.call(417.0, -13.0)])
	_c("r6", "DC", "DCC")
	_c("r7", "TCC", "TG-1")
	_c("r8", "SG-2", "SEC-R")
	# the main trunk along the spine's upper level, aft and forward of the power core;
	# between L6 and L5 it was severed long before the ship came in
	_c("t11", "L11-D", "L12-D")
	_c("tt", "L12-D", "TL-F")
	_c("tl", "TL-F", "TL-D", [V.call(486.5, -4.6), V.call(489.9, -4.6)])
	_c("tp", "TL-D", "PMP-T", [V.call(491.0, -1.2), V.call(579.5, -1.2)])
	for k in range(11, 1, -1):
		_c("t%d" % (k - 1), "L%d-D" % k, "L%d-D" % (k - 1))
	var cut = w.lines.get("t5")
	if cut != null:
		cut.alive = false
		cut.cut_at = (Geom.centroid(by_tag["L6-D"].poly) + Geom.centroid(by_tag["L5-D"].poly)) * 0.5
	for k in range(1, 13):
		_c("ll%d" % k, "L%d-D" % k, "LAMP-L%d" % k)
	for k in [7, 9, 11]:
		_c("mp%d" % k, "L%d-D" % k, "PMP-L%d" % k)
	# the industrial block, off L7
	_c("i1", "L7-D", "IND-F")
	_c("i2", "IND-F", "IND-D", [V.call(271.0, -3.6), V.call(271.0, -12.0)])
	_c("i3", "IND-D", "ENG-C1")
	_c("i4", "IND-D", "LAMP-IU")
	_c("i5", "IND-D", "HDC", [V.call(271.0, -12.0), V.call(271.0, 14.0)])
	_c("i6", "HDC", "CHG-1")
	_c("i7", "CHG-1", "CHG-2")
	_c("i8", "IND-D", "LAMP-IL", [V.call(271.0, -12.0), V.call(271.0, 12.0)])
	_c("i9", "HDC", "CHG-3", [V.call(298.0, 30.0), V.call(342.0, 30.0)])
	_c("i10", "IND-D", "ARM-1", [V.call(250.0, -18.0)])
	# ring A: its hub off L2, the slip ring out to the ring's own distribution
	_c("ha1", "L2-D", "HA-F")
	_c("ha2", "HA-F", "HA-DIST", [V.call(85.0, -3.6), V.call(85.0, 12.0)])
	_c("ha3", "HA-DIST", "SR-A")
	_c("sra", "SR-A", "RA-DIST", [V.call(85.0, 17.5), V.call(85.0, 96.5)])
	_c("ha4", "HA-DIST", "BCTL-A", [V.call(85.0, 12.0), V.call(85.0, -12.0)])
	_c("ha5", "HA-DIST", "LAMP-HAL")
	_c("ha6", "BCTL-A", "LAMP-HAU")
	_c("ha7", "BCTL-A", "BCOOL-A")
	_c("ra1", "BAT-RA", "RA-DIST")
	# round the ring (seen side-on: along its far side) to the top module
	_c("ra2", "RA-DIST", "RA-DU", [V.call(100.0, 99.0), V.call(96.0, 60.0), V.call(95.0, 0.0), V.call(96.0, -60.0), V.call(100.0, -99.0)])
	_c("ra3", "RA-DU", "AIR-A")
	_c("ra4", "RA-DU", "LAMP-RAU")
	_c("ra5", "RA-DIST", "LAMP-RAL")
	_c("ra6", "RA-DIST", "MED-M")
	# ring B, off L5
	_c("hb1", "L5-D", "HB-F")
	_c("hb2", "HB-F", "HB-DIST", [V.call(198.0, -3.6), V.call(198.0, 12.0)])
	_c("hb3", "HB-DIST", "SR-B")
	_c("srb", "SR-B", "RB-DIST", [V.call(186.0, 18.5), V.call(186.0, 100.5)])
	_c("hb4", "HB-DIST", "BCTL-B", [V.call(198.0, 12.0), V.call(198.0, -12.0)])
	_c("hb5", "HB-DIST", "LAMP-HBL")
	_c("hb6", "BCTL-B", "LAMP-HBU")
	_c("hb7", "BCTL-B", "BCOOL-B")
	_c("rb1", "BAT-RB", "RB-DIST")
	_c("rb12", "GEN-RB", "RB-DIST")
	_c("rb2", "RB-DIST", "RB-DU", [V.call(214.0, 103.0), V.call(209.0, 60.0), V.call(207.0, 0.0), V.call(209.0, -60.0), V.call(214.0, -103.0)])
	_c("rb3", "RB-DU", "WP-U")
	_c("rb4", "RB-DU", "LS-B")
	_c("rb5", "RB-DU", "LAMP-RBU")
	_c("rb6", "RB-DU", "IRR-GU")
	_c("rb7", "RB-DIST", "IRR-GL")
	_c("rb8", "RB-DIST", "LAMP-RBL")
	_c("rb9", "RB-DIST", "CHL-PLANT")
	_c("rb10", "CHL-PLANT", "CHL-CS")
	_c("rb11", "RB-DIST", "WP-L")
	# the command section on its own supply
	_c("b1", "BAT-BR", "BR-DIST")
	_c("b2", "BR-DIST", "CMD")
	_c("b3", "BR-DIST", "DR-8")
	for i in range(8, 1, -1):
		_c("bd%d" % i, "DR-%d" % i, "DR-%d" % (i - 1))
	_c("b4", "BR-DIST", "COM-R")
	_c("b5", "BR-DIST", "LAMP-BR1")
	_c("b6", "COM-R", "DISH-M", [V.call(30.0, 6.0), V.call(30.0, -19.0)])
	_c("b7", "COM-R", "TX")
	_c("b8", "BR-DIST", "DKC-1")
	_c("b9", "BR-DIST", "NAV-T")
	# L6's backup battery and the lower harness it keeps alive forward
	_c("lb0", "BAT-L6", "L6-LD")
	for k in range(6, 1, -1):
		_c("lb%d" % (k - 1), "L%d-LD" % k, "L%d-LD" % (k - 1))
	for k in [1, 3, 5]:
		_c("lp%d" % k, "L%d-LD" % k, "PMP-L%d" % k)
	# the spine's water and air mains through the valve blocks
	for k in range(1, 12):
		var a: Vector2 = _cen("VB-%d" % k)
		var b: Vector2 = _cen("VB-%d" % (k + 1))
		_p("wm%d" % k, "water", "VB-%d" % k, "VB-%d" % (k + 1), [V.call(a.x + 0.6, 4.6), V.call(b.x - 0.6, 4.6)])
		_p("am%d" % k, "air", "VB-%d" % k, "VB-%d" % (k + 1), [V.call(a.x + 0.6, 4.2), V.call(b.x - 0.6, 4.2)])
	_p("wt8", "water", "WT-8", "VB-8")
	_p("air7", "air", "AIR-7", "VB-7")
	for k in [1, 3, 5, 7, 9, 11]:
		_p("pw%d" % k, "water", "PMP-L%d" % k, "VB-%d" % k)
	# ring B's water and the irrigation
	_p("rw1", "rbw", "WT-1", "WP-U")
	_p("rw2", "rbw", "WT-2", "WP-U")
	_p("rw3", "rbw", "WT-3", "WP-L")
	_p("rw4", "rbw", "WT-4", "WP-L")
	_p("rw5", "rbw", "WP-U", "LS-B")
	for c in range(1, 7):
		_p("iu%d" % c, "irrU", "IRR-GU", "GU-T%d1" % c)
		_p("il%d" % c, "irrL", "IRR-GL", "GL-T%d1" % c)
	# the reactor's primary loop, the radiator loops out to the wings
	_p("rc1", "rcool", "VS-R", "PCP-1")
	_p("rc2", "rcool", "VS-R", "PCP-2")
	_p("rc3", "rcool", "PCP-1", "HX-1")
	_p("rc4", "rcool", "PCP-2", "HX-2")
	_p("rc5", "rcool", "HX-1", "PRZ")
	_p("rd0", "radU", "HX-1", "WSP-U", [V.call(458.0, -32.0)])
	_p("rl0", "radL", "HX-2", "WSP-L", [V.call(466.0, -12.0), V.call(466.0, 33.0)])
	for r in range(1, 5):
		_p("rd%d" % r, "radU", "WSP-U" if r == 1 else "RAD-U%d2" % (r - 1), "RAD-U%d2" % r)
		_p("rl%d" % r, "radL", "WSP-L" if r == 1 else "RAD-L%d2" % (r - 1), "RAD-L%d2" % r)
	# the propellant: each sphere to the manifold, the manifold to the engines
	for n in range(1, 9):
		var tc: Vector2 = _cen("PT-%d" % n)
		_p("pf%d" % n, "prop", "PT-%d" % n, "PMAN", [V.call(tc.x, -3.0 if n <= 4 else 3.0), V.call(578.0, -3.0 if n <= 4 else 3.0)])
	_p("pm", "prop", "PMAN", "PMP-T")
	for i in range(1, 6):
		_p("fe%d" % i, "feed", "PMAN", "ENG-%d" % i)
	_p("sf1", "shf1", "SH1-F", "SH1-E")
	_p("sf2", "shf2", "SH2-F", "SH2-E")


# ---------------------------------------------------------------- controls

static func _ct(id: String, kind: String, tag: String, d: Vector2, opts: Dictionary = {}) -> void:
	if not by_tag.has(tag):
		push_warning("ARK01 control %s: no %s" % [id, tag])
		return
	K.ctrl(id, kind, by_tag[tag], _cen(tag) + d, opts)


static func _port(room: String, x: float, y: float, px: float, py: float) -> void:
	var p = K.at(px, py, ["hull", "beam"])
	if p == null:
		push_warning("ARK01 port %s finds no hull at %s,%s" % [room, px, py])
		return
	K.ctrl("G-" + room, "port", p, Vector2(x, y), {"medium": "gas", "target": room})


static func _controls() -> void:
	# the rooms' gas ports, on the outside (the spine's on its chords, where nothing covers them)
	_port("BR", 25.0, 12.2, 25.0, 11.7)
	var spx := {1: 64.0, 2: 108.0, 3: 141.0, 4: 170.0, 5: 218.0, 6: 236.0, 9: 370.0, 10: 381.5, 12: 481.0}
	for k in spx:
		_port("L%d" % k, spx[k], 8.7, spx[k], 8.0)
	_port("HAU", 75.8, -13.0, 76.3, -13.0)
	_port("HAL", 75.8, 13.0, 76.3, 13.0)
	_port("HBU", 181.8, -14.0, 182.3, -14.0)
	_port("HBL", 181.8, 14.0, 182.3, 14.0)
	_port("RBU", 167.8, -111.0, 168.3, -111.0)
	_port("RBL", 167.8, 111.0, 168.3, 111.0)
	_port("INDU", 239.8, -30.0, 240.3, -30.0)
	_port("INDL", 239.8, 25.0, 240.3, 25.0)
	_port("PWRU", 384.8, -20.0, 385.3, -20.0)
	_port("PWRL", 384.8, 20.0, 385.3, 20.0)
	K.ctrl("G-CS", "port", K.at(CS_X[0] + 0.3, 109.4, ["hull"]), Vector2(CS_X[0] - 0.2, 109.4), {"medium": "gas", "target": "CS", "hidden_room": "RBL"})
	# the gas bottles' valves
	for v in [["G-O2A", "O2-A", "RAU"], ["G-N2A", "N2-A", "RAU"], ["G-O2B", "O2-B", "RBU"], ["G-WG1", "WG-1", "INDU"], ["G-WG2", "WG-2", "INDU"]]:
		_ct(v[0], "port", v[1], Vector2(0, 0.3), {"medium": "gas", "target": v[1], "hidden_room": v[2]})
	# fluid ports
	_ct("PW-M", "port", "WT-8", Vector2(0.6, 0.6), {"medium": "water", "target": "wmain", "hidden_room": "L8"})
	for n in range(1, 5):
		_ct("PW-%d" % n, "port", "WT-%d" % n, Vector2(0.6, 0.8), {"medium": "water", "target": "wt%d" % n, "hidden_room": "RBU" if n <= 2 else "RBL"})
	_ct("PRC", "port", "PRZ", Vector2(0, 0.8), {"medium": "coolant", "target": "rcool", "hidden_room": "PWRU"})
	_ct("PRD-U", "port", "WSP-U", Vector2(-34.2, 0.0), {"medium": "coolant", "target": "radU"})
	_ct("PRD-L", "port", "WSP-L", Vector2(-34.2, 0.0), {"medium": "coolant", "target": "radL"})
	for n in range(1, 9):
		_ct("PP-%d" % n, "port", "PT-%d" % n, Vector2(-8.6, 0.0), {"medium": "fuel", "target": "pt%d" % n})
	_ct("PP-T", "port", "PMAN", Vector2(0, -1.6), {"medium": "fuel", "target": "pman"})
	_ct("PS-1", "port", "SH1-F", Vector2(0, -0.9), {"medium": "fuel", "target": "sh1", "hidden_room": "INDL"})
	_ct("PS-2", "port", "SH2-F", Vector2(0, -0.9), {"medium": "fuel", "target": "sh2", "hidden_room": "INDL"})
	_ct("PIR-U", "port", "IRR-GU", Vector2(0, 0.8), {"medium": "water", "target": "irrU", "hidden_room": "RBU"})
	_ct("PIR-L", "port", "IRR-GL", Vector2(0, -0.8), {"medium": "water", "target": "irrL", "hidden_room": "RBL"})
	_ct("PRW", "port", "WP-L", Vector2(0, -0.8), {"medium": "water", "target": "rbw", "hidden_room": "RBL"})
	# the supplies' switches and test points
	_ct("K-AUX", "switch", "DC", Vector2(-0.6, -0.9), {"target": "K-AUX", "state": true, "hidden_room": "PWRL"})
	_ct("E-1", "test", "DC", Vector2(0.4, -0.9), {"medium": "volt", "target": "bus", "hidden_room": "PWRL"})
	_ct("DIS-DC", "discharge", "CAP-DC", Vector2(0, -0.6), {"target": "CAP-DC", "state": false, "hidden_room": "PWRL"})
	_ct("K-L6", "switch", "BAT-L6", Vector2(-0.4, -0.6), {"target": "K-L6", "state": true, "hidden_room": "L6"})
	_ct("E-L6", "test", "L6-LD", Vector2(0, -0.4), {"medium": "volt", "target": "L6-LD", "hidden_room": "L6"})
	_ct("E-L5", "test", "L5-D", Vector2(0, 0.4), {"medium": "volt", "target": "L5-D", "hidden_room": "L5"})
	_ct("K-BR", "switch", "BAT-BR", Vector2(-0.4, -0.5), {"target": "K-BR", "state": true, "hidden_room": "BR"})
	_ct("E-BR", "test", "BR-DIST", Vector2(0, 0.4), {"medium": "volt", "target": "BR-DIST", "hidden_room": "BR"})
	_ct("K-RA", "switch", "BAT-RA", Vector2(-0.4, -0.5), {"target": "K-RA", "state": true, "hidden_room": "RAL"})
	_ct("E-RA", "test", "RA-DIST", Vector2(0, 0.4), {"medium": "volt", "target": "RA-DIST", "hidden_room": "RAL"})
	_ct("K-RB", "switch", "BAT-RB", Vector2(-0.4, -0.5), {"target": "K-RB", "state": true, "hidden_room": "RBL"})
	_ct("E-RB", "test", "RB-DIST", Vector2(0, 0.4), {"medium": "volt", "target": "RB-DIST", "hidden_room": "RBL"})
	_ct("SR-A", "switch", "SR-A", Vector2(0, -0.3), {"target": "SR-A", "state": true, "hidden_room": "HAL"})
	_ct("SR-B", "switch", "SR-B", Vector2(0, -0.3), {"target": "SR-B", "state": true, "hidden_room": "HBL"})
	_ct("XA", "valve", "RA-DU", Vector2(0.4, 0.6), {"target": "XA", "state": true, "hidden_room": "RAU"})
	_ct("XB", "valve", "RB-DU", Vector2(0.4, 0.6), {"target": "XB", "state": true, "hidden_room": "RBU"})
	# the hubs' brake controls: four motor-brakes, the cooling, the capacitor dump, the
	# bearing lock, the ring's speed and the brakes' temperature
	for r in ["A", "B"]:
		var bc: String = "BCTL-" + r
		for i in 4:
			_ct("BRK-%s%d" % [r, i + 1], "switch", bc, Vector2(-0.45 + 0.3 * i, -0.6), {"target": "BRK-%s%d" % [r, i + 1], "state": false, "hidden_room": "H%sU" % r})
		_ct("BCOOL-" + r, "switch", "BCOOL-" + r, Vector2(0, -0.3), {"target": "BCOOL-" + r, "state": false, "hidden_room": "H%sU" % r})
		_ct("BDUMP-" + r, "discharge", "BCAP-" + r, Vector2(0, -0.5), {"target": "BCAP-" + r, "state": false, "hidden_room": "H%sU" % r})
		_ct("LOCK-" + r, "switch", bc, Vector2(0.0, 0.3), {"target": "LOCK-" + r, "state": false, "hidden_room": "H%sU" % r})
		_ct("RPM-" + r, "probe", bc, Vector2(0.3, 0.3), {"medium": "ring", "target": r, "hidden_room": "H%sU" % r})
		_ct("BT-" + r, "probe", "DSP-%s1" % r, Vector2(0, -0.6), {"medium": "bheat", "target": r, "hidden_room": "H%sU" % r})
		_ct("E-BC" + r, "test", "BCAP-" + r, Vector2(0.3, 0.3), {"medium": "volt", "target": "BCAP-" + r, "hidden_room": "H%sU" % r})
	# the reactor's rod locks and the dose there
	for i in 4:
		_ct("RL-%d" % (i + 1), "switch", "RODP", Vector2(-0.3 + 0.2 * i, -0.4), {"target": "RL-%d" % (i + 1), "state": false, "hidden_room": "PWRU"})
	_ct("DOSE-1", "probe", "DOSE-M", Vector2(0, 0.2), {"medium": "dose", "target": "CORE-M", "hidden_room": "PWRU"})
	# the spine's strain gauges, one a segment on its bottom chord
	for k in range(1, 13):
		_ct("SS-%d" % k, "probe", "CB-%d" % k, Vector2(0, 0.0), {"medium": "spine", "target": "L%d" % k})
	# the cold store's thermometer and the berth's temporary cooling for it
	_ct("T-CS", "probe", "CHL-CS", Vector2(0, 0.4), {"medium": "cold", "target": "CS", "hidden_room": "CS"})
	K.ctrl("CS-SOCK", "socket", K.at(CS_X[0] + 0.3, 114.1, ["hull"]), Vector2(CS_X[0] - 0.2, 114.1), {"target": "cold", "state": false, "hidden_room": "RBL"})
	# the berth's power: a socket on the command section's belly
	K.ctrl("AUX-S", "socket", K.at(40.0, 11.7, ["hull"]), Vector2(40.0, 12.2), {"target": "aux", "state": false})
	# the doors and hatches
	# a spine door's control on its forward side (reached from the segment before it)
	# (on the side with a gas port where only one side has one: L8 and L11 vent through these)
	for k in 12:
		var side := "BR" if k == 0 else "L%d" % k
		if k == 8:
			side = "L9"
		elif k == 11:
			side = "L12"
		K.door("D-%d" % k, side)
	for t in ["HT-DK1", "HT-DK2", "HD-1"]:
		K.door(t, "")
	K.door("D-CS", "RBL")
	for ta in TAS:
		for s2 in ["U", "L", "U2", "L2"]:
			K.door("HT-T%s%s" % [ta[0], s2], "")
	for r in SPOKES:
		for i in SPOKES[r].size():
			for s3 in ["U", "L"]:
				K.door("HT-S%s%s%dH" % [r, s3, i + 1], "")
				K.door("HT-S%s%s%dR" % [r, s3, i + 1], "")


# ---------------------------------------------------------------- rooms

static func _rooms() -> void:
	var R := func(x0, y0, x1, y1): return K.mp(_rect(x0, y0, x1, y1))
	w.add_room("BR", K.mp([Vector2(0.75, -3.8), Vector2(6.48, -11.4), Vector2(49.4, -11.4), Vector2(49.4, -5.4), Vector2(49.7, -5.4), Vector2(49.7, 5.4),
		Vector2(49.4, 5.4), Vector2(49.4, 11.4), Vector2(6.48, 11.4), Vector2(0.75, 3.8)]))
	for k in range(1, 13):
		w.add_room("L%d" % k, R.call(SB[k - 1] + 0.3, -5.4, SB[k] - (0.3 if k < 12 else 0.6), 5.4))
	for r in HUBS:
		var h: Array = HUBS[r]
		w.add_room("H%sU" % r, R.call(h[0] + T, -h[2] + T, h[1] - T, -HALL - T))
		w.add_room("H%sL" % r, R.call(h[0] + T, HALL + T, h[1] - T, h[2] - T))
	for ta in TAS:
		w.add_room("T%sU" % ta[0], R.call(ta[1], -HALL, ta[2], -6.0))
		w.add_room("T%sL" % ta[0], R.call(ta[1], 6.0, ta[2], HALL))
	for r in SPOKES:
		var i := 0
		for sp in SPOKES[r]:
			i += 1
			w.add_room("S%sU%d" % [r, i], R.call(sp[0], -RIMS[r][2], sp[1], -HUBS[r][2]))
			w.add_room("S%sL%d" % [r, i], R.call(sp[0], HUBS[r][2], sp[1], RIMS[r][2]))
	for r in RIMS:
		var m: Array = RIMS[r]
		w.add_room("R%sU" % r, R.call(m[0] + T, -m[3] + T, m[1] - T, -m[2] - T))
		if r == "A":
			w.add_room("RAL", R.call(m[0] + T, m[2] + T, m[1] - T, m[3] - T))
	# ring B's bottom module round its cold store (a slit to reach the box's far side)
	var bx0 := 168.6
	var bx1 := 217.4
	var y0 := 100.6
	var y1 := 121.4
	var cs0: float = CS_X[0]
	var cs1: float = CS_X[1]
	w.add_room("RBL", K.mp([Vector2(bx0, y0), Vector2(bx1, y0), Vector2(bx1, y1), Vector2(206.05, y1), Vector2(206.05, 114.7), Vector2(cs1, 114.7),
		Vector2(cs1, 108.3), Vector2(cs0, 108.3), Vector2(cs0, 114.7), Vector2(205.95, 114.7), Vector2(205.95, y1), Vector2(bx0, y1)]))
	w.add_room("CS", R.call(cs0 + 0.6, 108.9, cs1 - 0.6, 114.1))
	w.add_room("INDU", R.call(240.6, -41.4, 359.4, -10.2))
	w.add_room("INDL", R.call(240.6, 10.2, 359.4, 35.4))
	w.add_room("PWRU", R.call(385.6, -33.4, 474.4, -10.2))
	w.add_room("PWRL", R.call(385.6, 10.2, 474.4, 31.4))


# ---------------------------------------------------------------- the ship file's sections

const ROOMS_GAS := {"BR": 101.0, "HAU": 101.0, "HAL": 101.0, "HBU": 101.0, "HBL": 101.0, "RAU": 0.2, "RAL": 0.2, "SAU1": 0.2, "SAL1": 0.2,
	"SBU1": 0.2, "SBU2": 0.2, "SBL1": 0.2, "SBL2": 0.2, "RBU": 100.0, "RBL": 100.0, "CS": 100.0, "INDU": 101.0, "INDL": 101.0, "PWRU": 101.0, "PWRL": 101.0}


static func meta() -> Dictionary:
	var rooms := ROOMS_GAS.duplicate()
	for k in range(1, 13):
		rooms["L%d" % k] = 101.0
	for ta in TAS:
		rooms["T%sU" % ta[0]] = 101.0
		rooms["T%sL" % ta[0]] = 101.0
	var room_names := {}
	for r in rooms:
		room_names[r] = "room_ark" + r
	var mrooms := {}
	for r in rooms:
		if float(rooms[r]) > 50.0 and not r.begins_with("T"):
			mrooms[r] = [0.2, 40.0, float(rooms[r])]
	var lamps := {"HAU": "LAMP-HAU", "HAL": "LAMP-HAL", "HBU": "LAMP-HBU", "HBL": "LAMP-HBL", "RAU": "LAMP-RAU", "RAL": "LAMP-RAL",
		"RBU": "LAMP-RBU", "RBL": "LAMP-RBL", "INDU": "LAMP-IU", "INDL": "LAMP-IL", "PWRU": "LAMP-PU", "PWRL": "LAMP-PL"}
	for k in range(1, 13):
		lamps["L%d" % k] = "LAMP-L%d" % k
	var vols := {
		"airmain": {"fluid": "air", "amount": 0.0, "nets": ["air"]},
		"wmain": {"fluid": "water", "amount": 1.2, "nets": ["water"], "piece": "WT-8", "port": "PW-M", "full": 2.0, "leak": 0.15, "leak_min": 0.005, "pump": [0.12, 0.008]},
		"rbw": {"fluid": "water", "amount": 0.15, "nets": ["rbw"], "piece": "WP-L", "port": "PRW", "full": 0.3, "leak": 0.06, "leak_min": 0.004, "pump": [0.1, 0.008]},
		"irrU": {"fluid": "water", "amount": 0.1, "nets": ["irrU"], "piece": "IRR-GU", "port": "PIR-U", "full": 0.2, "leak": 0.05, "leak_min": 0.004, "pump": [0.1, 0.008]},
		"irrL": {"fluid": "water", "amount": 0.1, "nets": ["irrL"], "piece": "IRR-GL", "port": "PIR-L", "full": 0.2, "leak": 0.05, "leak_min": 0.004, "pump": [0.1, 0.008]},
		"rcool": {"fluid": "coolant", "amount": 1.0, "piece": "PRZ", "port": "PRC", "full": 1.2, "nets": ["rcool"], "leak": 0.2, "pump": [0.2, 0.006]},
		"radU": {"fluid": "coolant", "amount": 0.5, "nets": ["radU"], "piece": "WSP-U", "port": "PRD-U", "full": 0.6, "leak": 0.15, "pump": [0.15, 0.006]},
		"radL": {"fluid": "coolant", "amount": 0.5, "nets": ["radL"], "piece": "WSP-L", "port": "PRD-L", "full": 0.6, "leak": 0.15, "pump": [0.15, 0.006]},
		"pman": {"fluid": "fuel", "amount": 0.1, "nets": ["prop", "feed"], "piece": "PMAN", "port": "PP-T", "full": 0.4, "leak": 0.1, "leak_min": 0.004, "pump": [0.12, 0.01]},
		"sh1": {"fluid": "fuel", "amount": 0.3, "nets": ["shf1"], "piece": "SH1-F", "port": "PS-1", "full": 0.5, "content": 1.0, "leak": 0.12, "pump": [0.1, 0.008]},
		"sh2": {"fluid": "fuel", "amount": 0.3, "nets": ["shf2"], "piece": "SH2-F", "port": "PS-2", "full": 0.5, "content": 1.0, "leak": 0.12, "pump": [0.1, 0.008]},
	}
	var fills := [1.6, 2.2, 0.8, 1.9, 2.4, 1.2, 0.6, 2.0]
	var mfl := {}
	for n in range(1, 9):
		vols["pt%d" % n] = {"fluid": "fuel", "amount": fills[n - 1], "piece": "PT-%d" % n, "port": "PP-%d" % n, "full": 3.0, "content": 1.0, "leak": 0.15, "pump": [0.15, 0.01]}
		mfl["pt%d" % n] = [0.3, 2.6]
	for n in range(1, 5):
		vols["wt%d" % n] = {"fluid": "water", "amount": 0.6, "piece": "WT-%d" % n, "port": "PW-%d" % n, "full": 3.0, "content": 1.0, "leak": 0.1, "pump": [0.12, 0.008]}
	var brakes := {}
	var segs := {}
	var gauges := {}
	var hits := {}
	for k in range(1, 13):
		segs["L%d" % k] = {"chords": ["CT-%d" % k, "CB-%d" % k], "x1": SB[k]}
		gauges["SS-%d" % k] = "L%d" % k
		hits["L%d" % k] = ["L%d-D" % k, "VB-%d" % k, "LAMP-L%d" % k]
	var labels := {"DC": "DC MAIN", "AUX-1": "AUX 1", "AUX-2": "AUX 2", "AUX-3": "AUX 3", "CAP-DC": "CAP", "SR-A": "SLIP A", "SR-B": "SLIP B",
		"BCTL-A": "BRAKE A", "BCTL-B": "BRAKE B", "BCAP-A": "BCAP A", "BCAP-B": "BCAP B", "RA-DIST": "RING A", "RB-DIST": "RING B", "RA-DU": "RING A", "RB-DU": "RING B",
		"HA-DIST": "HUB A", "HB-DIST": "HUB B", "BAT-L6": "L6 BACKUP", "BAT-BR": "UPS", "BAT-RA": "BATT A", "BAT-RB": "BATT B", "CORE-M": "MAIN", "SEC-R": "SEC",
		"CMD": "COMMAND", "VDR": "VDR", "CHL-CS": "COLD", "CHL-PLANT": "COLD PLANT", "GEN-RB": "GEN B", "SHIELD": "SHIELD", "RODP": "RODS", "PMAN": "PROP MAN",
		"PMP-T": "PROP PUMP", "TL-D": "TAIL", "IND-D": "IND", "BR-DIST": "BRIDGE", "HDC": "HANGAR", "LIFT-1": "LIFT", "LIFT-2": "LIFT", "JB-6": "L6 JB"}
	for k in range(1, 13):
		labels["L%d-D" % k] = "L%d" % k
		if k <= 6:
			labels["L%d-LD" % k] = "L%d LOW" % k
	for n in range(1, 9):
		labels["PT-%d" % n] = "P%d" % n
	for i in range(1, 6):
		labels["ENG-%d" % i] = "E%d" % i
	var ctrls_cfg := {"G-BR": {"rate": 40.0}, "G-HAU": {"rate": 30.0}, "G-HAL": {"rate": 30.0}, "G-HBU": {"rate": 34.0}, "G-HBL": {"rate": 34.0},
		"G-RBU": {"rate": 50.0}, "G-RBL": {"rate": 50.0}, "G-CS": {"rate": 16.0}, "G-INDU": {"rate": 90.0}, "G-INDL": {"rate": 90.0},
		"G-PWRU": {"rate": 70.0}, "G-PWRL": {"rate": 70.0}, "G-O2A": {"rate": 2.0}, "G-N2A": {"rate": 2.0}, "G-O2B": {"rate": 2.0}, "G-WG1": {"rate": 0.5}, "G-WG2": {"rate": 0.5}}
	for k in [1, 2, 3, 4, 5, 6, 9, 10, 12]:
		ctrls_cfg["G-L%d" % k] = {"rate": 50.0}
	return {
		"id": "ark01",
		"name": "ARK-01 VOYAGER",
		"title": ["ARK-01「远航者」殖民飞船 · 608 m", "ARK-01 VOYAGER · COLONY SHIP · 608 m"],
		"contract": "ARK-01",
		"length": 608.0,
		"gas_cell_max": 0.8,
		"value": {"total": 7714400.0, "metal": 300000.0},
		"clamps": [[42.0, 12.0], [250.0, 36.0], [398.0, 32.0]],
		"room_names": room_names,
		"gas": {"rooms": rooms, "vessels": {
				"O2-A": {"V": 1.0, "kpa": 1400.0, "piece": "O2-A", "burst": 300.0},
				"N2-A": {"V": 1.0, "kpa": 1400.0, "piece": "N2-A", "burst": 300.0},
				"O2-B": {"V": 1.2, "kpa": 1400.0, "piece": "O2-B", "burst": 300.0},
				"WG-1": {"V": 0.1, "kpa": 2000.0, "piece": "WG-1", "burst": 300.0},
				"WG-2": {"V": 0.1, "kpa": 2000.0, "piece": "WG-2", "burst": 300.0}},
			"valves": [{"ctrl": "XA", "a": "RAU", "b": "RAL", "g": 30.0}, {"ctrl": "XB", "a": "RBU", "b": "RBL", "g": 40.0}], "value": 60000.0},
		"power": {
			"bus": "DC",
			"sources": [
				{"piece": "AUX-1", "kind": "battery", "volts": 440.0, "local_volts": 48.0, "cable": "pa1", "switch": "K-AUX", "charge": 0.85, "drain": 0.0002},
				{"piece": "AUX-2", "kind": "battery", "volts": 440.0, "local_volts": 48.0, "cable": "pa2", "switch": "K-AUX", "charge": 0.8, "drain": 0.0002},
				{"piece": "AUX-3", "kind": "battery", "volts": 440.0, "local_volts": 48.0, "cable": "pa3", "switch": "K-AUX", "charge": 0.75, "drain": 0.0002},
				{"piece": "CAP-DC", "kind": "cap", "volts": 440.0, "cable": "pcap", "charge": 0.9, "discharge": "DIS-DC"},
			],
			"isolated": [
				{"piece": "BAT-L6", "volts": 220.0, "charge": 0.8, "switch": "K-L6"},
				{"piece": "BAT-BR", "volts": 220.0, "charge": 0.7, "switch": "K-BR"},
				{"piece": "BAT-RA", "volts": 220.0, "charge": 0.6, "switch": "K-RA"},
				{"piece": "BAT-RB", "volts": 220.0, "charge": 0.8, "switch": "K-RB"},
				{"piece": "BCAP-A", "kind": "cap", "volts": 600.0, "charge": 0.0, "discharge": "BDUMP-A"},
				{"piece": "BCAP-B", "kind": "cap", "volts": 600.0, "charge": 0.0, "discharge": "BDUMP-B"},
				{"piece": "SH1-B", "volts": 28.0, "charge": 0.6},
				{"piece": "SH2-B", "volts": 28.0, "charge": 0.5},
			],
			"breakers": {"sra": "SR-A", "srb": "SR-B"},
			"lamps": lamps,
		},
		"fluids": {"volumes": vols, "joins": [], "value": {"fuel": 90000.0, "water": 8000.0, "coolant": 9000.0}},
		"reactor": {"core": "CORE-M", "rate": 900.0, "shields": ["SHIELD"], "limit": 150.0,
			"drums": {"CRD-1": "RL-1", "CRD-2": "RL-2", "CRD-3": "RL-3", "CRD-4": "RL-4"}, "petals": [], "safe": 60.0},
		"cold": {"rooms": {"CS": -20.0}, "chillers": {"CHL-CS": ["CS"]}, "plant": "CHL-PLANT", "supply": "CS-SOCK", "warm": 0.04, "thaw": -5.0, "keep": 0.35,
			"cargo": {"CS": ["FOOD-1", "FOOD-2", "FOOD-3", "FOOD-4", "FOOD-5"]}},
		"liner": {"pods": {}, "glazings": [
			{"room": "RBU", "panes": ["GL-U1", "GL-U2", "GL-U3", "GL-U4", "GL-U5"], "kpa": 20.0},
			{"room": "RBL", "panes": ["GL-L1", "GL-L2", "GL-L3", "GL-L4", "GL-L5"], "kpa": 20.0},
			{"room": "BR", "panes": ["WIN-1", "WIN-2"], "kpa": 20.0}]},
		"rings": {"rings": {
				"A": {"rpm": 3.0, "area": [[66.0, -116.0, 104.0, -9.65], [66.0, 9.65, 104.0, 116.0]], "hub": [85.0, 0.0], "radius": 105.0, "half_width": 9.0,
					"bus": "RA-DIST", "slip": "SR-A", "brakes": ["BRK-A1", "BRK-A2", "BRK-A3", "BRK-A4"],
					"brake_pieces": {"BRK-A1": "DSP-A1", "BRK-A2": "DSP-A2", "BRK-A3": "DSP-A3", "BRK-A4": "DSP-A4"},
					"cool": "BCOOL-A", "cap": "BCAP-A", "lock": "LOCK-A", "rollers": ["BRA-1", "BRA-2", "BRA-3", "BRA-4", "BRA-5", "BRA-6", "BRA-7", "BRA-8"],
					"seize_hits": ["SLIFT-AU1", "SLIFT-AL1", "SPL-AU1", "SPL-AL1", "SEAL-A"], "airlocks": ["HT-TAU", "HT-TAU2", "HT-TAL", "HT-TAL2"], "decel": 0.012, "shock": {}},
				"B": {"rpm": 2.9, "area": [[166.0, -124.0, 220.0, -9.65], [166.0, 9.65, 220.0, 124.0]], "hub": [193.0, 0.0], "radius": 110.0, "half_width": 11.0,
					"bus": "RB-DIST", "slip": "SR-B", "brakes": ["BRK-B1", "BRK-B2", "BRK-B3", "BRK-B4"],
					"brake_pieces": {"BRK-B1": "DSP-B1", "BRK-B2": "DSP-B2", "BRK-B3": "DSP-B3", "BRK-B4": "DSP-B4"},
					"cool": "BCOOL-B", "cap": "BCAP-B", "lock": "LOCK-B", "rollers": ["BRB-1", "BRB-2", "BRB-3", "BRB-4", "BRB-5", "BRB-6", "BRB-7", "BRB-8"],
					"seize_hits": ["SLIFT-BU1", "SLIFT-BU2", "SLIFT-BL1", "SLIFT-BL2", "SEAL-B"], "airlocks": ["HT-TBU", "HT-TBU2", "HT-TBL", "HT-TBL2"], "decel": 0.0075,
					"shock": {"kpa": 30.0, "doors": {
						"HT-SBU1R": ["RBU", "SBU1", ["GL-U1", "GL-U2", "GL-U3", "GL-U4", "GL-U5"]], "HT-SBU2R": ["RBU", "SBU2", ["GL-U1", "GL-U2", "GL-U3", "GL-U4", "GL-U5"]],
						"HT-SBL1R": ["RBL", "SBL1", ["GL-L1", "GL-L2", "GL-L3", "GL-L4", "GL-L5"]], "HT-SBL2R": ["RBL", "SBL2", ["GL-L1", "GL-L2", "GL-L3", "GL-L4", "GL-L5"]]}}}},
			"safe": 0.05, "torque": 0.6, "torque_t": 6.0, "hits": ["SEAL-A", "SEAL-B", "SR-A", "SR-B", "HA-DIST", "HB-DIST", "BCTL-A", "BCTL-B"],
			"cap_k": 0.45, "heat_k": 0.55},
		"spine": {"segments": segs, "order": ["L1", "L2", "L3", "L4", "L5", "L6", "L7", "L8", "L9", "L10", "L11", "L12"], "hung_x": HUNG_X,
			"cap": snappedf(hung_t / 1.4, 0.1), "gauges": gauges, "hits": hits},
		"workday": {"len": 2700.0, "fee": 15000.0, "days": 10},
		"ctrls_cfg": ctrls_cfg,
		"labels": labels,
		"hints": {},
		"market": {
			"class": "ARK", "name": ["远航者级殖民飞船", "VOYAGER-CLASS COLONY SHIP"], "time": 450.0,
			"rooms": mrooms,
			"charge": {"AUX-1": [0.4, 0.95], "AUX-2": [0.4, 0.95], "AUX-3": [0.4, 0.95], "BAT-L6": [0.4, 0.9], "BAT-BR": [0.3, 0.9], "BAT-RA": [0.3, 0.9], "BAT-RB": [0.4, 0.9]},
			"fluids": mfl,
			"knockable": ["NAV-T", "CHART"],
			"drift": [],
			"section_x": 240.0,
			"slots": {"fire_system": {"x": 330.0, "y0": -11.6, "y1": -10.2, "base": [fire_base, -10.2], "room": "INDU", "port": [330.4, -11.53]}},
			"mechanisms": true,
		},
		"procedures": {
			"VDR": [
				{"do": "hose", "ctrl": "G-BR"},
				{"do": "wait", "until": {"P": ["BR", "<", 5.0]}, "max": 240.0},
				{"do": "operate", "ctrl": "HT-DK1"},
				{"do": "wait", "until": {"open": ["BR"]}, "max": 20.0},
				{"do": "operate", "ctrl": "K-BR"},
				{"do": "measure", "ctrl": "E-BR", "expect": ["<", 1.0]},
				{"do": "free", "piece": "VDR"},
				{"do": "deliver", "piece": "VDR", "zone": "equip"},
			],
			"CMD": [
				{"do": "hose", "ctrl": "G-BR"},
				{"do": "wait", "until": {"P": ["BR", "<", 5.0]}, "max": 240.0},
				{"do": "operate", "ctrl": "HT-DK1"},
				{"do": "wait", "until": {"open": ["BR"]}, "max": 20.0},
				{"do": "operate", "ctrl": "K-BR"},
				{"do": "measure", "ctrl": "E-BR", "expect": ["<", 1.0]},
				{"do": "free", "piece": "CMD"},
				{"do": "deliver", "piece": "CMD", "zone": "equip"},
			],
		},
	}


# what hangs on the spine aft of the power core's forward end (worked out as it is built)
const HUNG_X := 380.0
static var hung_t := 0.0
static var fire_base := ""


static func _weigh() -> void:
	hung_t = 0.0
	for id in w.order:
		var p = w.pieces[id]
		if not p.gone and Geom.centroid(p.poly).x / Geom.M > HUNG_X:
			hung_t += p.mass
	var fb = K.at(330.7, -9.9, ["hull"])
	fire_base = fb.tag if fb != null else ""
