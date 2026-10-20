extends RefCounted
# Each ship's signature machines (2026-10-20 rework, player: "parts you can name, drawn
# the way the real thing is built"): a drilling ship's top drive and triplex mud pumps,
# a cryoplant's turboexpanders, a telescope's wavefront sensor... Picked by the piece's
# kind (name_key), so every ship carrying one shows it; recorded once and replayed
# like the shared art (art_equip.gd, whose primitives these use).

const E = preload("res://scripts/art_equip.gd")
const M := 48.0

const BY_NAME := {
	# DR-150 Derrick
	"p_dr_top_drive": "top_drive", "p_dr_drawworks": "drawworks", "p_dr_crown_block": "crown_block",
	"p_dr_travel_block": "travel_block", "p_dr_rotary": "rotary_table", "p_dr_stand": "drillpipe",
	"p_dr_bha": "bha", "p_dr_mud_pump": "mud_pump", "p_dr_shaker": "shaker", "p_dr_desander": "hydrocyclone",
	"p_dr_degasser": "degasser", "p_dr_centrifuge": "decanter", "p_dr_mud_gas_sep": "gas_buster",
	"p_dr_agitator": "agitator", "p_dr_roughneck": "roughneck", "p_dr_pipe_rack": "pipe_rack",
	"p_dr_casing": "pipe_bundle", "p_dr_bop": "bop", "p_dr_lathe": "lathe", "p_dr_mill": "mill",
	"p_dr_standpipe": "standpipe", "p_dr_choke": "choke_manifold", "p_dr_bop_accumulator": "koomey",
	# HG-170 Gas Sea (and FX-70's helium compressors)
	"p_hg_intake_comp": "axial_comp",
	"p_fx_he_compressor": "screw_comp",
	"p_hg_sample_comp": "screw_comp",
	"p_hg_cryocooler": "cold_box_h2",
	"p_hg_ortho_para": "ortho_para",
	"p_hg_precooler": "precooler",
	"p_hg_separator": "psa",
	"p_hg_chromatograph": "gc",
	"p_hg_mass_spec": "mass_spec",
	"p_hg_turboexpander": "turboexpander",
	# QC-30 Quantum
	"p_qc_stage_50k": "dr_stage",
	"p_qc_stage_4k": "dr_stage",
	"p_qc_stage_still": "dr_stage",
	"p_qc_stage_cp": "dr_stage",
	"p_qc_stage_mxc": "dr_stage",
	"p_qc_qpu": "qpu",
	"p_qc_pt_head": "pulse_tube",
	"p_qc_ghs": "ghs",
	"p_qc_vit": "iso_table",
	"p_qc_awg": "instrument_rack",
	"p_qc_readout": "instrument_rack",
	"p_qc_turbo": "turbo_pump",
	"p_qc_still_pump": "scroll_pump",
	"p_qc_compressor": "screw_comp",
	# OB-90 Observatory (and the cameras and spectrometers elsewhere)
	"p_ob_hexapod": "hexapod",
	"p_ob_aft_optics": "aft_optics",
	"p_ob_fsm": "fsm",
	"p_ob_nircam": "ir_camera",
	"p_ev_thermal_cam": "ir_camera",
	"p_ob_spectro": "spectrograph",
	"p_ev_spectrometer": "spectrograph",
	"p_ob_fgs": "fgs",
	"p_ob_wfs": "wfs",
	"p_ob_cryocooler": "pulse_tube",
	"p_ob_recoater": "recoater",
	"p_ob_wheel": "reaction_wheel",
	"p_star_tracker": "star_tracker",
	# DC-84 Deep Mind
	"p_dc_rack": "immersion_rack",
	"p_dc_cdu": "cdu",
	"p_dc_dry_cooler": "dry_cooler",
	"p_dc_array": "storage_array",
	"p_dc_core_switch": "switch_chassis",
	"p_dc_drive": "drive_carrier",
	# ARK-01 Voyager: the power core, the rings
	"p_reactor_core": "pwr_core",
	"p_ark_secondary_reactor": "pwr_core",
	"p_core_pump": "rcp",
	"p_ark_pressurizer": "pressurizer",
	"p_ark_crd": "crdm",
	"p_ark_turbine": "steam_turbine",
	"p_ark_condenser": "condenser",
	"p_ark_despin": "despin_brake",
	"p_ark_slip_ring": "slip_ring",
	"p_ark_rotary_seal": "rotary_seal",
	"p_ark_spoke_lift": "spoke_lift",
	"p_lift_car": "spoke_lift",
	"p_ark_vehicle": "work_vehicle",
	"p_ark_food_module": "food_module",
	"p_cross_manifold": "manifold",
	# ST-40, EV-55, BL-88, LC-140
	"p_st_turbopump": "turbopump",
	"p_ev_coronagraph": "coronagraph",
	"p_ev_particle": "particle_det",
	"p_ev_magnetometer": "magnetometer",
	"p_bl_electrolyser": "electrolyser",
	"p_bl_compost": "composter",
	"p_bl_beehive": "beehive",
	"p_lc_forklift": "forklift",
	"p_lc_hold_crane": "hold_crane",
	# R2 reference ships
	"p_scanner": "xray_scanner",
	"p_mail": "mail_sorter",
	"p_fdr": "blackbox",
	"p_winch": "tow_winch",
	"p_sail_winch": "tow_winch",
	"p_lathe": "lathe",
	"p_hyd_pump": "hpu",
	"p_spray": "spray_bar",
	"p_microscope": "microscope",
	"p_co2": "co2_scrubber",
	"p_uv_steriliser": "uv_steriliser",
	"p_humidity": "humidifier",
	"p_ref_plant": "ref_plant",
	"p_evaporator": "evaporator",
	"p_forklift": "forklift",
	"p_safe_box": "safe_deposit",
	"p_armory": "gun_rack",
	"p_biometric": "biometric",
	"p_separator": "separator_3ph",
	"p_level_radar": "level_radar",
	"p_flow_meter": "coriolis",
	"p_manifold": "manifold",
	"p_optics": "ir_camera",
	"p_inertial_unit": "imu",
	"p_align_bench": "iso_table",
	"p_furnace_core": "arc_furnace",
	"p_ingot_rack": "ingot_rack",
	"p_sorter": "eddy_sorter",
	"p_mag_sep": "mag_separator",
	"p_scrubber": "scrubber",
	"p_spectro": "spectrograph",
	"p_heat_pump": "chiller",
	"p_car": "car",
	"p_deck_tractor": "deck_tractor",
	"p_apu": "apu",
	"p_escape_pod": "escape_pod",
	# the odd-shaped ships
	"p_crane_trolley": "hold_crane",
	"p_ntr_core": "ntr_core",
	"p_control_drum": "control_drum",
	"p_rad_shield": "shadow_shield",
	"p_flywheel": "flywheel_rotor",
	"p_launch_cradle": "launch_cradle",
	"p_tether_damper": "tether_damper",
	"p_hyd_clamp": "hyd_clamp",
	"p_piano": "piano",
	"p_wine_wall": "wine_rack",
	"p_bar": "bar",
	# the early ships
	"p_reactor": "pwr_core",
	"p_crusher": "crusher",
	"p_screener": "shaker",
	"p_reliq": "cold_box_h2",
	"p_n2gen": "psa",
	"p_o2_gen": "psa",
	"p_bog": "screw_comp",
	"p_valve_block": "manifold",
}

const DRAWN := ["top_drive", "drawworks", "crown_block", "travel_block", "rotary_table", "drillpipe", "bha", "mud_pump",
	"shaker", "hydrocyclone", "degasser", "decanter", "gas_buster", "agitator", "roughneck", "pipe_rack", "pipe_bundle",
	"bop", "lathe", "mill", "standpipe", "choke_manifold", "koomey", "axial_comp", "screw_comp", "cold_box_h2", "ortho_para", "precooler", "psa", "gc", "mass_spec", "turboexpander", "dr_stage", "qpu", "pulse_tube", "ghs", "iso_table", "instrument_rack", "turbo_pump", "scroll_pump", "hexapod", "aft_optics", "fsm", "ir_camera", "spectrograph", "fgs", "wfs", "recoater", "reaction_wheel", "star_tracker", "immersion_rack", "cdu", "dry_cooler", "storage_array", "switch_chassis", "drive_carrier", "pwr_core", "rcp", "pressurizer", "crdm", "steam_turbine", "condenser", "despin_brake", "slip_ring", "rotary_seal", "spoke_lift", "work_vehicle", "food_module", "turbopump", "coronagraph", "particle_det", "magnetometer", "electrolyser", "composter", "beehive", "forklift", "hold_crane", "xray_scanner", "mail_sorter", "tow_winch", "spray_bar", "microscope", "co2_scrubber", "uv_steriliser", "humidifier", "ref_plant", "evaporator", "safe_deposit", "gun_rack", "biometric", "separator_3ph", "level_radar", "coriolis", "imu", "arc_furnace", "ingot_rack", "eddy_sorter", "mag_separator", "scrubber", "car", "deck_tractor", "apu", "escape_pod", "ntr_core", "control_drum", "shadow_shield", "flywheel_rotor", "launch_cradle", "tether_damper", "hyd_clamp", "piano", "wine_rack", "bar", "crusher"]


static func L(ci: CanvasItem, a: Vector2, b: Vector2, al: float = 0.5, wd: float = 1.0) -> void:
	E.L(ci, a, b, al, wd)


static func R(ci: CanvasItem, r: Rect2, al: float = 0.5, wd: float = 1.0) -> void:
	E.R(ci, r, al, wd)


static func O(ci: CanvasItem, c: Vector2, r: float, al: float = 0.5, wd: float = 1.0) -> void:
	E.O(ci, c, r, al, wd)


static func A(ci: CanvasItem, c: Vector2, r: float, a0: float, a1: float, al: float = 0.5, wd: float = 1.0) -> void:
	E.A(ci, c, r, a0, a1, al, wd)


static func D(ci: CanvasItem, c: Vector2, r: float = 1.1, al: float = 0.5) -> void:
	E.D(ci, c, r, al)


static func P(ci: CanvasItem, pts: PackedVector2Array, al: float = 0.5, wd: float = 1.0) -> void:
	E.P(ci, pts, al, wd)


static func S(ci: CanvasItem, segs: PackedVector2Array, al: float = 0.3, wd: float = 1.0) -> void:
	E.S(ci, segs, al, wd)


static func sub(r: Rect2, x0: float, y0: float, x1: float, y1: float) -> Rect2:
	return E.sub(r, x0, y0, x1, y1)


static func hatch(ci: CanvasItem, r: Rect2, pitch: float, vert: bool, al: float = 0.22, cap: int = 120) -> void:
	E.hatch(ci, r, pitch, vert, al, cap)


static func _draw_art(ci: CanvasItem, art: String, r: Rect2, p, font: Font) -> void:
	match art:
		"top_drive": top_drive(ci, r)
		"drawworks": drawworks(ci, r)
		"crown_block": crown_block(ci, r)
		"travel_block": travel_block(ci, r)
		"rotary_table": rotary_table(ci, r)
		"drillpipe": drillpipe(ci, r)
		"bha": bha(ci, r)
		"mud_pump": mud_pump(ci, r)
		"shaker": shaker(ci, r)
		"hydrocyclone": hydrocyclone(ci, r)
		"degasser": degasser(ci, r)
		"decanter": decanter(ci, r)
		"gas_buster": gas_buster(ci, r)
		"agitator": agitator(ci, r)
		"roughneck": roughneck(ci, r)
		"pipe_rack": pipe_rack(ci, r)
		"pipe_bundle": pipe_bundle(ci, r)
		"bop": bop(ci, r)
		"lathe": lathe(ci, r)
		"mill": mill(ci, r)
		"standpipe": standpipe(ci, r)
		"choke_manifold": choke_manifold(ci, r)
		"koomey": koomey(ci, r)
		"axial_comp": axial_comp(ci, r)
		"screw_comp": screw_comp(ci, r)
		"cold_box_h2": cold_box_h2(ci, r)
		"ortho_para": ortho_para(ci, r)
		"precooler": precooler(ci, r)
		"psa": psa(ci, r)
		"gc": gc(ci, r)
		"mass_spec": mass_spec(ci, r)
		"turboexpander": turboexpander(ci, r)
		"dr_stage": dr_stage(ci, r, p)
		"qpu": qpu(ci, r)
		"pulse_tube": pulse_tube(ci, r)
		"ghs": ghs(ci, r)
		"iso_table": iso_table(ci, r)
		"instrument_rack": instrument_rack(ci, r)
		"turbo_pump": turbo_pump(ci, r)
		"scroll_pump": scroll_pump(ci, r)
		"hexapod": hexapod(ci, r)
		"aft_optics": aft_optics(ci, r)
		"fsm": fsm(ci, r)
		"ir_camera": ir_camera(ci, r)
		"spectrograph": spectrograph(ci, r)
		"fgs": fgs(ci, r)
		"wfs": wfs(ci, r)
		"recoater": recoater(ci, r)
		"reaction_wheel": reaction_wheel(ci, r)
		"star_tracker": star_tracker(ci, r)
		"immersion_rack": immersion_rack(ci, r)
		"cdu": cdu(ci, r)
		"dry_cooler": dry_cooler(ci, r)
		"storage_array": storage_array(ci, r)
		"switch_chassis": switch_chassis(ci, r)
		"drive_carrier": drive_carrier(ci, r)
		"pwr_core": pwr_core(ci, r)
		"rcp": rcp(ci, r)
		"pressurizer": pressurizer(ci, r)
		"crdm": crdm(ci, r)
		"steam_turbine": steam_turbine(ci, r)
		"condenser": condenser(ci, r)
		"despin_brake": despin_brake(ci, r)
		"slip_ring": slip_ring(ci, r)
		"rotary_seal": rotary_seal(ci, r)
		"spoke_lift": spoke_lift(ci, r)
		"work_vehicle": work_vehicle(ci, r)
		"food_module": food_module(ci, r)
		"turbopump": turbopump(ci, r)
		"coronagraph": coronagraph(ci, r)
		"particle_det": particle_det(ci, r)
		"magnetometer": magnetometer(ci, r)
		"electrolyser": electrolyser(ci, r)
		"composter": composter(ci, r)
		"beehive": beehive(ci, r)
		"forklift": forklift(ci, r)
		"hold_crane": hold_crane(ci, r)
		"xray_scanner": xray_scanner(ci, r)
		"mail_sorter": mail_sorter(ci, r)
		"tow_winch": tow_winch(ci, r)
		"spray_bar": spray_bar(ci, r)
		"microscope": microscope(ci, r)
		"co2_scrubber": co2_scrubber(ci, r)
		"uv_steriliser": uv_steriliser(ci, r)
		"humidifier": humidifier(ci, r)
		"ref_plant": ref_plant(ci, r)
		"evaporator": evaporator(ci, r)
		"safe_deposit": safe_deposit(ci, r)
		"gun_rack": gun_rack(ci, r)
		"biometric": biometric(ci, r)
		"separator_3ph": separator_3ph(ci, r)
		"level_radar": level_radar(ci, r)
		"coriolis": coriolis(ci, r)
		"imu": imu(ci, r)
		"arc_furnace": arc_furnace(ci, r)
		"ingot_rack": ingot_rack(ci, r)
		"eddy_sorter": eddy_sorter(ci, r)
		"mag_separator": mag_separator(ci, r)
		"scrubber": scrubber(ci, r)
		"car": car(ci, r)
		"deck_tractor": deck_tractor(ci, r)
		"apu": apu(ci, r)
		"escape_pod": escape_pod(ci, r)
		"ntr_core": ntr_core(ci, r)
		"control_drum": control_drum(ci, r)
		"shadow_shield": shadow_shield(ci, r)
		"flywheel_rotor": flywheel_rotor(ci, r)
		"launch_cradle": launch_cradle(ci, r)
		"tether_damper": tether_damper(ci, r)
		"hyd_clamp": hyd_clamp(ci, r)
		"piano": piano(ci, r)
		"wine_rack": wine_rack(ci, r)
		"bar": bar(ci, r)
		"crusher": crusher(ci, r)


# ================================================================== DR-150 Derrick

