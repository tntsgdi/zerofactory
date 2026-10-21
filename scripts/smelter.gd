extends RefCounted
# The berth's furnace below the scrap mouth (player 2026-10-20: "the furnace
# needs a real furnace's structure and details, but the way in stays easy").
# The mouth on the floor is unchanged: it takes scrap at once and pays for it.
# Under the floor the scrap goes into a bunker; a screw feeder charges it into a
# vacuum induction furnace whose crucible spins (the berth has no gravity: at
# 45 rpm the melt is held against the lining at about 1.4 g). A water-cooled
# copper coil heats it; laminated yokes carry the coil's flux; the rammed MgO
# lining wears a little every heat. Full and hot enough, the furnace swings its
# condenser hood aside, tilts on its trunnions and taps through the slide gate
# into water-cooled copper ingot moulds that index along a casting line.
# Only picture and read-outs: nothing here holds the mouth up or changes money
# (Jev 2026-10-20: A 0.94). The numbers are an honest heat balance:
#   heating   dT/dt = (P·η − Q_wall − Q_rad) / (m_l·c_l + m_s·c_s)
#   melting   dm/dt = K·(T − T_liq), each kg taking c_s·(T_liq − 20) + L + c_l·(T − T_liq)
#   coil water ΔT = Q / (ṁ·c_w); skin depth δ = 503·√(ρ / (μ_r·f))
# Geometry in metres from the furnace axis X and the floor line F (y down).

const M := 48.0
const CAP := 12.0            # t the crucible holds
const HEEL := 4.0            # t left in after a tap (hot heel)
const INGOT := 1.0           # t per ingot
const P_RATED := 24.0        # MW from the inverter
const ETA := 0.78            # coil efficiency (the rest goes into the coil water)
const T_LIQ := 1515.0        # °C: liquidus of the low-carbon scrap
const T_TAP := 1640.0        # °C: tapping temperature
const T_HOLD := 1585.0       # °C: held while waiting for scrap
const C_L := 820.0           # J/kg·K liquid steel
const C_S := 650.0           # J/kg·K solid, averaged 20..1515 °C
const L_FUS := 272000.0      # J/kg
const K_MELT := 0.0004       # t/(s·K): how fast the bath dissolves solid charge
const FEED := 0.025          # t/s: the screw feeder flat out
const BUNKER_CAP := 40.0     # t; beyond it the scrap waits in the yard
const FLOW := 240.0          # m³/h of coil water
const T_IN := 28.0           # °C coil water in
const RPM := 45.0
const R_IN := 0.6            # m: the crucible's inner radius
const H_IN := 2.0            # m: its inner height
const RHO_L := 7.0           # t/m³ liquid steel
const TILT_MAX := 0.56       # rad (32°)
const TILT_T := 7.0          # s to tilt over or back
const POUR := 0.6            # t/s through the taphole
const PIV := 5.2             # m below the floor: the trunnion axis
const PITCH := 0.72          # m between ingot moulds
const LINE_X0 := 2.2         # m: the casting line from the furnace's right
const LINE_X1 := 11.0
const FILL_X := 2.65         # m: where the stream lands

var X := 21.0
var m_l := 8.0               # t liquid
var m_s := 0.0               # t solid charge not yet dissolved
var T := 1600.0
var bunker := 18.0
var yard := 0.0
var power := 0.0             # MW drawn now
var feed := 0.0              # t/s charging now
var phase := "melt"          # melt heat tilt pour back hold
var phase_t := 0.0
var tilt := 0.0
var hood := 0.0              # 0 over the crucible, 1 slid aside
var gate := 0.0              # slide gate open 0..1
var line_off := 0.0          # m the casting line has moved
var line_goal := 0.0
var shipped := 0                # ingots off the end of the casting line, down to the barge
var shipped_t := 0.0
var ingots: Array = []       # [cast at line_off, °C, mass]
var cast_t := 0.0            # t poured into the mould at the fill station
var lining := 118.0          # mm working lining left
var heat_no := 312
var ingot_no := 0
var condensate := 0.0        # kg of metal vapour on the trap
var pressure := 0.002        # Pa in the furnace chamber
var flare_t := 0.0
var leak_ma := 2.4
var ram_open := 0.0          # the compaction ram backs off while scrap comes in
var incoming: Array = []     # [t, from x (m), mass]
var bits: Array = []         # [t, side, y]: scrap leaving the feeder into the bath
var t := 0.0
var _bit_acc := 0.0
# the immersion lance: it dips through the hood every so often for a temperature and a sample
var lance_t := 20.0
var dip := 0.0                # 0 up, 1 in the melt
var tc_T := 1590.0            # °C the last dip read
var tc_age := 0.0
# the melt's chemistry by optical emission spectrometry of the last sample (mass %)
var chem := {"C": 0.12, "Mn": 0.55, "Si": 0.22, "Cr": 0.06, "Ni": 0.05, "Cu": 0.10, "S": 0.015, "P": 0.014}
var bath_chem := chem.duplicate()
var vapor := 0.0              # how hard the melt is fuming now (0..1): what the trap sees
var hpu_bar := 210.0          # bar in the tilt hydraulics' accumulator
const DY := 2.65              # m: the furnace sits this far below the pre-processing line


func _init() -> void:
	# a furnace that has been running: somewhere in its cycle, scrap waiting
	m_l = randf_range(HEEL + 1.0, CAP - 1.5)
	T = randf_range(1560.0, 1620.0)
	bunker = randf_range(6.0, 22.0)
	lining = randf_range(96.0, 131.0)
	heat_no = 300 + randi() % 90
	ingot_no = heat_no * 8
	for i in 6:
		ingots.append([-(i + 1) * PITCH * 1.0, 300.0 + i * 40.0, INGOT])


# charge for the melt (t), from the pre-processing line (scrapline.gd): pressed pucks into
# the bunker, shredded fines through the hood; dirty is how much wiring, motors and
# coatings came with it (0 a clean plate, 1 shredded equipment) - copper and nickel
# don't come out in an induction furnace, they stay in the steel
func charge(mass: float, from_x: float, dirty: float = 0.0) -> void:
	incoming.append([0.0, from_x, mass, 0.6 + absf(from_x - X) / 3.0])
	ram_open = 1.0
	var tot := maxf(0.5, m_l + m_s + bunker) + mass
	var add := {"Cu": 0.08 + 0.32 * dirty, "Ni": 0.04 + 0.10 * dirty, "Cr": 0.05 + 0.12 * dirty, "C": 0.12, "Mn": 0.55, "Si": 0.22, "S": 0.015 + 0.01 * dirty, "P": 0.014}
	for el in bath_chem:
		bath_chem[el] = (float(bath_chem[el]) * (tot - mass) + float(add[el]) * mass) / tot


# something that should have gone to the hazard bay went off in the melt
func flare() -> void:
	flare_t = 1.0
	T += 45.0
	pressure = 2400.0


func fill() -> float:
	return clampf(bunker / BUNKER_CAP, 0.0, 1.0)


# the melt's thickness on the wall (m): the annulus a mass makes on the spinning crucible
func layer(m: float) -> float:
	var v := m / RHO_L
	return R_IN - sqrt(maxf(0.0, R_IN * R_IN - v / (PI * H_IN)))


func g_load() -> float:
	var w := RPM * TAU / 60.0
	return w * w * R_IN / 9.81


func freq() -> float:
	# cold ferromagnetic charge (below its Curie point) loads the coil and pulls the resonance down
	var solid := m_s / maxf(0.5, m_l + m_s)
	return 392.0 + 64.0 * clampf(m_l / CAP, 0.0, 1.0) - 55.0 * solid


func skin_mm() -> float:
	return 503.0 * sqrt(1.38e-6 / freq()) * 1000.0


func q_wall() -> float:
	return 0.9 * (T - 25.0) / 1600.0


func q_rad() -> float:
	return 0.25 * pow((T + 273.0) / 1913.0, 4.0)


func water_out() -> float:
	var q := power * (1.0 - ETA) + q_wall() * 0.85
	return T_IN + q * 1e6 / (FLOW / 3600.0 * 1000.0 * 4186.0)


