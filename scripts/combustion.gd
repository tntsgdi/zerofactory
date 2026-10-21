extends Node2D
# Fire, by its chemistry. What lies adrift (liquids.gd's globules, the vapour they boil
# off, the systems' propellant clouds) burns only where it has something to burn with:
#   air: a room still holding air (over AIR_KPA) and oxygen in it. The fire uses the
#     room's oxygen up (a closed room puts its own fire out) and its hot products
#     raise the room's pressure, enough to blow the doors out;
#   a hypergolic partner: monomethylhydrazine and nitrogen tetroxide light on contact,
#     no spark needed, in vacuum as well as in air (the reason a bipropellant ship
#     keeps its fuel and its oxidiser in separate tanks and lines).
# Fuel in vacuum with no oxidiser does not burn: it boils, part of it freezes, and it
# drifts off. Carried into a room with air, it is a fuel cloud again.
# What lights it: the laser beam, an electric arc and the sparks of a cut live cable,
# a short, a kerf still red-hot (and the metal round it), the drone's thruster plume,
# a blast, and the fire itself: a burning globule lights what lies within its flame
# a moment later (the flame front's speed), so a spill burns through from where it
# was lit.
# What burning does: each kilogram burnt gives its heat of combustion. Spread over a
# few hundred milliseconds in one place it is an explosion: its TNT equivalent sizes
# the blast (Hopkinson scaling, R ∝ W^⅓): equipment wrecked close in and dented
# further out, joints torn, loose pieces thrown, the drone burnt. In vacuum there is
# no air to carry a shock, only the expanding products: a much smaller yield. A
# globule burning on a piece of equipment scorches it.
# Nothing here is saved: what was adrift or alight is gone on a load.

const M := 48.0
const AIR_KPA := 15.0           # a room's pressure under which a flame can't keep going
const O2_KG := 0.0131           # kg of oxygen in one kPa·m³ of it (at 20 °C)
const REACH := 0.7              # m: how far past its own surface a flame lights the next
const SPEED_SPRAY := 6.0        # m/s: a flame front through drops
const SPEED_VAPOUR := 18.0      # m/s: through a vapour cloud
const NTO_PER_MMH := 2.5        # kg of N₂O₄ for a kilogram of MMH (stoichiometric)
const HC_HYPER := 2.1e7         # J per kg of MMH burnt with N₂O₄
const TNT := 4.6e6              # J per kg of TNT
const WINDOW := 0.2             # s of burning gathered into one blast

# per look: role, heat of combustion with oxygen (J/kg), oxygen it takes (kg/kg),
# liquid density (kg/m³), whether it burns in air, its hypergolic partner
const CHEM := {
	"fuel": {"role": "fuel", "hc": 4.3e7, "o2": 3.4, "rho": 800.0, "air": true},
	"mmh": {"role": "fuel", "hc": 2.8e7, "o2": 1.74, "rho": 880.0, "air": true, "hyper": "nto"},
	"lh2": {"role": "fuel", "hc": 1.2e8, "o2": 8.0, "rho": 71.0, "air": true},
	"lng": {"role": "fuel", "hc": 5.0e7, "o2": 4.0, "rho": 430.0, "air": true},
	"nto": {"role": "ox", "rho": 1440.0, "hyper": "mmh"},
}

var game
var world
var vapour: Array = []          # {pos, vel, kg, look, r (m), t, burn, ign}
var burning := 0                # units alight this step
var burnt_kg := 0.0             # fuel burnt all told (for the tests)
var blasts: Array = []          # [centre, yield kg TNT, room] of every blast (for the tests)
var _sparks: Array = []         # [pos, r m] lit this step
var _acc := {}                  # cell -> {e, sum (pos·e), t, room}: burning gathered into blasts
var _o2_frac := {}              # room -> its air's oxygen fraction (where the systems don't track it)
var _t := 0.0
var _said := {}
var _fine := 0.0
var _fine_t := -1.0
var _fine_at := Vector2.ZERO