# a top drive: the bails up to the travelling block, the gooseneck and wash pipe
# the mud comes in through, two drive motors on top of the gearbox, the main shaft
# with its two IBOP valves, the pipe handler (link-tilt arms, elevator) below, the
# guide dolly riding the derrick rail
static func top_drive(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cx: float = w * 0.55
	# bails
	L(ci, Vector2(cx - w * 0.12, 0), Vector2(cx - w * 0.2, h * 0.18), 0.5, 1.4)
	L(ci, Vector2(cx + w * 0.12, 0), Vector2(cx + w * 0.2, h * 0.18), 0.5, 1.4)
	# motors with their fins
	for k in 2:
		var m := Rect2(cx - w * 0.3 + k * w * 0.32, h * 0.08, w * 0.26, h * 0.26)
		R(ci, m, 0.55)
		hatch(ci, E.inset(m, 2.0), 3.0, true, 0.22, 12)
		R(ci, Rect2(m.position.x + m.size.x * 0.3, m.position.y - h * 0.04, m.size.x * 0.4, h * 0.04), 0.45)
	# gooseneck and wash pipe
	P(ci, PackedVector2Array([Vector2(w * 0.04, h * 0.05), Vector2(w * 0.12, h * 0.02), Vector2(w * 0.2, h * 0.08), Vector2(w * 0.2, h * 0.36)]), 0.5, 1.4)
	L(ci, Vector2(w * 0.2, h * 0.36), Vector2(cx - w * 0.1, h * 0.36), 0.45)
	# gearbox
	var gb := Rect2(cx - w * 0.34, h * 0.34, w * 0.68, h * 0.2)
	R(ci, gb, 0.6, 1.2)
	O(ci, gb.get_center(), gb.size.y * 0.32, 0.45)
	O(ci, gb.get_center() + Vector2(-gb.size.x * 0.28, 0), gb.size.y * 0.2, 0.4)
	O(ci, gb.get_center() + Vector2(gb.size.x * 0.28, 0), gb.size.y * 0.2, 0.4)
	# shaft, IBOPs, saver sub
	L(ci, Vector2(cx - 2.0, gb.end.y), Vector2(cx - 2.0, h * 0.82), 0.55)
	L(ci, Vector2(cx + 2.0, gb.end.y), Vector2(cx + 2.0, h * 0.82), 0.55)
	for f in [0.6, 0.68]:
		R(ci, Rect2(cx - 4.0, h * f, 8.0, h * 0.05), 0.55)
		L(ci, Vector2(cx + 4.0, h * f + h * 0.025), Vector2(cx + 8.0, h * f + h * 0.025), 0.45)
	# pipe handler: link-tilt arms down to the elevator
	for s in [-1.0, 1.0]:
		L(ci, Vector2(cx + s * w * 0.14, gb.end.y), Vector2(cx + s * w * 0.18, h * 0.88), 0.45)
	var el := Rect2(cx - w * 0.2, h * 0.88, w * 0.4, h * 0.1)
	R(ci, el, 0.55)
	L(ci, Vector2(cx, el.position.y), Vector2(cx, el.end.y), 0.4)
	# guide dolly on the rail (left)
	var dl := Rect2(0, h * 0.3, w * 0.12, h * 0.4)
	R(ci, dl, 0.5)
	for f in [0.38, 0.62]:
		O(ci, Vector2(w * 0.06, h * f), minf(w * 0.04, 3.0), 0.5)
	L(ci, Vector2(dl.end.x, h * 0.44), Vector2(gb.position.x, h * 0.44), 0.45, 1.4)


# drawworks: the grooved drum between its flanges, the drill line spooled on it
# and running up to the crown, the disc brake with its calipers, the AC motor and
# gearbox driving it, the skid
static func drawworks(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var base_y: float = h * 0.92
	L(ci, Vector2(2, base_y), Vector2(w - 2, base_y), 0.55, 1.6)
	E.hatch(ci, Rect2(4, base_y + 1.0, w - 8, h - base_y - 2.0), 6.0, true, 0.2, 30)
	var dr: float = minf(h * 0.36, w * 0.24)
	var c := Vector2(w * 0.36, base_y - dr - h * 0.06)
	# brake disc behind the drum, calipers gripping its rim
	O(ci, c, dr * 1.12, 0.45)
	for a in [-PI * 0.5, -PI * 0.15]:
		var q: Vector2 = c + Vector2.from_angle(a) * dr * 1.12
		R(ci, Rect2(q - Vector2(4, 4), Vector2(8, 8)), 0.6)
	# the drum: flanges, grooves, wraps of line
	O(ci, c, dr, 0.6, 1.2)
	O(ci, c, dr * 0.62, 0.5)
	for k in 4:
		O(ci, c, dr * (0.68 + k * 0.07), 0.22)
	O(ci, c, dr * 0.14, 0.55)
	# the fast line leaving the top of the drum up to the crown
	L(ci, c + Vector2(dr * 0.2, -dr * 0.88), Vector2(w * 0.7, 0), 0.5, 1.4)
	# drum stand
	L(ci, c + Vector2(-dr * 0.5, dr * 0.85), Vector2(c.x - dr * 0.9, base_y), 0.45, 1.4)
	L(ci, c + Vector2(dr * 0.5, dr * 0.85), Vector2(c.x + dr * 0.9, base_y), 0.45, 1.4)
	# gearbox and motor
	var gb := Rect2(c.x + dr * 1.2, base_y - h * 0.42, w * 0.14, h * 0.4)
	R(ci, gb, 0.5)
	O(ci, gb.get_center(), gb.size.x * 0.3, 0.4)
	E.motor(ci, Rect2(gb.end.x, base_y - h * 0.4, w - gb.end.x - 4.0, h * 0.34), true, 0.5)


# the crown block: the row of sheaves on their shaft in the frame, the bumper
# timbers above, the line reeved over them
static func crown_block(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, 1, w - 2, h * 0.16), 0.55)
	E.hatch(ci, Rect2(3, 2, w - 6, h * 0.14), 4.0, true, 0.2, 40)
	var n := clampi(int(w / maxf(h * 0.75, 10.0)), 2, 8)
	var sw: float = w / n
	var sr: float = minf(sw * 0.42, h * 0.36)
	for i in n:
		var c := Vector2((i + 0.5) * sw, h * 0.58)
		O(ci, c, sr, 0.55, 1.2)
		O(ci, c, sr * 0.82, 0.3)
		D(ci, c, 1.3, 0.6)
		L(ci, c + Vector2(-sr, 0), Vector2(c.x - sr, h), 0.35)
		L(ci, c + Vector2(sr, 0), Vector2(c.x + sr, h), 0.35)
	L(ci, Vector2(sw * 0.5, h * 0.58), Vector2(w - sw * 0.5, h * 0.58), 0.4)
	for x in [2.0, w - 2.0]:
		L(ci, Vector2(x, h * 0.16), Vector2(x, h - 1.0), 0.5, 1.4)


# the travelling block: the becket, cheek plates round the sheaves, the line
# running down and up over them, the bail at its foot
static func travel_block(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cx: float = w * 0.5
	var sr: float = minf(w * 0.38, h * 0.16)
	var body := PackedVector2Array([Vector2(cx - sr * 1.2, h * 0.12), Vector2(cx + sr * 1.2, h * 0.12), Vector2(cx + sr * 1.25, h * 0.62), Vector2(cx + sr * 0.6, h * 0.76), Vector2(cx - sr * 0.6, h * 0.76), Vector2(cx - sr * 1.25, h * 0.62), Vector2(cx - sr * 1.2, h * 0.12)])
	P(ci, body, 0.6, 1.2)
	for k in 2:
		var c := Vector2(cx, h * (0.26 + k * 0.22))
		O(ci, c, sr, 0.5)
		O(ci, c, sr * 0.78, 0.25)
		D(ci, c, 1.3, 0.6)
	# lines in and out of the top
	for s in [-0.7, -0.25, 0.25, 0.7]:
		L(ci, Vector2(cx + s * sr, 0), Vector2(cx + s * sr, h * 0.12), 0.4)
	# the bail and its clevis
	A(ci, Vector2(cx, h * 0.84), sr * 0.7, 0.0, PI, 0.55, 1.6)
	L(ci, Vector2(cx - sr * 0.7, h * 0.84), Vector2(cx - sr * 0.7, h * 0.76), 0.5, 1.4)
	L(ci, Vector2(cx + sr * 0.7, h * 0.84), Vector2(cx + sr * 0.7, h * 0.76), 0.5, 1.4)
	R(ci, Rect2(cx - sr * 0.3, h * 0.94, sr * 0.6, h * 0.05), 0.55)


# the rotary table set in the drill floor: its housing, the turntable with its
# ring gear, the master bushing round the string's bore, the drive pinion
static func rotary_table(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cx: float = w * (49.6 + 0.4 - 48.6) / 2.8
	var bore: float = w * 0.8 / 2.8 * 0.5 + 1.0
	R(ci, Rect2(w * 0.04, h * 0.2, w * 0.92, h * 0.7), 0.5)
	# turntable top and its ring gear
	L(ci, Vector2(cx - w * 0.36, h * 0.2), Vector2(cx + w * 0.36, h * 0.2), 0.65, 1.8)
	E.hatch(ci, Rect2(cx - w * 0.34, h * 0.32, w * 0.68, h * 0.22), 3.0, true, 0.3, 80)
	# master bushing round the bore, and the bore itself
	R(ci, Rect2(cx - bore - w * 0.06, h * 0.12, w * 0.12 + bore * 2.0, h * 0.4), 0.55)
	L(ci, Vector2(cx - bore, 0), Vector2(cx - bore, h), 0.45)
	L(ci, Vector2(cx + bore, 0), Vector2(cx + bore, h), 0.45)
	# drive pinion and its shaft out to the side
	O(ci, Vector2(w * 0.88, h * 0.55), h * 0.18, 0.5)
	L(ci, Vector2(w * 0.88, h * 0.55), Vector2(w - 1.0, h * 0.55), 0.5, 1.4)
	for x in [w * 0.12, w * 0.7]:
		D(ci, Vector2(x, h * 0.75), 1.1, 0.5)


# a stand of drill pipe: three joints, their tool joints (box above, pin below)
# with the hardbanding round them
static func drillpipe(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var vert: bool = h >= w
	var ln: float = h if vert else w
	var th: float = w if vert else h
	var X := func(u: float, v: float) -> Vector2: return Vector2(v, u) if vert else Vector2(u, v)
	var segs := PackedVector2Array()
	segs.append(X.call(0.0, th * 0.3))
	segs.append(X.call(ln, th * 0.3))
	segs.append(X.call(0.0, th * 0.7))
	segs.append(X.call(ln, th * 0.7))
	S(ci, segs, 0.55)
	var tj: float = minf(th * 0.5, ln * 0.06)
	for k in 4:
		var u: float = ln * k / 3.0
		var u0: float = clampf(u - tj * 0.5, 0.0, ln - tj)
		R(ci, Rect2(X.call(u0, th * 0.12), X.call(u0 + tj, th * 0.88) - X.call(u0, th * 0.12)).abs(), 0.6)
		L(ci, X.call(u0 + tj * 0.3, th * 0.12), X.call(u0 + tj * 0.3, th * 0.88), 0.3)
		L(ci, X.call(u0 + tj * 0.7, th * 0.12), X.call(u0 + tj * 0.7, th * 0.88), 0.3)
		if k > 0 and k < 3:
			L(ci, X.call(u0 - tj * 0.3, th * 0.3), X.call(u0, th * 0.12), 0.4)
			L(ci, X.call(u0 - tj * 0.3, th * 0.7), X.call(u0, th * 0.88), 0.4)
	L(ci, X.call(0.0, th * 0.5), X.call(ln, th * 0.5), 0.12)


# the bottom-hole assembly: drill collars, a stabiliser with its spiral blades,
# the MWD tool, the core barrel and at its foot the core bit
static func bha(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cx: float = w * 0.5
	var cw: float = w * 0.32
	L(ci, Vector2(cx - cw, 0), Vector2(cx - cw, h * 0.86), 0.6)
	L(ci, Vector2(cx + cw, 0), Vector2(cx + cw, h * 0.86), 0.6)
	# collar connections
	for f in [0.18, 0.36]:
		L(ci, Vector2(cx - cw, h * f), Vector2(cx + cw, h * f), 0.45)
	# MWD tool: its window and pulser
	E.R(ci, Rect2(cx - cw * 0.5, h * 0.04, cw, h * 0.1), 0.45)
	D(ci, Vector2(cx, h * 0.09), 1.2, 0.6)
	# stabiliser: wider, spiral blades
	var st := Rect2(cx - w * 0.46, h * 0.42, w * 0.92, h * 0.14)
	R(ci, st, 0.55)
	var segs := PackedVector2Array()
	for k in 3:
		var x0: float = st.position.x + st.size.x * (0.1 + k * 0.3)
		segs.append(Vector2(x0, st.position.y + 1.0))
		segs.append(Vector2(x0 + st.size.x * 0.22, st.end.y - 1.0))
	S(ci, segs, 0.45)
	# core barrel (inner tube shown)
	L(ci, Vector2(cx - cw * 0.45, h * 0.58), Vector2(cx - cw * 0.45, h * 0.86), 0.3)
	L(ci, Vector2(cx + cw * 0.45, h * 0.58), Vector2(cx + cw * 0.45, h * 0.86), 0.3)
	# core bit: the crown with its cutters, the throat for the core
	P(ci, PackedVector2Array([Vector2(cx - cw, h * 0.86), Vector2(cx - cw * 1.15, h * 0.92), Vector2(cx - cw * 0.9, h * 0.99), Vector2(cx - cw * 0.35, h * 0.99), Vector2(cx - cw * 0.35, h * 0.9)]), 0.6, 1.2)
	P(ci, PackedVector2Array([Vector2(cx + cw, h * 0.86), Vector2(cx + cw * 1.15, h * 0.92), Vector2(cx + cw * 0.9, h * 0.99), Vector2(cx + cw * 0.35, h * 0.99), Vector2(cx + cw * 0.35, h * 0.9)]), 0.6, 1.2)
	for k in 4:
		D(ci, Vector2(cx + (-0.85 + k * 0.55) * cw if k < 2 else cx + (0.35 + (k - 2) * 0.5) * cw, h * 0.98), 1.0, 0.7)


# a triplex mud pump side-on: the power end (crankcase, the bull gear and its
# pinion), the three crosshead extension rods, the fluid end with its three valve
# covers, the pulsation dampener on the discharge, the suction manifold below,
# the drive motor on top with its belt guard
static func mud_pump(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var base_y: float = h * 0.94
	L(ci, Vector2(2, base_y), Vector2(w - 2, base_y), 0.55, 1.6)
	# power end
	var pe := Rect2(w * 0.5, h * 0.38, w * 0.46, base_y - h * 0.38)
	R(ci, pe, 0.6, 1.2)
	var bg := Vector2(pe.position.x + pe.size.x * 0.58, pe.position.y + pe.size.y * 0.5)
	var br: float = minf(pe.size.x, pe.size.y) * 0.36
	O(ci, bg, br, 0.5)
	O(ci, bg, br * 0.86, 0.22)
	D(ci, bg, 1.4, 0.6)
	O(ci, bg + Vector2(-br * 1.0, -br * 0.65), br * 0.28, 0.45)
	# rods
	var segs := PackedVector2Array()
	for k in 3:
		var y: float = pe.position.y + pe.size.y * (0.25 + k * 0.25)
		segs.append(Vector2(w * 0.3, y))
		segs.append(Vector2(pe.position.x, y))
	S(ci, segs, 0.5, 1.4)
	# fluid end: block, three valve covers on top, discharge manifold, dampener
	var fe := Rect2(w * 0.06, h * 0.42, w * 0.26, base_y - h * 0.46)
	R(ci, fe, 0.6, 1.2)
	for k in 3:
		var y: float = pe.position.y + pe.size.y * (0.25 + k * 0.25)
		R(ci, Rect2(fe.end.x - 3.0, y - 3.0, 6.0, 6.0), 0.5)
	L(ci, Vector2(fe.position.x, h * 0.38), Vector2(fe.end.x, h * 0.38), 0.55, 1.6)
	for k in 3:
		var x: float = fe.position.x + fe.size.x * (0.2 + k * 0.3)
		L(ci, Vector2(x, h * 0.38), Vector2(x, fe.position.y), 0.45)
	var dc := Vector2(fe.position.x + fe.size.x * 0.5, h * 0.22)
	O(ci, dc, minf(w * 0.08, h * 0.1), 0.55, 1.2)
	L(ci, dc + Vector2(0, minf(w * 0.08, h * 0.1)), Vector2(dc.x, h * 0.38), 0.5, 1.4)
	L(ci, Vector2(fe.position.x, h * 0.38), Vector2(1, h * 0.38), 0.5)
	# suction manifold below the fluid end
	L(ci, Vector2(1, base_y - h * 0.06), Vector2(fe.end.x, base_y - h * 0.06), 0.45)
	# the motor on top with its belt guard down to the pinion
	E.motor(ci, Rect2(w * 0.52, h * 0.06, w * 0.42, h * 0.22), false, 0.5)
	P(ci, PackedVector2Array([Vector2(w * 0.9, h * 0.17), Vector2(w * 0.98, h * 0.2), Vector2(bg.x - br * 0.6 + br * 0.6, pe.position.y + 1.0)]), 0.35)


# a shale shaker: the basket on its springs, tilted, with its screen panels; the
# two vibrator motors on the basket, the feeder at the back, the discharge lip
# and the underflow tray beneath
static func shaker(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var b0 := Vector2(w * 0.18, h * 0.4)
	var b1 := Vector2(w * 0.96, h * 0.3)
	P(ci, PackedVector2Array([b0, b1, b1 + Vector2(0, h * 0.2), b0 + Vector2(0, h * 0.22), b0]), 0.6, 1.2)
	# screens: zigzag panels along the deck
	var n := clampi(int(w / 14.0), 3, 8)
	for k in n:
		var a: Vector2 = b0.lerp(b1, float(k) / n) + Vector2(0, h * 0.04)
		var b: Vector2 = b0.lerp(b1, float(k + 1) / n) + Vector2(0, h * 0.04)
		var pts := PackedVector2Array()
		for e in 7:
			pts.append(a.lerp(b, e / 6.0) + Vector2(0, (1.5 if e % 2 == 0 else -1.5)))
		P(ci, pts, 0.35)
	# vibrators
	for f in [0.4, 0.72]:
		var q: Vector2 = b0.lerp(b1, f) + Vector2(0, -h * 0.1)
		O(ci, q, minf(w * 0.06, h * 0.08), 0.55)
		L(ci, q + Vector2(0, minf(w * 0.06, h * 0.08)), b0.lerp(b1, f), 0.45)
	# feeder (possum belly) at the back
	P(ci, PackedVector2Array([Vector2(2, h * 0.2), Vector2(w * 0.18, h * 0.2), Vector2(w * 0.18, h * 0.55), Vector2(w * 0.06, h * 0.55), Vector2(2, h * 0.4), Vector2(2, h * 0.2)]), 0.5)
	L(ci, Vector2(w * 0.04, 0), Vector2(w * 0.04, h * 0.2), 0.45, 1.4)
	# springs
	for f in [0.25, 0.85]:
		var q: Vector2 = b0.lerp(b1, f) + Vector2(0, h * 0.22)
		var pts := PackedVector2Array()
		for e in 6:
			pts.append(q + Vector2(2.5 if e % 2 == 0 else -2.5, e * h * 0.03))
		P(ci, pts, 0.45)
	# underflow tray and the frame
	P(ci, PackedVector2Array([Vector2(w * 0.14, h * 0.7), Vector2(w * 0.2, h * 0.92), Vector2(w * 0.9, h * 0.92), Vector2(w * 0.98, h * 0.7)]), 0.5)
	L(ci, Vector2(w * 0.5, h * 0.92), Vector2(w * 0.5, h), 0.45)
	L(ci, b1 + Vector2(0, h * 0.1), b1 + Vector2(w * 0.04, h * 0.18), 0.4)


# hydrocyclones (desander): the cones standing on the feed manifold's branches,
# their vortex finders up into the overflow header, the apexes over the trough
static func hydrocyclone(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var n := clampi(roundi(w / (h * 0.32)), 1, 6)
	var cw: float = w / n
	L(ci, Vector2(2, h * 0.08), Vector2(w - 2, h * 0.08), 0.55, 1.6)
	L(ci, Vector2(2, h * 0.24), Vector2(w - 2, h * 0.24), 0.5, 1.4)
	for i in n:
		var cx: float = (i + 0.5) * cw
		var rr: float = cw * 0.32
		R(ci, Rect2(cx - rr, h * 0.28, rr * 2.0, h * 0.12), 0.55)
		P(ci, PackedVector2Array([Vector2(cx - rr, h * 0.4), Vector2(cx - rr * 0.18, h * 0.84), Vector2(cx + rr * 0.18, h * 0.84), Vector2(cx + rr, h * 0.4)]), 0.55)
		L(ci, Vector2(cx, h * 0.08), Vector2(cx, h * 0.34), 0.45)
		L(ci, Vector2(cx - rr, h * 0.33), Vector2(cx - rr * 1.6, h * 0.24), 0.45)
		L(ci, Vector2(cx - rr * 0.1, h * 0.86), Vector2(cx - rr * 0.1, h * 0.9), 0.5)
	P(ci, PackedVector2Array([Vector2(2, h * 0.88), Vector2(w * 0.06, h * 0.98), Vector2(w * 0.94, h * 0.98), Vector2(w - 2, h * 0.88)]), 0.5)


# a vacuum degasser: the vessel with its inclined baffle plates the mud thins out
# over, the vacuum pump and its gas line, the jet discharge at the foot
static func degasser(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var vs := Rect2(w * 0.08, h * 0.04, w * 0.58, h * 0.82)
	var sh := E.vessel_v(ci, vs, 0.55)
	var n := clampi(int(sh.size.y / 9.0), 2, 8)
	for k in n:
		var y: float = sh.position.y + (k + 0.6) * sh.size.y / (n + 0.4)
		if k % 2 == 0:
			L(ci, Vector2(sh.position.x + 1.0, y), Vector2(sh.end.x - sh.size.x * 0.25, y + sh.size.y * 0.06), 0.4)
		else:
			L(ci, Vector2(sh.end.x - 1.0, y), Vector2(sh.position.x + sh.size.x * 0.25, y + sh.size.y * 0.06), 0.4)
	var pc := Vector2(w * 0.84, h * 0.3)
	E.volute(ci, pc, minf(w * 0.13, h * 0.1), true, 0.5)
	L(ci, Vector2(vs.end.x, vs.position.y + vs.size.y * 0.1), pc + Vector2(-minf(w * 0.13, h * 0.1), 0), 0.4)
	R(ci, Rect2(w * 0.72, h * 0.46, w * 0.24, h * 0.18), 0.45)
	L(ci, Vector2(vs.get_center().x, vs.end.y), Vector2(vs.get_center().x, h - 1.0), 0.5, 1.4)
	L(ci, Vector2(vs.get_center().x, h - 2.0), Vector2(w - 1.0, h - 2.0), 0.45)


# a decanter centrifuge on its skid: the bowl (cylinder into cone), the scroll
# flights inside it, the gearbox on one end, the feed tube in the other, the main
# motor below driving it by belts, the solids and liquid discharge chutes
static func decanter(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var ay: float = h * 0.34
	var br: float = minf(h * 0.16, w * 0.14)
	var x0: float = w * 0.14
	var x1: float = w * 0.62
	var x2: float = w * 0.88
	P(ci, PackedVector2Array([Vector2(x0, ay - br), Vector2(x1, ay - br), Vector2(x2, ay - br * 0.45), Vector2(x2, ay + br * 0.45), Vector2(x1, ay + br), Vector2(x0, ay + br), Vector2(x0, ay - br)]), 0.6, 1.2)
	var segs := PackedVector2Array()
	var nf := clampi(int((x2 - x0) / 6.0), 3, 24)
	for k in nf:
		var x: float = x0 + 2.0 + k * (x2 - x0 - 4.0) / nf
		var rr: float = br * (1.0 if x < x1 else lerpf(1.0, 0.45, (x - x1) / (x2 - x1))) * 0.85
		segs.append(Vector2(x, ay - rr))
		segs.append(Vector2(x + 4.0, ay + rr))
	S(ci, segs, 0.3)
	L(ci, Vector2(x0, ay), Vector2(x2 + w * 0.08, ay), 0.3)
	# gearbox end and feed end
	R(ci, Rect2(w * 0.02, ay - br * 0.8, x0 - w * 0.02, br * 1.6), 0.55)
	O(ci, Vector2(w * 0.08, ay), br * 0.45, 0.45)
	L(ci, Vector2(x2, ay), Vector2(w - 1.0, ay), 0.5, 1.4)
	# the cover over it all and the chutes
	P(ci, PackedVector2Array([Vector2(x0 - 2.0, ay + br + 3.0), Vector2(x0 - 2.0, ay - br - 4.0), Vector2(x2 + 2.0, ay - br - 4.0), Vector2(x2 + 2.0, ay + br + 3.0)]), 0.35)
	L(ci, Vector2(x2 - 4.0, ay + br * 0.6), Vector2(x2 - 8.0, h * 0.62), 0.45)
	L(ci, Vector2(x0 + 6.0, ay + br), Vector2(x0 + 2.0, h * 0.62), 0.45)
	# skid, motor below, belts
	L(ci, Vector2(2, h * 0.62), Vector2(w - 2, h * 0.62), 0.5, 1.4)
	E.motor(ci, Rect2(w * 0.3, h * 0.66, w * 0.5, h * 0.24), false, 0.5)
	L(ci, Vector2(w * 0.08, ay + br * 0.45), Vector2(w * 0.26, h * 0.7), 0.35)
	L(ci, Vector2(w * 0.08, ay - br * 0.2), Vector2(w * 0.3, h * 0.82), 0.35)
	L(ci, Vector2(2, h * 0.97), Vector2(w - 2, h * 0.97), 0.5, 1.4)


# a mud-gas separator ("poor boy"): the tall vessel with its staggered baffle
# plates, the inlet on the side, the vent line up out of the top, the U-tube mud
# leg out of the bottom
static func gas_buster(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var vs := Rect2(w * 0.24, h * 0.1, w * 0.46, h * 0.72)
	var sh := E.vessel_v(ci, vs, 0.6)
	var n := clampi(int(sh.size.y / 8.0), 3, 10)
	for k in n:
		var y: float = sh.position.y + sh.size.y * (0.2 + 0.7 * k / n)
		if k % 2 == 0:
			L(ci, Vector2(sh.position.x + 1.0, y), Vector2(sh.end.x - sh.size.x * 0.3, y), 0.4)
		else:
			L(ci, Vector2(sh.end.x - 1.0, y), Vector2(sh.position.x + sh.size.x * 0.3, y), 0.4)
	L(ci, Vector2(1, sh.position.y + sh.size.y * 0.15), Vector2(vs.position.x, sh.position.y + sh.size.y * 0.15), 0.5, 1.4)
	L(ci, Vector2(vs.get_center().x, vs.position.y), Vector2(vs.get_center().x, 0), 0.5, 1.4)
	P(ci, PackedVector2Array([Vector2(vs.get_center().x, vs.end.y), Vector2(vs.get_center().x, h * 0.96), Vector2(w * 0.86, h * 0.96), Vector2(w * 0.86, h * 0.7), Vector2(w - 1.0, h * 0.7)]), 0.5, 1.2)
	L(ci, Vector2(vs.position.x + 3.0, vs.end.y - 2.0), Vector2(vs.position.x - 2.0, h - 1.0), 0.45)
	L(ci, Vector2(vs.end.x - 3.0, vs.end.y - 2.0), Vector2(vs.end.x + 2.0, h - 1.0), 0.45)


# a mud agitator: the gearmotor on its mounting plate, the shaft down into the tank,
# the pitched-blade impeller at its foot
static func agitator(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cx: float = w * 0.5
	E.motor(ci, Rect2(w * 0.08, h * 0.04, w * 0.5, h * 0.18), false, 0.5)
	var gb := Rect2(cx - w * 0.1, h * 0.06, w * 0.38, h * 0.22)
	R(ci, gb, 0.55)
	O(ci, gb.get_center(), gb.size.y * 0.3, 0.4)
	L(ci, Vector2(w * 0.06, h * 0.3), Vector2(w * 0.94, h * 0.3), 0.6, 2.0)
	L(ci, Vector2(gb.get_center().x, h * 0.3), Vector2(gb.get_center().x, h * 0.86), 0.55, 1.6)
	var ic := Vector2(gb.get_center().x, h * 0.86)
	for s in [-1.0, 1.0]:
		P(ci, PackedVector2Array([ic, ic + Vector2(s * w * 0.32, -h * 0.05), ic + Vector2(s * w * 0.34, h * 0.03), ic]), 0.55)
	O(ci, ic, 2.0, 0.6)
	# the tank wall it hangs in, dashed
	var segs := PackedVector2Array()
	for k in 8:
		var y: float = h * (0.34 + k * 0.08)
		segs.append(Vector2(w * 0.04, y))
		segs.append(Vector2(w * 0.04, y + h * 0.04))
		segs.append(Vector2(w * 0.96, y))
		segs.append(Vector2(w * 0.96, y + h * 0.04))
	S(ci, segs, 0.25)


# an iron roughneck: the carriage on its rail, the arm folding out on parallel links,
# the wrench head (spinner above with its rollers, torque wrench below, its jaws)
static func roughneck(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(w * 0.04, h * 0.84, w * 0.5, h * 0.14), 0.55)
	for f in [0.12, 0.44]:
		O(ci, Vector2(w * f, h * 0.98), minf(w * 0.04, 3.0), 0.5)
	var j := Vector2(w * 0.2, h * 0.84)
	var e := Vector2(w * 0.38, h * 0.36)
	L(ci, j, e, 0.55, 1.6)
	L(ci, j + Vector2(w * 0.12, 0), e + Vector2(w * 0.12, 0), 0.45, 1.2)
	L(ci, Vector2(w * 0.42, h * 0.84), Vector2(w * 0.32, h * 0.56), 0.45)
	R(ci, Rect2(w * 0.3, h * 0.56, w * 0.06, h * 0.14), 0.45)
	# the wrench head
	var hd := Rect2(w * 0.5, h * 0.06, w * 0.46, h * 0.62)
	R(ci, hd, 0.6, 1.2)
	var sp := sub(hd, 0.08, 0.06, 0.92, 0.36)
	R(ci, sp, 0.5)
	for f in [0.25, 0.75]:
		O(ci, sp.position + sp.size * Vector2(f, 0.5), sp.size.y * 0.32, 0.45)
	var tw := sub(hd, 0.08, 0.44, 0.92, 0.92)
	R(ci, tw, 0.5)
	L(ci, tw.position + tw.size * Vector2(0, 0.5), tw.position + tw.size * Vector2(1, 0.5), 0.4)
	for f in [0.3, 0.7]:
		P(ci, PackedVector2Array([tw.position + tw.size * Vector2(f - 0.12, 0.15), tw.position + tw.size * Vector2(f, 0.35), tw.position + tw.size * Vector2(f + 0.12, 0.15)]), 0.45)
	L(ci, e + Vector2(w * 0.06, 0), Vector2(hd.position.x, h * 0.36), 0.5, 1.4)
	L(ci, Vector2(hd.get_center().x, hd.position.y), Vector2(hd.get_center().x, hd.end.y), 0.2)


# a pipe rack: stanchions, the pipe stacked between them end-on (each with its
# bore), the chocks
static func pipe_rack(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	for x in [2.0, w - 2.0]:
		L(ci, Vector2(x, 1), Vector2(x, h - 1), 0.55, 1.6)
	L(ci, Vector2(2, h - 2.0), Vector2(w - 2, h - 2.0), 0.55, 1.6)
	var pr: float = clampf(h * 0.13, 3.0, 9.0)
	var rows := clampi(int((h - 4.0) / (pr * 1.75)), 1, 6)
	for k in rows:
		var y: float = h - 4.0 - pr - k * pr * 1.75
		var off: float = pr if k % 2 == 1 else 0.0
		var n := int((w - 8.0 - off) / (pr * 2.05))
		for i in n:
			var c := Vector2(5.0 + off + pr + i * pr * 2.05, y)
			O(ci, c, pr, 0.5)
			O(ci, c, pr * 0.55, 0.3)
	L(ci, Vector2(2, h * 0.5), Vector2(w - 2, h * 0.5), 0.2)


# a bundle of casing joints end-on, strapped
static func pipe_bundle(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var pr: float = clampf(minf(w, h) * 0.16, 3.0, 10.0)
	var rows := clampi(int((h - 4.0) / (pr * 1.75)), 1, 6)
	for k in rows:
		var y: float = h - 3.0 - pr - k * pr * 1.75
		var off: float = pr if k % 2 == 1 else 0.0
		var n := int((w - 6.0 - off) / (pr * 2.05))
		for i in n:
			var c := Vector2(3.0 + off + pr + i * pr * 2.05, y)
			O(ci, c, pr, 0.5)
			O(ci, c, pr * 0.72, 0.28)
	for f in [0.2, 0.8]:
		L(ci, Vector2(w * f, 1), Vector2(w * f, h - 1), 0.45, 1.4)
	L(ci, Vector2(1, h - 1), Vector2(w - 1, h - 1), 0.5, 1.4)


# a blowout preventer stack on its skid: the annular preventer on top (its packing
# element), three ram preventers below it (pipe rams, the blind-shear rams with
# their bigger operators, pipe rams) each with bonnets and hydraulic cylinders
# out both sides, the choke and kill valves on the side outlets, the wellhead
# connector at the foot, the frame's guide posts and the two control pods
static func bop(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cx: float = w * 0.5
	var bw: float = w * 0.36
	# frame and guide posts
	for x in [w * 0.04, w * 0.96]:
		L(ci, Vector2(x, h * 0.04), Vector2(x, h * 0.97), 0.5, 1.4)
	L(ci, Vector2(w * 0.04, h * 0.97), Vector2(w * 0.96, h * 0.97), 0.55, 1.8)
	L(ci, Vector2(w * 0.04, h * 0.3), Vector2(w * 0.96, h * 0.3), 0.35)
	# riser adapter
	R(ci, Rect2(cx - bw * 0.3, 0, bw * 0.6, h * 0.05), 0.55)
	# annular preventer: domed head, the packing element donut
	var an := Rect2(cx - bw * 0.55, h * 0.05, bw * 1.1, h * 0.2)
	P(ci, PackedVector2Array([Vector2(an.position.x, an.end.y), Vector2(an.position.x, an.position.y + an.size.y * 0.4), Vector2(cx - bw * 0.3, an.position.y), Vector2(cx + bw * 0.3, an.position.y), Vector2(an.end.x, an.position.y + an.size.y * 0.4), Vector2(an.end.x, an.end.y), Vector2(an.position.x, an.end.y)]), 0.6, 1.2)
	A(ci, Vector2(cx, an.position.y + an.size.y * 0.62), bw * 0.32, PI, TAU, 0.45)
	L(ci, Vector2(cx - bw * 0.32, an.position.y + an.size.y * 0.62), Vector2(cx + bw * 0.32, an.position.y + an.size.y * 0.62), 0.45)
	# the rams
	var rams := [[0.28, 0.16, 0.42], [0.48, 0.18, 0.5], [0.7, 0.16, 0.42]]
	for e in rams:
		var y0: float = h * e[0]
		var rh: float = h * e[1]
		var reach: float = w * e[2]
		R(ci, Rect2(cx - bw * 0.5, y0, bw, rh), 0.6, 1.2)
		for s in [-1.0, 1.0]:
			var bx0: float = cx + s * bw * 0.5
			var bx1: float = cx + s * reach
			R(ci, Rect2(minf(bx0, bx1), y0 + rh * 0.15, absf(bx1 - bx0), rh * 0.7), 0.5)
			L(ci, Vector2(bx1, y0 + rh * 0.3), Vector2(bx1 + s * 3.0, y0 + rh * 0.3), 0.45)
			L(ci, Vector2(bx1, y0 + rh * 0.7), Vector2(bx1 + s * 3.0, y0 + rh * 0.7), 0.45)
			# the ram block inside, at its stroke
			R(ci, Rect2(cx + s * bw * 0.06 - (bw * 0.36 if s < 0 else 0.0), y0 + rh * 0.35, bw * 0.36, rh * 0.3), 0.35)
	# the bore through it all
	L(ci, Vector2(cx - 2.5, 0), Vector2(cx - 2.5, h * 0.94), 0.25)
	L(ci, Vector2(cx + 2.5, 0), Vector2(cx + 2.5, h * 0.94), 0.25)
	# choke and kill valves on the side outlets
	for s in [-1.0, 1.0]:
		var vy: float = h * 0.66
		var vx: float = cx + s * bw * 0.75
		L(ci, Vector2(cx + s * bw * 0.5, vy), Vector2(vx + s * 6.0, vy), 0.5)
		P(ci, PackedVector2Array([Vector2(vx - 3, vy - 3), Vector2(vx + 3, vy + 3), Vector2(vx + 3, vy - 3), Vector2(vx - 3, vy + 3), Vector2(vx - 3, vy - 3)]), 0.55)
	# wellhead connector
	var wc := Rect2(cx - bw * 0.42, h * 0.86, bw * 0.84, h * 0.1)
	R(ci, wc, 0.6, 1.2)
	E.hatch(ci, E.inset(wc, 1.5), 3.0, true, 0.3, 20)
	# control pods on the frame
	for s in [-1.0, 1.0]:
		R(ci, Rect2(cx + s * w * 0.38 - w * 0.06, h * 0.06, w * 0.12, h * 0.18), 0.5)
		D(ci, Vector2(cx + s * w * 0.38, h * 0.1), 1.2, 0.6)


# a lathe: the bed on its cabinet legs, the headstock with the chuck and its jaws,
# the carriage and tool post, the tailstock, the lead screw
static func lathe(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var by: float = h * 0.5
	R(ci, Rect2(w * 0.02, by, w * 0.96, h * 0.08), 0.6)
	for x in [0.04, 0.72]:
		var lg := Rect2(w * x, by + h * 0.08, w * 0.24, h * 0.4)
		R(ci, lg, 0.45)
		L(ci, lg.position + Vector2(lg.size.x * 0.5, 4.0), lg.position + Vector2(lg.size.x * 0.5, lg.size.y - 4.0), 0.3)
	L(ci, Vector2(w * 0.04, by + h * 0.14), Vector2(w * 0.96, by + h * 0.14), 0.4)
	var hs := Rect2(w * 0.03, h * 0.12, w * 0.24, by - h * 0.12)
	R(ci, hs, 0.6, 1.2)
	E.gauge(ci, hs.position + hs.size * Vector2(0.3, 0.35), minf(hs.size.y * 0.16, 5.0), 0.45)
	var cc := Vector2(hs.end.x + w * 0.03, by - h * 0.14)
	R(ci, Rect2(hs.end.x, cc.y - h * 0.12, w * 0.05, h * 0.24), 0.55)
	for s in [-1.0, 1.0]:
		L(ci, Vector2(hs.end.x + w * 0.05, cc.y + s * h * 0.06), Vector2(hs.end.x + w * 0.08, cc.y + s * h * 0.03), 0.5)
	L(ci, Vector2(hs.end.x + w * 0.05, cc.y), Vector2(w * 0.62, cc.y), 0.4, 1.4)
	var cr := Rect2(w * 0.44, by - h * 0.12, w * 0.16, h * 0.12)
	R(ci, cr, 0.55)
	R(ci, Rect2(cr.position.x + cr.size.x * 0.3, cr.position.y - h * 0.08, cr.size.x * 0.4, h * 0.08), 0.5)
	E.wheel(ci, Vector2(cr.get_center().x, by + h * 0.04), minf(h * 0.06, 4.0), 0.45)
	var ts := Rect2(w * 0.78, h * 0.26, w * 0.14, by - h * 0.26)
	R(ci, ts, 0.55)
	L(ci, Vector2(ts.position.x, cc.y), Vector2(w * 0.66, cc.y), 0.5, 1.4)
	E.wheel(ci, Vector2(ts.end.x + w * 0.03, cc.y), minf(h * 0.06, 4.0), 0.45)


# a milling machine: the column and base, the knee and saddle with the table and
# its T-slots and a vice, the head with its spindle and the motor on top
static func mill(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(w * 0.04, h * 0.9, w * 0.92, h * 0.08), 0.55)
	var col := Rect2(w * 0.62, h * 0.18, w * 0.3, h * 0.72)
	R(ci, col, 0.55)
	L(ci, Vector2(col.position.x + 3.0, col.position.y + 4.0), Vector2(col.position.x + 3.0, col.end.y - 4.0), 0.3)
	var hd := Rect2(w * 0.24, h * 0.1, w * 0.46, h * 0.2)
	R(ci, hd, 0.6, 1.2)
	E.motor(ci, Rect2(w * 0.3, 0, w * 0.4, h * 0.1), false, 0.45)
	L(ci, Vector2(w * 0.36, hd.end.y), Vector2(w * 0.36, h * 0.42), 0.55, 1.6)
	P(ci, PackedVector2Array([Vector2(w * 0.34, h * 0.42), Vector2(w * 0.36, h * 0.46), Vector2(w * 0.38, h * 0.42)]), 0.5)
	E.wheel(ci, Vector2(w * 0.2, h * 0.2), minf(w * 0.05, 4.0), 0.45)
	var tb := Rect2(w * 0.06, h * 0.5, w * 0.56, h * 0.06)
	R(ci, tb, 0.6)
	for k in 3:
		L(ci, Vector2(tb.position.x + 2.0, tb.position.y + tb.size.y * (0.3 + k * 0.2)), Vector2(tb.end.x - 2.0, tb.position.y + tb.size.y * (0.3 + k * 0.2)), 0.25)
	R(ci, Rect2(w * 0.26, h * 0.44, w * 0.18, h * 0.06), 0.5)
	R(ci, Rect2(w * 0.16, h * 0.56, w * 0.46, h * 0.08), 0.45)
	R(ci, Rect2(w * 0.22, h * 0.64, w * 0.4, h * 0.26), 0.45)
	E.wheel(ci, Vector2(w * 0.12, h * 0.6), minf(w * 0.05, 4.0), 0.45)


# the standpipe manifold: the vertical standpipe, its gate valves and pressure
# gauges, the rotary hose's gooseneck off the top, the bleed-off line
static func standpipe(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cx: float = w * 0.4
	L(ci, Vector2(cx - 3.0, h * 0.04), Vector2(cx - 3.0, h), 0.6)
	L(ci, Vector2(cx + 3.0, h * 0.04), Vector2(cx + 3.0, h), 0.6)
	A(ci, Vector2(cx + w * 0.2, h * 0.06), w * 0.2, PI, TAU, 0.55, 1.4)
	for f in [0.28, 0.6]:
		var vc := Vector2(cx, h * f)
		var vs: float = minf(w * 0.18, 6.0)
		P(ci, PackedVector2Array([vc + Vector2(-vs, -vs * 0.7), vc + Vector2(vs, vs * 0.7), vc + Vector2(vs, -vs * 0.7), vc + Vector2(-vs, vs * 0.7), vc + Vector2(-vs, -vs * 0.7)]), 0.6)
		L(ci, vc + Vector2(vs, 0), vc + Vector2(vs * 2.2, 0), 0.45)
		E.wheel(ci, vc + Vector2(vs * 2.8, 0), vs * 0.6, 0.45)
	E.gauge(ci, Vector2(cx - w * 0.22, h * 0.44), minf(w * 0.14, 6.0), 0.55)
	L(ci, Vector2(cx - w * 0.22 + minf(w * 0.14, 6.0), h * 0.44), Vector2(cx - 3.0, h * 0.44), 0.4)
	L(ci, Vector2(cx + 3.0, h * 0.82), Vector2(w - 1.0, h * 0.82), 0.5)


# the choke manifold: a header with its gate valves, the adjustable choke (its
# wedge body and actuator), the gauge
static func choke_manifold(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var y: float = h * 0.64
	L(ci, Vector2(1, y - 3.0), Vector2(w - 1, y - 3.0), 0.55)
	L(ci, Vector2(1, y + 3.0), Vector2(w - 1, y + 3.0), 0.55)
	for f in [0.18, 0.8]:
		var vc := Vector2(w * f, y)
		var vs: float = minf(w * 0.08, 6.0)
		P(ci, PackedVector2Array([vc + Vector2(-vs, -vs), vc + Vector2(vs, vs), vc + Vector2(-vs, vs), vc + Vector2(vs, -vs), vc + Vector2(-vs, -vs)]), 0.6)
		L(ci, vc + Vector2(0, -vs), vc + Vector2(0, -vs * 2.4), 0.45)
		E.wheel(ci, vc + Vector2(0, -vs * 2.8), vs * 0.55, 0.45)
	# the choke: angle body, its actuator box
	var cc := Vector2(w * 0.5, y)
	R(ci, Rect2(cc - Vector2(w * 0.1, h * 0.12), Vector2(w * 0.2, h * 0.24)), 0.6, 1.2)
	L(ci, cc + Vector2(0, -h * 0.12), cc + Vector2(0, -h * 0.3), 0.5, 1.4)
	R(ci, Rect2(cc + Vector2(-w * 0.12, -h * 0.5), Vector2(w * 0.24, h * 0.2)), 0.55)
	E.gauge(ci, Vector2(w * 0.5, h * 0.9), minf(h * 0.08, 5.0), 0.5)
	L(ci, Vector2(w * 0.5, h * 0.76), Vector2(w * 0.5, h * 0.82), 0.4)


# the BOP accumulator unit (Koomey): its racked bottles on the header, the
# electric and air pumps, the manifold of control valves with their gauges
static func koomey(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	E.gastank(ci, Rect2(0, h * 0.3, w, h * 0.7))
	var vb := Rect2(w * 0.06, h * 0.02, w * 0.88, h * 0.22)
	R(ci, vb, 0.55)
	var n := clampi(int(vb.size.x / 8.0), 2, 6)
	for k in n:
		var x: float = vb.position.x + (k + 0.5) * vb.size.x / n
		L(ci, Vector2(x, vb.position.y + 2.0), Vector2(x, vb.get_center().y), 0.6, 1.6)
		D(ci, Vector2(x, vb.end.y - 3.0), 1.1, 0.55)
	L(ci, Vector2(w * 0.5, vb.end.y), Vector2(w * 0.5, h * 0.3), 0.45)


# ================================================================== HG-170 Gas Sea

# an axial compressor stage on the scoop's throat: the casing narrowing aft, the
# rotor drum, rows of rotor blades between rows of stator vanes, the inlet guide
# vanes, the bearing struts, the drive shaft out the back
static func axial_comp(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var vert: bool = h > w
	var ln: float = h if vert else w
	var th: float = w if vert else h
	var X := func(u: float, v: float) -> Vector2: return Vector2(v, u) if vert else Vector2(u, v)
	var c: float = th * 0.5
	# casing: wide at the inlet (u=0), narrow aft
	P(ci, PackedVector2Array([X.call(0.0, c - th * 0.48), X.call(ln * 0.85, c - th * 0.34), X.call(ln, c - th * 0.34)]), 0.6, 1.2)
	P(ci, PackedVector2Array([X.call(0.0, c + th * 0.48), X.call(ln * 0.85, c + th * 0.34), X.call(ln, c + th * 0.34)]), 0.6, 1.2)
	# rotor drum
	P(ci, PackedVector2Array([X.call(ln * 0.08, c - th * 0.12), X.call(ln * 0.85, c - th * 0.2), X.call(ln * 0.85, c + th * 0.2), X.call(ln * 0.08, c + th * 0.12), X.call(ln * 0.08, c - th * 0.12)]), 0.5)
	var n := clampi(int(ln / 7.0), 4, 18)
	var segs := PackedVector2Array()
	var vanes := PackedVector2Array()
	for k in n:
		var u: float = ln * (0.1 + 0.74 * (k + 0.5) / n)
		var t: float = u / (ln * 0.85)
		var outer: float = lerpf(th * 0.46, th * 0.35, t)
		var inner: float = lerpf(th * 0.12, th * 0.2, t)
		var arr: PackedVector2Array = segs if k % 2 == 0 else vanes
		for sg in [-1.0, 1.0]:
			arr.append(X.call(u, c + sg * inner))
			arr.append(X.call(u + (2.5 if k % 2 == 0 else -2.0), c + sg * (outer - 1.0)))
	S(ci, segs, 0.45)
	S(ci, vanes, 0.3)
	# inlet guide vanes and the nose cone
	P(ci, PackedVector2Array([X.call(ln * 0.08, c - th * 0.12), X.call(0.0, c), X.call(ln * 0.08, c + th * 0.12)]), 0.5)
	L(ci, X.call(ln * 0.85, c), X.call(ln, c), 0.55, 1.6)
	for sg in [-1.0, 1.0]:
		L(ci, X.call(ln * 0.92, c + sg * th * 0.04), X.call(ln * 0.92, c + sg * th * 0.33), 0.4, 1.4)


# a twin-screw compressor package: the male and female rotors in their housing, the
# motor driving them, the oil separator vessel, the oil cooler, the suction filter
static func screw_comp(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var base_y: float = h * 0.94
	L(ci, Vector2(2, base_y), Vector2(w - 2, base_y), 0.55, 1.6)
	var hs := Rect2(w * 0.06, h * 0.42, w * 0.34, h * 0.36)
	R(ci, hs, 0.6, 1.2)
	for k in 2:
		var y: float = hs.position.y + hs.size.y * (0.3 + k * 0.4)
		var segs := PackedVector2Array()
		var nl := clampi(int(hs.size.x / 4.0), 3, 20)
		for i in nl:
			var x: float = hs.position.x + 2.0 + i * (hs.size.x - 4.0) / nl
			segs.append(Vector2(x, y - hs.size.y * 0.14))
			segs.append(Vector2(x + 3.0 * (1.0 if k == 0 else -1.0), y + hs.size.y * 0.14))
		S(ci, segs, 0.35)
		L(ci, Vector2(hs.position.x, y), Vector2(hs.end.x, y), 0.25)
	E.motor(ci, Rect2(hs.end.x, h * 0.46, w * 0.3, h * 0.28), true, 0.5)
	var os := Rect2(w * 0.74, h * 0.1, w * 0.2, h * 0.76)
	E.vessel_v(ci, os, 0.55)
	L(ci, Vector2(hs.get_center().x, hs.position.y), Vector2(hs.get_center().x, h * 0.18), 0.5, 1.4)
	L(ci, Vector2(hs.get_center().x, h * 0.18), Vector2(os.position.x, h * 0.18), 0.5, 1.4)
	R(ci, Rect2(w * 0.08, h * 0.08, w * 0.22, h * 0.22), 0.45)
	E.hatch(ci, Rect2(w * 0.1, h * 0.1, w * 0.18, h * 0.18), 3.0, true, 0.22, 20)
	E.gauge(ci, Vector2(w * 0.86, h * 0.92 - h * 0.5), minf(w * 0.05, 4.0), 0.5)


# a hydrogen cold box: the vacuum jacket, the plate-fin heat exchangers in series
# down its height, the turboexpanders between them, the Joule-Thomson valve and
# the liquid separator at the foot, the transfer lines out
static func cold_box_h2(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(w * 0.04, h * 0.02, w * 0.92, h * 0.96), 0.55, 1.2)
	R(ci, Rect2(w * 0.07, h * 0.04, w * 0.86, h * 0.92), 0.25)
	for k in 3:
		var hx := Rect2(w * 0.14, h * (0.07 + k * 0.24), w * 0.34, h * 0.2)
		R(ci, hx, 0.5)
		E.hatch(ci, E.inset(hx, 1.5), 2.5, true, 0.18, 40)
		if k < 2:
			var tc := Vector2(w * 0.7, hx.end.y)
			O(ci, tc, minf(w * 0.08, h * 0.05), 0.55)
			E.impeller(ci, tc, minf(w * 0.08, h * 0.05) * 0.8, 0.4)
			L(ci, Vector2(hx.end.x, hx.get_center().y), Vector2(tc.x, hx.get_center().y), 0.4)
			L(ci, Vector2(tc.x, hx.get_center().y), tc - Vector2(0, minf(w * 0.08, h * 0.05)), 0.4)
			L(ci, tc + Vector2(0, minf(w * 0.08, h * 0.05)), Vector2(tc.x, hx.end.y + h * 0.06), 0.4)
			L(ci, Vector2(tc.x, hx.end.y + h * 0.06), Vector2(hx.end.x, hx.end.y + h * 0.06), 0.4)
	# JT valve and separator
	var jv := Vector2(w * 0.31, h * 0.8)
	P(ci, PackedVector2Array([jv + Vector2(-3, -3), jv + Vector2(3, 3), jv + Vector2(3, -3), jv + Vector2(-3, 3), jv + Vector2(-3, -3)]), 0.6)
	var sp := Rect2(w * 0.5, h * 0.76, w * 0.36, h * 0.18)
	E.vessel_h(ci, sp, 0.5)
	L(ci, Vector2(sp.position.x + 2.0, sp.get_center().y + sp.size.y * 0.15), Vector2(sp.end.x - 2.0, sp.get_center().y + sp.size.y * 0.15), 0.3)
	L(ci, jv + Vector2(3, 0), Vector2(sp.position.x, jv.y), 0.4)
	for x in [0.3, 0.5, 0.7]:
		L(ci, Vector2(w * x, 0), Vector2(w * x, h * 0.07), 0.45)


# an ortho-para converter: the catalyst beds (hydrous iron oxide, dotted) packed in
# the passages of a heat exchanger, the cold bath round it, inlet and outlet
static func ortho_para(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var vs := Rect2(w * 0.12, h * 0.06, w * 0.76, h * 0.86)
	var sh := E.vessel_v(ci, vs, 0.6)
	var n := 3
	for k in n:
		var b := Rect2(sh.position.x + sh.size.x * (0.08 + k * 0.3), sh.position.y + 3.0, sh.size.x * 0.24, sh.size.y - 6.0)
		R(ci, b, 0.45)
		var dots := PackedVector2Array()
		var ny := clampi(int(b.size.y / 4.0), 2, 30)
		var nx := clampi(int(b.size.x / 4.0), 1, 6)
		for j in ny:
			for i in nx:
				var q := b.position + Vector2((i + 0.5 + (0.5 if j % 2 == 1 else 0.0)) * b.size.x / (nx + 0.5), (j + 0.5) * b.size.y / ny)
				dots.append(q)
				dots.append(q + Vector2(0.8, 0))
		S(ci, dots, 0.45)
	# the coolant coil between the beds
	for k in 2:
		var x: float = sh.position.x + sh.size.x * (0.35 + k * 0.3)
		var pts := PackedVector2Array()
		var nz := clampi(int(sh.size.y / 6.0), 3, 20)
		for j in nz + 1:
			pts.append(Vector2(x + (2.0 if j % 2 == 0 else -2.0), sh.position.y + 2.0 + j * (sh.size.y - 4.0) / nz))
		P(ci, pts, 0.3)
	L(ci, Vector2(vs.get_center().x, vs.position.y), Vector2(vs.get_center().x, 0), 0.5, 1.4)
	L(ci, Vector2(vs.get_center().x, vs.end.y), Vector2(vs.get_center().x, h), 0.5, 1.4)
	L(ci, Vector2(vs.position.x, sh.get_center().y), Vector2(1, sh.get_center().y), 0.45)


# a liquid-nitrogen precooler: the LN2 bath vessel, the coiled tube bundle the gas
# runs through, the boil-off vent, the level probe
static func precooler(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var vs := Rect2(w * 0.1, h * 0.08, w * 0.8, h * 0.84)
	var sh := E.vessel_v(ci, vs, 0.6)
	var lvl: float = sh.position.y + sh.size.y * 0.2
	var pts := PackedVector2Array()
	var nw := clampi(int(sh.size.x / 5.0), 3, 30)
	for k in nw + 1:
		pts.append(Vector2(sh.position.x + sh.size.x * k / nw, lvl + (1.0 if k % 2 == 0 else -1.0)))
	P(ci, pts, 0.4)
	var nc := clampi(int(sh.size.y * 0.7 / 5.0), 3, 24)
	for k in nc:
		var y: float = lvl + 4.0 + k * (sh.end.y - lvl - 8.0) / nc
		O(ci, Vector2(sh.position.x + sh.size.x * 0.32, y), 2.0, 0.35)
		O(ci, Vector2(sh.position.x + sh.size.x * 0.68, y), 2.0, 0.35)
	L(ci, Vector2(sh.position.x + sh.size.x * 0.32, lvl), Vector2(sh.position.x + sh.size.x * 0.32, 1.0), 0.45)
	L(ci, Vector2(sh.position.x + sh.size.x * 0.68, lvl), Vector2(sh.position.x + sh.size.x * 0.68, 1.0), 0.45)
	P(ci, PackedVector2Array([Vector2(vs.end.x - 4.0, vs.position.y), Vector2(vs.end.x - 4.0, 2.0), Vector2(w - 2.0, 2.0)]), 0.4)
	L(ci, Vector2(sh.get_center().x, vs.position.y), Vector2(sh.get_center().x, sh.end.y - 4.0), 0.25)


# a pressure-swing adsorption separator: two adsorber columns with their beds, the
# valve manifolds at their tops and bottoms switching between them
static func psa(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	for k in 2:
		var col := Rect2(w * (0.1 + k * 0.46), h * 0.14, w * 0.34, h * 0.72)
		var sh := E.vessel_v(ci, col, 0.6)
		E.hatch(ci, Rect2(sh.position.x + 2.0, sh.position.y + sh.size.y * 0.15, sh.size.x - 4.0, sh.size.y * 0.7), 3.0, false, 0.18, 40)
		L(ci, Vector2(sh.position.x, sh.position.y + sh.size.y * 0.15), Vector2(sh.end.x, sh.position.y + sh.size.y * 0.15), 0.4)
		L(ci, Vector2(sh.position.x, sh.position.y + sh.size.y * 0.85), Vector2(sh.end.x, sh.position.y + sh.size.y * 0.85), 0.4)
	for y in [h * 0.06, h * 0.94]:
		L(ci, Vector2(w * 0.1, y), Vector2(w * 0.9, y), 0.55, 1.4)
		for k in 2:
			var x: float = w * (0.27 + k * 0.46)
			L(ci, Vector2(x, y), Vector2(x, h * 0.14 if y < h * 0.5 else h * 0.86), 0.45)
			var vc := Vector2(x, (y + (h * 0.14 if y < h * 0.5 else h * 0.86)) * 0.5)
			P(ci, PackedVector2Array([vc + Vector2(-3, -2.5), vc + Vector2(3, 2.5), vc + Vector2(-3, 2.5), vc + Vector2(3, -2.5), vc + Vector2(-3, -2.5)]), 0.55)


# a gas chromatograph: the oven door with its window onto the coiled column, the
# injector port and autosampler turret on top, the detector block, the display
static func gc(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var b := Rect2(w * 0.04, h * 0.2, w * 0.92, h * 0.78)
	R(ci, b, 0.55)
	var ov := Rect2(b.position.x + b.size.x * 0.06, b.position.y + b.size.y * 0.12, b.size.x * 0.56, b.size.y * 0.76)
	R(ci, ov, 0.5)
	var cc := ov.get_center()
	for k in 4:
		O(ci, cc, minf(ov.size.x, ov.size.y) * (0.16 + k * 0.07), 0.3)
	L(ci, Vector2(ov.end.x - 3.0, ov.position.y + 4.0), Vector2(ov.end.x - 3.0, ov.end.y - 4.0), 0.6, 1.6)
	# autosampler turret and the injector
	var tc := Vector2(b.position.x + b.size.x * 0.3, h * 0.12)
	O(ci, tc, minf(w * 0.14, h * 0.1), 0.55)
	for k in 8:
		D(ci, tc + Vector2.from_angle(TAU * k / 8.0) * minf(w * 0.14, h * 0.1) * 0.7, 0.9, 0.5)
	L(ci, tc + Vector2(0, minf(w * 0.14, h * 0.1)), Vector2(tc.x, b.position.y), 0.5, 1.4)
	R(ci, Rect2(b.position.x + b.size.x * 0.7, b.position.y + b.size.y * 0.1, b.size.x * 0.24, b.size.y * 0.3), 0.5)
	E.screen_face(ci, Rect2(b.position.x + b.size.x * 0.7, b.position.y + b.size.y * 0.5, b.size.x * 0.24, b.size.y * 0.24), 0, 0.4)


# a quadrupole mass spectrometer: the vacuum chamber with the ion source, the four
# rods, the detector, the turbopump hanging under it, the electronics box
static func mass_spec(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var ch := Rect2(w * 0.04, h * 0.18, w * 0.62, h * 0.34)
	R(ci, ch, 0.6, 1.2)
	R(ci, Rect2(ch.position.x + 3.0, ch.position.y + ch.size.y * 0.3, ch.size.x * 0.12, ch.size.y * 0.4), 0.5)
	for k in 4:
		var y: float = ch.position.y + ch.size.y * (0.2 + k * 0.2)
		L(ci, Vector2(ch.position.x + ch.size.x * 0.22, y), Vector2(ch.end.x - ch.size.x * 0.18, y), 0.45, 1.4)
	O(ci, Vector2(ch.end.x - ch.size.x * 0.08, ch.get_center().y), ch.size.y * 0.18, 0.5)
	L(ci, Vector2(ch.position.x + ch.size.x * 0.12, ch.get_center().y), Vector2(ch.end.x - ch.size.x * 0.1, ch.get_center().y), 0.15)
	# turbopump under the chamber
	var tp := Rect2(ch.position.x + ch.size.x * 0.35, ch.end.y, ch.size.x * 0.3, h * 0.42)
	R(ci, tp, 0.5)
	for k in 5:
		var y: float = tp.position.y + tp.size.y * (0.1 + k * 0.12)
		L(ci, Vector2(tp.position.x + 2.0, y), Vector2(tp.end.x - 2.0, y + 2.0), 0.3)
	R(ci, Rect2(tp.position.x + tp.size.x * 0.2, tp.end.y - tp.size.y * 0.28, tp.size.x * 0.6, tp.size.y * 0.24), 0.45)
	var eb := Rect2(w * 0.72, h * 0.1, w * 0.24, h * 0.84)
	R(ci, eb, 0.5)
	E.screen_face(ci, sub(eb, 0.1, 0.06, 0.9, 0.3), 1, 0.4)
	E.hatch(ci, sub(eb, 0.15, 0.4, 0.85, 0.9), 3.0, false, 0.2, 20)


# a turboexpander: the expansion turbine's volute and wheel, the shaft through its
# gas bearings, the brake compressor (or generator) on the other end, the inlet
# nozzle valve, on its skid
static func turboexpander(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var n := 2 if w > h * 1.6 else 1
	var uw: float = w / n
	for i in n:
		var x0: float = i * uw
		var ay: float = h * 0.46
		var vr: float = minf(uw * 0.16, h * 0.22)
		var tc := Vector2(x0 + uw * 0.22, ay)
		O(ci, tc, vr, 0.6, 1.2)
		E.impeller(ci, tc, vr * 0.75, 0.45)
		var bc := Vector2(x0 + uw * 0.78, ay)
		O(ci, bc, vr * 0.9, 0.55, 1.2)
		E.impeller(ci, bc, vr * 0.65, 0.4)
		var bh := Rect2(tc.x + vr, ay - vr * 0.45, bc.x - tc.x - vr * 1.9, vr * 0.9)
		R(ci, bh, 0.55)
		E.hatch(ci, E.inset(bh, 2.0), 3.0, true, 0.2, 20)
		L(ci, tc, bc, 0.3)
		# inlet with its nozzle valve, outlet down
		L(ci, tc + Vector2(0, -vr), Vector2(tc.x, h * 0.06), 0.5, 1.4)
		var vc := Vector2(tc.x, h * 0.14)
		P(ci, PackedVector2Array([vc + Vector2(-3, -3), vc + Vector2(3, 3), vc + Vector2(-3, 3), vc + Vector2(3, -3), vc + Vector2(-3, -3)]), 0.6)
		L(ci, tc + Vector2(-vr, 0), Vector2(x0 + 2.0, ay), 0.5, 1.4)
		L(ci, bc + Vector2(0, -vr * 0.9), Vector2(bc.x, h * 0.1), 0.45)
		L(ci, Vector2(x0 + uw * 0.1, h * 0.92), Vector2(x0 + uw * 0.9, h * 0.92), 0.55, 1.6)
		for f in [0.3, 0.7]:
			L(ci, Vector2(x0 + uw * f, ay + vr * 0.45), Vector2(x0 + uw * f, h * 0.92), 0.45)


# ================================================================== QC-30 Quantum

# a dilution refrigerator stage: the gold-plated copper plate with its bolt circle,
# the coax lines passing down through it with their attenuators or filters
# thermalised on it, the heat exchanger / pot on the colder stages, the supports
static func dr_stage(ci: CanvasItem, r: Rect2, p) -> void:
	var w := r.size.x
	var h := r.size.y
	var nk: String = p.name_key if p != null else ""
	R(ci, Rect2(1, h * 0.3, w - 2, h * 0.4), 0.65, 1.2)
	var nb := clampi(int(w / 9.0), 3, 30)
	E.bolts(ci, Vector2(3, h * 0.5), Vector2(w - 3, h * 0.5), nb, 0.45, 0.8)
	# coax lines through the plate, each with its component on the plate
	var nl := clampi(int(w * 0.5 / 7.0), 3, 14)
	for k in nl:
		var x: float = w * 0.25 + (k + 0.5) * w * 0.5 / nl
		L(ci, Vector2(x, 0), Vector2(x, h), 0.35)
		var comp := Rect2(x - 1.6, h * 0.04, 3.2, h * 0.24)
		R(ci, comp, 0.55)
	# the stage's own hardware
	match nk:
		"p_qc_stage_50k", "p_qc_stage_4k":
			# pulse-tube cold-head flange and the heat links
			R(ci, Rect2(w * 0.04, h * 0.0, w * 0.14, h * 0.3), 0.55)
			E.hatch(ci, Rect2(w * 0.05, h * 0.02, w * 0.12, h * 0.26), 2.5, true, 0.25, 12)
		"p_qc_stage_still":
			# the still pot and its heater
			R(ci, Rect2(w * 0.04, h * 0.7, w * 0.16, h * 0.28), 0.55)
			E.hatch(ci, Rect2(w * 0.06, h * 0.74, w * 0.12, h * 0.2), 3.0, false, 0.3, 6)
		"p_qc_stage_cp":
			# the continuous heat exchanger, a spiral
			for k in 3:
				O(ci, Vector2(w * 0.12, h * 0.84), h * (0.05 + k * 0.04), 0.35)
		"p_qc_stage_mxc":
			# the mixing chamber can and the step heat exchangers
			R(ci, Rect2(w * 0.04, h * 0.7, w * 0.18, h * 0.3), 0.6)
			for k in 3:
				R(ci, Rect2(w * (0.8 + k * 0.05), h * 0.72, w * 0.04, h * 0.24), 0.4)
		_:
			pass
	# the support rods to the stage above
	for x in [w * 0.02, w * 0.98]:
		L(ci, Vector2(x, 0), Vector2(x, h * 0.3), 0.5, 1.4)


# the processor package at the bottom of the fridge: the copper sample box, its
# lid screws, the SMA connectors along its edges, the chip seen through a window
static func qpu(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, 1, w - 2, h - 2), 0.7, 1.4)
	E.corner_bolts(ci, Rect2(1, 1, w - 2, h - 2), 2.5, 0.6)
	var ch := Rect2(w * 0.32, h * 0.25, w * 0.36, h * 0.5)
	R(ci, ch, 0.65)
	E.hatch(ci, E.inset(ch, 1.0), 2.0, true, 0.35, 12)
	for k in 4:
		var x: float = w * (0.18 + k * 0.21)
		D(ci, Vector2(x, 1.5), 1.0, 0.7)
		D(ci, Vector2(x, h - 1.5), 1.0, 0.7)


# a pulse-tube cold head: the motor-driven rotary valve on top, the regenerator
# and the pulse tube side by side down to the first stage flange, then again to the
# second stage, the buffer volume and the helium flex lines
static func pulse_tube(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var vert: bool = h >= w * 0.8
	var top := Rect2(w * 0.2, h * 0.02, w * 0.6, h * 0.2)
	R(ci, top, 0.6, 1.2)
	O(ci, top.get_center(), minf(top.size.y * 0.32, top.size.x * 0.2), 0.45)
	R(ci, Rect2(w * 0.08, h * 0.24, w * 0.84, h * 0.06), 0.6)
	var f1: float = h * (0.62 if vert else 0.66)
	for k in 2:
		var x: float = w * (0.35 + k * 0.3)
		L(ci, Vector2(x - 2.5, h * 0.3), Vector2(x - 2.5, f1), 0.5)
		L(ci, Vector2(x + 2.5, h * 0.3), Vector2(x + 2.5, f1), 0.5)
		if k == 0:
			E.hatch(ci, Rect2(x - 2.0, h * 0.32, 4.0, f1 - h * 0.34), 2.5, false, 0.3, 30)
	R(ci, Rect2(w * 0.18, f1, w * 0.64, h * 0.05), 0.6)
	var f2: float = h * 0.92
	L(ci, Vector2(w * 0.42, f1 + h * 0.05), Vector2(w * 0.42, f2), 0.5)
	L(ci, Vector2(w * 0.58, f1 + h * 0.05), Vector2(w * 0.58, f2), 0.5)
	R(ci, Rect2(w * 0.3, f2, w * 0.4, h * 0.06), 0.6)
	P(ci, PackedVector2Array([Vector2(top.end.x, top.get_center().y), Vector2(w - 2.0, top.get_center().y), Vector2(w - 2.0, h * 0.5)]), 0.4)


# the gas handling system: its mimic panel (the valves of the 3He/4He circuit drawn
# as a flow diagram, each with its indicator), the pressure gauges along the top,
# the cold trap and pumps behind the lower doors
static func ghs(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, 1, w - 2, h - 2), 0.55)
	var mp := Rect2(w * 0.06, h * 0.14, w * 0.88, h * 0.48)
	R(ci, mp, 0.45)
	var nx := clampi(int(mp.size.x / 14.0), 3, 10)
	var ny := 3
	var pts: Array = []
	for j in ny:
		for i in nx:
			pts.append(mp.position + Vector2((i + 0.5) * mp.size.x / nx, (j + 0.5) * mp.size.y / ny))
	var segs := PackedVector2Array()
	for j in ny:
		segs.append(pts[j * nx])
		segs.append(pts[j * nx + nx - 1])
	for i in range(0, nx, 2):
		segs.append(pts[i])
		segs.append(pts[(ny - 1) * nx + i])
	S(ci, segs, 0.3)
	for q in pts:
		var c: Vector2 = q
		P(ci, PackedVector2Array([c + Vector2(-2.5, -2), c + Vector2(2.5, 2), c + Vector2(2.5, -2), c + Vector2(-2.5, 2), c + Vector2(-2.5, -2)]), 0.55)
	var ng := clampi(int(w / 16.0), 2, 8)
	for i in ng:
		E.gauge(ci, Vector2(w * 0.06 + (i + 0.5) * w * 0.88 / ng, h * 0.07), minf(h * 0.05, 4.5), 0.5)
	for f in [0.25, 0.75]:
		E.door_leaf(ci, Rect2(w * (f - 0.22), h * 0.66, w * 0.44, h * 0.3), f < 0.5, 0.4)


# a vibration isolation table: the honeycomb top, the pneumatic legs with their
# bellows and level valves, the fridge's mounting ring through it
static func iso_table(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, h * 0.05, w - 2, h * 0.55), 0.6, 1.2)
	E.hatch(ci, Rect2(3, h * 0.12, w - 6, h * 0.4), 4.0, true, 0.15, 160)
	var dots := PackedVector2Array()
	for i in clampi(int(w / 8.0), 2, 120):
		var q := Vector2(4.0 + i * 8.0, h * 0.09)
		dots.append(q)
		dots.append(q + Vector2(0.7, 0))
	S(ci, dots, 0.5)
	R(ci, Rect2(w * 0.42, h * 0.02, w * 0.16, h * 0.62), 0.6)
	for f in [0.06, 0.94]:
		var lx: float = w * f
		R(ci, Rect2(lx - 4.0, h * 0.6, 8.0, h * 0.38), 0.55)
		var pts := PackedVector2Array()
		for k in 5:
			pts.append(Vector2(lx + (3.0 if k % 2 == 0 else -3.0), h * (0.64 + k * 0.06)))
		P(ci, pts, 0.4)


# a rack of room-temperature instruments: arbitrary waveform generators and
# digitisers, each a front panel with its screen, knobs and the row of SMA outputs
static func instrument_rack(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	L(ci, Vector2(2, 1), Vector2(2, h - 1), 0.5)
	L(ci, Vector2(w - 2, 1), Vector2(w - 2, h - 1), 0.5)
	var uh: float = clampf(h / 7.0, 12.0, 26.0)
	var n := int((h - 4.0) / uh)
	for k in n:
		var b := Rect2(4, 2.0 + k * uh, w - 8, uh - 2.0)
		R(ci, b, 0.45)
		E.screen_face(ci, Rect2(b.position.x + 2.0, b.position.y + 2.0, b.size.x * 0.32, b.size.y - 4.0), k, 0.35)
		O(ci, Vector2(b.position.x + b.size.x * 0.45, b.get_center().y), minf(b.size.y * 0.22, 3.5), 0.45)
		var ns := clampi(int(b.size.x * 0.4 / 4.0), 2, 12)
		for i in ns:
			O(ci, Vector2(b.position.x + b.size.x * 0.56 + i * b.size.x * 0.4 / ns, b.get_center().y + b.size.y * 0.15), 1.2, 0.55)
		D(ci, Vector2(b.end.x - 3.0, b.position.y + 3.0), 0.8, 0.7)


# a turbomolecular pump: inlet flange, the stacked rotor and stator blade rows,
# the motor and bearings in the base, the backing port
static func turbo_pump(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(w * 0.04, h * 0.02, w * 0.92, h * 0.08), 0.6)
	var body := Rect2(w * 0.14, h * 0.1, w * 0.72, h * 0.56)
	R(ci, body, 0.55)
	var n := clampi(int(body.size.y / 4.5), 3, 14)
	for k in n:
		var y: float = body.position.y + (k + 0.5) * body.size.y / n
		var segs := PackedVector2Array()
		var nb := clampi(int(body.size.x / 5.0), 3, 20)
		for i in nb:
			var x: float = body.position.x + 2.0 + i * (body.size.x - 4.0) / nb
			var s: float = 2.0 if k % 2 == 0 else -2.0
			segs.append(Vector2(x, y - 1.5))
			segs.append(Vector2(x + s, y + 1.5))
		S(ci, segs, 0.3 if k % 2 == 0 else 0.2)
	L(ci, Vector2(w * 0.5, body.position.y), Vector2(w * 0.5, h * 0.92), 0.4)
	R(ci, Rect2(w * 0.24, h * 0.66, w * 0.52, h * 0.3), 0.5)
	R(ci, Rect2(w * 0.86, h * 0.72, w * 0.12, h * 0.1), 0.5)


# a scroll pump: the fixed and orbiting scrolls (two interleaved spirals) in their
# housing, the motor beside, the exhaust
static func scroll_pump(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var c := Vector2(w * 0.32, h * 0.5)
	var rad: float = minf(w * 0.26, h * 0.4)
	O(ci, c, rad, 0.6, 1.2)
	for k in 2:
		var pts := PackedVector2Array()
		for e in 28:
			var t: float = e / 27.0
			pts.append(c + Vector2.from_angle(t * TAU * 2.2 + k * PI) * rad * 0.9 * t)
		P(ci, pts, 0.45 if k == 0 else 0.3)
	E.motor(ci, Rect2(c.x + rad + 2.0, h * 0.28, w - c.x - rad - 4.0, h * 0.44), true, 0.5)
	L(ci, c + Vector2(0, -rad), Vector2(c.x, 2.0), 0.45, 1.4)
	L(ci, Vector2(2, h * 0.94), Vector2(w - 2, h * 0.94), 0.5, 1.4)


# ================================================================== OB-90 Observatory

# a hexapod: the top and bottom plates, six struts crossing between them in pairs,
# each a linear actuator with its motor and the universal joints at its ends
static func hexapod(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(w * 0.08, 1, w * 0.84, h * 0.08), 0.6, 1.2)
	R(ci, Rect2(w * 0.02, h * 0.9, w * 0.96, h * 0.08), 0.6, 1.2)
	var tops := [0.18, 0.34, 0.66, 0.82]
	var bots := [0.08, 0.3, 0.7, 0.92]
	var pairs := [[0, 1], [1, 0], [2, 3], [3, 2], [1, 2], [2, 1]]
	for pr in pairs:
		var a := Vector2(w * tops[pr[0]], h * 0.09)
		var b := Vector2(w * bots[pr[1]], h * 0.9)
		L(ci, a, a.lerp(b, 0.55), 0.55, 1.6)
		L(ci, a.lerp(b, 0.5), b, 0.45, 1.0)
		var m: Vector2 = a.lerp(b, 0.6)
		var d: Vector2 = (b - a).normalized()
		P(ci, PackedVector2Array([m + d.orthogonal() * 2.5, m + d.orthogonal() * 2.5 + d * 7.0, m - d.orthogonal() * 2.5 + d * 7.0, m - d.orthogonal() * 2.5, m + d.orthogonal() * 2.5]), 0.45)
		O(ci, a, 1.6, 0.6)
		O(ci, b, 1.6, 0.6)


# the aft optics: the tertiary mirror, the fold mirrors and the fine steering mirror
# on the optical bench, the beam path threading them to the instrument ports, the
# baffles; the bench's mounts below
static func aft_optics(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var bench := Rect2(w * 0.02, h * 0.8, w * 0.96, h * 0.1)
	R(ci, bench, 0.6, 1.2)
	var dots := PackedVector2Array()
	for i in clampi(int(bench.size.x / 6.0), 2, 60):
		var q := Vector2(bench.position.x + 3.0 + i * 6.0, bench.get_center().y)
		dots.append(q)
		dots.append(q + Vector2(0.7, 0))
	S(ci, dots, 0.5)
	for f in [0.15, 0.85]:
		P(ci, PackedVector2Array([Vector2(w * f - 4.0, h), Vector2(w * f, bench.end.y), Vector2(w * f + 4.0, h)]), 0.45)
	# the beam: in from the top left, M3 down, fold, FSM, out to two ports
	var m3 := Vector2(w * 0.2, h * 0.55)
	var f1 := Vector2(w * 0.55, h * 0.6)
	var fsm := Vector2(w * 0.55, h * 0.25)
	var out1 := Vector2(w * 0.98, h * 0.25)
	var out2 := Vector2(w * 0.98, h * 0.6)
	P(ci, PackedVector2Array([Vector2(w * 0.2, 0), m3, f1, fsm, out1]), 0.3)
	L(ci, f1, out2, 0.18)
	# mirrors in their mounts
	for mm in [[m3, 0.6], [f1, -0.6], [fsm, 0.7]]:
		var c: Vector2 = mm[0]
		var a: float = mm[1]
		var t := Vector2.from_angle(a + PI * 0.5) * minf(w, h) * 0.08
		L(ci, c - t, c + t, 0.7, 2.2)
		var mt := Rect2(c.x - minf(w, h) * 0.05, c.y + minf(w, h) * 0.06, minf(w, h) * 0.1, bench.position.y - c.y - minf(w, h) * 0.06)
		if mt.size.y > 2.0:
			L(ci, Vector2(c.x, c.y + minf(w, h) * 0.06), Vector2(c.x, bench.position.y), 0.45, 1.4)
	# a beam splitter cube and the ports
	R(ci, Rect2(w * 0.72, h * 0.2, w * 0.06, w * 0.06), 0.55)
	for oy in [0.25, 0.6]:
		R(ci, Rect2(w * 0.9, h * oy - h * 0.06, w * 0.08, h * 0.12), 0.55)
	# baffles
	for x in [0.35, 0.65]:
		L(ci, Vector2(w * x, h * 0.05), Vector2(w * x, h * 0.18), 0.35, 1.4)


# a fast steering mirror: the mirror on its flexure, three piezo stacks behind it,
# the housing and its position sensors
static func fsm(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	L(ci, Vector2(w * 0.2, h * 0.08), Vector2(w * 0.2, h * 0.92), 0.8, 2.6)
	R(ci, Rect2(w * 0.24, h * 0.12, w * 0.12, h * 0.76), 0.5)
	for f in [0.25, 0.5, 0.75]:
		var y: float = h * f
		R(ci, Rect2(w * 0.36, y - h * 0.05, w * 0.34, h * 0.1), 0.5)
		E.hatch(ci, Rect2(w * 0.37, y - h * 0.045, w * 0.32, h * 0.09), 2.2, true, 0.3, 20)
	R(ci, Rect2(w * 0.7, h * 0.06, w * 0.26, h * 0.88), 0.55)
	D(ci, Vector2(w * 0.83, h * 0.2), 1.2, 0.6)
	D(ci, Vector2(w * 0.83, h * 0.8), 1.2, 0.6)


# an infrared camera: its dewar (vacuum jacket, the cold finger to the detector),
# the filter wheel, the lens barrel, the cryocooler on its back, the readout box
static func ir_camera(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var dw := Rect2(w * 0.3, h * 0.16, w * 0.46, h * 0.68)
	R(ci, dw, 0.6, 1.2)
	R(ci, E.inset(dw, 3.0), 0.25)
	var det := Rect2(dw.position.x + 4.0, dw.get_center().y - dw.size.y * 0.2, 3.0, dw.size.y * 0.4)
	R(ci, det, 0.7)
	L(ci, Vector2(det.end.x, dw.get_center().y), Vector2(dw.end.x - 4.0, dw.get_center().y), 0.45, 1.6)
	O(ci, Vector2(dw.position.x - w * 0.06, dw.get_center().y), minf(w * 0.08, h * 0.3), 0.5)
	for k in 6:
		O(ci, Vector2(dw.position.x - w * 0.06, dw.get_center().y) + Vector2.from_angle(TAU * k / 6.0) * minf(w * 0.08, h * 0.3) * 0.6, minf(w * 0.08, h * 0.3) * 0.22, 0.3)
	# lens barrel
	P(ci, PackedVector2Array([Vector2(dw.position.x - w * 0.14, dw.get_center().y - h * 0.16), Vector2(2, dw.get_center().y - h * 0.22), Vector2(2, dw.get_center().y + h * 0.22), Vector2(dw.position.x - w * 0.14, dw.get_center().y + h * 0.16)]), 0.55)
	for f in [0.25, 0.55]:
		A(ci, Vector2(w * f * 0.3 + 4.0, dw.get_center().y), h * 0.2, -0.9, 0.9, 0.4)
	# cryocooler and readout box
	R(ci, Rect2(dw.end.x, dw.get_center().y - h * 0.12, w * 0.16, h * 0.24), 0.5)
	E.hatch(ci, Rect2(dw.end.x + 2.0, dw.get_center().y - h * 0.1, w * 0.12, h * 0.2), 2.5, true, 0.25, 12)
	R(ci, Rect2(dw.position.x + dw.size.x * 0.2, dw.end.y, dw.size.x * 0.6, h * 0.12), 0.45)


# a spectrograph: the slit, the collimator mirror, the diffraction grating (ruled),
# the camera optics and the detector, all on its bench under the light-tight cover
static func spectrograph(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, 1, w - 2, h - 2), 0.45)
	L(ci, Vector2(1, h * 0.86), Vector2(w - 1, h * 0.86), 0.5, 1.4)
	var slit := Vector2(w * 0.06, h * 0.3)
	L(ci, slit + Vector2(0, -h * 0.08), slit + Vector2(0, -1.0), 0.7, 1.6)
	L(ci, slit + Vector2(0, 1.0), slit + Vector2(0, h * 0.08), 0.7, 1.6)
	var col := Vector2(w * 0.86, h * 0.3)
	A(ci, col + Vector2(w * 0.2, 0), w * 0.2, PI - 0.5, PI + 0.5, 0.65, 1.8)
	var gr := Vector2(w * 0.45, h * 0.62)
	var gt := Vector2.from_angle(0.5) * h * 0.18
	L(ci, gr - gt, gr + gt, 0.7, 2.0)
	var segs := PackedVector2Array()
	for k in 7:
		var q: Vector2 = (gr - gt).lerp(gr + gt, (k + 0.5) / 7.0)
		segs.append(q)
		segs.append(q + Vector2.from_angle(0.5 + PI * 0.5) * 2.5)
	S(ci, segs, 0.45)
	P(ci, PackedVector2Array([slit, col + Vector2(-2, 0), gr]), 0.25)
	var cam := Vector2(w * 0.16, h * 0.68)
	L(ci, gr, cam, 0.25)
	L(ci, gr, cam + Vector2(0, -h * 0.08), 0.2)
	L(ci, gr, cam + Vector2(0, h * 0.08), 0.2)
	for k in 2:
		A(ci, Vector2(w * (0.28 - k * 0.04) + h * 0.1, h * 0.68), h * 0.12, PI - 0.7, PI + 0.7, 0.45)
	R(ci, Rect2(w * 0.04, h * 0.58, w * 0.05, h * 0.2), 0.65)


# a fine guidance sensor: the pick-off mirror, the relay optics, the two guide
# detectors on their focus mechanisms, the electronics box
static func fgs(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(w * 0.04, h * 0.04, w * 0.92, h * 0.62), 0.5)
	L(ci, Vector2(w * 0.1, h * 0.1), Vector2(w * 0.24, h * 0.28), 0.7, 2.0)
	P(ci, PackedVector2Array([Vector2(w * 0.17, 0), Vector2(w * 0.17, h * 0.19), Vector2(w * 0.86, h * 0.19)]), 0.25)
	for f in [0.4, 0.55]:
		A(ci, Vector2(w * f + h * 0.12, h * 0.19), h * 0.12, PI - 0.6, PI + 0.6, 0.45)
	for k in 2:
		var d := Rect2(w * (0.66 + k * 0.14), h * 0.1, w * 0.1, h * 0.3)
		R(ci, d, 0.55)
		R(ci, Rect2(d.position.x + 1.5, d.position.y + d.size.y * 0.3, 2.0, d.size.y * 0.4), 0.7)
	L(ci, Vector2(w * 0.86, h * 0.19), Vector2(w * 0.86, h * 0.4), 0.2)
	var eb := Rect2(w * 0.1, h * 0.7, w * 0.8, h * 0.26)
	R(ci, eb, 0.45)
	E.hatch(ci, sub(eb, 0.05, 0.2, 0.5, 0.8), 3.0, true, 0.22, 20)
	for k in 3:
		O(ci, eb.position + eb.size * Vector2(0.62 + k * 0.12, 0.5), minf(eb.size.y * 0.2, 3.0), 0.5)


# a Shack-Hartmann wavefront sensor: the pick-off, the collimating lens, the
# lenslet array (a column of little lenses), the camera behind it seeing the spot
# grid, the reference source and the processing electronics, on a vertical bench
static func wfs(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, 1, w - 2, h - 2), 0.45)
	var ax: float = w * 0.45
	# the beam down the bench
	L(ci, Vector2(ax, 0), Vector2(ax, h * 0.62), 0.22)
	# collimator
	A(ci, Vector2(ax, h * 0.12 + w * 0.35), w * 0.35, -PI * 0.5 - 0.6, -PI * 0.5 + 0.6, 0.55, 1.4)
	A(ci, Vector2(ax, h * 0.12 - w * 0.35 + 6.0), w * 0.35, PI * 0.5 - 0.6, PI * 0.5 + 0.6, 0.55, 1.4)
	# lenslet array: a row of small lenses across the beam
	var la: float = h * 0.36
	var n := clampi(int(w * 0.6 / 4.0), 4, 16)
	for k in n:
		var x: float = ax - w * 0.3 + (k + 0.5) * w * 0.6 / n
		A(ci, Vector2(x, la), w * 0.3 / n, PI, TAU, 0.55)
		L(ci, Vector2(x, la), Vector2(x, h * 0.5), 0.15)
	L(ci, Vector2(ax - w * 0.32, la), Vector2(ax + w * 0.32, la), 0.5)
	# camera with its spot grid
	var cam := Rect2(ax - w * 0.32, h * 0.5, w * 0.64, h * 0.16)
	R(ci, cam, 0.6, 1.2)
	var dots := PackedVector2Array()
	for k in n:
		for j in 2:
			var q := Vector2(cam.position.x + (k + 0.5) * cam.size.x / n + (0.8 if (k + j) % 3 == 0 else 0.0), cam.position.y + cam.size.y * (0.35 + j * 0.3))
			dots.append(q)
			dots.append(q + Vector2(0.8, 0))
	S(ci, dots, 0.7)
	# reference source and electronics
	R(ci, Rect2(w * 0.78, h * 0.16, w * 0.16, h * 0.1), 0.5)
	L(ci, Vector2(w * 0.78, h * 0.21), Vector2(ax, h * 0.21), 0.2)
	var eb := Rect2(w * 0.1, h * 0.72, w * 0.8, h * 0.24)
	R(ci, eb, 0.5)
	E.screen_face(ci, sub(eb, 0.06, 0.15, 0.5, 0.85), 2, 0.35)
	E.hatch(ci, sub(eb, 0.58, 0.2, 0.94, 0.8), 3.0, true, 0.22, 16)


# a mirror recoater: the vacuum chamber with its door, the evaporation sources and
# their shutter, the segment held face-down in its fixture, the pumps
static func recoater(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var ch := Rect2(w * 0.06, h * 0.08, w * 0.7, h * 0.76)
	R(ci, ch, 0.6, 1.2)
	E.corner_bolts(ci, ch, 3.0, 0.5)
	var seg := Rect2(ch.position.x + ch.size.x * 0.2, ch.position.y + ch.size.y * 0.12, ch.size.x * 0.6, ch.size.y * 0.08)
	R(ci, seg, 0.55)
	L(ci, Vector2(seg.position.x, seg.end.y), Vector2(seg.end.x, seg.end.y), 0.8, 2.0)
	for k in 3:
		var sc := Vector2(ch.position.x + ch.size.x * (0.3 + k * 0.2), ch.end.y - ch.size.y * 0.15)
		A(ci, sc, ch.size.x * 0.05, PI, TAU, 0.6)
		L(ci, sc, sc + Vector2(0, ch.size.y * 0.1), 0.45)
		for e in [-0.3, 0.0, 0.3]:
			L(ci, sc + Vector2(0, -ch.size.x * 0.06), sc + Vector2.from_angle(-PI * 0.5 + e) * ch.size.y * 0.4, 0.12)
	L(ci, Vector2(ch.position.x + ch.size.x * 0.2, ch.position.y + ch.size.y * 0.6), Vector2(ch.end.x - ch.size.x * 0.2, ch.position.y + ch.size.y * 0.6), 0.4, 1.4)
	R(ci, Rect2(w * 0.78, h * 0.3, w * 0.18, h * 0.4), 0.5)
	E.hatch(ci, Rect2(w * 0.8, h * 0.34, w * 0.14, h * 0.32), 3.0, false, 0.25, 12)
	L(ci, Vector2(ch.end.x, h * 0.5), Vector2(w * 0.78, h * 0.5), 0.45, 1.4)
	L(ci, Vector2(2, h * 0.96), Vector2(w - 2, h * 0.96), 0.5, 1.4)


# a reaction wheel: the flywheel's rim and web in its housing, the hub on the
# motor's bearings, the stator coils, the housing's bolt flange
static func reaction_wheel(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var c := Vector2(w * 0.5, h * 0.5)
	var rad: float = minf(w, h) * 0.46
	O(ci, c, rad, 0.6, 1.2)
	for k in 12:
		D(ci, c + Vector2.from_angle(TAU * k / 12.0) * rad * 0.94, 0.8, 0.5)
	O(ci, c, rad * 0.8, 0.55, 1.4)
	O(ci, c, rad * 0.7, 0.3)
	for k in 6:
		var a: float = TAU * k / 6.0
		L(ci, c + Vector2.from_angle(a) * rad * 0.28, c + Vector2.from_angle(a) * rad * 0.7, 0.3)
	O(ci, c, rad * 0.28, 0.5)
	for k in 9:
		var a: float = TAU * k / 9.0
		R(ci, Rect2(c + Vector2.from_angle(a) * rad * 0.19 - Vector2(1.5, 1.5), Vector2(3, 3)), 0.4)
	D(ci, c, 1.4, 0.6)


# a star tracker: its long sun baffle with the vanes inside, the optical head and
# the electronics box at the root
static func star_tracker(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var bt := Rect2(w * 0.24, 1, w * 0.52, h * 0.6)
	P(ci, PackedVector2Array([Vector2(bt.position.x - w * 0.1, bt.position.y), Vector2(bt.position.x, bt.end.y), Vector2(bt.end.x, bt.end.y), Vector2(bt.end.x + w * 0.1, bt.position.y)]), 0.6)
	var segs := PackedVector2Array()
	for k in 4:
		var y: float = bt.position.y + bt.size.y * (0.2 + k * 0.2)
		var inset_x: float = w * 0.1 * (1.0 - (y - bt.position.y) / bt.size.y)
		segs.append(Vector2(bt.position.x - inset_x + 1.0, y))
		segs.append(Vector2(bt.position.x + bt.size.x * 0.3, y))
		segs.append(Vector2(bt.end.x - bt.size.x * 0.3, y))
		segs.append(Vector2(bt.end.x + inset_x - 1.0, y))
	S(ci, segs, 0.4)
	R(ci, Rect2(w * 0.18, h * 0.62, w * 0.64, h * 0.34), 0.6)
	O(ci, Vector2(w * 0.5, h * 0.62), w * 0.14, 0.5)


# ================================================================== DC-84 Deep Mind

# a server rack standing in its immersion tank: blade servers on edge, their heat
# sinks, the dielectric's surface across them, the lifting lugs and the power
# shelf above the fluid
static func immersion_rack(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var fl: float = h * 0.18
	R(ci, Rect2(1, 1, w - 2, h * 0.1), 0.55)
	for f in [0.15, 0.85]:
		A(ci, Vector2(w * f, 1.0), minf(w * 0.04, 4.0), PI, TAU, 0.6, 1.4)
	var pts := PackedVector2Array()
	var nw := clampi(int(w / 6.0), 3, 60)
	for k in nw + 1:
		pts.append(Vector2(w * k / nw, fl + (1.0 if k % 2 == 0 else -1.0)))
	P(ci, pts, 0.45)
	E.F(ci, Rect2(1, fl, w - 2, h - fl - 1.0), 0.03)
	var n := clampi(int(w / 7.0), 3, 40)
	var bw: float = (w - 4.0) / n
	for k in n:
		var b := Rect2(2.0 + k * bw + 0.5, h * 0.14, bw - 1.0, h * 0.82)
		R(ci, b, 0.4)
		E.hatch(ci, Rect2(b.position.x + 1.0, b.position.y + b.size.y * 0.35, b.size.x - 2.0, b.size.y * 0.3), 2.0, false, 0.22, 20)
		D(ci, Vector2(b.get_center().x, b.position.y + 3.0), 0.8, 0.7)
		R(ci, Rect2(b.position.x + 1.0, b.end.y - b.size.y * 0.15, b.size.x - 2.0, b.size.y * 0.1), 0.3)


# a coolant distribution unit: the brazed plate heat exchanger (its plate stack),
# the two pumps, the filter, the expansion vessel, the controller with its display
static func cdu(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, 1, w - 2, h - 2), 0.45)
	var hx := Rect2(w * 0.06, h * 0.08, w * 0.28, h * 0.6)
	R(ci, hx, 0.6, 1.2)
	E.hatch(ci, E.inset(hx, 1.5), 2.2, true, 0.3, 40)
	for f in [0.15, 0.85]:
		O(ci, Vector2(hx.get_center().x, hx.position.y + hx.size.y * f), minf(hx.size.x * 0.18, 4.0), 0.55)
	for k in 2:
		var pc := Vector2(w * (0.48 + k * 0.22), h * 0.74)
		var pr: float = minf(w * 0.08, h * 0.1)
		O(ci, pc, pr, 0.55)
		E.impeller(ci, pc, pr * 0.75, 0.4)
		R(ci, Rect2(pc.x - pr * 0.6, pc.y - pr * 3.2, pr * 1.2, pr * 2.2), 0.5)
		E.hatch(ci, Rect2(pc.x - pr * 0.5, pc.y - pr * 3.1, pr, pr * 2.0), 2.5, false, 0.2, 10)
	var ev := Rect2(w * 0.84, h * 0.08, w * 0.1, h * 0.36)
	E.vessel_v(ci, ev, 0.5)
	R(ci, Rect2(w * 0.08, h * 0.74, w * 0.22, h * 0.18), 0.5)
	E.pleats(ci, Rect2(w * 0.1, h * 0.76, w * 0.18, h * 0.14), 3.0, true, 0.3)
	E.screen_face(ci, Rect2(w * 0.42, h * 0.08, w * 0.34, h * 0.18), 0, 0.4)
	L(ci, Vector2(hx.end.x, hx.position.y + hx.size.y * 0.85), Vector2(w * 0.48, hx.position.y + hx.size.y * 0.85), 0.4, 1.4)


# a dry cooler: the finned coil in a V under its row of fans, the headers, the legs
static func dry_cooler(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var n := clampi(roundi(w / (h * 0.9)), 1, 8)
	var cw: float = w / n
	for i in n:
		var x0: float = i * cw
		var top: float = h * 0.18
		P(ci, PackedVector2Array([Vector2(x0 + cw * 0.06, top), Vector2(x0 + cw * 0.5, h * 0.8), Vector2(x0 + cw * 0.94, top)]), 0.6, 1.2)
		var segs := PackedVector2Array()
		for k in 7:
			var t: float = (k + 1) / 8.0
			var a := Vector2(x0 + cw * 0.06, top).lerp(Vector2(x0 + cw * 0.5, h * 0.8), t)
			var b := Vector2(x0 + cw * 0.94, top).lerp(Vector2(x0 + cw * 0.5, h * 0.8), t)
			segs.append(a + Vector2(-2, 0))
			segs.append(a + Vector2(2, 0))
			segs.append(b + Vector2(-2, 0))
			segs.append(b + Vector2(2, 0))
		S(ci, segs, 0.35)
		R(ci, Rect2(x0 + cw * 0.1, 1, cw * 0.8, top - 2.0), 0.5)
		E.fan(ci, Vector2(x0 + cw * 0.5, top * 0.5), minf(cw * 0.36, top * 0.42), 5, 0.4)
	L(ci, Vector2(2, h * 0.84), Vector2(w - 2, h * 0.84), 0.5, 1.4)
	for f in [0.05, 0.95]:
		L(ci, Vector2(w * f, h * 0.84), Vector2(w * f, h - 1.0), 0.5, 1.4)


# a storage array: disk shelves stacked, each a row of drive carriers with their
# lights, the controller shelf at the top
static func storage_array(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	L(ci, Vector2(2, 1), Vector2(2, h - 1), 0.5)
	L(ci, Vector2(w - 2, 1), Vector2(w - 2, h - 1), 0.5)
	var ctl := Rect2(4, 2, w - 8, h * 0.12)
	R(ci, ctl, 0.55)
	for k in 2:
		R(ci, Rect2(ctl.position.x + 2.0 + k * ctl.size.x * 0.5, ctl.position.y + 2.0, ctl.size.x * 0.46, ctl.size.y - 4.0), 0.4)
	var sh: float = clampf(h / 8.0, 10.0, 20.0)
	var y: float = ctl.end.y + 2.0
	while y + sh < h - 2.0:
		var b := Rect2(4, y, w - 8, sh - 2.0)
		R(ci, b, 0.42)
		var nd := clampi(int(b.size.x / 3.6), 4, 40)
		var segs := PackedVector2Array()
		for i in nd:
			var x: float = b.position.x + (i + 0.5) * b.size.x / nd
			segs.append(Vector2(x, b.position.y + 1.5))
			segs.append(Vector2(x, b.end.y - 3.0))
		S(ci, segs, 0.25)
		for i in range(0, nd, 2):
			D(ci, Vector2(b.position.x + (i + 0.5) * b.size.x / nd, b.end.y - 1.5), 0.6, 0.7)
		y += sh


# a core switch chassis: the supervisor modules, the line cards with their rows of
# ports and status lights, the fan trays, the power supplies at the foot
static func switch_chassis(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, 1, w - 2, h - 2), 0.5)
	E.hatch(ci, Rect2(4, 3, w - 8, h * 0.06), 3.0, true, 0.3, 40)
	var n := clampi(int(h * 0.74 / 9.0), 4, 18)
	var lh: float = h * 0.74 / n
	for k in n:
		var b := Rect2(4, h * 0.1 + k * lh, w - 8, lh - 1.5)
		R(ci, b, 0.4)
		if k < 2:
			E.screen_face(ci, Rect2(b.position.x + 2.0, b.position.y + 1.0, b.size.x * 0.3, b.size.y - 2.0), 3, 0.3)
			continue
		var np := clampi(int(b.size.x * 0.8 / 3.2), 4, 48)
		var segs := PackedVector2Array()
		for i in np:
			var x: float = b.position.x + b.size.x * 0.15 + i * b.size.x * 0.8 / np
			segs.append(Vector2(x, b.get_center().y - 1.0))
			segs.append(Vector2(x, b.get_center().y + 1.0))
		S(ci, segs, 0.5)
		D(ci, Vector2(b.position.x + 3.0, b.get_center().y), 0.7, 0.7)
	for k in 3:
		R(ci, Rect2(4 + k * (w - 8) / 3.0 + 1.0, h * 0.86, (w - 8) / 3.0 - 2.0, h * 0.11), 0.45)


# a drive in its carrier: the latch handle, the activity light, the label window
static func drive_carrier(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, 1, w - 2, h - 2), 0.55)
	R(ci, Rect2(w * 0.08, h * 0.2, w * 0.5, h * 0.6), 0.4)
	E.hatch(ci, Rect2(w * 0.1, h * 0.25, w * 0.46, h * 0.5), 2.5, true, 0.25, 12)
	L(ci, Vector2(w * 0.66, h * 0.3), Vector2(w * 0.94, h * 0.5), 0.6, 1.4)
	D(ci, Vector2(w * 0.8, h * 0.78), 0.8, 0.8)


# ================================================================== ARK-01 Voyager

# a pressurised-water reactor cut through: the vessel with its hemispherical bottom
# head and the bolted closure head (the stud ring), the control rod drive housings
# standing on the head, the inlet and outlet nozzles, the core barrel, the core of
# fuel assemblies (the rods in some of them pulled), the lower plenum
static func pwr_core(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var vw: float = minf(w * 0.66, h * 0.6)
	var cx: float = w * 0.5
	var vx0: float = cx - vw * 0.5
	var vx1: float = cx + vw * 0.5
	var hry: float = minf(vw * 0.32, h * 0.1)
	var head_y: float = h * 0.2 + hry
	var top: float = head_y + h * 0.05
	var bry: float = minf(vw * 0.4, h * 0.12)
	var bot: float = h * 0.97 - bry
	# vessel walls and the bottom head (the cladding inside)
	for t in [0.0, 3.5]:
		var al: float = 0.6 if t == 0.0 else 0.32
		L(ci, Vector2(vx0 + t, top), Vector2(vx0 + t, bot), al, 1.4 if t == 0.0 else 1.0)
		L(ci, Vector2(vx1 - t, top), Vector2(vx1 - t, bot), al, 1.4 if t == 0.0 else 1.0)
		E._head(ci, Vector2(cx, bot), vw * 0.5 - t, bry - t, false, al)
	# the closure flange with its stud ring, the closure head
	R(ci, Rect2(vx0 - w * 0.04, head_y, vw + w * 0.08, top - head_y), 0.65, 1.4)
	E.bolts(ci, Vector2(vx0 - w * 0.02, (head_y + top) * 0.5), Vector2(vx1 + w * 0.02, (head_y + top) * 0.5), clampi(int(vw / 6.0), 6, 30), 0.6, 1.0)
	E._head(ci, Vector2(cx, head_y), vw * 0.5, hry, true, 0.6)
	# CRDM housings standing on the head, their cooling shroud's top ring
	var nd := clampi(int(vw / 9.0), 3, 13)
	var segs := PackedVector2Array()
	for k in nd:
		var x: float = vx0 + vw * (0.15 + 0.7 * (k + 0.5) / nd)
		var u: float = (x - cx) / (vw * 0.5)
		var y0: float = head_y - hry * sqrt(maxf(0.0, 1.0 - u * u))
		segs.append(Vector2(x - 1.5, y0))
		segs.append(Vector2(x - 1.5, h * 0.03))
		segs.append(Vector2(x + 1.5, y0))
		segs.append(Vector2(x + 1.5, h * 0.03))
	S(ci, segs, 0.4)
	L(ci, Vector2(vx0 + vw * 0.12, h * 0.03), Vector2(vx1 - vw * 0.12, h * 0.03), 0.5, 1.4)
	R(ci, Rect2(vx0 + vw * 0.1, h * 0.08, vw * 0.8, h * 0.05), 0.35)
	# nozzles: hot leg out one side, cold leg in the other
	for sg in [-1.0, 1.0]:
		var x: float = vx0 if sg < 0.0 else vx1
		var ny: float = top + (bot - top) * 0.12
		var nh: float = minf(h * 0.04, vw * 0.06)
		L(ci, Vector2(x, ny - nh), Vector2(x + sg * (w * 0.5 - vw * 0.5 - 2.0), ny - nh), 0.55, 1.2)
		L(ci, Vector2(x, ny + nh), Vector2(x + sg * (w * 0.5 - vw * 0.5 - 2.0), ny + nh), 0.55, 1.2)
	# core barrel and the core
	var cb0: float = vx0 + vw * 0.1
	var cb1: float = vx1 - vw * 0.1
	L(ci, Vector2(cb0, top + 2.0), Vector2(cb0, bot + bry * 0.3), 0.45)
	L(ci, Vector2(cb1, top + 2.0), Vector2(cb1, bot + bry * 0.3), 0.45)
	var core := Rect2(cb0 + 3.0, top + (bot - top) * 0.3, cb1 - cb0 - 6.0, (bot - top) * 0.6)
	R(ci, core, 0.55)
	var na := clampi(int(core.size.x / 7.0), 3, 15)
	var fa := PackedVector2Array()
	for k in na:
		var x0: float = core.position.x + k * core.size.x / na
		fa.append(Vector2(x0, core.position.y))
		fa.append(Vector2(x0, core.end.y))
		var nr := clampi(int(core.size.x / na / 2.2), 1, 4)
		for e in nr:
			var x: float = x0 + (e + 0.5) * core.size.x / na / nr
			fa.append(Vector2(x, core.position.y + 2.0))
			fa.append(Vector2(x, core.end.y - 2.0))
	S(ci, fa, 0.25)
	# control rods: some in, some drawn up into the upper internals
	for k in range(1, na, 2):
		var x: float = core.position.x + (k + 0.5) * core.size.x / na
		var tip: float = core.position.y + (core.size.y * 0.8 if k % 4 == 1 else -(bot - top) * 0.12)
		L(ci, Vector2(x, top + 2.0), Vector2(x, tip), 0.55, 1.4)
	# upper and lower core support plates
	L(ci, Vector2(cb0, core.position.y - 3.0), Vector2(cb1, core.position.y - 3.0), 0.4, 1.4)
	L(ci, Vector2(cb0, core.end.y + 3.0), Vector2(cb1, core.end.y + 3.0), 0.4, 1.4)


# a reactor coolant pump: the canned motor standing on top with its flywheel and
# cooling jacket, the seal housing, the pump casing with suction below and the
# discharge out the side
static func rcp(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cx: float = w * 0.45
	var mw: float = w * 0.42
	var mot := Rect2(cx - mw * 0.5, h * 0.06, mw, h * 0.42)
	R(ci, mot, 0.6, 1.2)
	E.hatch(ci, E.inset(mot, 2.0), 3.2, true, 0.2, 24)
	R(ci, Rect2(cx - mw * 0.6, h * 0.02, mw * 1.2, h * 0.05), 0.55)
	L(ci, Vector2(cx - mw * 0.55, h * 0.3), Vector2(cx + mw * 0.55, h * 0.3), 0.45, 1.4)
	R(ci, Rect2(cx - mw * 0.3, mot.end.y, mw * 0.6, h * 0.12), 0.55)
	L(ci, Vector2(cx, mot.end.y), Vector2(cx, mot.end.y + h * 0.12), 0.5, 1.4)
	var pc := Vector2(cx, h * 0.76)
	var pr: float = minf(w * 0.3, h * 0.18)
	P(ci, PackedVector2Array([pc + Vector2(-pr, -pr * 0.6), pc + Vector2(-pr * 0.8, -pr), pc + Vector2(pr * 0.8, -pr), pc + Vector2(pr, -pr * 0.6), pc + Vector2(pr, pr * 0.6), pc + Vector2(pr * 0.6, pr), pc + Vector2(-pr * 0.6, pr), pc + Vector2(-pr, pr * 0.6), pc + Vector2(-pr, -pr * 0.6)]), 0.6, 1.2)
	E.impeller(ci, pc, pr * 0.6, 0.45)
	L(ci, Vector2(pc.x - pr * 0.3, pc.y + pr), Vector2(pc.x - pr * 0.3, h), 0.5)
	L(ci, Vector2(pc.x + pr * 0.3, pc.y + pr), Vector2(pc.x + pr * 0.3, h), 0.5)
	L(ci, Vector2(pc.x + pr, pc.y - pr * 0.35), Vector2(w - 2.0, pc.y - pr * 0.35), 0.5, 1.2)
	L(ci, Vector2(pc.x + pr, pc.y + pr * 0.25), Vector2(w - 2.0, pc.y + pr * 0.25), 0.5, 1.2)
	E.flange(ci, Vector2(w - 3.0, pc.y - pr * 0.05), Vector2.RIGHT, pr * 0.42, 0.55)


# the pressuriser: its tall vessel, the steam space over the water line, the spray
# nozzle in the top head, the relief and safety valves on top, the immersion
# heaters through the bottom head, the surge line
static func pressurizer(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var vs := Rect2(w * 0.18, h * 0.1, w * 0.64, h * 0.78)
	var sh := E.vessel_v(ci, vs, 0.6)
	var lv: float = sh.position.y + sh.size.y * 0.42
	var pts := PackedVector2Array()
	var nw := clampi(int(sh.size.x / 5.0), 3, 20)
	for k in nw + 1:
		pts.append(Vector2(sh.position.x + sh.size.x * k / nw, lv + (1.0 if k % 2 == 0 else -1.0)))
	P(ci, pts, 0.45)
	E.F(ci, Rect2(sh.position.x, lv, sh.size.x, sh.end.y - lv), 0.035)
	# heaters up from the bottom head
	var segs := PackedVector2Array()
	for k in 5:
		var x: float = sh.position.x + sh.size.x * (0.2 + k * 0.15)
		segs.append(Vector2(x, vs.end.y + h * 0.04))
		segs.append(Vector2(x, sh.end.y - sh.size.y * 0.3))
	S(ci, segs, 0.4)
	# spray nozzle and the valves on top
	L(ci, Vector2(w * 0.5, vs.position.y), Vector2(w * 0.5, sh.position.y + sh.size.y * 0.08), 0.5)
	P(ci, PackedVector2Array([Vector2(w * 0.44, sh.position.y + sh.size.y * 0.1), Vector2(w * 0.5, sh.position.y + sh.size.y * 0.06), Vector2(w * 0.56, sh.position.y + sh.size.y * 0.1)]), 0.45)
	for f in [0.32, 0.68]:
		L(ci, Vector2(w * f, vs.position.y + h * 0.02), Vector2(w * f, h * 0.03), 0.5)
		R(ci, Rect2(w * f - 3.0, h * 0.01, 6.0, h * 0.05), 0.55)
	L(ci, Vector2(w * 0.5, vs.end.y), Vector2(w * 0.5, h - 1.0), 0.55, 1.4)


# a control rod drive mechanism: the pressure housing, the latch and the lift and
# hold coil stacks round it, the rod position indicator coil above, the drive rod
static func crdm(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cx: float = w * 0.5
	L(ci, Vector2(cx - w * 0.12, 0), Vector2(cx - w * 0.12, h), 0.55)
	L(ci, Vector2(cx + w * 0.12, 0), Vector2(cx + w * 0.12, h), 0.55)
	L(ci, Vector2(cx, 0), Vector2(cx, h), 0.3)
	for k in 3:
		var c := Rect2(cx - w * 0.36, h * (0.52 + k * 0.14), w * 0.72, h * 0.11)
		R(ci, c, 0.55)
		E.hatch(ci, Rect2(c.position.x + 1.5, c.position.y + 1.0, c.size.x - 3.0, c.size.y - 2.0), 2.5, false, 0.25, 10)
	var rpi := Rect2(cx - w * 0.26, h * 0.08, w * 0.52, h * 0.36)
	R(ci, rpi, 0.5)
	E.hatch(ci, E.inset(rpi, 1.5), 3.0, false, 0.18, 30)
	R(ci, Rect2(cx - w * 0.4, h * 0.94, w * 0.8, h * 0.05), 0.6)


# a steam turbine set: the high-pressure cylinder and the bigger low-pressure one
# on one shaft, their blade rows growing longer toward the exhaust, the steam chest
# and governor valves on top, the bearings, the exhaust down to the condenser
static func steam_turbine(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var ay: float = h * 0.5
	var segs := PackedVector2Array()
	# HP: small, LP: double-flow, large
	var hp0: float = w * 0.04
	var hp1: float = w * 0.36
	var lp0: float = w * 0.42
	var lp1: float = w * 0.96
	P(ci, PackedVector2Array([Vector2(hp0, ay - h * 0.14), Vector2(hp1, ay - h * 0.24), Vector2(hp1, ay + h * 0.24), Vector2(hp0, ay + h * 0.14), Vector2(hp0, ay - h * 0.14)]), 0.6, 1.2)
	var lc: float = (lp0 + lp1) * 0.5
	P(ci, PackedVector2Array([Vector2(lp0, ay - h * 0.2), Vector2(lc - w * 0.04, ay - h * 0.26), Vector2(lc + w * 0.04, ay - h * 0.26), Vector2(lp1, ay - h * 0.2), Vector2(lp1, ay + h * 0.36), Vector2(lp0, ay + h * 0.36), Vector2(lp0, ay - h * 0.2)]), 0.6, 1.2)
	L(ci, Vector2(1, ay), Vector2(w - 1, ay), 0.35)
	var n := clampi(int((hp1 - hp0) / 5.0), 3, 14)
	for k in n:
		var x: float = hp0 + (k + 0.5) * (hp1 - hp0) / n
		var bl: float = lerpf(h * 0.1, h * 0.2, float(k) / n)
		segs.append(Vector2(x, ay - bl))
		segs.append(Vector2(x, ay + bl))
	n = clampi(int((lp1 - lp0) / 10.0), 2, 10)
	for k in n:
		var t: float = absf((k + 0.5) / n - 0.5) * 2.0
		var x: float = lp0 + (k + 0.5) * (lp1 - lp0) / n
		var bl: float = lerpf(h * 0.08, h * 0.24, t)
		segs.append(Vector2(x, ay - bl))
		segs.append(Vector2(x, ay + bl))
	S(ci, segs, 0.35)
	# steam chest and valves, crossover pipe
	R(ci, Rect2(hp0 + w * 0.04, h * 0.06, w * 0.14, h * 0.12), 0.55)
	for k in 2:
		E.wheel(ci, Vector2(hp0 + w * (0.07 + k * 0.08), h * 0.04), minf(h * 0.03, 4.0), 0.5)
	P(ci, PackedVector2Array([Vector2(hp1 - w * 0.04, ay - h * 0.24), Vector2(hp1 - w * 0.04, h * 0.1), Vector2(lc, h * 0.1), Vector2(lc, ay - h * 0.26)]), 0.5, 1.4)
	# bearings and the exhaust hood to the condenser
	for x in [hp0, hp1 + w * 0.03, lp1]:
		R(ci, Rect2(x - 3.0, ay - h * 0.06, 6.0, h * 0.12), 0.55)
	P(ci, PackedVector2Array([Vector2(lp0 + w * 0.06, ay + h * 0.36), Vector2(lp0 + w * 0.1, h - 1.0), Vector2(lp1 - w * 0.1, h - 1.0), Vector2(lp1 - w * 0.06, ay + h * 0.36)]), 0.45)


# a surface condenser: the shell, the tube bundle (its tubes end-on), the tube
# sheets and waterboxes at the ends, the exhaust neck in the top, the hotwell
static func condenser(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var sh := E.vessel_h(ci, Rect2(w * 0.02, h * 0.18, w * 0.96, h * 0.6), 0.6)
	var dots := PackedVector2Array()
	var nx := clampi(int(sh.size.x / 5.0), 3, 60)
	var ny := clampi(int(sh.size.y * 0.6 / 5.0), 2, 12)
	for j in ny:
		for i in nx:
			var q := Vector2(sh.position.x + (i + 0.5 + (0.5 if j % 2 == 1 else 0.0)) * sh.size.x / (nx + 0.5), sh.position.y + sh.size.y * 0.25 + j * sh.size.y * 0.6 / ny)
			dots.append(q)
			dots.append(q + Vector2(0.9, 0))
	S(ci, dots, 0.4)
	P(ci, PackedVector2Array([Vector2(w * 0.3, sh.position.y), Vector2(w * 0.34, h * 0.02), Vector2(w * 0.66, h * 0.02), Vector2(w * 0.7, sh.position.y)]), 0.5)
	R(ci, Rect2(w * 0.35, sh.end.y, w * 0.3, h * 0.18), 0.5)
	L(ci, Vector2(w * 0.5, sh.end.y + h * 0.18), Vector2(w * 0.5, h), 0.5)


# a ring's despin brake: the brake disc on the hub, the calipers with their pads
# and hydraulic cylinders, the cooling fins on the disc
static func despin_brake(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var c := Vector2(w * 0.42, h * 0.5)
	var rad: float = minf(w * 0.4, h * 0.46)
	O(ci, c, rad, 0.6, 1.4)
	O(ci, c, rad * 0.62, 0.45)
	var segs := PackedVector2Array()
	for k in 24:
		var a: float = TAU * k / 24.0
		segs.append(c + Vector2.from_angle(a) * rad * 0.66)
		segs.append(c + Vector2.from_angle(a + 0.12) * rad * 0.96)
	S(ci, segs, 0.25)
	O(ci, c, rad * 0.2, 0.55)
	for k in 6:
		D(ci, c + Vector2.from_angle(TAU * k / 6.0) * rad * 0.42, 1.0, 0.55)
	for a in [-0.5, 0.5]:
		var q: Vector2 = c + Vector2.from_angle(a) * rad * 0.82
		var t := Vector2.from_angle(a)
		P(ci, PackedVector2Array([q - t * rad * 0.22 + t.orthogonal() * rad * 0.18, q + t * rad * 0.34 + t.orthogonal() * rad * 0.18, q + t * rad * 0.34 - t.orthogonal() * rad * 0.18, q - t * rad * 0.22 - t.orthogonal() * rad * 0.18, q - t * rad * 0.22 + t.orthogonal() * rad * 0.18]), 0.6, 1.2)
		L(ci, q + t * rad * 0.34, Vector2(w - 2.0, q.y), 0.4)


# a slip ring: the stack of rings on the rotating side, the brush block on the
# fixed side with a brush on each ring, the cables out of both
static func slip_ring(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var st := Rect2(w * 0.18, h * 0.08, w * 0.4, h * 0.84)
	R(ci, st, 0.55)
	var n := clampi(int(st.size.y / 5.0), 3, 14)
	for k in n:
		var y: float = st.position.y + (k + 0.5) * st.size.y / n
		L(ci, Vector2(st.position.x - 2.0, y), Vector2(st.end.x + 2.0, y), 0.55, 1.6)
		L(ci, Vector2(st.end.x + 2.0, y), Vector2(w * 0.74, y), 0.35)
	R(ci, Rect2(w * 0.74, h * 0.1, w * 0.16, h * 0.8), 0.55)
	L(ci, Vector2(w * 0.38, 0), Vector2(w * 0.38, h), 0.25)
	for f in [0.25, 0.75]:
		L(ci, Vector2(w * 0.9, h * f), Vector2(w - 1.0, h * f), 0.4)
		L(ci, Vector2(1, h * f), Vector2(st.position.x, h * f), 0.4)


# a rotary seal between the turning hub and the fixed spine: the labyrinth of teeth
# from either side, the buffer gas groove, the seal housing bolts
static func rotary_seal(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, 1, w - 2, h * 0.3), 0.55)
	R(ci, Rect2(1, h * 0.7, w - 2, h * 0.29), 0.55)
	var n := clampi(int(w / 6.0), 3, 30)
	var segs := PackedVector2Array()
	for k in n:
		var x: float = (k + 0.5) * w / n
		if k % 2 == 0:
			segs.append(Vector2(x, h * 0.31))
			segs.append(Vector2(x, h * 0.6))
		else:
			segs.append(Vector2(x, h * 0.69))
			segs.append(Vector2(x, h * 0.4))
	S(ci, segs, 0.5)
	R(ci, Rect2(w * 0.45, h * 0.31, w * 0.1, h * 0.08), 0.5)
	L(ci, Vector2(w * 0.5, 0), Vector2(w * 0.5, h * 0.31), 0.4)
	E.bolts(ci, Vector2(3, h * 0.15), Vector2(w - 3, h * 0.15), clampi(int(w / 9.0), 2, 12), 0.5, 0.9)
	E.bolts(ci, Vector2(3, h * 0.85), Vector2(w - 3, h * 0.85), clampi(int(w / 9.0), 2, 12), 0.5, 0.9)


# a spoke elevator car: the cage with its doors, the rack and pinion drive on the
# guide rail, the drive motor on the roof, the safety gear under the floor
static func spoke_lift(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cg := Rect2(w * 0.12, h * 0.16, w * 0.76, h * 0.72)
	R(ci, cg, 0.6, 1.2)
	L(ci, Vector2(cg.get_center().x, cg.position.y + 3.0), Vector2(cg.get_center().x, cg.end.y - 3.0), 0.4)
	R(ci, E.inset(Rect2(cg.position, Vector2(cg.size.x * 0.5, cg.size.y)), 3.0), 0.3)
	R(ci, E.inset(Rect2(cg.position + Vector2(cg.size.x * 0.5, 0), Vector2(cg.size.x * 0.5, cg.size.y)), 3.0), 0.3)
	L(ci, Vector2(w * 0.04, 0), Vector2(w * 0.04, h), 0.5, 1.4)
	var segs := PackedVector2Array()
	for k in clampi(int(h / 4.0), 3, 60):
		var y: float = 2.0 + k * 4.0
		segs.append(Vector2(w * 0.04, y))
		segs.append(Vector2(w * 0.08, y))
	S(ci, segs, 0.35)
	O(ci, Vector2(w * 0.1, h * 0.3), minf(w * 0.05, 4.0), 0.55)
	O(ci, Vector2(w * 0.1, h * 0.75), minf(w * 0.05, 4.0), 0.55)
	E.motor(ci, Rect2(w * 0.2, h * 0.02, w * 0.5, h * 0.12), false, 0.5)
	R(ci, Rect2(w * 0.2, cg.end.y, w * 0.6, h * 0.08), 0.5)


# a work vehicle in its bay: the chassis on its wheels / landing pads, the cab with
# its window, the manipulator arm folded over the deck, the cargo bed
static func work_vehicle(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var ch := Rect2(w * 0.04, h * 0.58, w * 0.92, h * 0.2)
	R(ci, ch, 0.6, 1.2)
	for f in [0.18, 0.5, 0.82]:
		O(ci, Vector2(w * f, h * 0.86), minf(h * 0.12, w * 0.07), 0.55)
		O(ci, Vector2(w * f, h * 0.86), minf(h * 0.05, w * 0.03), 0.4)
	var cab := PackedVector2Array([Vector2(w * 0.66, ch.position.y), Vector2(w * 0.68, h * 0.14), Vector2(w * 0.86, h * 0.14), Vector2(w * 0.96, h * 0.36), Vector2(w * 0.96, ch.position.y)])
	P(ci, cab, 0.6, 1.2)
	P(ci, PackedVector2Array([Vector2(w * 0.71, h * 0.2), Vector2(w * 0.84, h * 0.2), Vector2(w * 0.91, h * 0.36), Vector2(w * 0.71, h * 0.36), Vector2(w * 0.71, h * 0.2)]), 0.45)
	var b := Vector2(w * 0.12, ch.position.y)
	var e := Vector2(w * 0.3, h * 0.2)
	var t := Vector2(w * 0.52, h * 0.34)
	L(ci, b, e, 0.55, 2.0)
	L(ci, e, t, 0.55, 1.6)
	O(ci, b, 2.5, 0.6)
	O(ci, e, 2.0, 0.6)
	P(ci, PackedVector2Array([t + Vector2(-2, 6), t, t + Vector2(4, 5)]), 0.55)
	R(ci, Rect2(w * 0.3, h * 0.42, w * 0.34, ch.position.y - h * 0.42), 0.4)


# a food production module: the rack of grow trays under their light bars, the
# nutrient film channels, the circulation pump and reservoir, the climate unit
static func food_module(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, 1, w - 2, h - 2), 0.55)
	var gw := Rect2(w * 0.04, h * 0.06, w * 0.66, h * 0.66)
	var nt := clampi(int(gw.size.y / 14.0), 2, 6)
	for k in nt:
		var y: float = gw.position.y + (k + 1) * gw.size.y / nt
		L(ci, Vector2(gw.position.x, y), Vector2(gw.end.x, y), 0.5, 1.4)
		var ly: float = y - gw.size.y / nt + 3.0
		R(ci, Rect2(gw.position.x + 4.0, ly, gw.size.x - 8.0, 2.5), 0.4)
		var segs := PackedVector2Array()
		var np := clampi(int(gw.size.x / 6.0), 3, 40)
		for i in np:
			var x: float = gw.position.x + 4.0 + (i + 0.5) * (gw.size.x - 8.0) / np
			segs.append(Vector2(x, y))
			segs.append(Vector2(x - 2.0, y - gw.size.y / nt * 0.45))
			segs.append(Vector2(x, y))
			segs.append(Vector2(x + 2.0, y - gw.size.y / nt * 0.4))
		S(ci, segs, 0.3)
	var rs := Rect2(w * 0.74, h * 0.5, w * 0.22, h * 0.44)
	R(ci, rs, 0.5)
	L(ci, Vector2(rs.position.x + 2.0, rs.position.y + rs.size.y * 0.3), Vector2(rs.end.x - 2.0, rs.position.y + rs.size.y * 0.3), 0.3)
	E.volute(ci, Vector2(w * 0.85, h * 0.32), minf(w * 0.06, h * 0.1), true, 0.5)
	E.louvres(ci, Rect2(w * 0.76, h * 0.06, w * 0.18, h * 0.14), 0.3)
	R(ci, Rect2(w * 0.04, h * 0.76, w * 0.66, h * 0.18), 0.4)
	E.hatch(ci, Rect2(w * 0.06, h * 0.78, w * 0.62, h * 0.14), 4.0, true, 0.2, 40)


# ================================================================== ST-40, EV-55, BL-88, LC-140

# a turbopump: the fuel and oxidiser pump housings on one shaft with the turbine
# between, its exhaust, the inlets and discharges
static func turbopump(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var ay: float = h * 0.52
	var pr: float = minf(w * 0.2, h * 0.32)
	var p1 := Vector2(w * 0.22, ay)
	var p2 := Vector2(w * 0.78, ay)
	for pc in [p1, p2]:
		O(ci, pc, pr, 0.6, 1.2)
		E.impeller(ci, pc, pr * 0.72, 0.45)
		L(ci, pc + Vector2(0, -pr), Vector2(pc.x, 1.0), 0.5, 1.2)
	var tb := Rect2(w * 0.4, ay - pr * 0.75, w * 0.2, pr * 1.5)
	R(ci, tb, 0.6, 1.2)
	E.hatch(ci, E.inset(tb, 2.0), 2.5, true, 0.35, 16)
	L(ci, p1, p2, 0.35)
	P(ci, PackedVector2Array([Vector2(tb.get_center().x, tb.end.y), Vector2(tb.get_center().x, h - 2.0), Vector2(w * 0.62, h - 2.0)]), 0.45)
	L(ci, p1 + Vector2(-pr, 0), Vector2(1, ay), 0.5)
	L(ci, p2 + Vector2(pr, 0), Vector2(w - 1, ay), 0.5)


# a stellar coronagraph: the telescope tube with its baffle vanes, the occulting
# disc on its spider at the entrance, the Lyot stop, the field lens, the camera
static func coronagraph(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var tube := Rect2(w * 0.2, h * 0.02, w * 0.6, h * 0.74)
	L(ci, tube.position, Vector2(tube.position.x, tube.end.y), 0.6, 1.4)
	L(ci, Vector2(tube.end.x, tube.position.y), tube.end, 0.6, 1.4)
	var segs := PackedVector2Array()
	for k in clampi(int(tube.size.y / 10.0), 3, 20):
		var y: float = tube.position.y + (k + 0.5) * 10.0
		segs.append(Vector2(tube.position.x, y))
		segs.append(Vector2(tube.position.x + tube.size.x * 0.18, y + 3.0))
		segs.append(Vector2(tube.end.x, y))
		segs.append(Vector2(tube.end.x - tube.size.x * 0.18, y + 3.0))
	S(ci, segs, 0.35)
	var oc := Vector2(w * 0.5, tube.position.y + h * 0.04)
	O(ci, oc, tube.size.x * 0.12, 0.6)
	L(ci, Vector2(tube.position.x, oc.y), Vector2(tube.end.x, oc.y), 0.35)
	L(ci, Vector2(tube.position.x + tube.size.x * 0.25, tube.position.y + tube.size.y * 0.55), Vector2(tube.end.x - tube.size.x * 0.25, tube.position.y + tube.size.y * 0.55), 0.6, 2.0)
	A(ci, Vector2(w * 0.5, tube.position.y + tube.size.y * 0.75 + tube.size.x * 0.5), tube.size.x * 0.5, -PI * 0.5 - 0.6, -PI * 0.5 + 0.6, 0.5, 1.4)
	var cam := Rect2(w * 0.24, tube.end.y + 2.0, w * 0.52, h * 0.2)
	R(ci, cam, 0.6, 1.2)
	R(ci, Rect2(cam.get_center().x - cam.size.x * 0.2, cam.position.y + 2.0, cam.size.x * 0.4, 3.0), 0.7)
	E.hatch(ci, Rect2(cam.position.x + 3.0, cam.position.y + cam.size.y * 0.5, cam.size.x - 6.0, cam.size.y * 0.4), 3.0, true, 0.22, 20)


# a particle detector: a stack of silicon detector planes behind its collimator,
# the absorber plates between them, the electronics box at the back
static func particle_det(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	P(ci, PackedVector2Array([Vector2(1, h * 0.1), Vector2(w * 0.3, h * 0.32), Vector2(w * 0.3, h * 0.68), Vector2(1, h * 0.9)]), 0.55)
	var n := 6
	for k in n:
		var x: float = w * (0.34 + k * 0.07)
		L(ci, Vector2(x, h * 0.26), Vector2(x, h * 0.74), 0.65 if k % 2 == 0 else 0.35, 1.6 if k % 2 == 0 else 1.0)
	R(ci, Rect2(w * 0.32, h * 0.22, w * 0.42, h * 0.56), 0.45)
	var eb := Rect2(w * 0.78, h * 0.18, w * 0.2, h * 0.64)
	R(ci, eb, 0.55)
	E.hatch(ci, E.inset(eb, 2.0), 3.0, false, 0.22, 20)


# a fluxgate magnetometer on its boom root: the sensor head (three orthogonal
# windings round their cores), the thermal can, the harness
static func magnetometer(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var c := Vector2(w * 0.5, h * 0.36)
	var s: float = minf(w * 0.34, h * 0.28)
	R(ci, Rect2(c - Vector2(s, s), Vector2(s * 2.0, s * 2.0)), 0.45)
	O(ci, c, s * 0.7, 0.55)
	E.hatch(ci, Rect2(c.x - s * 0.8, c.y - s * 0.18, s * 1.6, s * 0.36), 2.5, true, 0.35, 16)
	E.hatch(ci, Rect2(c.x - s * 0.18, c.y - s * 0.8, s * 0.36, s * 1.6), 2.5, false, 0.35, 16)
	D(ci, c, 1.6, 0.6)
	L(ci, c + Vector2(0, s), Vector2(c.x, h * 0.92), 0.5, 1.4)
	R(ci, Rect2(w * 0.3, h * 0.88, w * 0.4, h * 0.1), 0.5)


# a water electrolyser: the cell stack between its end plates and tie rods, the
# hydrogen and oxygen gas separators above it, the circulation pump, the rectifier
static func electrolyser(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var st := Rect2(w * 0.06, h * 0.5, w * 0.6, h * 0.42)
	R(ci, Rect2(st.position.x, st.position.y, 5.0, st.size.y), 0.6)
	R(ci, Rect2(st.end.x - 5.0, st.position.y, 5.0, st.size.y), 0.6)
	E.hatch(ci, Rect2(st.position.x + 5.0, st.position.y + 2.0, st.size.x - 10.0, st.size.y - 4.0), 2.2, true, 0.3, 80)
	L(ci, Vector2(st.position.x - 2.0, st.position.y - 2.0), Vector2(st.end.x + 2.0, st.position.y - 2.0), 0.45)
	L(ci, Vector2(st.position.x - 2.0, st.end.y + 2.0), Vector2(st.end.x + 2.0, st.end.y + 2.0), 0.45)
	for k in 2:
		var vs := Rect2(w * (0.08 + k * 0.32), h * 0.06, w * 0.24, h * 0.36)
		E.vessel_v(ci, vs, 0.55)
		L(ci, Vector2(vs.get_center().x, vs.end.y), Vector2(vs.get_center().x, st.position.y), 0.45)
		L(ci, Vector2(vs.get_center().x, vs.position.y), Vector2(vs.get_center().x, 0), 0.45)
	var rc := Rect2(w * 0.72, h * 0.08, w * 0.24, h * 0.5)
	R(ci, rc, 0.5)
	E.hatch(ci, sub(rc, 0.15, 0.1, 0.85, 0.6), 3.0, true, 0.25, 12)
	E.volute(ci, Vector2(w * 0.84, h * 0.8), minf(w * 0.08, h * 0.1), true, 0.5)


# a composter: the rotating drum on its rollers, the paddles inside, the gear ring
# and drive motor, the biofilter on the vent
static func composter(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var c := Vector2(w * 0.42, h * 0.46)
	var rad: float = minf(w * 0.36, h * 0.38)
	O(ci, c, rad, 0.6, 1.4)
	O(ci, c, rad * 0.9, 0.3)
	for k in 4:
		var a: float = TAU * k / 4.0 + 0.4
		L(ci, c + Vector2.from_angle(a) * rad * 0.15, c + Vector2.from_angle(a) * rad * 0.8, 0.45, 1.4)
	O(ci, c, rad * 0.15, 0.5)
	for f in [-0.6, 0.6]:
		O(ci, c + Vector2(rad * f, rad * 1.0), rad * 0.12, 0.55)
	L(ci, Vector2(c.x - rad, h * 0.96), Vector2(c.x + rad, h * 0.96), 0.5, 1.4)
	R(ci, Rect2(w * 0.82, h * 0.1, w * 0.14, h * 0.4), 0.5)
	E.hatch(ci, Rect2(w * 0.83, h * 0.12, w * 0.12, h * 0.36), 3.0, false, 0.3, 12)
	L(ci, c + Vector2(rad * 0.7, -rad * 0.7), Vector2(w * 0.82, h * 0.3), 0.4)


# a beehive: the stacked boxes (brood box, supers) with their frames, the roof,
# the entrance slot on the stand
static func beehive(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	P(ci, PackedVector2Array([Vector2(w * 0.04, h * 0.16), Vector2(w * 0.5, h * 0.02), Vector2(w * 0.96, h * 0.16)]), 0.6, 1.2)
	for k in 3:
		var b := Rect2(w * 0.1, h * (0.16 + k * 0.24), w * 0.8, h * 0.24)
		R(ci, b, 0.5)
		E.hatch(ci, Rect2(b.position.x + 3.0, b.position.y + 2.0, b.size.x - 6.0, b.size.y - 4.0), 3.0, true, 0.2, 20)
	L(ci, Vector2(w * 0.3, h * 0.88), Vector2(w * 0.7, h * 0.88), 0.6, 1.6)
	L(ci, Vector2(w * 0.16, h * 0.9), Vector2(w * 0.16, h), 0.45)
	L(ci, Vector2(w * 0.84, h * 0.9), Vector2(w * 0.84, h), 0.45)


# a forklift: the mast with its carriage and forks, the counterweighted body, the
# driver's overhead guard, the wheels
static func forklift(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var mx: float = w * 0.18
	L(ci, Vector2(mx, h * 0.04), Vector2(mx, h * 0.86), 0.6, 1.6)
	L(ci, Vector2(mx + 4.0, h * 0.04), Vector2(mx + 4.0, h * 0.86), 0.45)
	R(ci, Rect2(mx - 6.0, h * 0.5, 6.0, h * 0.2), 0.55)
	L(ci, Vector2(2, h * 0.7), Vector2(mx, h * 0.7), 0.6, 1.8)
	var body := PackedVector2Array([Vector2(mx + 6.0, h * 0.86), Vector2(mx + 6.0, h * 0.56), Vector2(w * 0.7, h * 0.56), Vector2(w * 0.96, h * 0.62), Vector2(w * 0.96, h * 0.86)])
	P(ci, body, 0.6, 1.2)
	P(ci, PackedVector2Array([Vector2(w * 0.3, h * 0.56), Vector2(w * 0.34, h * 0.14), Vector2(w * 0.74, h * 0.14), Vector2(w * 0.74, h * 0.56)]), 0.5)
	L(ci, Vector2(w * 0.5, h * 0.56), Vector2(w * 0.46, h * 0.38), 0.45)
	for f in [0.34, 0.8]:
		O(ci, Vector2(w * f, h * 0.88), minf(w * 0.1, h * 0.1), 0.55)


# a hold crane trolley: the trolley on its bridge rail, the hoist drum and motor,
# the rope falls to the hook block
static func hold_crane(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	L(ci, Vector2(1, h * 0.04), Vector2(w - 1, h * 0.04), 0.6, 1.8)
	var tr := Rect2(w * 0.1, h * 0.06, w * 0.8, h * 0.2)
	R(ci, tr, 0.6, 1.2)
	for f in [0.2, 0.8]:
		O(ci, Vector2(tr.position.x + tr.size.x * f, tr.position.y), minf(tr.size.y * 0.25, 4.0), 0.55)
	O(ci, tr.get_center(), tr.size.y * 0.32, 0.5)
	E.hatch(ci, Rect2(tr.get_center().x - tr.size.y * 0.3, tr.position.y + 2.0, tr.size.y * 0.6, tr.size.y - 4.0), 2.5, true, 0.25, 10)
	R(ci, Rect2(tr.end.x - tr.size.x * 0.28, tr.position.y + tr.size.y * 0.2, tr.size.x * 0.22, tr.size.y * 0.6), 0.45)
	var hb := Rect2(w * 0.32, h * 0.62, w * 0.36, h * 0.16)
	for x in [w * 0.4, w * 0.6]:
		L(ci, Vector2(x, tr.end.y), Vector2(x, hb.position.y), 0.45)
	R(ci, hb, 0.6)
	O(ci, hb.get_center(), hb.size.y * 0.32, 0.45)
	L(ci, Vector2(w * 0.5, hb.end.y), Vector2(w * 0.5, h * 0.84), 0.55, 1.4)
	A(ci, Vector2(w * 0.5, h * 0.9), minf(w * 0.1, h * 0.06), -PI * 0.5, PI * 1.1, 0.6, 1.6)


# ================================================================== R2 and the odd-shaped ships

# an X-ray parcel scanner: the tunnel with its lead curtains, the conveyor through
# it, the generator above, the detector array, the operator's screen; a big one is
# a flat-panel scanning array instead
static func xray_scanner(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	if w > 4.0 * M:
		E.radar(ci, r)
		return
	var tn := Rect2(w * 0.12, h * 0.3, w * 0.62, h * 0.5)
	R(ci, Rect2(w * 0.08, h * 0.08, w * 0.7, h * 0.8), 0.55, 1.2)
	R(ci, tn, 0.45)
	for x in [tn.position.x + 2.0, tn.end.x - 2.0]:
		var segs := PackedVector2Array()
		for k in 5:
			segs.append(Vector2(x - 1.5 + k * 0.8, tn.position.y + 1.0))
			segs.append(Vector2(x - 1.5 + k * 0.8, tn.end.y - 2.0))
		S(ci, segs, 0.3)
	L(ci, Vector2(1, tn.end.y), Vector2(w * 0.96, tn.end.y), 0.6, 1.6)
	for k in 6:
		O(ci, Vector2(w * (0.06 + k * 0.16), tn.end.y + 2.5), 2.0, 0.4)
	R(ci, Rect2(w * 0.3, h * 0.1, w * 0.26, h * 0.16), 0.55)
	P(ci, PackedVector2Array([Vector2(w * 0.43, h * 0.26), Vector2(w * 0.3, tn.end.y), Vector2(w * 0.56, tn.end.y), Vector2(w * 0.43, h * 0.26)]), 0.18)
	L(ci, Vector2(tn.end.x - 6.0, tn.position.y), Vector2(tn.end.x - 6.0, tn.end.y), 0.5, 1.6)
	E.screen_face(ci, Rect2(w * 0.8, h * 0.1, w * 0.18, h * 0.3), 1, 0.4)
	L(ci, Vector2(w * 0.89, h * 0.4), Vector2(w * 0.89, h * 0.92), 0.4)


# a mail sorting frame: rows of pigeonholes with their label strips and a few
# letters in them, the bag hooks along the foot
static func mail_sorter(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, 1, w - 2, h * 0.86), 0.5)
	var nx := clampi(int(w / 9.0), 2, 40)
	var ny := clampi(int(h * 0.86 / 10.0), 2, 30)
	var segs := PackedVector2Array()
	for i in range(1, nx):
		segs.append(Vector2(1 + i * (w - 2) / nx, 1))
		segs.append(Vector2(1 + i * (w - 2) / nx, h * 0.86))
	for j in range(1, ny):
		segs.append(Vector2(1, 1 + j * h * 0.86 / ny))
		segs.append(Vector2(w - 1, 1 + j * h * 0.86 / ny))
	S(ci, segs, 0.3)
	var lt := PackedVector2Array()
	for j in ny:
		for i in nx:
			if (i * 7 + j * 3) % 4 == 0:
				var c := Vector2(1 + (i + 0.5) * (w - 2) / nx, 1 + (j + 0.7) * h * 0.86 / ny)
				lt.append(c + Vector2(-(w - 2) / nx * 0.3, 0))
				lt.append(c + Vector2((w - 2) / nx * 0.3, -1.5))
	S(ci, lt, 0.5)
	for k in clampi(int(w / 20.0), 1, 12):
		var x: float = (k + 0.5) * w / clampi(int(w / 20.0), 1, 12)
		A(ci, Vector2(x, h * 0.93), 2.5, 0.0, PI, 0.5)


# a towing / sail winch: the drum between its flanges with the wire wound on,
# the level-wind carriage, the band brake round one flange, the hydraulic motor
static func tow_winch(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var c := Vector2(w * 0.5, h * 0.55)
	var rad: float = minf(w * 0.42, h * 0.4)
	O(ci, c, rad, 0.6, 1.4)
	O(ci, c, rad * 0.45, 0.5)
	for k in 5:
		O(ci, c, rad * (0.5 + k * 0.08), 0.22)
	A(ci, c, rad * 1.06, PI * 0.15, PI * 0.95, 0.55, 2.0)
	L(ci, c + Vector2.from_angle(PI * 0.95) * rad * 1.06, c + Vector2(-rad * 1.1, rad * 0.9), 0.5)
	O(ci, c, rad * 0.14, 0.6)
	D(ci, c, 1.4, 0.6)
	# level wind across the top and the wire leaving
	L(ci, Vector2(c.x - rad, h * 0.06), Vector2(c.x + rad, h * 0.06), 0.5, 1.4)
	R(ci, Rect2(c.x - rad * 0.2, h * 0.02, rad * 0.4, h * 0.08), 0.55)
	L(ci, Vector2(c.x, h * 0.1), c + Vector2(0, -rad * 0.7), 0.45)
	R(ci, Rect2(c.x + rad * 0.55, c.y + rad * 0.55, rad * 0.4, rad * 0.4), 0.5)
	L(ci, Vector2(c.x - rad, h * 0.98), Vector2(c.x + rad, h * 0.98), 0.5, 1.4)


# a spray bar under the deckhead: the supply header, the drop pipes, the misting
# nozzles with their spray fans
static func spray_bar(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	if w < 1.5 * M:
		# a hand spray can, not a bar
		E.fueltank(ci, r, null, null)
		return
	L(ci, Vector2(1, h * 0.2), Vector2(w - 1, h * 0.2), 0.55, 1.6)
	var n := clampi(int(w / 20.0), 2, 30)
	var segs := PackedVector2Array()
	for k in n:
		var x: float = (k + 0.5) * w / n
		L(ci, Vector2(x, h * 0.2), Vector2(x, h * 0.55), 0.45)
		R(ci, Rect2(x - 2.0, h * 0.55, 4.0, h * 0.12), 0.55)
		for e in [-0.5, 0.0, 0.5]:
			segs.append(Vector2(x, h * 0.67))
			segs.append(Vector2(x + e * w / n * 0.5, h * 0.98))
	S(ci, segs, 0.18)


# a microscope: the base and pillar, the stage with its slide, the objective turret,
# the binocular head and the camera port, the light source
static func microscope(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(w * 0.1, h * 0.86, w * 0.7, h * 0.12), 0.55)
	P(ci, PackedVector2Array([Vector2(w * 0.62, h * 0.86), Vector2(w * 0.7, h * 0.2), Vector2(w * 0.56, h * 0.12)]), 0.6, 1.6)
	L(ci, Vector2(w * 0.2, h * 0.56), Vector2(w * 0.62, h * 0.56), 0.6, 1.8)
	L(ci, Vector2(w * 0.28, h * 0.54), Vector2(w * 0.48, h * 0.54), 0.5)
	O(ci, Vector2(w * 0.38, h * 0.8), minf(w * 0.06, h * 0.05), 0.5)
	P(ci, PackedVector2Array([Vector2(w * 0.3, h * 0.34), Vector2(w * 0.46, h * 0.34), Vector2(w * 0.42, h * 0.44), Vector2(w * 0.34, h * 0.44), Vector2(w * 0.3, h * 0.34)]), 0.55)
	L(ci, Vector2(w * 0.38, h * 0.44), Vector2(w * 0.38, h * 0.5), 0.55, 1.6)
	R(ci, Rect2(w * 0.28, h * 0.2, w * 0.3, h * 0.14), 0.55)
	L(ci, Vector2(w * 0.3, h * 0.2), Vector2(w * 0.18, h * 0.08), 0.55, 1.6)
	L(ci, Vector2(w * 0.34, h * 0.2), Vector2(w * 0.24, h * 0.06), 0.55, 1.6)
	R(ci, Rect2(w * 0.5, h * 0.04, w * 0.1, h * 0.16), 0.5)
	E.wheel(ci, Vector2(w * 0.72, h * 0.66), minf(w * 0.06, h * 0.05), 0.5)


# a CO2 scrubber: twin amine (or zeolite) beds in their canisters, the switching
# valves between them, the blower, the vacuum desorb line
static func co2_scrubber(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	for k in 2:
		var cn := Rect2(w * (0.06 + k * 0.32), h * 0.14, w * 0.26, h * 0.74)
		R(ci, cn, 0.6, 1.2)
		var dots := PackedVector2Array()
		var ny := clampi(int(cn.size.y / 4.0), 3, 30)
		var nx := clampi(int(cn.size.x / 4.0), 2, 10)
		for j in ny:
			for i in nx:
				var q := cn.position + Vector2((i + 0.5 + (0.5 if j % 2 == 1 else 0.0)) * cn.size.x / (nx + 0.5), (j + 0.5) * cn.size.y / ny)
				dots.append(q)
				dots.append(q + Vector2(0.8, 0))
		S(ci, dots, 0.35)
		L(ci, Vector2(cn.get_center().x, cn.position.y), Vector2(cn.get_center().x, h * 0.06), 0.45)
		L(ci, Vector2(cn.get_center().x, cn.end.y), Vector2(cn.get_center().x, h * 0.96), 0.45)
	L(ci, Vector2(w * 0.19, h * 0.06), Vector2(w * 0.51, h * 0.06), 0.5, 1.4)
	L(ci, Vector2(w * 0.19, h * 0.96), Vector2(w * 0.51, h * 0.96), 0.5, 1.4)
	var vc := Vector2(w * 0.35, h * 0.06)
	P(ci, PackedVector2Array([vc + Vector2(-3, -2.5), vc + Vector2(3, 2.5), vc + Vector2(3, -2.5), vc + Vector2(-3, 2.5), vc + Vector2(-3, -2.5)]), 0.6)
	E.fan(ci, Vector2(w * 0.82, h * 0.3), minf(w * 0.12, h * 0.2), 6, 0.45)
	R(ci, Rect2(w * 0.72, h * 0.56, w * 0.22, h * 0.34), 0.5)
	E.hatch(ci, Rect2(w * 0.74, h * 0.6, w * 0.18, h * 0.26), 3.0, true, 0.22, 12)


# a UV steriliser: the stainless chamber with the lamp sleeve down its axis, the
# UV intensity sensor, the ballast box, inlet and outlet
static func uv_steriliser(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var sh := E.vessel_h(ci, Rect2(w * 0.04, h * 0.3, w * 0.8, h * 0.4), 0.6)
	R(ci, Rect2(sh.position.x, sh.get_center().y - h * 0.05, sh.size.x, h * 0.1), 0.45)
	L(ci, Vector2(sh.position.x + 2.0, sh.get_center().y), Vector2(sh.end.x - 2.0, sh.get_center().y), 0.7, 1.4)
	for x in [0.25, 0.55]:
		L(ci, Vector2(w * x, sh.position.y), Vector2(w * x, h * 0.12), 0.5, 1.4)
	R(ci, Rect2(w * 0.86, h * 0.2, w * 0.12, h * 0.6), 0.5)
	D(ci, Vector2(w * 0.92, h * 0.28), 1.2, 0.7)
	E.gauge(ci, Vector2(w * 0.7, h * 0.18), minf(h * 0.08, 5.0), 0.5)


# a steam humidifier: the electrode boiling cylinder, the fill and drain valves, the
# steam hose up to the dispersion tube, the control box
static func humidifier(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(w * 0.04, h * 0.04, w * 0.6, h * 0.92), 0.45)
	var cyl := Rect2(w * 0.12, h * 0.26, w * 0.24, h * 0.6)
	E.vessel_v(ci, cyl, 0.55)
	for k in 3:
		L(ci, Vector2(cyl.position.x + cyl.size.x * (0.25 + k * 0.25), cyl.position.y + 2.0), Vector2(cyl.position.x + cyl.size.x * (0.25 + k * 0.25), cyl.end.y - cyl.size.y * 0.3), 0.45)
	P(ci, PackedVector2Array([Vector2(cyl.get_center().x, cyl.position.y), Vector2(cyl.get_center().x, h * 0.12), Vector2(w * 0.96, h * 0.12)]), 0.5, 1.4)
	var segs := PackedVector2Array()
	for k in clampi(int(w * 0.3 / 5.0), 2, 12):
		var x: float = w * 0.68 + k * 5.0
		segs.append(Vector2(x, h * 0.12))
		segs.append(Vector2(x + 1.5, h * 0.06))
	S(ci, segs, 0.3)
	R(ci, Rect2(w * 0.42, h * 0.3, w * 0.18, h * 0.3), 0.5)
	D(ci, Vector2(w * 0.51, h * 0.38), 1.2, 0.7)
	L(ci, Vector2(cyl.get_center().x, cyl.end.y), Vector2(cyl.get_center().x, h * 0.96), 0.45)


# a refrigeration plant: two semi-hermetic compressors on the receiver, the oil
# separator, the water-cooled condenser, the liquid line with its sight glass and
# filter-drier, the suction accumulator, the control panel
static func ref_plant(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var rc := E.vessel_h(ci, Rect2(w * 0.04, h * 0.74, w * 0.66, h * 0.16), 0.55)
	for k in 2:
		var cp := Rect2(w * (0.08 + k * 0.32), h * 0.44, w * 0.26, h * 0.26)
		R(ci, cp, 0.6, 1.2)
		E.hatch(ci, Rect2(cp.position.x + cp.size.x * 0.5, cp.position.y + 2.0, cp.size.x * 0.46, cp.size.y - 4.0), 3.0, true, 0.22, 16)
		for e in 3:
			O(ci, cp.position + cp.size * Vector2(0.12 + e * 0.13, 0.35), minf(cp.size.y * 0.12, 3.5), 0.45)
		L(ci, Vector2(cp.get_center().x, cp.end.y), Vector2(cp.get_center().x, rc.position.y), 0.45)
	var cd := E.vessel_h(ci, Rect2(w * 0.04, h * 0.08, w * 0.66, h * 0.22), 0.55)
	E.hatch(ci, E.inset(cd, 2.0), 4.0, false, 0.18, 10)
	E.vessel_v(ci, Rect2(w * 0.74, h * 0.08, w * 0.1, h * 0.4), 0.5)
	E.vessel_v(ci, Rect2(w * 0.74, h * 0.52, w * 0.1, h * 0.36), 0.5)
	L(ci, Vector2(w * 0.7, h * 0.36), Vector2(w * 0.04, h * 0.36), 0.45)
	O(ci, Vector2(w * 0.4, h * 0.36), 2.5, 0.6)
	R(ci, Rect2(w * 0.5, h * 0.34, w * 0.08, h * 0.04), 0.5)
	var pn := Rect2(w * 0.87, h * 0.1, w * 0.11, h * 0.8)
	R(ci, pn, 0.5)
	for k in 3:
		D(ci, pn.position + pn.size * Vector2(0.5, 0.12 + k * 0.08), 1.1, 0.6)


# an evaporator: the finned coil, the fans blowing through it, the drain pan and
# the expansion valve on its inlet
static func evaporator(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var vert: bool = h > w
	var ln: float = h if vert else w
	var th: float = w if vert else h
	var X := func(u: float, v: float) -> Vector2: return Vector2(v, u) if vert else Vector2(u, v)
	var B := func(u0: float, v0: float, u1: float, v1: float) -> Rect2: return Rect2(X.call(u0, v0), X.call(u1, v1) - X.call(u0, v0)).abs()
	var coil: Rect2 = B.call(2.0, th * 0.08, ln - 2.0, th * 0.5)
	R(ci, coil, 0.55)
	E.hatch(ci, coil, 2.2, not vert, 0.22, 160)
	var nf := clampi(int(ln / maxf(th * 0.9, 12.0)), 1, 10)
	for k in nf:
		var fc: Vector2 = X.call((k + 0.5) * ln / nf, th * 0.74)
		E.fan(ci, fc, minf(ln / nf * 0.4, th * 0.22), 5, 0.4)
	L(ci, X.call(2.0, th * 0.97), X.call(ln - 2.0, th * 0.97), 0.45, 1.4)


# a wall of safe deposit boxes: the doors in rows and sizes, each with its two
# keyholes and hinge pins, the vault's guard lock panel
static func safe_deposit(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, 1, w - 2, h - 2), 0.6, 1.2)
	var y := 3.0
	var row := 0
	while y < h - 6.0:
		var rh: float = minf([10.0, 14.0, 20.0][row % 3], h - 3.0 - y)
		var bw: float = [16.0, 22.0, 16.0][row % 3]
		var n := maxi(1, int((w - 6.0) / bw))
		bw = (w - 6.0) / n
		for i in n:
			var b := Rect2(3.0 + i * bw + 0.5, y + 0.5, bw - 1.0, rh - 1.0)
			R(ci, b, 0.4)
			if b.size.x > 8.0 and b.size.y > 6.0:
				D(ci, b.position + Vector2(b.size.x * 0.35, b.size.y * 0.5), 0.8, 0.6)
				D(ci, b.position + Vector2(b.size.x * 0.65, b.size.y * 0.5), 0.8, 0.6)
		y += rh
		row += 1


# a gun rack: rifles stood in their cradles behind the locking bar, the ammunition
# drawers below
static func gun_rack(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, 1, w - 2, h - 2), 0.55)
	var n := clampi(int(w / 9.0), 2, 30)
	for k in n:
		var x: float = (k + 0.5) * w / n
		P(ci, PackedVector2Array([Vector2(x - 1.0, h * 0.08), Vector2(x - 1.0, h * 0.5), Vector2(x - 3.0, h * 0.62), Vector2(x - 2.0, h * 0.68), Vector2(x + 2.0, h * 0.68), Vector2(x + 1.5, h * 0.5), Vector2(x + 1.0, h * 0.08)]), 0.5)
	L(ci, Vector2(3, h * 0.3), Vector2(w - 3, h * 0.3), 0.6, 1.8)
	O(ci, Vector2(w - 5.0, h * 0.3), 2.0, 0.6)
	for k in 2:
		var d := Rect2(3, h * (0.72 + k * 0.13), w - 6, h * 0.12)
		R(ci, d, 0.45)
		L(ci, d.get_center() + Vector2(-5, 0), d.get_center() + Vector2(5, 0), 0.6, 1.4)


# a biometric access panel: the palm reader with its hand outline, the iris camera,
# the keypad, the door strike's status lights
static func biometric(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(w * 0.1, h * 0.04, w * 0.8, h * 0.92), 0.55, 1.2)
	O(ci, Vector2(w * 0.5, h * 0.14), minf(w * 0.1, h * 0.06), 0.55)
	D(ci, Vector2(w * 0.5, h * 0.14), 1.0, 0.7)
	var pr := Rect2(w * 0.22, h * 0.26, w * 0.56, h * 0.36)
	R(ci, pr, 0.45)
	var pc := pr.position + pr.size * Vector2(0.5, 0.72)
	O(ci, pc, pr.size.x * 0.18, 0.45)
	for k in 5:
		var a: float = -PI * 0.5 + (k - 2) * 0.32
		L(ci, pc + Vector2.from_angle(a) * pr.size.x * 0.18, pc + Vector2.from_angle(a) * pr.size.x * (0.42 if k != 0 else 0.3), 0.45, 1.4)
	for j in 3:
		for i in 3:
			R(ci, Rect2(w * (0.28 + i * 0.16), h * (0.68 + j * 0.08), w * 0.12, h * 0.06), 0.4)
	for k in 2:
		D(ci, Vector2(w * (0.4 + k * 0.2), h * 0.93), 1.0, 0.7)


# a three-phase separator: the horizontal vessel, the inlet diverter, the weir
# plate, the oil, water and gas levels, the mist eliminator before the gas outlet,
# its three outlets; stood up, a vertical separator with its demister pad
static func separator_3ph(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	if h > w:
		var sh := E.vessel_v(ci, Rect2(w * 0.12, h * 0.04, w * 0.76, h * 0.9), 0.6)
		var dm := Rect2(sh.position.x + 2.0, sh.position.y + sh.size.y * 0.06, sh.size.x - 4.0, sh.size.y * 0.08)
		R(ci, dm, 0.45)
		E.hatch(ci, dm, 2.5, true, 0.3, 30)
		L(ci, Vector2(1, sh.position.y + sh.size.y * 0.35), Vector2(sh.position.x + sh.size.x * 0.4, sh.position.y + sh.size.y * 0.35), 0.5)
		L(ci, Vector2(sh.position.x + sh.size.x * 0.4, sh.position.y + sh.size.y * 0.3), Vector2(sh.position.x + sh.size.x * 0.4, sh.position.y + sh.size.y * 0.42), 0.55, 1.6)
		var lv: float = sh.position.y + sh.size.y * 0.62
		L(ci, Vector2(sh.position.x + 2.0, lv), Vector2(sh.end.x - 2.0, lv), 0.4)
		E.F(ci, Rect2(sh.position.x, lv, sh.size.x, sh.end.y - lv), 0.035)
		return
	var sh := E.vessel_h(ci, Rect2(w * 0.02, h * 0.16, w * 0.96, h * 0.68), 0.6)
	var wx: float = sh.position.x + sh.size.x * 0.68
	L(ci, Vector2(wx, sh.end.y), Vector2(wx, sh.position.y + sh.size.y * 0.45), 0.6, 1.6)
	var oil: float = sh.position.y + sh.size.y * 0.5
	var wat: float = sh.position.y + sh.size.y * 0.75
	L(ci, Vector2(sh.position.x + 2.0, oil), Vector2(wx, oil), 0.45)
	L(ci, Vector2(sh.position.x + 2.0, wat), Vector2(wx, wat), 0.3)
	L(ci, Vector2(wx, sh.position.y + sh.size.y * 0.6), Vector2(sh.end.x - 2.0, sh.position.y + sh.size.y * 0.6), 0.45)
	E.F(ci, Rect2(sh.position.x, oil, wx - sh.position.x, sh.end.y - oil), 0.035)
	L(ci, Vector2(sh.position.x + sh.size.x * 0.08, sh.position.y + sh.size.y * 0.2), Vector2(sh.position.x + sh.size.x * 0.08, sh.position.y + sh.size.y * 0.6), 0.55, 1.6)
	var dm := Rect2(sh.end.x - sh.size.x * 0.14, sh.position.y + 2.0, sh.size.x * 0.08, sh.size.y * 0.35)
	R(ci, dm, 0.45)
	E.hatch(ci, dm, 2.0, true, 0.3, 20)
	for nz in [[sh.position.x + sh.size.x * 0.05, sh.position.y, -1.0], [sh.end.x - sh.size.x * 0.05, sh.position.y, -1.0], [sh.position.x + sh.size.x * 0.4, sh.end.y, 1.0], [sh.end.x - sh.size.x * 0.12, sh.end.y, 1.0]]:
		L(ci, Vector2(nz[0], nz[1]), Vector2(nz[0], nz[1] + nz[2] * h * 0.12), 0.5, 1.4)
	for f in [0.25, 0.75]:
		P(ci, PackedVector2Array([Vector2(w * f - h * 0.1, h - 1.0), Vector2(w * f - h * 0.05, sh.end.y), Vector2(w * f + h * 0.05, sh.end.y), Vector2(w * f + h * 0.1, h - 1.0)]), 0.45)


# a radar level gauge: the horn antenna down through its flange into the tank, the
# electronics head with its display and cable entry
static func level_radar(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cx: float = w * 0.5
	R(ci, Rect2(cx - w * 0.22, h * 0.04, w * 0.44, h * 0.32), 0.6, 1.2)
	O(ci, Vector2(cx, h * 0.2), minf(w * 0.12, h * 0.1), 0.5)
	L(ci, Vector2(cx + w * 0.22, h * 0.2), Vector2(w - 2.0, h * 0.26), 0.4)
	R(ci, Rect2(cx - w * 0.08, h * 0.36, w * 0.16, h * 0.12), 0.5)
	L(ci, Vector2(cx - w * 0.3, h * 0.5), Vector2(cx + w * 0.3, h * 0.5), 0.6, 2.0)
	P(ci, PackedVector2Array([Vector2(cx - w * 0.06, h * 0.5), Vector2(cx - w * 0.22, h * 0.86), Vector2(cx + w * 0.22, h * 0.86), Vector2(cx + w * 0.06, h * 0.5)]), 0.55)
	for e in [-0.3, 0.0, 0.3]:
		L(ci, Vector2(cx, h * 0.88), Vector2(cx + e * w, h), 0.15)


# a Coriolis flow meter: the two bent measuring tubes side by side between the
# process flanges, the driver and the pick-off coils, the transmitter on top
static func coriolis(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var fy: float = h * 0.82
	L(ci, Vector2(1, fy), Vector2(w - 1, fy), 0.55, 1.6)
	E.flange(ci, Vector2(3.0, fy), Vector2.LEFT, minf(h * 0.08, 6.0), 0.55)
	E.flange(ci, Vector2(w - 3.0, fy), Vector2.RIGHT, minf(h * 0.08, 6.0), 0.55)
	for k in 2:
		var o: float = k * 4.0
		P(ci, PackedVector2Array([Vector2(w * 0.2 + o, fy), Vector2(w * 0.2 + o, h * 0.42 + o), Vector2(w * 0.35, h * 0.3 + o), Vector2(w * 0.65, h * 0.3 + o), Vector2(w * 0.8 - o, h * 0.42 + o), Vector2(w * 0.8 - o, fy)]), 0.5 - k * 0.15, 1.2)
	R(ci, Rect2(w * 0.46, h * 0.26, w * 0.08, h * 0.1), 0.6)
	for f in [0.3, 0.7]:
		O(ci, Vector2(w * f, h * 0.42), 2.2, 0.6)
	R(ci, Rect2(w * 0.36, h * 0.02, w * 0.28, h * 0.18), 0.55)
	E.screen_face(ci, Rect2(w * 0.4, h * 0.04, w * 0.2, h * 0.12), 3, 0.35)
	L(ci, Vector2(w * 0.5, h * 0.2), Vector2(w * 0.5, h * 0.26), 0.45)


# an inertial measurement unit: three ring-laser gyros on the orthogonal faces of its
# block (each a triangle of mirrors), the accelerometers, the isolators, the box
static func imu(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, 1, w - 2, h - 2), 0.5)
	var n := 3 if w > h * 1.6 else 1
	for k in n:
		var c := Vector2((k + 0.5) * w / n, h * 0.45)
		var s: float = minf(w / n * 0.36, h * 0.32)
		P(ci, PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.87, s * 0.5), c + Vector2(-s * 0.87, s * 0.5), c + Vector2(0, -s)]), 0.6, 1.2)
		for q in [c + Vector2(0, -s), c + Vector2(s * 0.87, s * 0.5), c + Vector2(-s * 0.87, s * 0.5)]:
			D(ci, q, 1.6, 0.6)
		O(ci, c, s * 0.2, 0.4)
	for f in [0.1, 0.9]:
		for g in [0.12, 0.88]:
			O(ci, Vector2(w * f, h * g), 2.0, 0.4)
	R(ci, Rect2(w * 0.3, h * 0.82, w * 0.4, h * 0.12), 0.45)


# an electric arc furnace: the shell and its refractory lining, the molten bath with
# the slag over it, the three graphite electrodes down through the roof, the roof's
# water-cooled panels, the tap spout and the tilting rockers below
static func arc_furnace(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cx: float = w * 0.46
	var sw: float = minf(w * 0.7, h * 1.4)
	var top: float = h * 0.36
	var bot: float = h * 0.86
	P(ci, PackedVector2Array([Vector2(cx - sw * 0.5, top), Vector2(cx - sw * 0.5, bot - h * 0.1), Vector2(cx - sw * 0.38, bot), Vector2(cx + sw * 0.38, bot), Vector2(cx + sw * 0.5, bot - h * 0.1), Vector2(cx + sw * 0.5, top)]), 0.65, 1.6)
	P(ci, PackedVector2Array([Vector2(cx - sw * 0.44, top), Vector2(cx - sw * 0.44, bot - h * 0.12), Vector2(cx - sw * 0.34, bot - h * 0.04), Vector2(cx + sw * 0.34, bot - h * 0.04), Vector2(cx + sw * 0.44, bot - h * 0.12), Vector2(cx + sw * 0.44, top)]), 0.35)
	var bath: float = bot - h * 0.2
	E.F(ci, Rect2(cx - sw * 0.43, bath, sw * 0.86, bot - h * 0.05 - bath), 0.05)
	var pts := PackedVector2Array()
	for k in 13:
		pts.append(Vector2(cx - sw * 0.43 + k * sw * 0.86 / 12.0, bath + (1.5 if k % 2 == 0 else -1.5)))
	P(ci, pts, 0.45)
	L(ci, Vector2(cx - sw * 0.43, bath - h * 0.04), Vector2(cx + sw * 0.43, bath - h * 0.04), 0.25)
	# roof and its cooling panels
	E._head(ci, Vector2(cx, top), sw * 0.5, minf(top - h * 0.08, sw * 0.22), true, 0.6)
	var segs := PackedVector2Array()
	for k in 8:
		var x: float = cx - sw * 0.45 + k * sw * 0.9 / 7.0
		segs.append(Vector2(x, top - h * 0.02))
		segs.append(Vector2(x, top - h * 0.08))
	S(ci, segs, 0.3)
	# electrodes and their arms
	for k in 3:
		var ex: float = cx + (k - 1) * sw * 0.16
		R(ci, Rect2(ex - 3.0, h * 0.04, 6.0, bath - h * 0.06 - h * 0.04), 0.6, 1.2)
		L(ci, Vector2(ex, h * 0.08), Vector2(w * 0.96, h * (0.06 + k * 0.04)), 0.4)
		L(ci, Vector2(ex - 4.0, bath - h * 0.03), Vector2(ex + 4.0, bath - h * 0.03), 0.6)
	L(ci, Vector2(w * 0.96, h * 0.04), Vector2(w * 0.96, h * 0.9), 0.5, 1.6)
	# tap spout and rockers
	P(ci, PackedVector2Array([Vector2(cx + sw * 0.5, bath), Vector2(cx + sw * 0.66, bath + h * 0.06), Vector2(cx + sw * 0.66, bath + h * 0.1), Vector2(cx + sw * 0.5, bath + h * 0.08)]), 0.55)
	for f in [-0.3, 0.3]:
		A(ci, Vector2(cx + sw * f, bot + h * 0.04), sw * 0.1, 0.2, PI - 0.2, 0.55, 1.4)
	L(ci, Vector2(cx - sw * 0.5, h * 0.98), Vector2(cx + sw * 0.5, h * 0.98), 0.5, 1.4)


# an ingot rack: the cast ingots (trapezoids) stacked in crossed layers between
# the uprights
static func ingot_rack(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	for x in [2.0, w - 2.0]:
		L(ci, Vector2(x, 1), Vector2(x, h - 1), 0.55, 1.6)
	var ih: float = clampf(h / 8.0, 4.0, 10.0)
	var iw: float = ih * 3.0
	var rows := int((h - 4.0) / ih)
	for j in rows:
		var y: float = h - 3.0 - (j + 1) * ih
		if j % 2 == 0:
			var n := int((w - 8.0) / (iw + 2.0))
			for i in n:
				var x: float = 5.0 + i * (iw + 2.0)
				P(ci, PackedVector2Array([Vector2(x, y + ih), Vector2(x + iw * 0.12, y + 1.0), Vector2(x + iw * 0.88, y + 1.0), Vector2(x + iw, y + ih), Vector2(x, y + ih)]), 0.5)
		else:
			var n := int((w - 8.0) / (ih * 1.2))
			for i in n:
				var x: float = 5.0 + i * ih * 1.2
				R(ci, Rect2(x, y + 1.0, ih, ih - 1.0), 0.4)
	L(ci, Vector2(2, h - 2.0), Vector2(w - 2, h - 2.0), 0.55, 1.6)


# an eddy-current sorter: the feed conveyor, the magnetic head pulley spinning its
# rotor inside the belt's end, the splitter that the non-ferrous metal jumps over,
# the vibrating feeder at the start, the chutes below
static func eddy_sorter(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var by: float = h * 0.42
	var hr: float = minf(h * 0.18, w * 0.08)
	var hc := Vector2(w * 0.68, by + hr)
	O(ci, Vector2(w * 0.08, by + hr), hr * 0.8, 0.5)
	O(ci, hc, hr, 0.6, 1.2)
	O(ci, hc, hr * 0.62, 0.45)
	for k in 8:
		var a: float = TAU * k / 8.0
		L(ci, hc + Vector2.from_angle(a) * hr * 0.25, hc + Vector2.from_angle(a) * hr * 0.6, 0.35)
	L(ci, Vector2(w * 0.08, by), Vector2(hc.x, by), 0.55, 1.4)
	L(ci, Vector2(w * 0.08, by + hr * 1.8), Vector2(hc.x, hc.y + hr), 0.45)
	var segs := PackedVector2Array()
	for k in clampi(int(w * 0.5 / 7.0), 3, 30):
		var x: float = w * 0.12 + k * 7.0
		segs.append(Vector2(x, by - 1.0))
		segs.append(Vector2(x + 3.0, by - 3.0))
	S(ci, segs, 0.4)
	# the trajectories: non-ferrous thrown far, the rest dropping close
	P(ci, PackedVector2Array([hc + Vector2(hr * 0.5, -hr), hc + Vector2(hr * 2.0, -hr * 1.1), hc + Vector2(hr * 3.0, hr * 0.4), hc + Vector2(hr * 3.4, hr * 2.0)]), 0.2)
	P(ci, PackedVector2Array([hc + Vector2(hr, 0), hc + Vector2(hr * 1.3, hr * 1.4), hc + Vector2(hr * 1.3, hr * 2.4)]), 0.2)
	L(ci, Vector2(hc.x + hr * 2.0, h * 0.62), Vector2(hc.x + hr * 2.2, h * 0.96), 0.6, 1.6)
	P(ci, PackedVector2Array([Vector2(w * 0.02, h * 0.12), Vector2(w * 0.24, h * 0.12), Vector2(w * 0.2, by - 2.0), Vector2(w * 0.06, by - 2.0), Vector2(w * 0.02, h * 0.12)]), 0.5)
	E.motor(ci, Rect2(hc.x - hr * 1.6, h * 0.76, hr * 2.4, h * 0.18), true, 0.45)
	L(ci, Vector2(2, h * 0.98), Vector2(w - 2, h * 0.98), 0.5, 1.4)


# a magnetic drum separator: the rotating shell over the stationary magnet arc, the
# feed chute, the splitter between the magnetic and non-magnetic chutes
static func mag_separator(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var c := Vector2(w * 0.45, h * 0.45)
	var rad: float = minf(w * 0.32, h * 0.34)
	O(ci, c, rad, 0.6, 1.4)
	A(ci, c, rad * 0.8, -PI * 0.2, PI * 0.7, 0.5, 2.0)
	var segs := PackedVector2Array()
	for k in 6:
		var a: float = -PI * 0.2 + k * PI * 0.18
		segs.append(c + Vector2.from_angle(a) * rad * 0.62)
		segs.append(c + Vector2.from_angle(a) * rad * 0.8)
	S(ci, segs, 0.4)
	O(ci, c, rad * 0.12, 0.55)
	P(ci, PackedVector2Array([Vector2(w * 0.05, h * 0.05), Vector2(w * 0.3, h * 0.05), c + Vector2(-rad * 0.3, -rad * 0.95)]), 0.5)
	L(ci, c + Vector2(rad * 0.2, rad * 1.0), Vector2(c.x + rad * 0.3, h * 0.97), 0.6, 1.6)
	P(ci, PackedVector2Array([Vector2(w * 0.06, h * 0.97), c + Vector2(-rad * 0.9, rad * 0.8)]), 0.45)
	P(ci, PackedVector2Array([Vector2(w * 0.95, h * 0.97), c + Vector2(rad * 1.0, rad * 0.4)]), 0.45)


# a wet scrubber tower: the packed bed between its support grids, the spray header
# above it, the mist eliminator at the top, the sump and recirculation pump
static func scrubber(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var tw := Rect2(w * 0.12, h * 0.04, w * 0.5, h * 0.82)
	var sh := E.vessel_v(ci, tw, 0.6)
	var pb := Rect2(sh.position.x + 2.0, sh.position.y + sh.size.y * 0.4, sh.size.x - 4.0, sh.size.y * 0.35)
	R(ci, pb, 0.45)
	var dots := PackedVector2Array()
	for j in clampi(int(pb.size.y / 4.0), 2, 30):
		for i in clampi(int(pb.size.x / 4.0), 2, 20):
			var q := pb.position + Vector2((i + 0.5 + (0.5 if j % 2 == 1 else 0.0)) * 4.0, (j + 0.5) * 4.0)
			if q.x < pb.end.x - 1.0:
				dots.append(q)
				dots.append(q + Vector2(1.0, 0.6))
	S(ci, dots, 0.4)
	var sy: float = sh.position.y + sh.size.y * 0.3
	L(ci, Vector2(sh.position.x + 2.0, sy), Vector2(sh.end.x - 2.0, sy), 0.5, 1.4)
	var segs := PackedVector2Array()
	for k in 4:
		var x: float = sh.position.x + sh.size.x * (0.15 + k * 0.23)
		segs.append(Vector2(x, sy))
		segs.append(Vector2(x - 3.0, sy + sh.size.y * 0.06))
		segs.append(Vector2(x, sy))
		segs.append(Vector2(x + 3.0, sy + sh.size.y * 0.06))
	S(ci, segs, 0.25)
	var me := Rect2(sh.position.x + 2.0, sh.position.y + sh.size.y * 0.08, sh.size.x - 4.0, sh.size.y * 0.08)
	R(ci, me, 0.45)
	E.hatch(ci, me, 2.5, true, 0.3, 30)
	E.volute(ci, Vector2(w * 0.82, h * 0.82), minf(w * 0.1, h * 0.08), true, 0.5)
	L(ci, Vector2(tw.end.x, h * 0.82), Vector2(w * 0.72, h * 0.82), 0.45)
	P(ci, PackedVector2Array([Vector2(w * 0.82, h * 0.7), Vector2(w * 0.82, h * 0.3), Vector2(tw.end.x, h * 0.3)]), 0.45)


# a car lashed on the deck, side-on: body, glasshouse, wheels with their chocks,
# the lashing straps to the deck rings
static func car(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var n := clampi(roundi(w / (h * 2.8)), 1, 8)
	var cw: float = w / n
	for i in n:
		var x0: float = i * cw + cw * 0.04
		var x1: float = (i + 1) * cw - cw * 0.04
		var lw: float = x1 - x0
		var by: float = h * 0.76
		P(ci, PackedVector2Array([Vector2(x0, by), Vector2(x0, h * 0.5), Vector2(x0 + lw * 0.22, h * 0.44), Vector2(x0 + lw * 0.32, h * 0.18), Vector2(x0 + lw * 0.7, h * 0.18), Vector2(x0 + lw * 0.84, h * 0.44), Vector2(x1, h * 0.5), Vector2(x1, by), Vector2(x0, by)]), 0.6, 1.2)
		L(ci, Vector2(x0 + lw * 0.5, h * 0.2), Vector2(x0 + lw * 0.5, h * 0.44), 0.4)
		L(ci, Vector2(x0 + lw * 0.26, h * 0.44), Vector2(x0 + lw * 0.82, h * 0.44), 0.35)
		for f in [0.2, 0.8]:
			var wc := Vector2(x0 + lw * f, by)
			O(ci, wc, h * 0.18, 0.6, 1.2)
			O(ci, wc, h * 0.08, 0.4)
			P(ci, PackedVector2Array([wc + Vector2(-h * 0.26, h * 0.22), wc + Vector2(-h * 0.2, h * 0.12), wc + Vector2(-h * 0.14, h * 0.22)]), 0.45)
		L(ci, Vector2(x0 + lw * 0.2, by), Vector2(x0 - 2.0, h - 1.0), 0.3)
		L(ci, Vector2(x0 + lw * 0.8, by), Vector2(x1 + 2.0, h - 1.0), 0.3)


# a deck tractor: the chassis, the cab, the fifth wheel / towing hook, the big
# low-pressure tyres
static func deck_tractor(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var by: float = h * 0.72
	R(ci, Rect2(w * 0.04, h * 0.48, w * 0.92, by - h * 0.48), 0.6, 1.2)
	P(ci, PackedVector2Array([Vector2(w * 0.08, h * 0.48), Vector2(w * 0.1, h * 0.08), Vector2(w * 0.42, h * 0.08), Vector2(w * 0.46, h * 0.48)]), 0.6, 1.2)
	R(ci, Rect2(w * 0.14, h * 0.14, w * 0.26, h * 0.2), 0.45)
	E.louvres(ci, Rect2(w * 0.54, h * 0.52, w * 0.2, by - h * 0.56), 0.3)
	O(ci, Vector2(w * 0.86, h * 0.44), minf(w * 0.05, h * 0.08), 0.55)
	L(ci, Vector2(w * 0.8, h * 0.48), Vector2(w * 0.92, h * 0.48), 0.6, 1.8)
	for f in [0.22, 0.76]:
		O(ci, Vector2(w * f, by + h * 0.04), minf(h * 0.22, w * 0.12), 0.6, 1.4)
		O(ci, Vector2(w * f, by + h * 0.04), minf(h * 0.1, w * 0.05), 0.4)


# an auxiliary power unit: the small gas turbine (intake, centrifugal compressor,
# can combustor, turbine, exhaust) and its gearbox with the generator on it
static func apu(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var ay: float = h * 0.46
	P(ci, PackedVector2Array([Vector2(w * 0.02, ay - h * 0.3), Vector2(w * 0.14, ay - h * 0.18), Vector2(w * 0.14, ay + h * 0.18), Vector2(w * 0.02, ay + h * 0.3)]), 0.5)
	O(ci, Vector2(w * 0.24, ay), h * 0.22, 0.6, 1.2)
	E.impeller(ci, Vector2(w * 0.24, ay), h * 0.16, 0.45)
	R(ci, Rect2(w * 0.34, ay - h * 0.16, w * 0.22, h * 0.32), 0.55)
	A(ci, Vector2(w * 0.45, ay), h * 0.1, PI * 0.5, PI * 1.5, 0.45)
	var segs := PackedVector2Array()
	for k in 4:
		var x: float = w * (0.58 + k * 0.035)
		segs.append(Vector2(x, ay - h * 0.14))
		segs.append(Vector2(x + 3.0, ay + h * 0.14))
	S(ci, segs, 0.45)
	R(ci, Rect2(w * 0.56, ay - h * 0.18, w * 0.16, h * 0.36), 0.55)
	P(ci, PackedVector2Array([Vector2(w * 0.72, ay - h * 0.14), Vector2(w * 0.98, ay - h * 0.22), Vector2(w * 0.98, ay + h * 0.22), Vector2(w * 0.72, ay + h * 0.14)]), 0.5)
	L(ci, Vector2(w * 0.1, ay), Vector2(w * 0.72, ay), 0.3)
	var gb := Rect2(w * 0.1, h * 0.72, w * 0.4, h * 0.24)
	R(ci, gb, 0.55)
	L(ci, Vector2(w * 0.24, ay + h * 0.22), Vector2(w * 0.24, gb.position.y), 0.45, 1.4)
	E.motor(ci, Rect2(gb.end.x, h * 0.74, w * 0.36, h * 0.2), true, 0.5)


# an escape pod in its cradle: the capsule (heat shield, side hatch, window), the
# seats inside, the retro-rocket pack, the launch rails and the clamp
static func escape_pod(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cap := PackedVector2Array([Vector2(w * 0.08, h * 0.2), Vector2(w * 0.72, h * 0.1), Vector2(w * 0.9, h * 0.3), Vector2(w * 0.9, h * 0.7), Vector2(w * 0.72, h * 0.9), Vector2(w * 0.08, h * 0.8), Vector2(w * 0.08, h * 0.2)])
	P(ci, cap, 0.6, 1.4)
	A(ci, Vector2(w * 0.34, h * 0.5), h * 0.6, PI * 0.72, PI * 1.28, 0.6, 2.0)
	R(ci, Rect2(w * 0.4, h * 0.26, w * 0.18, h * 0.48), 0.5)
	D(ci, Vector2(w * 0.55, h * 0.5), 1.2, 0.6)
	O(ci, Vector2(w * 0.76, h * 0.42), h * 0.08, 0.5)
	for k in 2:
		var sx: float = w * (0.16 + k * 0.12)
		P(ci, PackedVector2Array([Vector2(sx, h * 0.3), Vector2(sx, h * 0.62), Vector2(sx + w * 0.08, h * 0.62)]), 0.45, 1.4)
	R(ci, Rect2(w * 0.9, h * 0.38, w * 0.08, h * 0.24), 0.55)
	for f in [0.42, 0.5, 0.58]:
		L(ci, Vector2(w * 0.98, h * f), Vector2(w, h * f), 0.5)
	L(ci, Vector2(w * 0.04, h * 0.97), Vector2(w * 0.96, h * 0.97), 0.55, 1.6)
	L(ci, Vector2(w * 0.04, h * 0.03), Vector2(w * 0.96, h * 0.03), 0.4)


# a nuclear thermal rocket's reactor, exhaust to the right: the pressure vessel, the
# hexagonal fuel elements with their hydrogen channels, the beryllium reflector
# round them with its control drums (each with its absorber plate), the inlet
# plenum and the core support plate, the throat at the outlet
static func ntr_core(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var v := Rect2(w * 0.06, h * 0.04, w * 0.84, h * 0.92)
	R(ci, v, 0.65, 1.4)
	var rf: float = v.size.y * 0.2
	var core := Rect2(v.position.x + v.size.x * 0.18, v.position.y + rf, v.size.x * 0.7, v.size.y - 2.0 * rf)
	R(ci, core, 0.55)
	var segs := PackedVector2Array()
	var nr := clampi(int(core.size.y / 4.0), 3, 30)
	for k in nr:
		var y: float = core.position.y + (k + 0.5) * core.size.y / nr
		segs.append(Vector2(core.position.x + 1.0, y))
		segs.append(Vector2(core.end.x - 1.0, y))
	S(ci, segs, 0.3)
	var ne := clampi(int(core.size.x / 10.0), 2, 12)
	for k in range(1, ne):
		L(ci, Vector2(core.position.x + k * core.size.x / ne, core.position.y), Vector2(core.position.x + k * core.size.x / ne, core.end.y), 0.2)
	# reflector bands top and bottom, the control drums in them
	for y0 in [v.position.y, core.end.y]:
		var band := Rect2(core.position.x, y0, core.size.x, rf)
		E.hatch(ci, band, 4.0, false, 0.12, 20)
		var nd := clampi(int(band.size.x / (rf * 1.2)), 2, 8)
		for k in nd:
			var dc := Vector2(band.position.x + (k + 0.5) * band.size.x / nd, band.get_center().y)
			O(ci, dc, rf * 0.38, 0.55)
			A(ci, dc, rf * 0.32, -PI * 0.3 + k, PI * 0.3 + k, 0.7, 2.0)
	# inlet plenum, support plate, the outlet throat
	L(ci, Vector2(core.position.x - 2.0, v.position.y + 2.0), Vector2(core.position.x - 2.0, v.end.y - 2.0), 0.55, 1.6)
	L(ci, Vector2(v.position.x - 0.0, h * 0.5), Vector2(core.position.x - 4.0, h * 0.5), 0.35)
	P(ci, PackedVector2Array([Vector2(v.end.x, h * 0.3), Vector2(w, h * 0.42), Vector2(w, h * 0.58), Vector2(v.end.x, h * 0.7)]), 0.6, 1.2)


# a control drum: the beryllium drum with its arc of boron carbide absorber, the shaft,
# the drive motor and its position resolver
static func control_drum(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var c := Vector2(w * 0.5, h * 0.5)
	var rad: float = minf(w, h) * 0.42
	O(ci, c, rad, 0.6, 1.2)
	A(ci, c, rad * 0.86, -PI * 0.35, PI * 0.35, 0.7, 3.0)
	E.hatch(ci, Rect2(c.x - rad * 0.6, c.y - rad * 0.6, rad * 1.2, rad * 1.2), 4.0, false, 0.08, 10)
	O(ci, c, rad * 0.18, 0.55)
	L(ci, c, c + Vector2.from_angle(0.0) * rad * 0.6, 0.45)
	R(ci, Rect2(c.x - rad * 0.25, c.y - rad * 0.25, rad * 0.5, rad * 0.5), 0.35)


# a shadow shield: alternating layers of tungsten (dense, cross-hatched) and lithium
# hydride (open) stacked across the line of sight, its tapered edges, the frame
static func shadow_shield(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var vert: bool = h >= w
	var ln: float = h if vert else w
	var th: float = w if vert else h
	var X := func(u: float, v: float) -> Vector2: return Vector2(v, u) if vert else Vector2(u, v)
	var nl := clampi(int(th / 5.0), 2, 10)
	for k in nl:
		var v0: float = k * th / nl
		var v1: float = (k + 1) * th / nl
		var rr := Rect2(X.call(1.0, v0), X.call(ln - 1.0, v1) - X.call(1.0, v0)).abs()
		R(ci, rr, 0.45)
		if k % 2 == 0:
			E.hatch(ci, rr, 3.0, not vert, 0.3, 300)
	E.bolts(ci, X.call(2.0, th * 0.5), X.call(ln - 2.0, th * 0.5), clampi(int(ln / 24.0), 2, 40), 0.5, 1.0)


# a flywheel energy store: the composite rim on its hub in the vacuum housing, the
# magnetic bearings top and bottom, the motor-generator in the middle, the vacuum
# pump port, the containment ring
static func flywheel_rotor(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var c := Vector2(w * 0.5, h * 0.5)
	var rad: float = minf(w, h) * 0.46
	O(ci, c, rad, 0.65, 1.6)
	O(ci, c, rad * 0.94, 0.3)
	for k in 5:
		O(ci, c, rad * (0.66 + k * 0.05), 0.22)
	O(ci, c, rad * 0.62, 0.55, 1.2)
	var segs := PackedVector2Array()
	for k in 6:
		var a: float = TAU * k / 6.0
		segs.append(c + Vector2.from_angle(a) * rad * 0.26)
		segs.append(c + Vector2.from_angle(a) * rad * 0.62)
	S(ci, segs, 0.35)
	O(ci, c, rad * 0.26, 0.55)
	var ns := 12
	for k in ns:
		var a: float = TAU * k / ns
		R(ci, Rect2(c + Vector2.from_angle(a) * rad * 0.18 - Vector2(1.5, 1.5), Vector2(3, 3)), 0.45)
	O(ci, c, rad * 0.08, 0.6)
	R(ci, Rect2(c.x + rad * 0.95, c.y - rad * 0.08, rad * 0.06, rad * 0.16), 0.5)


# a launch cradle: the sled on its rails, the shoes, the saddle pads the payload
# sits in, the release latches
static func launch_cradle(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	L(ci, Vector2(1, h * 0.86), Vector2(w - 1, h * 0.86), 0.6, 2.0)
	R(ci, Rect2(w * 0.02, h * 0.44, w * 0.96, h * 0.3), 0.55)
	var n := clampi(int(w / 40.0), 2, 20)
	for k in n:
		var x: float = w * 0.02 + (k + 0.5) * w * 0.96 / n
		R(ci, Rect2(x - 5.0, h * 0.74, 10.0, h * 0.12), 0.5)
		P(ci, PackedVector2Array([Vector2(x - 8.0, h * 0.44), Vector2(x - 4.0, h * 0.12), Vector2(x + 4.0, h * 0.12), Vector2(x + 8.0, h * 0.44)]), 0.5)
		if k % 2 == 0:
			O(ci, Vector2(x, h * 0.3), 2.0, 0.6)
	E.hatch(ci, Rect2(w * 0.03, h * 0.5, w * 0.94, h * 0.18), 12.0, true, 0.2, 80)


# a tether damper: the hydraulic cylinder with its rod, the spring round it, the
# clevis eyes, the gas reservoir
static func tether_damper(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var ay: float = h * 0.5
	O(ci, Vector2(h * 0.3, ay), h * 0.22, 0.55)
	O(ci, Vector2(w - h * 0.3, ay), h * 0.22, 0.55)
	R(ci, Rect2(h * 0.55, ay - h * 0.26, w * 0.46, h * 0.52), 0.6, 1.2)
	L(ci, Vector2(h * 0.55 + w * 0.46, ay), Vector2(w - h * 0.5, ay), 0.6, 1.8)
	var pts := PackedVector2Array()
	var nz := clampi(int(w * 0.6 / 4.0), 4, 30)
	for k in nz + 1:
		pts.append(Vector2(w * 0.2 + k * w * 0.6 / nz, ay + (h * 0.38 if k % 2 == 0 else -h * 0.38)))
	P(ci, pts, 0.3)
	R(ci, Rect2(h * 0.7, ay - h * 0.46, w * 0.18, h * 0.16), 0.45)


# a hydraulic clamp: the jaw (fixed and moving halves), the cylinder pushing the
# moving one, the hose connections, the base plate's bolts
static func hyd_clamp(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(w * 0.04, h * 0.84, w * 0.92, h * 0.12), 0.55)
	E.bolts(ci, Vector2(w * 0.08, h * 0.9), Vector2(w * 0.92, h * 0.9), 4, 0.5, 1.0)
	P(ci, PackedVector2Array([Vector2(w * 0.08, h * 0.84), Vector2(w * 0.08, h * 0.12), Vector2(w * 0.3, h * 0.12), Vector2(w * 0.3, h * 0.4), Vector2(w * 0.2, h * 0.4), Vector2(w * 0.2, h * 0.84)]), 0.6, 1.2)
	R(ci, Rect2(w * 0.32, h * 0.14, w * 0.16, h * 0.26), 0.6, 1.2)
	E.hatch(ci, Rect2(w * 0.3, h * 0.16, w * 0.02, h * 0.22), 2.0, false, 0.4, 10)
	L(ci, Vector2(w * 0.48, h * 0.27), Vector2(w * 0.6, h * 0.27), 0.6, 2.0)
	R(ci, Rect2(w * 0.6, h * 0.14, w * 0.34, h * 0.26), 0.6, 1.2)
	for f in [0.66, 0.88]:
		L(ci, Vector2(w * f, h * 0.4), Vector2(w * f, h * 0.84), 0.4)
		D(ci, Vector2(w * f, h * 0.42), 1.2, 0.55)


# a grand piano side-on: the case's long curve, the open lid on its prop, the
# keyboard and the music desk, the legs and the pedal lyre
static func piano(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var ty: float = h * 0.46
	P(ci, PackedVector2Array([Vector2(w * 0.04, ty), Vector2(w * 0.96, ty), Vector2(w * 0.96, ty + h * 0.16), Vector2(w * 0.04, ty + h * 0.16), Vector2(w * 0.04, ty)]), 0.6, 1.2)
	L(ci, Vector2(w * 0.1, ty), Vector2(w * 0.9, h * 0.06), 0.55, 1.4)
	L(ci, Vector2(w * 0.6, ty), Vector2(w * 0.62, h * 0.2), 0.45)
	R(ci, Rect2(w * 0.86, ty - h * 0.12, w * 0.1, h * 0.12), 0.5)
	E.hatch(ci, Rect2(w * 0.86, ty - h * 0.06, w * 0.1, h * 0.05), 2.0, true, 0.4, 20)
	L(ci, Vector2(w * 0.84, ty - h * 0.2), Vector2(w * 0.86, ty - h * 0.06), 0.45)
	for f in [0.08, 0.5, 0.9]:
		L(ci, Vector2(w * f, ty + h * 0.16), Vector2(w * f, h * 0.96), 0.55, 1.6)
	P(ci, PackedVector2Array([Vector2(w * 0.78, ty + h * 0.16), Vector2(w * 0.76, h * 0.9), Vector2(w * 0.8, h * 0.9), Vector2(w * 0.78, ty + h * 0.16)]), 0.45)
	var segs := PackedVector2Array()
	for k in 8:
		var x: float = w * (0.12 + k * 0.08)
		segs.append(Vector2(x, ty + 2.0))
		segs.append(Vector2(x + w * 0.06, ty + h * 0.14))
	S(ci, segs, 0.15)


# a wine wall: the diamond lattice of bottle bins, the bottle ends in them, the
# climate unit's grille at the top
static func wine_rack(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, 1, w - 2, h - 2), 0.55)
	E.louvres(ci, Rect2(4, 3, w - 8, h * 0.08), 0.3)
	var top: float = h * 0.12
	var s: float = clampf(w / 6.0, 8.0, 20.0)
	var segs := PackedVector2Array()
	var k := -int(h / s) - 2
	while k * s < w + h:
		segs.append(Vector2(k * s, top))
		segs.append(Vector2(k * s + (h - top), h))
		segs.append(Vector2(k * s + (h - top), top))
		segs.append(Vector2(k * s, h))
		k += 1
	# clip to the frame by drawing only the inner segments
	var clipped := PackedVector2Array()
	for i in range(0, segs.size(), 2):
		var res := Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([segs[i], segs[i + 1]]), PackedVector2Array([Vector2(2, top), Vector2(w - 2, top), Vector2(w - 2, h - 2), Vector2(2, h - 2)]))
		for seg in res:
			if seg.size() >= 2:
				clipped.append(seg[0])
				clipped.append(seg[seg.size() - 1])
	S(ci, clipped, 0.4)
	for j in int((h - top) / s):
		for i in int(w / s):
			var c := Vector2((i + 0.5) * s, top + (j + 0.5) * s)
			if c.x < w - 4.0 and c.y < h - 4.0:
				O(ci, c, s * 0.12, 0.5)


# a bar: the counter with its foot rail, the beer taps, the back bar's shelves of
# bottles, the glass rack
static func bar(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cy: float = h * 0.56
	L(ci, Vector2(1, cy), Vector2(w - 1, cy), 0.65, 2.2)
	R(ci, Rect2(w * 0.04, cy, w * 0.92, h * 0.42), 0.5)
	L(ci, Vector2(w * 0.04, h * 0.92), Vector2(w * 0.96, h * 0.92), 0.45, 1.4)
	for k in 3:
		var x: float = w * (0.5 + k * 0.08)
		L(ci, Vector2(x, cy), Vector2(x, cy - h * 0.12), 0.55, 1.4)
		L(ci, Vector2(x, cy - h * 0.12), Vector2(x + 3.0, cy - h * 0.1), 0.55)
	for row in 2:
		var y: float = h * (0.12 + row * 0.18)
		L(ci, Vector2(w * 0.04, y + h * 0.12), Vector2(w * 0.96, y + h * 0.12), 0.45)
		var n := clampi(int(w / 7.0), 3, 40)
		for i in n:
			var x: float = w * 0.06 + i * w * 0.88 / n
			var bh: float = h * (0.08 + 0.03 * fposmod(i * 0.37 + row, 1.0))
			P(ci, PackedVector2Array([Vector2(x, y + h * 0.12), Vector2(x, y + h * 0.12 - bh * 0.6), Vector2(x + 1.0, y + h * 0.12 - bh), Vector2(x + 2.0, y + h * 0.12 - bh), Vector2(x + 3.0, y + h * 0.12 - bh * 0.6), Vector2(x + 3.0, y + h * 0.12)]), 0.4)


# a cone crusher: the bowl liner and the mantle gyrating inside it, the eccentric
# and main shaft, the feed hopper on top, the countershaft to the motor, the frame
static func crusher(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cx: float = w * 0.46
	var s: float = minf(w * 0.4, h * 0.42)
	# hopper
	P(ci, PackedVector2Array([Vector2(cx - s * 0.9, h * 0.04), Vector2(cx - s * 0.4, h * 0.22), Vector2(cx + s * 0.4, h * 0.22), Vector2(cx + s * 0.9, h * 0.04)]), 0.55, 1.2)
	# bowl (outer) and mantle (inner cone)
	P(ci, PackedVector2Array([Vector2(cx - s * 0.5, h * 0.22), Vector2(cx - s, h * 0.6), Vector2(cx - s, h * 0.72), Vector2(cx + s, h * 0.72), Vector2(cx + s, h * 0.6), Vector2(cx + s * 0.5, h * 0.22)]), 0.65, 1.4)
	P(ci, PackedVector2Array([Vector2(cx - s * 0.12, h * 0.3), Vector2(cx - s * 0.78, h * 0.66), Vector2(cx + s * 0.82, h * 0.64), Vector2(cx + s * 0.16, h * 0.3), Vector2(cx - s * 0.12, h * 0.3)]), 0.55, 1.2)
	var segs := PackedVector2Array()
	for k in 5:
		var t: float = (k + 1) / 6.0
		segs.append(Vector2(lerpf(cx - s * 0.12, cx - s * 0.78, t), lerpf(h * 0.3, h * 0.66, t)))
		segs.append(Vector2(lerpf(cx + s * 0.16, cx + s * 0.82, t), lerpf(h * 0.3, h * 0.64, t)))
	S(ci, segs, 0.15)
	L(ci, Vector2(cx, h * 0.26), Vector2(cx, h * 0.86), 0.55, 1.6)
	R(ci, Rect2(cx - s * 0.3, h * 0.72, s * 0.6, h * 0.12), 0.55)
	O(ci, Vector2(cx, h * 0.78), s * 0.1, 0.5)
	# countershaft to the motor
	L(ci, Vector2(cx + s * 0.3, h * 0.78), Vector2(w * 0.86, h * 0.78), 0.5, 1.4)
	E.motor(ci, Rect2(w * 0.8, h * 0.62, w * 0.18, h * 0.2), true, 0.5)
	# frame and discharge
	L(ci, Vector2(cx - s, h * 0.72), Vector2(cx - s * 1.1, h * 0.97), 0.5, 1.4)
	L(ci, Vector2(cx + s, h * 0.72), Vector2(cx + s * 1.1, h * 0.97), 0.5, 1.4)
	L(ci, Vector2(cx - s * 1.2, h * 0.97), Vector2(w - 2, h * 0.97), 0.55, 1.6)