func step(dt: float) -> void:
	if dt <= 0.0:
		return
	t += dt
	phase_t += dt
	ram_open = maxf(0.0, ram_open - dt * 1.2)
	flare_t = maxf(0.0, flare_t - dt * 0.6)
	pressure = maxf(0.002 + 0.03 * exp((T - 1600.0) / 80.0), pressure * exp(-dt * 1.5))
	leak_ma = 2.0 + (131.0 - lining) * 0.02 + 0.3 * sin(t * 0.7)
	# scrap on its way from the mouth: lands in the bunker
	for c in incoming:
		c[0] += dt
	for c in incoming.filter(func(c): return c[0] >= c[3]):
		incoming.erase(c)
		bunker += float(c[2])
	if bunker > BUNKER_CAP:
		yard += bunker - BUNKER_CAP
		bunker = BUNKER_CAP
	elif yard > 0.0 and bunker < BUNKER_CAP - 2.0:
		var take := minf(yard, 0.4 * dt)
		yard -= take
		bunker += take
	# the cycle
	feed = 0.0
	match phase:
		"melt", "hold":
			power = P_RATED if T < T_TAP + 15.0 else maxf(0.0, (q_wall() + q_rad()) / ETA)
			if bunker > 0.01 and m_l + m_s < CAP - 0.05 and m_s < 0.8 and T > T_LIQ + 40.0:
				feed = minf(FEED, bunker / dt)
			if bunker <= 0.01 and m_s <= 0.001:
				phase = "hold"
				power = minf(power, maxf(0.0, (q_wall() + q_rad()) / ETA + (2.0 if T < T_HOLD else 0.0)))
			elif phase == "hold":
				phase = "melt"
			if m_l >= CAP - 0.05 and m_s <= 0.001:
				_go("heat")
		"heat":
			power = P_RATED
			if T >= T_TAP:
				_go("tilt")
		"tilt":
			power = (q_wall() + q_rad()) / ETA
			hood = minf(1.0, hood + dt / 2.0)
			if hood >= 1.0:
				tilt = minf(TILT_MAX, tilt + TILT_MAX * dt / TILT_T)
				if tilt >= TILT_MAX:
					_go("pour")
		"pour":
			power = (q_wall() + q_rad()) / ETA
			gate = minf(1.0, gate + dt * 2.0)
			var out := minf(POUR * dt * gate, m_l - HEEL)
			m_l -= out
			cast_t += out
			if cast_t >= INGOT:
				cast_t -= INGOT
				ingots.append([line_goal, T - 60.0, INGOT])
				ingot_no += 1
				line_goal += PITCH
			if m_l <= HEEL + 0.001:
				if cast_t > 0.05:
					ingots.append([line_goal, T - 60.0, cast_t])
					ingot_no += 1
					line_goal += PITCH
				cast_t = 0.0
				_go("back")
		"back":
			power = (q_wall() + q_rad()) / ETA
			gate = maxf(0.0, gate - dt * 2.0)
			tilt = maxf(0.0, tilt - TILT_MAX * dt / TILT_T)
			if tilt <= 0.0:
				hood = maxf(0.0, hood - dt / 2.0)
				if hood <= 0.0:
					heat_no += 1
					lining -= 0.35
					if lining < 62.0:
						lining = 131.0     # relined between contracts
					_go("melt")
	# the casting line indexes one mould on per ingot
	line_off = move_toward(line_off, line_goal, 0.5 * dt)
	for ig in ingots:
		# water-cooled copper: fast at first, then slower as the shell forms
		ig[1] = 25.0 + (float(ig[1]) - 25.0) * exp(-dt / 70.0)
	for ig in ingots:
		if FILL_X + line_off - float(ig[0]) >= LINE_X1 - 0.3:
			shipped += 1
			shipped_t += float(ig[2])
	ingots = ingots.filter(func(ig): return FILL_X + line_off - float(ig[0]) < LINE_X1 - 0.3)
	# charging and melting
	m_s += feed * dt
	bunker -= feed * dt
	if feed > 0.0:
		_bit_acc += dt
		while _bit_acc > 0.12:
			_bit_acc -= 0.12
			bits.append([0.0, -1.0 if randf() < 0.5 else 1.0, randf_range(0.15, 0.85)])
	for b in bits:
		b[0] += dt
	bits = bits.filter(func(b): return b[0] < 0.9)
	var dm := 0.0
	if m_s > 0.0 and T > T_LIQ:
		dm = minf(m_s, K_MELT * (T - T_LIQ) * dt)
	m_s -= dm
	m_l += dm
	condensate += dm * 0.6
	vapor = lerpf(vapor, clampf(dm / dt / 0.02, 0.0, 1.0) + clampf((T - 1600.0) / 200.0, 0.0, 0.4), 1.0 - exp(-2.0 * dt))
	# the lance: down through its port in the hood for a reading and a sample, then out
	tc_age += dt
	lance_t += dt
	if phase in ["melt", "heat", "hold"] and hood < 0.01 and lance_t > 40.0:
		dip = minf(1.0, dip + dt / 1.2)
		if dip >= 1.0 and lance_t > 43.0:
			lance_t = 0.0
			tc_T = T + randf_range(-3.0, 3.0)
			tc_age = 0.0
			for el in bath_chem:
				chem[el] = float(bath_chem[el]) * randf_range(0.97, 1.03)
	else:
		dip = maxf(0.0, dip - dt / 0.8)
	hpu_bar = move_toward(hpu_bar, 175.0 if phase in ["tilt", "back"] else 210.0, 20.0 * dt)
	var e_melt := dm * 1000.0 * (C_S * (T_LIQ - 20.0) + L_FUS + C_L * (T - T_LIQ))
	var e_in := (power * ETA - q_wall() - q_rad()) * 1e6 * dt
	var cap_j := m_l * 1000.0 * C_L + m_s * 1000.0 * C_S
	T += (e_in - e_melt) / maxf(1.0, cap_j)
	T = clampf(T, 1450.0, 1720.0)


func _go(p: String) -> void:
	phase = p
	phase_t = 0.0


func state_key() -> String:
	if flare_t > 0.3:
		return "fu_st_flare"
	return "fu_st_" + phase


# ---------------------------------------------------------------- colour

# what glowing steel looks like at T (°C): dull red, orange, yellow-white
static func glow_col(temp: float, a: float = 1.0) -> Color:
	var u := clampf((temp - 480.0) / 1150.0, 0.0, 1.0)
	var c: Color
	if u < 0.5:
		c = Color(0.35, 0.03, 0.0).lerp(Color(1.0, 0.36, 0.08), u * 2.0)
	else:
		c = Color(1.0, 0.36, 0.08).lerp(Color(1.0, 0.86, 0.58), (u - 0.5) * 2.0)
	var k := 0.55 + 0.6 * u
	return Color(c.r * k, c.g * k, c.b * k, a)


# ---------------------------------------------------------------- drawing

# a point of the furnace body (metres from the axis and the floor) as it sits, tilted on its trunnions
func body_pt(x: float, y: float, F: float) -> Vector2:
	var r := Vector2(x, y - PIV).rotated(tilt)
	return Vector2(X + r.x, F + PIV + r.y) * M


func _rect(ci: CanvasItem, x0: float, y0: float, x1: float, y1: float, F: float, fill_c: Color, edge: Color = Color(0, 0, 0, 0), w: float = 1.0) -> void:
	var p := PackedVector2Array([Vector2(X + x0, F + y0) * M, Vector2(X + x1, F + y0) * M, Vector2(X + x1, F + y1) * M, Vector2(X + x0, F + y1) * M])
	ci.draw_colored_polygon(p, fill_c)
	if edge.a > 0.0:
		p.append(p[0])
		ci.draw_polyline(p, edge, w)


func _brect(ci: CanvasItem, x0: float, y0: float, x1: float, y1: float, F: float, fill_c: Color, edge: Color = Color(0, 0, 0, 0), w: float = 1.0) -> void:
	var p := PackedVector2Array([body_pt(x0, y0, F), body_pt(x1, y0, F), body_pt(x1, y1, F), body_pt(x0, y1, F)])
	ci.draw_colored_polygon(p, fill_c)
	if edge.a > 0.0:
		p.append(p[0])
		ci.draw_polyline(p, edge, w)


func _bline(ci: CanvasItem, x0: float, y0: float, x1: float, y1: float, F: float, c: Color, w: float = 1.0) -> void:
	ci.draw_line(body_pt(x0, y0, F), body_pt(x1, y1, F), c, w)


func _curve(a: Vector2, b: Vector2, sag: float) -> PackedVector2Array:
	var mid := (a + b) * 0.5 + Vector2(0, sag)
	var pts := PackedVector2Array()
	for i in 13:
		var u := i / 12.0
		pts.append(a.lerp(mid, u).lerp(mid.lerp(b, u), u))
	return pts


const STEEL := Color(0.06, 0.063, 0.072)
const STEEL_HI := Color(0.085, 0.089, 0.1)
const COPPER := Color(0.62, 0.36, 0.2)
const MGO := Color(0.19, 0.155, 0.125)
const GROUT := Color(0.13, 0.13, 0.115)