func setup(g) -> void:
	game = g
	world = g.world
	z_index = 36
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m


static func is_fuel(look: String) -> bool:
	return CHEM.has(look) and CHEM[look].role == "fuel"


static func reacts(look: String) -> bool:
	return CHEM.has(look)


# ---------------------------------------------------------------- what others tell it

# something that can light a fuel: a spark, an arc, a blast (r: m round pos)
func spark(pos: Vector2, r: float = 0.5) -> void:
	_sparks.append([pos, r])


# vapour boiled off a globule (kg of it) joins the nearest cloud of its kind
func add_vapour(pos: Vector2, vel: Vector2, kg: float, look: String) -> void:
	if kg <= 0.0 or not reacts(look):
		return
	for v in vapour:
		if v.look == look and v.burn < 0.0 and v.pos.distance_to(pos) < maxf(1.2, float(v.r) * 0.6) * M:
			var tot: float = float(v.kg) + kg
			v.pos = (v.pos * float(v.kg) + pos * kg) / tot
			v.vel = (v.vel * float(v.kg) + vel * kg) / tot
			v.kg = tot
			return
	if vapour.size() >= 80:
		return
	vapour.append({"pos": pos, "vel": vel, "kg": kg, "look": look, "r": 0.4, "t": 0.0, "burn": -1.0, "ign": -1.0})


# the systems' propellant cloud met the beam (tools.gd): it burns if it has air
func ignite_cloud(cl: Dictionary, pos: Vector2) -> void:
	var look: String = str(cl.get("look", "fuel"))
	var rho: float = float(CHEM.get(look, CHEM.fuel).get("rho", 800.0))
	var u := {"pos": cl.pos, "vel": Vector2.ZERO, "kg": float(cl.amount) * rho, "look": look, "r": float(cl.r) / M, "t": 0.0, "burn": -1.0, "ign": -1.0}
	if _oxidiser(u) == "":
		return
	game.sys.clouds.erase(cl)
	vapour.append(u)
	_light(u, "beam")


# ---------------------------------------------------------------- oxygen

func _room_at(pos: Vector2) -> String:
	return world.room_at(pos)


func o2_avail(room: String) -> float:
	var s = game.sys
	if room == "" or not s.vols.has(room) or s.P(room) < AIR_KPA:
		return 0.0
	var n: float = s.vols[room].n
	if s.o2_on:
		return maxf(0.0, float(s.o2.get(room, 0.0))) * O2_KG
	return maxf(0.0, float(_o2_frac.get(room, 0.21)) * n) * O2_KG


func _use_o2(room: String, kg: float) -> void:
	var s = game.sys
	if s.o2_on:
		s.o2[room] = maxf(0.0, float(s.o2.get(room, 0.0)) - kg / O2_KG)
	else:
		var n: float = maxf(s.vols[room].n, 1e-6)
		_o2_frac[room] = maxf(0.0, float(_o2_frac.get(room, 0.21)) - kg / O2_KG / n)


# hot products let into a room's air (kPa·m³): its pressure up, its oxygen thinner
func _add_gas(room: String, dn: float) -> void:
	var s = game.sys
	var n: float = s.vols[room].n
	if not s.o2_on:
		_o2_frac[room] = float(_o2_frac.get(room, 0.21)) * n / maxf(n + dn, 1e-6)
	s.vols[room].n = n + dn


# what a unit can burn with where it is: "air", "hyper" (its partner beside it), or ""
func _oxidiser(u: Dictionary) -> String:
	var ch: Dictionary = CHEM.get(u.look, {})
	if ch.get("role", "") != "fuel":
		return ""
	if ch.has("hyper") and _partner_near(u, float(_r(u)) + REACH) != null:
		return "hyper"
	if bool(ch.get("air", false)) and o2_avail(_room_at(u.pos)) > 0.01:
		return "air"
	return ""


# ---------------------------------------------------------------- the units