# the whole plant below the floor: F is the floor line (m), mx the mouth's x (m), font for read-outs,
# zoom the camera's (labels fade out when far away), txt a Callable(key) -> String
const FAR := 0.55               # below this zoom the plant is drawn as outlines


func draw(ci: CanvasItem, F: float, mx: float, font: Font, font_b: Font, zoom: float, txt: Callable) -> void:
	var floor_y := F
	F += DY
	if zoom < FAR:
		_draw_far(ci, F)
		return
	# ---- the bunker and its compaction ram
	var fl := fill()
	_rect(ci, -1.4, 1.0, 1.4, 2.85, F, Color(0.045, 0.047, 0.054), Pal.ink(0.5), 1.4)
	for sx: float in [-0.7, 0.0, 0.7]:
		ci.draw_line(Vector2(X + sx, F + 1.0) * M, Vector2(X + sx, F + 1.08) * M, Pal.ink(0.3), 2.0)
	var pile_top := 2.8 - 1.55 * fl
	# the scrap in it: a jumble of offcuts packed under the ram
	# far out (the whole berth in view) the small stuff is left out: it would be under a pixel
	var n := int(fl * 26.0) if zoom >= 0.4 else 0
	for i in n:
		var u := fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
		var v := fposmod(sin(i * 78.233) * 12543.123, 1.0)
		var cx := X - 1.2 + u * 2.4
		var cy := lerpf(2.75, pile_top + 0.12, v)
		var a := u * 6.0
		var s := 0.13 + 0.1 * v
		var poly := PackedVector2Array()
		for k in 4:
			poly.append(Vector2(cx, cy) * M + Vector2.from_angle(a + k * 1.6 + v) * s * M * (0.7 + 0.3 * float(k % 2)))
		ci.draw_colored_polygon(poly, Color(0.17, 0.165, 0.17))
		poly.append(poly[0])
		ci.draw_polyline(poly, Pal.ink(0.38), 1.0)
	var ram_y := maxf(1.15, pile_top - 0.08 - ram_open * 0.35)
	ci.draw_rect(Rect2(Vector2(X - 1.32, F + ram_y - 0.1) * M, Vector2(2.64 * M, 0.1 * M)), STEEL_HI)
	ci.draw_rect(Rect2(Vector2(X - 1.32, F + ram_y - 0.1) * M, Vector2(2.64 * M, 0.1 * M)), Pal.ink(0.55), false, 1.2)
	for sx: float in [-0.8, 0.8]:
		ci.draw_line(Vector2(X + sx, F + 1.0) * M, Vector2(X + sx, F + ram_y - 0.1) * M, Pal.ink(0.5), 3.0)
		ci.draw_rect(Rect2(Vector2(X + sx - 0.09, F + 1.0) * M, Vector2(0.18 * M, 0.35 * M)), STEEL_HI)
	# radar level gauge on the lid
	ci.draw_rect(Rect2(Vector2(X + 1.0, F + 0.88) * M, Vector2(0.24 * M, 0.12 * M)), Pal.ink(0.5))
	ci.draw_line(Vector2(X + 1.12, F + 1.0) * M, Vector2(X + 1.12, F + pile_top) * M, Pal.tint(Pal.AIR, 0.25 + 0.15 * sin(t * 6.0), 1.2), 1.0)
	_label(ci, font, Vector2(X + 1.5, F + 1.35) * M, txt.call("fu_bunker"), zoom)
	# ---- screw feeder into the hood
	_rect(ci, -0.18, 2.85, 0.18, 3.36, F, Color(0.05, 0.053, 0.06), Pal.ink(0.5))
	var turn := fposmod(t * (3.0 if feed > 0.0 else 0.0), 1.0)
	for i in 5:
		var yy := F + 2.9 + (i + turn) * 0.1
		if yy < F + 3.34:
			ci.draw_line(Vector2(X - 0.16, yy) * M, Vector2(X + 0.16, yy + 0.06) * M, Pal.ink(0.35), 1.2)
	_label(ci, font, Vector2(X + 0.3, F + 3.15) * M, txt.call("fu_auger"), zoom)
	# ---- the inverter cabinet and the heat exchanger, off to the left
	ci.draw_set_transform(Vector2(-2.6, 0.2) * M)
	_rect(ci, -7.4, 1.6, -4.2, 3.6, F, Color(0.05, 0.053, 0.06), Pal.ink(0.5), 1.4)
	for i in 3:
		var cc := Vector2(X - 7.0 + i * 0.5, F + 2.35) * M
		ci.draw_rect(Rect2(cc - Vector2(0.17, 0.5) * M, Vector2(0.34, 1.0) * M), Color(0.08, 0.083, 0.095))
		ci.draw_rect(Rect2(cc - Vector2(0.17, 0.5) * M, Vector2(0.34, 1.0) * M), Pal.ink(0.35), false, 1.0)
		ci.draw_line(cc - Vector2(0.1, 0.58) * M, cc - Vector2(0.1, 0.5) * M, Pal.ink(0.5), 2.0)
	for i in 6:
		var fy := F + 1.85 + i * 0.22
		ci.draw_line(Vector2(X - 5.4, fy) * M, Vector2(X - 4.5, fy) * M, Pal.ink(0.28), 1.0)
	ci.draw_rect(Rect2(Vector2(X - 5.5, F + 1.75) * M, Vector2(1.1 * M, 1.35 * M)), Pal.ink(0.3), false, 1.0)
	var lamp := Pal.tint(Pal.FLUID, 0.9, 1.4) if power > 1.0 else Pal.ink(0.3)
	ci.draw_circle(Vector2(X - 4.5, F + 3.35) * M, 3.0, lamp)
	_label(ci, font, Vector2(X - 7.4, F + 1.6) * M + Vector2(0, -6), txt.call("fu_vip") % [P_RATED], zoom)
	# inside it: rectifier, DC link choke, IGBT bridge, the resonant capacitors (schematic)
	ci.draw_arc(Vector2(X - 5.95, F + 3.3) * M, 0.12 * M, 0.0, TAU, 12, Pal.ink(0.4), 1.0)
	for q in 4:
		ci.draw_arc(Vector2(X - 5.95 + (q - 1.5) * 0.09, F + 3.3) * M, 0.045 * M, PI, TAU, 6, Pal.ink(0.45), 1.0)
	_label(ci, font, Vector2(X - 7.3, F + 3.85) * M, txt.call("fu_vip_d"), zoom)
	ci.draw_set_transform(Vector2.ZERO)
	# ---- the base frame the trunnion pedestals stand on, the struts up to the floor
	ci.draw_rect(Rect2(Vector2(X - 2.7, F + 7.55) * M, Vector2(5.4 * M, 0.22 * M)), STEEL_HI)
	ci.draw_rect(Rect2(Vector2(X - 2.7, F + 7.55) * M, Vector2(5.4 * M, 0.22 * M)), Pal.ink(0.45), false, 1.2)
	for s: float in [-1.0, 1.0]:
		ci.draw_line(Vector2(X + 2.6 * s, F + 7.6) * M, Vector2(X + 3.4 * s, floor_y + 0.6) * M, Pal.ink(0.2), 3.0)
	_hx(ci, F, font, zoom, txt)
	_hpu(ci, F, font, zoom, txt)
	# ---- the condenser hood (slides aside before the furnace tilts) and the vapour trap
	var hdx := -2.6 * Pal.ease_io(hood)
	ci.draw_line(Vector2(X - 4.3, F + 3.3) * M, Vector2(X + 1.7, F + 3.3) * M, Pal.ink(0.3), 1.4)
	var hp := PackedVector2Array([Vector2(X + hdx - 1.6, F + 3.36) * M, Vector2(X + hdx + 1.6, F + 3.36) * M,
		Vector2(X + hdx + 1.35, F + 3.82) * M, Vector2(X + hdx - 1.35, F + 3.82) * M])
	ci.draw_colored_polygon(hp, Color(0.055, 0.058, 0.066))
	var hcl := hp.duplicate()
	hcl.append(hp[0])
	ci.draw_polyline(hcl, Pal.ink(0.55), 1.4)
	for i in 7:
		var tx := X + hdx - 1.3 + i * 0.43
		ci.draw_circle(Vector2(tx, F + 3.7) * M, 0.05 * M, Pal.tint(Pal.AIR, 0.35))
	_label(ci, font, Vector2(X + hdx - 1.75, F + 3.62) * M + Vector2(0, 4), txt.call("fu_hood"), zoom, true)
	_condenser(ci, F, hdx, font, zoom, txt)
	# the immersion lance through its port in the hood: down for a reading and a sample
	var lx := X + hdx - 0.45
	var ltip := 3.4 + 1.5 * Pal.ease_io(dip)
	ci.draw_rect(Rect2(Vector2(lx - 0.12, F + 2.95) * M, Vector2(0.24, 0.38) * M), STEEL_HI)
	ci.draw_rect(Rect2(Vector2(lx - 0.12, F + 2.95) * M, Vector2(0.24, 0.38) * M), Pal.ink(0.5), false, 1.0)
	ci.draw_line(Vector2(lx, F + 2.95) * M, Vector2(lx + 0.12 * dip, F + ltip) * M, Pal.ink(0.7), 2.0)
	if dip > 0.9:
		ci.draw_circle(Vector2(lx + 0.12 * dip, F + ltip) * M, 3.0, glow_col(T, 0.9))
	_label(ci, font, Vector2(lx - 0.15, F + 2.9) * M, txt.call("fu_lance"), zoom, true)
	# ---- the furnace body, tilted on its trunnions
	# water-cooled power cables and coil-water hoses (flexible: the body swings)
	var term := body_pt(-1.4, 4.45, F)
	ci.draw_polyline(_curve(Vector2(X - 6.8, F + 3.3) * M, term, 0.6 * M), Pal.ink(0.5), 3.0)
	ci.draw_polyline(_curve(Vector2(X - 6.8, F + 3.5) * M, body_pt(-1.4, 4.75, F), 0.7 * M), Pal.ink(0.45), 3.0)
	var w_out := water_out()
	ci.draw_polyline(_curve(Vector2(X - 7.4, F + 4.55) * M, body_pt(-1.4, 5.7, F), 0.5 * M), Pal.tint(Pal.AIR, 0.55), 2.4)
	ci.draw_polyline(_curve(Vector2(X - 6.45, F + 5.9) * M, body_pt(-1.4, 6.1, F), 0.5 * M), Pal.heat(clampf((w_out - 28.0) / 40.0, 0.2, 0.7), 1.0), 2.4)
	# shell and lugs
	_brect(ci, -1.4, 3.9, 1.4, 6.6, F, STEEL, Pal.ink(0.6), 1.6)
	for yy: float in [4.3, 5.2, 6.1]:
		_bline(ci, -1.4, yy, -1.48, yy, F, Pal.ink(0.4), 2.0)
		_bline(ci, 1.4, yy, 1.48, yy, F, Pal.ink(0.4), 2.0)
	# laminated yokes either side: fine lines across each pack
	for s: float in [-1.0, 1.0]:
		var x0 := 1.17 * s
		var x1 := 1.37 * s
		_brect(ci, minf(x0, x1), 4.1, maxf(x0, x1), 6.4, F, Color(0.075, 0.078, 0.088), Pal.ink(0.35), 1.0)
		var lam := PackedVector2Array()
		var ly := 4.16
		while ly < 6.36:
			lam.append_array([body_pt(x0, ly, F), body_pt(x1, ly, F)])
			ly += 0.07
		ci.draw_multiline(lam, Pal.ink(0.13), 1.0)
	# the coil: hollow copper turns in section, water in their bores, a current wave along them
	var ph := t * TAU * 0.8
	for s: float in [-1.0, 1.0]:
		for i in 9:
			var cy := 4.25 + i * 0.235
			var c0 := Vector2(1.0 * s - 0.085, cy)
			var lit := 0.5 + 0.5 * sin(ph - i * 0.7)
			var cu := COPPER.lerp(Color(1.0, 0.62, 0.36), 0.25 * lit * clampf(power / P_RATED, 0.0, 1.0))
			_brect(ci, c0.x, c0.y, c0.x + 0.17, c0.y + 0.17, F, cu, Color(0.25, 0.14, 0.08), 1.0)
			_brect(ci, c0.x + 0.05, c0.y + 0.05, c0.x + 0.12, c0.y + 0.12, F, Pal.tint(Pal.AIR, 0.75, 0.5))
	# grout and insulation, then the working lining (stippled), the rim
	for s: float in [-1.0, 1.0]:
		_brect(ci, minf(0.84 * s, 0.9 * s), 4.0, maxf(0.84 * s, 0.9 * s), 6.4, F, GROUT)
	_brect(ci, -0.84, 3.95, 0.84, 6.25, F, MGO, Pal.ink(0.3), 1.0)
	var worn := clampf((131.0 - lining) / 70.0, 0.0, 1.0) * 0.06
	_brect(ci, -R_IN - worn, 4.0, R_IN + worn, 6.0 + worn * 0.5, F, Color(0.02, 0.018, 0.02))
	var st := PackedVector2Array()
	for i in (36 if zoom >= 0.4 else 0):
		var u := fposmod(sin(i * 3.7) * 9137.31, 1.0)
		var v := fposmod(sin(i * 9.1) * 4211.77, 1.0)
		var sx := -0.82 + u * 0.2 if i % 2 == 0 else 0.62 + u * 0.2
		st.append_array([body_pt(sx, 4.0 + v * 2.2, F), body_pt(sx + 0.02, 4.0 + v * 2.2 + 0.02, F)])
	if not st.is_empty():
		ci.draw_multiline(st, Color(0.3, 0.25, 0.2), 1.0)
	_brect(ci, -0.98, 3.86, 0.98, 3.96, F, STEEL_HI, Pal.ink(0.55), 1.2)
	for q in 3:
		var tcy := 4.5 + q * 0.7
		var bt := back_temp() + (q - 1) * 18.0
		ci.draw_circle(body_pt(-0.86, tcy, F), 2.6, glow_col(bt + 400.0, 0.9))
		ci.draw_circle(body_pt(0.86, tcy, F), 2.6, glow_col(bt + 400.0, 0.9))
	# the spout and the taphole's slide gate
	var sp := PackedVector2Array([body_pt(0.84, 3.88, F), body_pt(1.55, 3.7, F), body_pt(1.66, 3.8, F), body_pt(1.32, 4.02, F), body_pt(0.84, 4.05, F)])
	ci.draw_colored_polygon(sp, STEEL_HI)
	var spc := sp.duplicate()
	spc.append(sp[0])
	ci.draw_polyline(spc, Pal.ink(0.6), 1.2)
	_brect(ci, 1.0 + 0.16 * gate, 3.86, 1.2 + 0.16 * gate, 4.06, F, Color(0.12, 0.12, 0.13), Pal.ink(0.6), 1.0)
	# the melt: a layer held to the lining by the spin, thicker as it fills; stirred by the field
	var s_l := layer(m_l)
	var mc := glow_col(T)
	var h0 := 4.02
	var h1 := 5.98
	for s: float in [-1.0, 1.0]:
		var xa := (R_IN + worn) * s
		var xb := (R_IN + worn - s_l) * s
		var band := PackedVector2Array([body_pt(xa, h0, F), body_pt(xb, h0 + 0.05, F), body_pt(xb, h1 - 0.05, F), body_pt(xa, h1, F)])
		ci.draw_colored_polygon(band, mc)
		# the slag: lighter than steel, the spin floats it to the inner surface
		var sl_th := 0.025 + 0.02 * clampf(condensate / 300.0, 0.0, 1.0)
		var slag := PackedVector2Array()
		for i in 10:
			var yy := lerpf(h0 + 0.06, h1 - 0.06, i / 9.0)
			slag.append(body_pt(xb + 0.004 * sin(i * 2.7 + t), yy, F))
		for i in range(9, -1, -1):
			var yy2 := lerpf(h0 + 0.06, h1 - 0.06, i / 9.0)
			slag.append(body_pt(xb - (sl_th + 0.012 * sin(i * 1.9 + t * 0.7)) * s, yy2, F))
		ci.draw_colored_polygon(slag, Color(0.32, 0.12, 0.05))
		# the free surface ripples
		var rip := PackedVector2Array()
		for i in 12:
			var yy := lerpf(h0 + 0.05, h1 - 0.05, i / 11.0)
			rip.append(body_pt(xb + 0.012 * sin(t * 7.0 + i * 1.3) * s, yy, F))
		ci.draw_polyline(rip, glow_col(T + 80.0), 1.4)
		# induction stirring: tracers in two loops, one in each half of the coil
		for loop in 2:
			var yc := lerpf(h0, h1, 0.27 + 0.46 * loop)
			for j in 3:
				var a := t * (1.6 if loop == 0 else -1.6) + j * TAU / 3.0
				var px := (xa + xb) * 0.5 + cos(a) * s_l * 0.3 * s
				var py := yc + sin(a) * 0.38
				ci.draw_circle(body_pt(px, py, F), 1.6, glow_col(T + 150.0, 0.9))
		# solid charge not yet taken into the melt
		var nsol := int(ceilf(m_s / 0.15))
		for j in mini(nsol, 6):
			var sy := lerpf(h0 + 0.3, h1 - 0.3, fposmod(j * 0.37 + (0.5 if s > 0 else 0.0), 1.0))
			var cxs := xb - 0.06 * s
			var chunk := PackedVector2Array([body_pt(cxs - 0.07, sy - 0.05, F), body_pt(cxs + 0.06, sy - 0.07, F), body_pt(cxs + 0.07, sy + 0.05, F), body_pt(cxs - 0.05, sy + 0.07, F)])
			ci.draw_colored_polygon(chunk, glow_col(T - 700.0))
	# scrap from the feeder crossing the core to the wall
	if tilt <= 0.001:
		for b in bits:
			var u: float = b[0] / 0.9
			var tx: float = (R_IN - s_l) * float(b[1]) * Pal.ease_in(clampf((u - 0.35) / 0.65, 0.0, 1.0))
			var ty: float = lerpf(3.4, 4.05 + float(b[2]) * 1.8, Pal.ease_out(clampf(u / 0.6, 0.0, 1.0)))
			ci.draw_rect(Rect2(body_pt(tx, ty, F) - Vector2(2.5, 2.5), Vector2(5, 5)), glow_col(400.0 + 900.0 * u))
	# ground-leak probe in the bottom block, the spin drive under it
	_bline(ci, -0.6, 6.32, 0.6, 6.32, F, Pal.tint(Pal.VOLT, 0.6, 1.1), 1.0)
	_brect(ci, -0.1, 6.6, 0.1, 6.92, F, STEEL_HI, Pal.ink(0.5))
	for i in 3:
		var sx2 := 0.09 * sin(t * RPM * TAU / 60.0 + i * TAU / 3.0)
		_bline(ci, sx2, 6.62, sx2, 6.9, F, Pal.ink(0.35 + 0.3 * cos(t * RPM * TAU / 60.0 + i * TAU / 3.0)), 1.0)
	_brect(ci, -0.44, 6.92, 0.44, 7.36, F, Color(0.07, 0.073, 0.082), Pal.ink(0.5), 1.2)
	_bline(ci, -0.3, 7.14, 0.3, 7.14, F, Pal.ink(0.25), 1.0)
	# the tilt cylinder: barrel on the base frame, rod to the lug on the shell
	var anc := Vector2(X - 2.0, F + 7.55) * M
	var lug := body_pt(-1.4, 6.3, F)
	var dirc := (lug - anc).normalized()
	ci.draw_line(anc, anc + dirc * 1.15 * M, Color(0.1, 0.104, 0.115), 9.0)
	ci.draw_line(anc, anc + dirc * 1.15 * M, Pal.ink(0.45), 1.0)
	ci.draw_line(anc + dirc * 1.15 * M, lug, Pal.ink(0.7), 3.0)
	ci.draw_circle(anc, 4.0, Pal.ink(0.5))
	ci.draw_circle(lug, 3.5, Pal.ink(0.6))
	# the near trunnion pedestal, cut away: drawn as phantom lines over the section
	var pv := Vector2(X, F + PIV) * M
	var ph_c := Pal.ink(0.2)
	ci.draw_line(pv, Vector2(X - 1.0, F + 7.55) * M, ph_c, 1.0)
	ci.draw_line(pv, Vector2(X + 1.0, F + 7.55) * M, ph_c, 1.0)
	ci.draw_arc(pv, 0.22 * M, 0.0, TAU, 20, Pal.ink(0.55), 2.0)
	ci.draw_arc(pv, 0.1 * M, 0.0, TAU, 12, Pal.ink(0.35), 1.0)
	# ---- the stream into the mould at the fill station
	var tip := body_pt(1.6, 3.77, F)
	var land := Vector2(X + FILL_X, F + 5.83) * M
	if phase == "pour" and gate > 0.2:
		var wob := sin(t * 23.0) * 1.2
		ci.draw_line(tip, land + Vector2(wob, 0), glow_col(T, 0.95), 5.0 * gate)
		ci.draw_line(tip, land + Vector2(wob, 0), glow_col(T + 120.0), 2.0)
	# ---- the casting line: moulds on a chain, ingots cooling as they go
	var ry := F + 6.15
	ci.draw_line(Vector2(X + LINE_X0, ry) * M, Vector2(X + LINE_X1, ry) * M, Pal.ink(0.45), 2.0)
	ci.draw_line(Vector2(X + LINE_X0, ry + 0.22) * M, Vector2(X + LINE_X1, ry + 0.22) * M, Pal.ink(0.2), 1.0)
	for e: float in [LINE_X0, LINE_X1]:
		ci.draw_arc(Vector2(X + e, ry + 0.11) * M, 0.13 * M, 0.0, TAU, 14, Pal.ink(0.45), 1.2)
		var sa := -line_off / 0.13
		ci.draw_line(Vector2(X + e, ry + 0.11) * M, Vector2(X + e, ry + 0.11) * M + Vector2.from_angle(sa) * 0.13 * M, Pal.ink(0.4), 1.0)
	var mo := fposmod(line_off, PITCH)
	var mx2 := FILL_X - PITCH * 1.0 + mo
	while mx2 < LINE_X1 - 0.35:
		if mx2 > LINE_X0 + 0.3:
			ci.draw_rect(Rect2(Vector2(X + mx2 - 0.31, F + 5.79) * M, Vector2(0.62 * M, 0.34 * M)), COPPER.darkened(0.45))
			ci.draw_rect(Rect2(Vector2(X + mx2 - 0.31, F + 5.79) * M, Vector2(0.62 * M, 0.34 * M)), Color(0.4, 0.24, 0.14), false, 1.0)
			ci.draw_rect(Rect2(Vector2(X + mx2 - 0.24, F + 5.84) * M, Vector2(0.48 * M, 0.22 * M)), Color(0.02, 0.02, 0.022))
		mx2 += PITCH
	for ig in ingots:
		var ix: float = FILL_X + line_off - float(ig[0])
		if ix < LINE_X0 + 0.3:
			continue
		var it: float = ig[1]
		var hk := clampf(float(ig[2]) / INGOT, 0.3, 1.0)
		ci.draw_rect(Rect2(Vector2(X + ix - 0.24, F + 6.06 - 0.22 * hk) * M, Vector2(0.48 * M, 0.22 * hk * M)), glow_col(it) if it > 480.0 else Color(0.16, 0.16, 0.17))
	# the stream filling the mould right now
	if cast_t > 0.0:
		var hk2 := clampf(cast_t / INGOT, 0.0, 1.0)
		ci.draw_rect(Rect2(Vector2(X + FILL_X + line_off - line_goal - 0.24, F + 6.06 - 0.22 * hk2) * M, Vector2(0.48 * M, 0.22 * hk2 * M)), glow_col(T - 60.0))
	ci.draw_rect(Rect2(Vector2(X + LINE_X1 - 0.2, F + 5.55) * M, Vector2(0.6 * M, 0.9 * M)), Color(0.05, 0.053, 0.06))
	ci.draw_rect(Rect2(Vector2(X + LINE_X1 - 0.2, F + 5.55) * M, Vector2(0.6 * M, 0.9 * M)), Pal.ink(0.45), false, 1.2)
	# ---- part callouts (fade out as the camera pulls back)
	# left column (text ending at the column), right column (text starting at it)
	_callout(ci, font, body_pt(-0.72, 5.1, F), Vector2(X - 2.25, F + 5.9) * M, txt.call("fu_lining"), zoom, true)
	_callout(ci, font, body_pt(-1.0, 5.6, F), Vector2(X - 2.25, F + 6.35) * M, txt.call("fu_coil"), zoom, true)
	_callout(ci, font, anc + dirc * 0.6 * M, Vector2(X - 2.6, F + 6.85) * M, txt.call("fu_ram"), zoom, true)
	_callout(ci, font, pv + Vector2(-0.16, 0.16) * M, Vector2(X - 2.6, F + 7.35) * M, txt.call("fu_trunnion"), zoom, true)
	_callout(ci, font, body_pt(1.1, 3.95, F), Vector2(X + 2.7, F + 4.3) * M, txt.call("fu_spout"), zoom)
	_callout(ci, font, body_pt(0.5, 6.32, F), Vector2(X + 1.75, F + 6.9) * M, txt.call("fu_leak"), zoom)
	_callout(ci, font, body_pt(0.44, 7.14, F), Vector2(X + 1.75, F + 7.35) * M, txt.call("fu_drive"), zoom)
	_callout(ci, font, body_pt(1.27, 6.35, F), Vector2(X + 1.75, F + 8.2) * M, txt.call("fu_yoke"), zoom)
	_label(ci, font, Vector2(X + 6.2, F + 6.6) * M + Vector2(0, 12), txt.call("fu_mould"), zoom)
	_callout(ci, font, body_pt(0.86, 5.2, F), Vector2(X + 1.75, F + 4.95) * M, txt.call("fu_tc"), zoom)
	_callout(ci, font, body_pt(R_IN - layer(m_l) - 0.02, 4.4, F), Vector2(X + 1.75, F + 4.62) * M, txt.call("fu_slag"), zoom)
	# the casting line's stations: release-agent spray before the fill, laser marking on the way, the ingot lift at the end
	var sprx := X + LINE_X0 + 0.15
	ci.draw_rect(Rect2(Vector2(sprx - 0.1, F + 5.35) * M, Vector2(0.2, 0.18) * M), STEEL_HI)
	if absf(line_off - line_goal) > 0.05:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(sprx, F + 5.53) * M, Vector2(sprx - 0.18, F + 5.82) * M, Vector2(sprx + 0.18, F + 5.82) * M]), Pal.ink(0.12))
	_label(ci, font, Vector2(sprx - 0.1, F + 5.3) * M, txt.call("fu_spray"), zoom, true)
	var lmx := X + 6.0
	ci.draw_rect(Rect2(Vector2(lmx - 0.15, F + 5.2) * M, Vector2(0.3, 0.25) * M), STEEL_HI)
	ci.draw_rect(Rect2(Vector2(lmx - 0.15, F + 5.2) * M, Vector2(0.3, 0.25) * M), Pal.ink(0.5), false, 1.0)
	for ig in ingots:
		if absf(FILL_X + line_off - float(ig[0]) - 6.0) < 0.12 and absf(line_off - line_goal) < 0.05:
			ci.draw_line(Vector2(lmx, F + 5.45) * M, Vector2(lmx, F + 5.85) * M, Pal.tint(Pal.AIR, 0.9, 2.0), 1.4)
	_label(ci, font, Vector2(lmx + 0.2, F + 5.3) * M, txt.call("fu_mark"), zoom)
	# ---- the read-out plate
	if zoom >= 0.3:
		_panel(ci, F, font, font_b, txt)
	else:
		ci.draw_rect(Rect2(Vector2(X + 10.5, F + 0.85) * M, Vector2(6.9 * M, 3.3 * M)), Color(0.035, 0.037, 0.042, 0.96))