func _units() -> Array:
	var out: Array = []
	if game.liquids != null:
		for b in game.liquids.blobs:
			if reacts(b.look):
				out.append(b)
	out.append_array(vapour)
	return out


static func _kg(u: Dictionary) -> float:
	if u.has("vol"):
		return float(u.vol) * float(CHEM[u.look].rho)
	return float(u.kg)


static func _take(u: Dictionary, kg: float) -> void:
	if u.has("vol"):
		u.vol = maxf(0.0, float(u.vol) - kg / float(CHEM[u.look].rho))
	else:
		u.kg = maxf(0.0, float(u.kg) - kg)


# its radius (m): a globule's, or a cloud's spread
func _r(u: Dictionary) -> float:
	if u.has("vol"):
		return game.liquids.radius_m(float(u.vol))
	return float(u.r)


var _grid := {}
const CELL := 2.0


func _build_grid(units: Array) -> void:
	_grid.clear()
	for u in units:
		var k := Vector2i(int(floor(u.pos.x / (CELL * M))), int(floor(u.pos.y / (CELL * M))))
		if not _grid.has(k):
			_grid[k] = []
		_grid[k].append(u)


func _near(pos: Vector2, r_m: float) -> Array:
	var out: Array = []
	var n := int(ceil(r_m / CELL))
	var k0 := Vector2i(int(floor(pos.x / (CELL * M))), int(floor(pos.y / (CELL * M))))
	for dx in range(-n, n + 1):
		for dy in range(-n, n + 1):
			out.append_array(_grid.get(k0 + Vector2i(dx, dy), []))
	return out


func _partner_near(u: Dictionary, reach_m: float):
	var want: String = str(CHEM.get(u.look, {}).get("hyper", ""))
	if want == "":
		return null
	for o in _near(u.pos, reach_m + 2.0):
		if o.look == want and _kg(o) > 0.0005 and o.pos.distance_to(u.pos) < (reach_m + _r(o)) * M:
			return o
	return null


# ---------------------------------------------------------------- each step

func _physics_process(dt: float) -> void:
	if game == null or game.sys == null or game.liquids == null:
		return
	_t += dt
	_vapour(dt)
	_flush_fine()
	var units := _units()
	if units.is_empty():
		_sparks.clear()
		_flush_blasts(true)
		queue_redraw()
		return
	_build_grid(units)
	var srcs := _sources()
	burning = 0
	for u in units:
		if not u.has("burn"):
			u["burn"] = -1.0
			u["ign"] = -1.0
		var lit: bool = float(u.burn) >= 0.0
		if not lit:
			if not is_fuel(u.look):
				continue
			# lit by the flame next to it, a moment ago
			if float(u.ign) >= 0.0 and _t >= float(u.ign):
				u.ign = -1.0
				if _oxidiser(u) != "":
					_light(u, "spread")
				continue
			var ox := ""
			# hypergolic: it lights the moment it meets its partner
			if CHEM[u.look].has("hyper") and _partner_near(u, _r(u) + 0.05) != null:
				_light(u, "hyper")
				continue
			for s in srcs:
				if _touches(u, s):
					if ox == "":
						ox = _oxidiser(u)
					if ox != "":
						_light(u, "spark")
					break
			continue
		_burn(u, dt)
	_sparks.clear()
	_flush_blasts(false)
	queue_redraw()


func _flush_fine() -> void:
	if _fine_t >= 0.0 and _t - _fine_t > 1.2:
		game.lose("loss_prop_blast", roundf(_fine / 10.0) * 10.0, _fine_at + Vector2(0, -60))
		_fine = 0.0
		_fine_t = -1.0


func _touches(u: Dictionary, s: Array) -> bool:
	var r: float = (_r(u) + float(s[1])) * M
	if s[0] is PackedVector2Array:
		var pl: PackedVector2Array = s[0]
		return pl.size() >= 2 and Geom.dist_to_polyline(u.pos, pl) < r
	return (s[0] as Vector2).distance_to(u.pos) < r