func _label(ci: CanvasItem, font: Font, at: Vector2, s: String, zoom: float, right: bool = false) -> void:
	var a := clampf((zoom - 0.8) / 0.3, 0.0, 1.0)
	if a <= 0.01:
		return
	var x := at.x
	if right:
		x -= font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	ci.draw_string(font, Vector2(x, at.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.5 * a))


func _callout(ci: CanvasItem, font: Font, from: Vector2, to: Vector2, s: String, zoom: float, left: bool = false) -> void:
	var a := clampf((zoom - 0.8) / 0.3, 0.0, 1.0)
	if a <= 0.01:
		return
	ci.draw_line(from, to, Pal.ink(0.22 * a), 1.0)
	ci.draw_circle(from, 1.8, Pal.ink(0.5 * a))
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var x0 := to.x - w - 6.0 if left else to.x
	ci.draw_line(Vector2(x0, to.y), Vector2(x0 + w + 6.0, to.y), Pal.ink(0.22 * a), 1.0)
	ci.draw_string(font, Vector2(x0 + 3.0, to.y - 3.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.6 * a))


# the plate beside the bunker: what the furnace is doing, in numbers
func _panel(ci: CanvasItem, F: float, font: Font, font_b: Font, txt: Callable) -> void:
	var r := Rect2(Vector2(X + 10.5, F + 0.85) * M, Vector2(6.9 * M, 3.3 * M))
	ci.draw_rect(r, Color(0.035, 0.037, 0.042, 0.96))
	ci.draw_rect(Rect2(r.position, Vector2(4, r.size.y)), Pal.heat(0.9, 1.1))
	ci.draw_rect(r, Pal.heat(0.3), false, 1.0)
	var x := r.position.x + 14.0
	var y := r.position.y + 20.0
	ci.draw_string(font_b, Vector2(x, y), txt.call("fu_title"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(0.92))
	var sk := state_key()
	var sc := Pal.heat(0.6 + 0.4 * sin(t * 8.0), 1.4) if phase in ["tilt", "pour", "back"] or flare_t > 0.3 else Pal.tint(Pal.FLUID, 0.9, 1.2)
	var sw := font_b.get_string_size(txt.call(sk), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	ci.draw_circle(Vector2(r.end.x - 16, y - 5), 4.0, sc)
	ci.draw_string(font_b, Vector2(r.end.x - 26 - sw, y), txt.call(sk), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, sc)
	var lines := [
		txt.call("fu_l1") % [power, int(P_RATED), int(freq()), int(round(skin_mm()))],
		txt.call("fu_l2") % [int(round(T)), int(T_LIQ), m_l + m_s, int(CAP)],
		txt.call("fu_l3") % [bunker, int(round(feed * 1000.0)), g_load(), int(RPM)],
		txt.call("fu_l4") % [int(FLOW), int(T_IN), int(round(water_out())), int(round(lining)), leak_ma],
		txt.call("fu_l5") % [_pa(pressure), condensate, heat_no, ingot_no],
		txt.call("fu_l6") % [chem.C, chem.Mn, chem.Si, chem.Cr, chem.Ni, chem.Cu, chem.S, chem.P],
		txt.call("fu_l7") % [int(round(tc_T)), int(tc_age), int(round(back_temp())), hpu_bar / 10.0],
	]
	if yard > 0.5:
		lines[2] += txt.call("fu_yard") % yard
	for i in lines.size():
		ci.draw_string(font, Vector2(x, y + 21.0 + i * 18.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24.0, 12, Pal.ink(0.66))


static func _pa(p: float) -> String:
	if p >= 100.0:
		return "%.1f k" % (p / 1000.0)
	if p >= 1.0:
		return "%.1f" % p
	return "%.3f" % p


# the light it gives off (added on top): the open crucible, the stream, the fresh ingots
func draw_add(ci: CanvasItem, F: float, tex: Texture2D) -> void:
	F += DY
	var c := body_pt(0.0, 5.0, F)
	var a := 0.04 + 0.05 * clampf(m_l / CAP, 0.0, 1.0) + 0.5 * flare_t
	ci.draw_texture_rect(tex, Rect2(c - Vector2(1.9, 1.9) * M, Vector2(3.8, 3.8) * M), false, glow_col(T, a))
	if hood > 0.05:
		# the open mouth of the crucible, uncovered
		var top := body_pt(0.0, 3.9, F)
		ci.draw_texture_rect(tex, Rect2(top - Vector2(1.4, 0.7) * M, Vector2(2.8, 1.4) * M), false, glow_col(T, 0.3 * hood))
	if phase == "pour" and gate > 0.2:
		var land := Vector2(X + FILL_X, F + 5.83) * M
		ci.draw_texture_rect(tex, Rect2(land - Vector2(1.0, 0.8) * M, Vector2(2.0, 1.6) * M), false, glow_col(T, 0.5 * gate))
	for ig in ingots:
		var it: float = ig[1]
		if it < 600.0:
			continue
		var ix: float = FILL_X + line_off - float(ig[0])
		if ix < LINE_X0 + 0.3:
			continue
		ci.draw_texture_rect(tex, Rect2(Vector2(X + ix - 0.6, F + 5.4) * M, Vector2(1.2, 1.0) * M), false, glow_col(it, 0.3 * clampf((it - 600.0) / 800.0, 0.0, 1.0)))
	if flare_t > 0.0:
		ci.draw_texture_rect(tex, Rect2(c - Vector2(3.0, 3.0) * M, Vector2(6.0, 6.0) * M), false, Pal.heat(0.6 * flare_t, 1.8))


# the plant from far away: its boxes, the furnace body with the melt's colour, the casting line
func _draw_far(ci: CanvasItem, F: float) -> void:
	var edge := Pal.ink(0.4)
	_rect(ci, -10.0, 1.8, -6.8, 3.8, F, STEEL, edge)
	_rect(ci, -11.4, 4.0, -7.6, 5.4, F, Color(0.03, 0.045, 0.055), edge)
	_rect(ci, -1.4, 1.0, 1.4, 2.85, F, STEEL, edge)
	_brect(ci, -1.4, 3.9, 1.4, 6.6, F, STEEL, edge)
	_brect(ci, -0.6, 4.0, 0.6, 6.0, F, glow_col(T, 0.9))
	_rect(ci, 2.6, 3.65, 4.4, 4.75, F, Color(0.03, 0.04, 0.05), edge)
	ci.draw_line(Vector2(X + LINE_X0, F + 6.15) * M, Vector2(X + LINE_X1, F + 6.15) * M, edge, 2.0)
	ci.draw_rect(Rect2(Vector2(X + 10.5, F + 0.85) * M, Vector2(6.9 * M, 3.3 * M)), Color(0.035, 0.037, 0.042, 0.96))


# °C at the lining's back face: what the thermocouples there read (it climbs as the lining wears)
func back_temp() -> float:
	return 180.0 + (T - 1400.0) * 0.55 + (131.0 - lining) * 2.2


# ---------------------------------------------------------------- the coil-water loop
# A shell-and-tube exchanger: the coil water (hot) runs the U-tubes, the station's
# thermal-control loop (cold) runs the shell side round the baffles; a centrifugal
# pump drives the coil loop and a bladder accumulator takes up the water's swell.
# The water moves: dashes run along every tube and snake round the baffles, the
# impeller and the flowmeter turn, the bladder breathes with the water's temperature.
func _hx(ci: CanvasItem, F: float, font: Font, zoom: float, txt: Callable) -> void:
	ci.draw_set_transform(Vector2(-3.0 * M, 0.0))
	var x0 := -8.4
	var x1 := -4.6
	var y0 := 4.0
	var y1 := 5.4
	var cy := (y0 + y1) * 0.5
	var w_out := water_out()
	var flow_k := clampf(power / P_RATED, 0.25, 1.0)
	# the shell, its heads, the tube sheet
	_rect(ci, x0, y0, x1, y1, F, Color(0.03, 0.045, 0.055), Pal.ink(0.55), 1.4)
	ci.draw_arc(Vector2(X + x1, F + cy) * M, (y1 - y0) * 0.5 * M, -PI * 0.5, PI * 0.5, 14, Pal.ink(0.55), 1.4)
	_rect(ci, x0 - 0.5, y0 + 0.05, x0, y1 - 0.05, F, Color(0.05, 0.053, 0.06), Pal.ink(0.5), 1.2)
	ci.draw_line(Vector2(X + x0 - 0.5, F + cy) * M, Vector2(X + x0, F + cy) * M, Pal.ink(0.5), 2.0)
	ci.draw_line(Vector2(X + x0, F + y0) * M, Vector2(X + x0, F + y1) * M, Pal.ink(0.7), 3.0)
	# baffles, alternately from the top and the bottom
	var bxs := [-7.6, -6.8, -6.0, -5.2]
	for i in bxs.size():
		var bx: float = bxs[i]
		if i % 2 == 0:
			ci.draw_line(Vector2(X + bx, F + y0) * M, Vector2(X + bx, F + y1 - 0.32) * M, Pal.ink(0.45), 2.0)
		else:
			ci.draw_line(Vector2(X + bx, F + y0 + 0.32) * M, Vector2(X + bx, F + y1) * M, Pal.ink(0.45), 2.0)
	# shell side: the station loop's water snaking over and under the baffles
	var path := PackedVector2Array([Vector2(x1 - 0.3, y1 - 0.15)])
	for i in range(bxs.size() - 1, -1, -1):
		var bx2: float = bxs[i]
		var gy := (y1 - 0.16) if i % 2 == 0 else (y0 + 0.16)
		path.append(Vector2(bx2 + 0.3, gy))
		path.append(Vector2(bx2 - 0.3, gy))
	path.append(Vector2(x0 + 0.3, y0 + 0.15))
	_flow(ci, path, F, Pal.tint(Pal.AIR, 0.7, 1.2), Pal.tint(Pal.AIR, 0.95, 1.6), 1.2 * flow_k, 0.7, zoom)
	# the U-tubes: coil water in hot along the top, back cooled along the bottom
	for r in 3:
		var ya := y0 + 0.2 + r * 0.16
		var yb := y1 - 0.2 - r * 0.16
		var xe := x1 - 0.25 - r * 0.12
		var tube := PackedVector2Array([Vector2(x0, ya), Vector2(xe, ya)])
		for q in 7:
			var a := -PI * 0.5 + PI * q / 6.0
			tube.append(Vector2(xe, (ya + yb) * 0.5) + Vector2(cos(a), sin(a)) * (yb - ya) * 0.5)
		tube.append(Vector2(x0, yb))
		var tw := PackedVector2Array()
		for p in tube:
			tw.append(Vector2(X + p.x, F + p.y) * M)
		ci.draw_polyline(tw, Color(0.25, 0.3, 0.32), 5.0)
		ci.draw_polyline(tw, Color(0.05, 0.12, 0.16), 3.0)
		var hot := Color(1.0, 0.6, 0.3).lerp(Color(0.5, 0.85, 1.0), 0.3)
		_flow(ci, tube, F, hot, Color(0.9, 0.95, 1.0, 1.0), 1.5 * flow_k, 0.45, zoom, Color(0.45, 0.8, 1.0))
	# nozzles and their thermometers
	_pipe(ci, [Vector2(-3.8, 5.56), Vector2(-3.8, y0 - 0.45), Vector2(x0 - 0.25, y0 - 0.45), Vector2(x0 - 0.25, y0 + 0.05)], F, Color(1.0, 0.62, 0.35), flow_k, zoom)
	_pipe(ci, [Vector2(x0 - 0.25, y1 - 0.05), Vector2(x0 - 0.25, y1 + 0.35), Vector2(-4.4, y1 + 0.35), Vector2(-4.4, 4.55)], F, Color(0.5, 0.85, 1.0), flow_k, zoom)
	_pipe(ci, [Vector2(-9.6, y1 + 0.75), Vector2(x1 - 0.3, y1 + 0.75), Vector2(x1 - 0.3, y1)], F, Pal.AIR, flow_k * 0.8, zoom)
	_pipe(ci, [Vector2(x0 + 0.3, y0), Vector2(x0 + 0.3, y0 - 0.9), Vector2(-9.6, y0 - 0.9)], F, Pal.AIR.lerp(Color(1, 0.7, 0.4), 0.35), flow_k * 0.8, zoom)
	var a2 := clampf((zoom - 0.8) / 0.3, 0.0, 1.0)
	if a2 > 0.01:
		ci.draw_string(font, Vector2(X + x0 - 0.2, F + y0 - 0.55) * M, "%d °C" % int(round(w_out)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.heat(0.85 * a2, 1.2))
		ci.draw_string(font, Vector2(X + x0 - 0.2, F + y1 + 0.62) * M, "%d °C" % int(T_IN), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.tint(Pal.AIR, 0.85 * a2, 1.2))
		ci.draw_string(font, Vector2(X - 9.6, F + y1 + 0.68) * M, txt.call("fu_loop_in"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.55 * a2))
		ci.draw_string(font, Vector2(X - 9.6, F + y0 - 0.97) * M, txt.call("fu_loop_out"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.55 * a2))
	# the coil-loop pump: a volute with its impeller turning, the motor behind it
	var pc := Vector2(X - 3.8, F + 5.9) * M
	var pr := 0.34 * M
	ci.draw_circle(pc, pr, Color(0.06, 0.07, 0.08))
	ci.draw_arc(pc, pr, 0.0, TAU, 24, Pal.ink(0.6), 1.6)
	ci.draw_circle(pc, pr * 0.78, Color(0.05, 0.12, 0.16))
	var ang := t * 9.0 * flow_k
	for v in 6:
		var va := ang + TAU * v / 6.0
		ci.draw_polyline(PackedVector2Array([pc + Vector2.from_angle(va) * pr * 0.15, pc + Vector2.from_angle(va + 0.35) * pr * 0.45, pc + Vector2.from_angle(va + 0.8) * pr * 0.72]), Pal.ink(0.7), 1.6)
	ci.draw_rect(Rect2(pc + Vector2(-pr - 0.55 * M, -0.22 * M), Vector2(0.5 * M, 0.44 * M)), Color(0.07, 0.073, 0.082))
	ci.draw_rect(Rect2(pc + Vector2(-pr - 0.55 * M, -0.22 * M), Vector2(0.5 * M, 0.44 * M)), Pal.ink(0.45), false, 1.0)
	_label(ci, font, pc + Vector2(-pr, pr + 14.0), txt.call("fu_pump") % int(FLOW), zoom)
	# the flowmeter on the cold leg: a turbine you can see turn
	var fm := Vector2(X - 4.4, F + 5.0) * M
	ci.draw_circle(fm, 0.13 * M, Color(0.05, 0.12, 0.16))
	ci.draw_arc(fm, 0.13 * M, 0.0, TAU, 14, Pal.ink(0.6), 1.2)
	for v in 3:
		ci.draw_line(fm, fm + Vector2.from_angle(t * 14.0 * flow_k + TAU * v / 3.0) * 0.11 * M, Pal.ink(0.7), 1.2)
	# the bladder accumulator: water below, nitrogen above, the bladder breathing with the water's swell
	var ax0 := X - 9.35
	var lvl := clampf(0.42 + (w_out - T_IN) / 120.0, 0.3, 0.75)
	var ar := Rect2(Vector2(ax0, F + 3.9) * M, Vector2(0.55, 1.6) * M)
	ci.draw_rect(ar, Color(0.05, 0.055, 0.065))
	var wy := ar.end.y - ar.size.y * lvl
	ci.draw_rect(Rect2(Vector2(ar.position.x, wy), Vector2(ar.size.x, ar.end.y - wy)), Color(0.15, 0.4, 0.55, 0.85))
	var bl := PackedVector2Array()
	for q in 9:
		var bx3 := ar.position.x + ar.size.x * q / 8.0
		bl.append(Vector2(bx3, wy + 2.5 * sin(t * 2.0 + q * 0.9)))
	ci.draw_polyline(bl, Pal.ink(0.7), 1.4)
	ci.draw_rect(ar, Pal.ink(0.55), false, 1.2)
	_label(ci, font, Vector2(ax0 - 0.1, F + 3.8) * M, txt.call("fu_accu"), zoom, true)
	_label(ci, font, Vector2(X + x0, F + y1 + 1.15) * M, txt.call("fu_hx"), zoom)
	ci.draw_set_transform(Vector2.ZERO)


# water moving along a path (m, from the axis): a tinted bore and bright dashes running with the flow
func _flow(ci: CanvasItem, path: PackedVector2Array, F: float, col: Color, hi: Color, speed: float, spacing: float, zoom: float, col_end: Color = Color(0, 0, 0, 0)) -> void:
	var pts := PackedVector2Array()
	for p in path:
		pts.append(Vector2(X + p.x, F + p.y) * M)
	if pts.size() < 2:
		return
	if col_end.a > 0.0:
		var cols := PackedColorArray()
		for i in pts.size():
			cols.append(col.lerp(col_end, float(i) / (pts.size() - 1)))
		ci.draw_polyline_colors(pts, cols, 2.0)
	else:
		ci.draw_polyline(pts, Color(col.r, col.g, col.b, 0.5), 2.0)
	if zoom < 0.35:
		return
	# dashes spaced along the path's length, moving with the water
	var L := 0.0
	var seg: Array = []
	for i in pts.size() - 1:
		var l := pts[i].distance_to(pts[i + 1])
		seg.append(l)
		L += l
	var gap := spacing * M
	var off := fposmod(t * speed * M, gap)
	var d := off
	var dash := PackedVector2Array()
	while d < L:
		var acc := 0.0
		for i in seg.size():
			if d <= acc + float(seg[i]):
				var u := (d - acc) / maxf(0.001, float(seg[i]))
				var p0 := pts[i].lerp(pts[i + 1], u)
				var dirv := (pts[i + 1] - pts[i]).normalized()
				dash.append_array([p0 - dirv * 3.0, p0 + dirv * 3.0])
				break
			acc += float(seg[i])
		d += gap
	if not dash.is_empty():
		ci.draw_multiline(dash, hi, 1.6)


func _pipe(ci: CanvasItem, path: Array, F: float, col: Color, flow_k: float, zoom: float) -> void:
	var pp := PackedVector2Array()
	for p in path:
		pp.append(p)
	var pts := PackedVector2Array()
	for p in pp:
		pts.append(Vector2(X + p.x, F + p.y) * M)
	ci.draw_polyline(pts, Color(0.22, 0.25, 0.27), 5.0)
	ci.draw_polyline(pts, Color(0.05, 0.1, 0.13), 3.0)
	_flow(ci, pp, F, col, Color(col.r, col.g, col.b, 0.95).lightened(0.4), 1.6 * flow_k, 0.55, zoom)


# ---------------------------------------------------------------- the metal-vapour condenser
# What boils off the melt in vacuum (zinc from galvanising, manganese, a little
# copper) is drawn off the hood into a cold trap: water-cooled plates where the
# vapour freezes straight out of the gas into a metal frost, thicker as the heats go
# by; the cooling water runs in the plates' channels.
func _condenser(ci: CanvasItem, F: float, hdx: float, font: Font, zoom: float, txt: Callable) -> void:
	var x0 := 2.6
	var x1 := 4.4
	var y0 := 3.65
	var y1 := 4.75
	# the bellows duct from the hood (it stretches when the hood slides aside)
	var a := Vector2(X + hdx + 1.5, F + 3.55) * M
	var b := Vector2(X + x0, F + y0 + 0.25) * M
	var n := 10
	var bel := PackedVector2Array()
	for i in n + 1:
		var u := float(i) / n
		bel.append(a.lerp(b, u) + Vector2(0, (4.0 if i % 2 == 0 else -4.0)))
	ci.draw_polyline(bel, Pal.ink(0.45), 6.0)
	ci.draw_polyline(bel, Color(0.06, 0.063, 0.07), 3.0)
	_rect(ci, x0, y0, x1, y1, F, Color(0.03, 0.04, 0.05), Pal.ink(0.55), 1.4)
	var frost := clampf(condensate / 600.0, 0.05, 1.0)
	for i in 5:
		var fx := x0 + 0.3 + i * 0.32
		# the cold plate with its water channel running
		ci.draw_rect(Rect2(Vector2(X + fx - 0.04, F + y0 + 0.1) * M, Vector2(0.08, y1 - y0 - 0.3) * M), Color(0.2, 0.24, 0.27))
		_flow(ci, PackedVector2Array([Vector2(fx, y1 - 0.2), Vector2(fx, y0 + 0.1)]), F, Color(0.4, 0.75, 1.0), Color(0.85, 0.95, 1.0), 1.0, 0.3, zoom)
		# metal frost on both faces of the plate
		var nf := int(4 + frost * 10)
		for q in nf:
			var fy := y0 + 0.15 + fposmod(q * 0.613 + i * 0.27, 1.0) * (y1 - y0 - 0.4)
			var side := -1.0 if q % 2 == 0 else 1.0
			ci.draw_circle(Vector2(X + fx + side * 0.06, F + fy) * M, 1.2 + frost * 1.4, Color(0.62, 0.64, 0.66, 0.9))
	# the vapour drifting in between the plates and freezing out
	for i in 9:
		var u := fposmod(t * 0.35 + i * 0.111, 1.0)
		var px := lerpf(x0 + 0.05, x1 - 0.15, u)
		var py := y0 + 0.3 + 0.55 * fposmod(i * 0.37, 1.0) + 0.06 * sin(t * 3.0 + i)
		ci.draw_circle(Vector2(X + px, F + py) * M, 3.0 + 3.0 * (1.0 - u), glow_col(1300.0 - 700.0 * u, (0.35 + 0.4 * vapor) * (1.0 - u)))
	# the collecting tray and its cake of condensate
	_rect(ci, x0 + 0.05, y1 - 0.12, x1 - 0.05, y1 - 0.02, F, Color(0.55, 0.57, 0.6, 0.35 + 0.5 * frost))
	_label(ci, font, Vector2(X + x0, F + y1 + 0.3) * M, txt.call("fu_trap"), zoom)


# ---------------------------------------------------------------- the tilt hydraulics
func _hpu(ci: CanvasItem, F: float, font: Font, zoom: float, txt: Callable) -> void:
	var r := Rect2(Vector2(X - 4.0, F + 6.95) * M, Vector2(1.2, 0.55) * M)
	ci.draw_rect(r, Color(0.06, 0.063, 0.072))
	ci.draw_rect(r, Pal.ink(0.5), false, 1.2)
	# the accumulator bottle (enough stored oil to tilt the furnace back with the power gone)
	var bc := Vector2(X - 3.2, F + 6.75) * M
	ci.draw_rect(Rect2(bc - Vector2(0.11, 0.0) * M, Vector2(0.22, 0.3) * M), Color(0.1, 0.104, 0.115))
	ci.draw_arc(bc, 0.11 * M, PI, TAU, 10, Pal.ink(0.55), 1.2)
	ci.draw_line(Vector2(X - 3.4, F + 7.5) * M, Vector2(X - 2.0, F + 7.55) * M, Pal.ink(0.35), 2.0)
	_label(ci, font, Vector2(X - 4.0, F + 7.75) * M, txt.call("fu_hpu") % (hpu_bar / 10.0), zoom)