# every source of ignition this step: the sparks reported, the beam, the drone's
# plume, the kerfs still red-hot
func _sources() -> Array:
	var out: Array = _sparks.duplicate()
	var tl = game.tools
	if tl != null and tl.cutting:
		out.append([tl.front, 0.15])
	var dr = game.drone
	if dr != null and dr.alive:
		var dirs := [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
		for i in 4:
			var f: float = float(dr.flame[i])
			if f > 0.25:
				out.append([dr.global_position + dirs[i] * (0.45 + 0.35 * f) * M, 0.25 + 0.3 * f])
	var now := Time.get_ticks_msec() / 1000.0
	for id in world._hot:
		var p = world.pieces.get(id)
		if p == null or p.gone:
			continue
		for h in p.heat:
			# a kerf glows for a couple of seconds: hot enough to light kerosene (210 °C) and MMH (196 °C)
			if now - float(h[1]) < 2.2:
				out.append([world.frame(p) * (h[0] as PackedVector2Array), 0.12])
	return out


static var debug := false


func _light(u: Dictionary, how: String) -> void:
	if debug:
		print("LIGHT %s %s at %s room '%s' (%.0f kPa) how %s ox %s" % [u.look, "globule" if u.has("vol") else "vapour", u.pos / M, _room_at(u.pos), game.sys.P(_room_at(u.pos)), how, _oxidiser(u)])
	u.burn = 0.0
	u.ign = -1.0
	u["mode"] = "hyper" if how == "hyper" else _oxidiser(u)
	if u.mode == "":
		u.mode = "air"
	# a globule burns from its surface in a second or so (a big one longer); a cloud flashes through
	var kg := _kg(u)
	var t_burn: float = (0.5 + 4.0 * _r(u)) if u.has("vol") else 0.25 + float(u.r) * 0.05
	u["rate"] = kg / t_burn
	game.fx.flash(u.pos, clampf(30.0 + sqrt(kg) * 30.0, 30.0, 260.0), 0.25, Pal.heat(1.0, 2.6))
	if u.mode == "hyper":
		_say_once("hyper_ignite", u.pos)
	elif how == "spark" or how == "beam":
		_say_once("prop_fire", u.pos)
	if not _said.has("inc_fire_" + str(int(_t))):
		_said["inc_fire_" + str(int(_t))] = true
		game.incident("fire", u.look)


func _say_once(key: String, at: Vector2) -> void:
	if _t - float(_said.get(key, -99.0)) > 4.0:
		_said[key] = _t
		game.say(key, at)


func _burn(u: Dictionary, dt: float) -> void:
	u.burn = float(u.burn) + dt
	var want: float = minf(_kg(u), float(u.get("rate", 1.0)) * dt)
	var got := want
	var room := _room_at(u.pos)
	var hc: float = float(CHEM[u.look].get("hc", 4e7))
	if u.mode == "hyper":
		# the oxidiser beside it is used up with it
		var need: float = want * NTO_PER_MMH
		var have := 0.0
		for o in _near(u.pos, _r(u) + REACH + 2.0):
			if o.look != CHEM[u.look].hyper or o.pos.distance_to(u.pos) > (_r(u) + REACH + _r(o)) * M:
				continue
			var t: float = minf(_kg(o), need - have)
			_take(o, t)
			o["lit_t"] = _t
			have += t
			if have >= need:
				break
		got = have / NTO_PER_MMH
		hc = HC_HYPER
		if got < want * 0.05 and o2_avail(room) > 0.01:
			u.mode = "air"
	if u.mode == "air":
		var o2_need: float = want * float(CHEM[u.look].get("o2", 3.0))
		var o2_have: float = minf(o2_need, o2_avail(room))
		got = o2_have / float(CHEM[u.look].get("o2", 3.0))
		if room != "" and o2_have > 0.0:
			_use_o2(room, o2_have)
	if got <= 1e-6:
		# nothing left to burn with: the flame goes out (the fuel can be lit again)
		u.burn = -1.0
		if room != "":
			_say_once("fire_smothered", u.pos)
		return
	burning += 1
	_take(u, got)
	burnt_kg += got
	var e: float = got * hc
	# the room's air heated by it: its pressure rises, Δp = (γ − 1)·Q/V with half the heat
	# staying in the gas (kPa·m³ = 0.4 × 0.5 × J / 1000)
	if room != "" and game.sys.vols.has(room):
		_add_gas(room, 2.0e-4 * e)
	_gather(u.pos, e, room)
	# it scorches what it burns on, and lights what is beside it
	if u.has("stuck") and int(u.stuck) >= 0:
		var p = world.pieces.get(int(u.stuck))
		if p != null and not p.gone and p.cls == "equip" and p.intact:
			game._dent(p, maxf(0.0, p.cond - (0.12 + p.fragile * 0.3) * dt), "dv_fire")
	var reach: float = _r(u) + REACH
	var speed: float = SPEED_SPRAY if u.has("vol") else SPEED_VAPOUR
	for o in _near(u.pos, reach + 3.0):
		if o == u or float(o.get("burn", -1.0)) >= 0.0 or float(o.get("ign", -1.0)) >= 0.0 or not is_fuel(o.look):
			continue
		var d: float = o.pos.distance_to(u.pos) / M
		if d < reach + _r(o):
			o["ign"] = _t + maxf(0.0, d - _r(u)) / speed
	var dr = game.drone
	if dr != null and dr.alive and dr.global_position.distance_to(u.pos) < (_r(u) * 2.2 + 0.5) * M:
		game.hurt_drone(clampf(sqrt(got / dt) * 6.0, 3.0, 30.0), u.pos, "fire_hit", "prop_fire", 0.4)
	if randf() < dt * 8.0:
		game.fx.puff(u.pos, Vector2.from_angle(randf() * TAU) * 40.0, randf_range(0.6, 1.2), 6.0, 20.0 + _r(u) * 90.0, Pal.heat(0.18, 1.4))
	if _kg(u) <= 0.0005:
		u.burn = -1.0
		if not u.has("vol"):
			u.kg = 0.0


# ---------------------------------------------------------------- blasts

func _gather(pos: Vector2, e: float, room: String) -> void:
	var k := Vector2i(int(floor(pos.x / (4.0 * M))), int(floor(pos.y / (4.0 * M))))
	if not _acc.has(k):
		_acc[k] = {"e": 0.0, "sum": Vector2.ZERO, "t": _t, "room": room}
	var a: Dictionary = _acc[k]
	a.e = float(a.e) + e
	a.sum = a.sum + pos * e


func _flush_blasts(all: bool) -> void:
	for k in _acc.keys():
		var a: Dictionary = _acc[k]
		if not all and _t - float(a.t) < WINDOW:
			continue
		_acc.erase(k)
		if float(a.e) > 0.0:
			_blast(a.sum / float(a.e), float(a.e), str(a.room))


# energy e (J) let go at c within a fraction of a second
func _blast(c: Vector2, e: float, room: String) -> void:
	# how much of it goes into a blast: a deflagration in air, or in vacuum only the products' expansion
	var eff: float = 0.12 if room != "" else 0.04
	var w: float = e * eff / TNT
	var s: float = pow(maxf(w, 1e-6), 1.0 / 3.0)
	var fire_r: float = clampf(0.6 + s * 2.2, 0.6, 30.0)
	game.fx.flash(c, fire_r * M, 0.45, Pal.heat(1.0, 2.8))
	if w < 0.05:
		# a flare, not a bang
		return
	var r_heavy: float = minf(2.5 * s, 40.0)
	var r_light: float = minf(7.0 * s, 70.0)
	blasts.append([c, w, room])
	game.incident("prop_blast", "%.1f kg TNT" % w)
	game.fx.ring(c, 10.0, r_light * M * 0.5, 0.6, Pal.heat(0.9, 2.2), 3.0)
	game.fx.burst_shards(c, clampi(int(8.0 + s * 10.0), 8, 40), 300.0 + s * 160.0, Pal.heat(0.9, 1.6), 10.0)
	game.fx.sparks(c, Vector2.UP, clampi(int(20.0 + s * 20.0), 20, 80), Pal.heat(1.0, 2.4), 420.0 + s * 100.0, 0.6, PI)
	for i in clampi(int(10.0 + s * 8.0), 10, 50):
		var d := Vector2.from_angle(randf() * TAU)
		game.fx.puff(c + d * randf() * fire_r * M * 0.5, d * randf_range(60, 260) * (1.0 + s * 0.3), randf_range(0.6, 1.4), 10.0, 40.0 + fire_r * 20.0, Pal.heat(0.22, 1.6))
	game.shake(clampf(0.3 + s * 0.25, 0.3, 1.2))
	game.hud.white_flash(clampf(0.15 + s * 0.08, 0.15, 0.6))
	game.hitstop(clampf(0.04 + s * 0.02, 0.04, 0.12))
	game.sfx.play("boom")
	_say_once("prop_blast", c + Vector2(0, -60))
	spark(c, r_light)
	# equipment: wrecked close in, dented further out
	var lost := 0.0
	for q in game._equip_near(c, r_light * M):
		var d: float = (world.frame(q) * Geom.centroid(q.poly)).distance_to(c) / M
		var k: float = 1.0 if d < r_heavy else clampf((r_light - d) / maxf(0.1, r_light - r_heavy), 0.0, 1.0)
		var before: float = q.cond
		game._dent(q, maxf(0.0, q.cond * (1.0 - 0.92 * k) - q.fragile * 0.1 * k), "dv_blast")
		lost += (before - q.cond) * q.value
	# fixings torn close in: what they held is thrown loose
	var torn := 0
	for j in world.joints:
		if not j.alive or j.type in ["clamp"] or torn >= 60:
			continue
		var jp: Vector2 = world.joint_world(j)
		var d2: float = jp.distance_to(c) / M
		if d2 < r_heavy * 0.7 and randf() < 1.0 - d2 / (r_heavy * 0.7):
			world.kill_joint(j)
			torn += 1
	for b in world.bodies:
		if not is_instance_valid(b):
			continue
		var d3: Vector2 = b.global_position - c
		var dm: float = d3.length() / M
		if dm < r_light:
			b.apply_central_impulse(d3.normalized() * b.mass * (120.0 + 260.0 * s) * (1.0 - dm / r_light))
	var dr = game.drone
	if dr != null and dr.alive:
		var dd: float = dr.global_position.distance_to(c) / M
		if dd < r_light:
			game.hurt_drone(clampf(140.0 * (1.0 - dd / r_light), 5.0, 140.0), c, "fire_hit", "prop_blast", 0.3)
			dr.linear_velocity += (dr.global_position - c).normalized() * (300.0 + s * 120.0) * (1.0 - dd / r_light)
	# one fine for a burst of blasts, not one each
	_fine += 1500.0 * clampf(s, 0.5, 8.0)
	if _fine_t < 0.0:
		_fine_t = _t
		_fine_at = c
	if lost > 50.0:
		game.fx.number(c + Vector2(0, -100), "−" + Pal.money(lost).trim_prefix("$"), Pal.heat(0.9, 1.3), 22)
	# a room's pressure past what its doors hold: they go
	if room != "" and game.sys.P(room) > 250.0:
		_blow_doors(room, c)
	world.redraw_all()


func _blow_doors(room: String, c: Vector2) -> void:
	var r = world.rooms.get(room)
	if r == null:
		return
	var box: Rect2 = r.bbox.grow(0.6 * M)
	var n := 0
	for id in world.order:
		var p = world.pieces[id]
		if p.gone or not p.door or p.body != null:
			continue
		if not box.intersects(Geom.bbox(world.world_poly(p))):
			continue
		for j in world.joints_of(p):
			world.kill_joint(j)
		n += 1
	if n > 0:
		game.incident("doors_blown", room)
		_say_once("doors_blown", c)
		game.sys.topology_dirty = true


# ---------------------------------------------------------------- vapour

func _vapour(dt: float) -> void:
	var s = game.sys
	for v in vapour:
		v.t = float(v.t) + dt
		var room := _room_at(v.pos)
		var air: bool = room != "" and s.P(room) > 5.0
		if air:
			# in air it lingers and spreads slowly
			v.r = minf(2.6, float(v.r) + 0.25 * dt)
			v.kg = float(v.kg) * (1.0 - 0.01 * dt)
			v.vel = v.vel.move_toward(Vector2.ZERO, 2.0 * M * dt)
		else:
			# in vacuum it expands at once and is too thin to matter within seconds
			v.r = minf(6.0, float(v.r) + 3.0 * dt)
			v.kg = float(v.kg) * exp(-dt / 2.5)
		var np: Vector2 = v.pos + v.vel * dt
		if _room_at(np) != room:
			v.vel = Vector2.ZERO
		else:
			v.pos = np
	vapour = vapour.filter(func(v): return float(v.kg) > 0.002)
	# the systems' propellant clouds: thinned out in vacuum at once, as above
	for cl in s.clouds:
		var room2 := _room_at(cl.pos)
		if room2 == "" or s.P(room2) < 5.0:
			cl.amount = float(cl.amount) * exp(-dt / 2.5)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var tex: Texture2D = game.fx.glow_tex if game != null and game.fx != null else null
	for v in vapour:
		var a: float = clampf(float(v.kg) * 0.15, 0.0, 0.18)
		if a < 0.01 or tex == null:
			continue
		var r: float = float(v.r) * M
		var col: Color
		match str(v.look):
			# nitrogen dioxide: red-brown
			"nto": col = Color(0.62, 0.3, 0.12, a)
			_: col = Pal.ink(a * 0.5)
		if float(v.burn) >= 0.0:
			col = Pal.heat(clampf(a * 4.0, 0.2, 0.9), 2.2)
		draw_texture_rect(tex, Rect2(v.pos - Vector2(r, r), Vector2(r, r) * 2.0), false, col)
	if game == null or game.liquids == null:
		return
	for b in game.liquids.blobs:
		if not reacts(b.look):
			continue
		var lit: bool = float(b.get("burn", -1.0)) >= 0.0
		var ox_lit: bool = _t - float(b.get("lit_t", -99.0)) < 0.15
		if not lit and not ox_lit:
			continue
		_flame(b.pos, game.liquids.radius_m(float(b.vol)) * M, b.get("nrm", Vector2.ZERO), float(b.ph), tex)


# a flame over a burning globule: a flickering tongue (up the surface's normal if it
# lies on one, all round if adrift: no buoyancy in free fall makes a flame round)
func _flame(c: Vector2, r: float, nrm: Vector2, ph: float, tex: Texture2D) -> void:
	var rf: float = maxf(6.0, r * 2.4)
	if tex != null:
		draw_texture_rect(tex, Rect2(c - Vector2(rf, rf) * 1.6, Vector2(rf, rf) * 3.2), false, Pal.heat(0.55, 2.2))
	var pts := PackedVector2Array()
	var n := 14
	for k in n:
		var a: float = k * TAU / n
		var d := Vector2.from_angle(a)
		var fl: float = 0.75 + 0.35 * sin(a * 3.0 + _t * 17.0 + ph) + 0.2 * sin(a * 5.0 - _t * 23.0)
		if nrm != Vector2.ZERO:
			fl *= 0.6 + 0.8 * maxf(0.0, d.dot(nrm))
		pts.append(c + d * rf * fl)
	if not Geometry2D.triangulate_polygon(pts).is_empty():
		draw_colored_polygon(pts, Pal.heat(0.35, 2.0))
	draw_circle(c, maxf(2.0, r * 0.9), Pal.heat(0.6, 2.6))
