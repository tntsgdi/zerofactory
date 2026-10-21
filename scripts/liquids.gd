extends Node2D
# Liquid let loose in free fall: what comes out of a cut line or a broken tank is not
# a number going down but globules of liquid, drifting. Each globule keeps its momentum
# (no gravity in the berth; air drag only where a room still holds air), trembles
# under its surface tension (small ones round and still, big ones slow and wobbling),
# merges with any it touches, splashes apart or wets the surface it meets, and is lost
# the way its liquid is lost:
#   cryogenic (liquid hydrogen, helium, LNG, nitrogen): flash-boils as it comes out,
#     the rest shrinking fast in a trail of vapour, frosting what it touches (helium
#     fastest, then hydrogen, then LNG);
#   water: evaporates slowly in air; in vacuum it freezes over into a ball of ice and
#     slowly sublimes;
#   fuel: oily, slow to evaporate (its vapour still feeds the systems' fuel clouds);
#   MMH and N₂O₄ (a bipropellant's fuel and oxidiser): the hydrazine clear and slow to
#     boil, the tetroxide orange-brown and boiling hard in vacuum (its vapour pressure
#     is near an atmosphere) until it freezes over; the two light on contact;
#   what burns, and when, is combustion.gd's: the vapour a burnable globule boils off
#     is handed to it;
#   glycol coolant: like water, but never freezes and barely evaporates;
#   drilling mud: thick, never splashes, sticks wherever it lands.
# What a globule does to what it touches (none for the "quiet" ones a module spilt and
# already charged for): powered electrics short (a little), cryogens frost and crack,
# the drone gets wet or frosted.
# The globules are not saved: on a load the liquid that was adrift is gone.
#
# Where a liquid's look comes from: its volume's "look" in the ship file ("lh2", "lhe",
# "lng", "ln2", "water", "fuel", "glycol", "mud"), else its fluid kind.

const MAX_BLOBS := 320
const MAX_VOL := 0.035          # m³ in one globule from a leak
const RHO_GAP := 0.6            # how close two globules come before they merge (of r1 + r2)

# per look: boil fraction/s in vacuum and in air, flash fraction lost on the way out,
# density (kg/m³, for the air drag), splash speed (m/s) above which it breaks up,
# whether it freezes (s in vacuum before it does), its vapour pressure at the berth's
# temperature (kPa: what pushes it out of a holed tank with no gas over it)
const LOOKS := {
	"lhe": {"boil_v": 0.30, "boil_a": 0.45, "flash": 0.45, "rho": 125.0, "splash": 1.5, "cryo": true, "pvap": 130.0},
	"lh2": {"boil_v": 0.12, "boil_a": 0.22, "flash": 0.25, "rho": 71.0, "splash": 1.8, "cryo": true, "pvap": 130.0},
	"lng": {"boil_v": 0.05, "boil_a": 0.09, "flash": 0.12, "rho": 430.0, "splash": 2.0, "cryo": true, "pvap": 120.0},
	"ln2": {"boil_v": 0.07, "boil_a": 0.12, "flash": 0.15, "rho": 810.0, "splash": 2.0, "cryo": true, "pvap": 120.0},
	"water": {"boil_v": 0.004, "boil_a": 0.0015, "flash": 0.0, "rho": 1000.0, "splash": 2.4, "freeze": 6.0, "pvap": 2.3},
	"fuel": {"boil_v": 0.006, "boil_a": 0.003, "flash": 0.0, "rho": 800.0, "splash": 2.8, "pvap": 0.7},
	"mmh": {"boil_v": 0.02, "boil_a": 0.004, "flash": 0.02, "rho": 880.0, "splash": 2.8, "freeze": 14.0, "pvap": 5.0},
	"nto": {"boil_v": 0.12, "boil_a": 0.03, "flash": 0.15, "rho": 1440.0, "splash": 2.6, "freeze": 4.0, "pvap": 96.0},
	"glycol": {"boil_v": 0.001, "boil_a": 0.0005, "flash": 0.0, "rho": 1110.0, "splash": 2.6, "pvap": 0.01},
	"oil": {"boil_v": 0.0002, "boil_a": 0.0, "flash": 0.0, "rho": 870.0, "splash": 3.2, "pvap": 0.01},
	"foam": {"boil_v": 0.004, "boil_a": 0.0015, "flash": 0.0, "rho": 1020.0, "splash": 2.2, "freeze": 8.0, "pvap": 2.3},
	"mud": {"boil_v": 0.0, "boil_a": 0.0, "flash": 0.0, "rho": 1800.0, "splash": 99.0, "sticky": true, "pvap": 0.0},
}
const CRYO := ["lhe", "lh2", "lng", "ln2"]

var game
var world
var blobs: Array = []           # {pos, vel, vol, look, t, ph, stuck, loc, nrm, ice, quiet, frozen_t}
var frost: Array = []           # [world pos, t, size]
var _new: Array = []            # globules made this step, joined at its end
var jets: Array = []            # [from, dir, flow, look] of the leaks running this step
var _t := 0.0
var _space = null
var spilt_total := 0.0          # m³ that ever came out as globules (for the tests)


func setup(g) -> void:
	game = g
	world = g.world
	z_index = 35


static func look_of(v: Dictionary) -> String:
	if v.has("look"):
		return str(v.look)
	match str(v.get("fluid", "")):
		"fuel": return "fuel"
		"lng": return "lng"
		"n2": return "ln2"
		"coolant": return "glycol"
		_: return "water"


static func radius_m(vol: float) -> float:
	return pow(maxf(vol, 1e-7) * 0.75 / PI, 1.0 / 3.0)


# a module's spill (a burst ball, a mud blowout, a tank failing): `n` globules
# sharing `vol` m³, flung out from `at` round `dir` within `spread` radians at
# `speed` m/s (±40 %)
func spill(at: Vector2, dir: Vector2, vol: float, look: String, n: int = 12, spread: float = PI, speed: float = 1.0, quiet: bool = true) -> void:
	if vol <= 0.0 or n <= 0:
		return
	var weights: Array = []
	var tot := 0.0
	for i in n:
		# a few big ones and many small: the way a broken mass of liquid comes apart
		var wgt: float = pow(randf_range(0.15, 1.0), 2.2)
		weights.append(wgt)
		tot += wgt
	for i in n:
		var v: float = vol * float(weights[i]) / tot
		var d: Vector2 = dir.normalized().rotated(randf_range(-spread * 0.5, spread * 0.5)) if dir != Vector2.ZERO else Vector2.from_angle(randf() * TAU)
		var off: Vector2 = Vector2.ZERO if n == 1 else d * randf_range(0.2, 1.0) * maxf(0.3, radius_m(vol) * 1.2) * Geom.M
		_add(at + off, d * speed * randf_range(0.6, 1.4) * Geom.M, v, look, quiet)
	_flush()


func _flush() -> void:
	for nb in _new:
		if blobs.size() >= MAX_BLOBS:
			# the smallest goes (it would have boiled off or merged by now)
			var k := 0
			for i in blobs.size():
				if float(blobs[i].vol) < float(blobs[k].vol):
					k = i
			blobs.remove_at(k)
		blobs.append(nb)
	_new.clear()


func _add(pos: Vector2, vel: Vector2, vol: float, look: String, quiet: bool) -> void:
	var lk: Dictionary = LOOKS.get(look, LOOKS.water)
	var v := vol
	if float(lk.get("flash", 0.0)) > 0.0:
		# part of a cryogen flashes to vapour the moment it is out
		v *= 1.0 - float(lk.flash)
		game.fx.puff(pos, vel * 0.6, randf_range(0.8, 1.6), 6.0, 26.0 + 300.0 * vol, Pal.ink(0.07))
	_new.append({"pos": pos, "vel": vel, "vol": v, "look": look, "t": 0.0, "ph": randf() * TAU, "stuck": -1, "loc": Vector2.ZERO,
		"nrm": Vector2.ZERO, "ice": false, "quiet": quiet, "vac_t": 0.0, "wet": {}})
	spilt_total += v


func total_volume(look: String = "") -> float:
	var s := 0.0
	for b in blobs:
		if look == "" or b.look == look:
			s += float(b.vol)
	return s


func count(look: String = "") -> int:
	return blobs.filter(func(b): return look == "" or b.look == look).size()


func _physics_process(dt: float) -> void:
	if game == null or game.sys == null:
		return
	_t += dt
	if _space == null:
		_space = get_world_2d().direct_space_state
	_flush()
	_leaks(dt)
	_move(dt)
	_flush()
	if Engine.get_physics_frames() % 2 == 0:
		_merge()
	for f in frost:
		f[1] = float(f[1]) + dt
	frost = frost.filter(func(f): return float(f[1]) < 24.0)
	queue_redraw()


# the systems' open leaks: what they drain comes out here as globules along the jet
func _leaks(dt: float) -> void:
	var s = game.sys
	jets.clear()
	for lk in s.leaks:
		var v = s.fvol.get(lk.src)
		if v == null:
			continue
		var flow: float = float(lk.get("rate", 0.0))
		if flow <= 0.0:
			continue
		var acc: float = float(lk.get("_liq", 0.0)) + flow * dt
		var look := look_of(v)
		var at: Vector2 = game.leak_pos(lk)
		var dir: Vector2 = lk.dir if lk.dir != Vector2.ZERO else Vector2.UP
		var severed: bool = lk.get("severed", false)
		if not severed:
			jets.append([at, dir, flow, look])
		# a jet: a stream of globules every few frames, sized by the flow (a tank cut open
		# lets its liquid go in big masses, all round the opening)
		var each: float = clampf(flow * (0.12 if flow < 0.3 else 0.06), 0.0004, MAX_VOL if flow < 0.3 else 0.09)
		var n := 0
		var spread: float = 1.6 if severed else 0.35
		# the jet's speed: from the pressure behind the hole (systems.gd), or a seep
		var sp: float = clampf(float(lk.v), 1.0, 18.0) if lk.has("v") else clampf(1.5 + flow * 30.0, 1.5, 6.0)
		while acc >= each and n < 6:
			acc -= each
			n += 1
			_add(at + dir * 0.2 * Geom.M, dir.rotated(randf_range(-spread, spread)) * sp * randf_range(0.7, 1.2) * Geom.M, each, look, false)
		lk["_liq"] = minf(acc, each * 6.0)


var _bounds := Rect2()
var _bounds_t := -99.0


# the ship's extent (and the berth floor's), grown a little: no surface to meet outside it
func _near_ship(pos: Vector2) -> bool:
	if _t - _bounds_t > 2.0:
		_bounds_t = _t
		var r := Rect2()
		var first := true
		for id in world.order:
			var p = world.pieces[id]
			if p.gone or p.body != null:
				continue
			var bb := Geom.bbox(world.world_poly(p))
			r = bb if first else r.merge(bb)
			first = false
		r = r.merge(Rect2(Vector2(-10.0, 8.0) * Geom.M, Vector2(Dock.FLOOR_X1 + 20.0, 4.0) * Geom.M))
		_bounds = r.grow(2.0 * Geom.M)
	return _bounds.has_point(pos)


func _room_kpa(pos: Vector2) -> float:
	var r: String = world.room_at(pos)
	return game.sys.P(r) if r != "" else 0.0


func _move(dt: float) -> void:
	var dead: Array = []
	for b in blobs:
		b.t = float(b.t) + dt
		var lk: Dictionary = LOOKS.get(b.look, LOOKS.water)
		var near: bool = _near_ship(b.pos)
		var kpa: float = _room_kpa(b.pos) if near else 0.0
		var air: bool = kpa > 5.0
		var v0: float = float(b.vol)
		# evaporation / boiling, freezing
		if bool(lk.get("cryo", false)):
			var boil: float = float(lk.boil_a if air else lk.boil_v)
			var lost: float = float(b.vol) * boil * dt
			b.vol = float(b.vol) - lost
			if randf() < dt * 6.0:
				game.fx.puff(b.pos, -b.vel * 0.2 + Vector2.from_angle(randf() * TAU) * 20.0, 0.9, 3.0, 8.0 + radius_m(b.vol) * 120.0, Pal.ink(0.06))
		elif b.ice:
			b.vol = float(b.vol) * (1.0 - 0.002 * dt)
		else:
			b.vol = float(b.vol) * (1.0 - float(lk.boil_a if air else lk.boil_v) * dt)
			if lk.has("freeze") and not air:
				b.vac_t = float(b.vac_t) + dt
				if float(b.vac_t) > float(lk.freeze):
					b.ice = true
		if float(b.vol) < 0.00008:
			dead.append(b)
			continue
		# what a burnable one boiled off is vapour, handed on in lumps
		if game.combustion != null and game.combustion.reacts(b.look):
			var vap: float = float(b.get("vap", 0.0)) + (v0 - float(b.vol)) * float(lk.get("rho", 1000.0))
			if vap > 0.05 or (vap > 0.0 and fmod(float(b.t), 0.3) < dt):
				game.combustion.add_vapour(b.pos, b.vel * 0.2, vap, b.look)
				vap = 0.0
			b["vap"] = vap
		if int(b.stuck) >= 0:
			var sp = world.pieces.get(int(b.stuck))
			if sp == null or sp.gone:
				b.stuck = -1
			else:
				b.pos = world.frame(sp) * b.loc
				_touch(b, sp)
				continue
		# air drag, quadratic: a = 3/8 · Cd · (ρ air / ρ liquid) · v² / r. Water barely
		# feels it; a small drop of liquid hydrogen (14 times lighter) is slowed; none in vacuum
		if air:
			var r: float = radius_m(b.vol)
			var v_ms: float = b.vel.length() / Geom.M
			var dec: float = 0.375 * 0.47 * (1.2 * kpa / 101.0) / float(lk.get("rho", 1000.0)) * v_ms * v_ms / maxf(r, 0.005)
			b.vel = b.vel.move_toward(Vector2.ZERO, dec * Geom.M * dt)
		var step: Vector2 = b.vel * dt
		if near and step.length() > 0.01:
			var q := PhysicsRayQueryParameters2D.create(b.pos, b.pos + step + step.normalized() * radius_m(b.vol) * Geom.M, World.STATIC_LAYER)
			var hit: Dictionary = _space.intersect_ray(q)
			if not hit.is_empty():
				_hit(b, hit, lk)
				continue
		b.pos = b.pos + step
		# the drone flying through it
		var dr = game.drone
		if dr != null and dr.alive and not b.quiet and dr.global_position.distance_to(b.pos) < radius_m(b.vol) * Geom.M + 18.0:
			_drone_wet(b, lk)
	for b in dead:
		blobs.erase(b)
	blobs = blobs.filter(func(b): return float(b.vol) > 0.0)


# meeting a surface: fast enough, it splashes apart; else it wets the surface and stays
func _hit(b: Dictionary, hit: Dictionary, lk: Dictionary) -> void:
	var nrm: Vector2 = hit.normal
	var vn: float = absf(b.vel.dot(nrm)) / Geom.M
	if vn > float(lk.get("splash", 2.4)) and float(b.vol) > 0.0006 and not b.ice:
		var parts := mini(4, 2 + int(vn))
		var refl: Vector2 = b.vel.bounce(nrm) * 0.45
		var v0: float = float(b.vol)
		b.vol = 0.0
		for i in parts:
			_add(hit.position + nrm * 3.0, refl.rotated(randf_range(-0.9, 0.9)) * randf_range(0.5, 1.1), v0 / parts, b.look, b.quiet)
		return
	if b.ice:
		b.vel = b.vel.bounce(nrm) * 0.5
		return
	var p = world.piece_at(hit.position - nrm * 2.0)
	if p == null:
		b.vel = b.vel.bounce(nrm) * 0.3
		return
	b.stuck = p.id
	b.nrm = nrm
	b.loc = world.frame(p).affine_inverse() * (hit.position + nrm * radius_m(b.vol) * Geom.M * 0.4)
	b.pos = world.frame(p) * b.loc
	b.vel = Vector2.ZERO
	_touch(b, p)


# what a globule does to what it lies on (once per piece)
func _touch(b: Dictionary, p) -> void:
	if b.quiet or b.wet.has(p.id) or p.cls != "equip" or not p.intact:
		return
	b.wet[p.id] = true
	var lk: Dictionary = LOOKS.get(b.look, LOOKS.water)
	var size_k: float = clampf(float(b.vol) / 0.01, 0.2, 1.0)
	if bool(lk.get("cryo", false)):
		frost.append([b.pos, 0.0, radius_m(b.vol) * Geom.M * 2.2])
		var before: float = p.cond
		game._dent(p, maxf(0.0, p.cond - p.fragile * 0.25 * size_k), "dv_frost")
		game.note_loss("dv_frost", p.tag, (before - p.cond) * p.value)
	elif b.look != "mud" and game.sys.electric_piece(p) and game.sys.piece_volts(p) > 1.0:
		var before2: float = p.cond
		game._dent(p, maxf(0.0, p.cond - 0.08 * size_k), "dv_wet_short")
		game.note_loss("dv_wet_short", p.tag, (before2 - p.cond) * p.value)
		game.fx.sparks(b.pos, b.nrm if b.nrm != Vector2.ZERO else Vector2.UP, 6, Pal.ink(0.9, 1.6), 140.0, 0.25, 1.2)
		if game.combustion != null:
			game.combustion.spark(b.pos, 0.6)


func _drone_wet(b: Dictionary, lk: Dictionary) -> void:
	if b.wet.has(-1):
		return
	b.wet[-1] = true
	if bool(lk.get("cryo", false)):
		game.hurt_drone(4.0 * clampf(float(b.vol) / 0.01, 0.3, 1.0), b.pos, "frost_hit", "frost", 1.5)
	# it splatters off the drone's shell
	b.vel = (b.pos - game.drone.global_position).normalized() * b.vel.length() * 0.4


# globules that touch become one: volumes add, momentum is kept
func _merge() -> void:
	var cell := 1.2 * Geom.M
	var grid := {}
	for i in blobs.size():
		var b = blobs[i]
		var key := Vector2i(int(floor(b.pos.x / cell)), int(floor(b.pos.y / cell)))
		if not grid.has(key):
			grid[key] = []
		grid[key].append(i)
	var gone := {}
	for key in grid:
		for i in grid[key]:
			if gone.has(i):
				continue
			var a = blobs[i]
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					for j in grid.get(key + Vector2i(dx, dy), []):
						if j <= i or gone.has(j):
							continue
						var c = blobs[j]
						if c.look != a.look or a.ice or c.ice or float(a.t) < 0.5 or float(c.t) < 0.5:
							continue
						var rr: float = (radius_m(a.vol) + radius_m(c.vol)) * Geom.M * RHO_GAP
						var d: Vector2 = c.pos - a.pos
						if d.length() > rr:
							continue
						# they coalesce when they come together gently (or one already lies on a
						# surface); a fast glancing pass just goes by
						var rel: Vector2 = c.vel - a.vel
						if int(a.stuck) < 0 and int(c.stuck) < 0:
							# flying apart (the pieces of a burst), or a fast pass: no
							var parting: bool = rel.dot(d) > 0.0 and rel.length() > 0.15 * Geom.M
							if parting or rel.length() > 1.2 * Geom.M:
								continue
						var m: float = float(a.vol) + float(c.vol)
						if int(a.stuck) < 0 and int(c.stuck) < 0:
							a.vel = (a.vel * float(a.vol) + c.vel * float(c.vol)) / m
						a.pos = (a.pos * float(a.vol) + c.pos * float(c.vol)) / m
						if int(c.stuck) >= 0 and int(a.stuck) < 0:
							a.stuck = c.stuck
							a.loc = c.loc
							a.nrm = c.nrm
						a.vol = m
						a.t = minf(float(a.t), float(c.t))
						a.quiet = a.quiet and c.quiet
						a.ph = float(a.ph) + 1.3
						gone[j] = true
	if gone.is_empty():
		return
	var keep: Array = []
	for i in blobs.size():
		if not gone.has(i):
			keep.append(blobs[i])
	blobs = keep


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	for f in frost:
		var a: float = 0.45 * (1.0 - float(f[1]) / 24.0)
		var c: Vector2 = f[0]
		var sz: float = float(f[2])
		for k in 6:
			var d := Vector2.from_angle(k * TAU / 6.0 + float(c.x) * 0.1)
			draw_line(c + d * sz * 0.2, c + d * sz, Pal.ink(a), 1.0, false)
			draw_line(c + d * sz * 0.6, c + d * sz * 0.6 + d.rotated(0.8) * sz * 0.25, Pal.ink(a * 0.7), 1.0, false)
	for j in jets:
		_draw_jet(j)
	for b in blobs:
		_draw_blob(b)


# a leak's jet: a ligament of liquid leaving the hole, necking (Plateau-Rayleigh) and
# pinching off into the drops the globules are; a cryogen's half-flashed to a plume
func _draw_jet(j: Array) -> void:
	var at: Vector2 = j[0]
	var dir: Vector2 = j[1]
	var flow: float = float(j[2])
	var look: String = j[3]
	var cryo: bool = look in CRYO
	var len_px: float = clampf(0.3 + flow * 12.0, 0.3, 1.4) * Geom.M
	var w0: float = clampf(1.5 + flow * 40.0, 1.5, 5.0)
	var nrm := Vector2(-dir.y, dir.x)
	var col := Pal.tint(Pal.FLUID, 0.85, 1.4 if cryo else 1.1)
	var n := 10
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for k in n + 1:
		var f: float = float(k) / n
		# the neck: waves along it growing until it breaks
		var wv: float = w0 * (1.0 - f * 0.55) * (1.0 + 0.35 * f * sin(f * 18.0 - _t * 22.0))
		var c: Vector2 = at + dir * len_px * f
		left.append(c + nrm * wv * 0.5)
		right.append(c - nrm * wv * 0.5)
	draw_polyline(left, col, 1.0, false)
	draw_polyline(right, col, 1.0, false)
	# the drops just pinched off its end
	for k in 3:
		var f2: float = 1.08 + k * 0.1 + fposmod(_t * 3.0, 0.1)
		draw_arc(at + dir * len_px * f2, w0 * 0.45, 0.0, TAU, 8, col, 1.0, false)
	if cryo:
		for k in 3:
			var f3: float = fposmod(_t * 1.5 + k * 0.33, 1.0)
			draw_arc(at + dir * len_px * f3 * 1.4 + nrm * sin(f3 * 9.0 + k) * 6.0, 3.0 + f3 * 10.0, 0.0, TAU, 10, Pal.ink(0.12 * (1.0 - f3)), 1.0, false)


func _draw_blob(b: Dictionary) -> void:
	var r: float = maxf(1.6, radius_m(b.vol) * Geom.M)
	var c: Vector2 = b.pos
	var look: String = b.look
	var col := Pal.tint(Pal.FLUID, 0.75, 1.2)
	var w := 1.2
	match look:
		"lhe", "lh2", "lng", "ln2":
			col = Pal.tint(Pal.FLUID, 0.95, 1.6)
			w = 0.9
		"fuel", "mmh":
			col = Pal.tint(Pal.FLUID, 0.8, 1.0)
			w = 1.8
		"nto":
			# nitrogen tetroxide: yellow-orange liquid
			col = Color(0.95, 0.6, 0.28, 0.9)
			w = 1.6
		"mud":
			col = Pal.ink(0.35)
			w = 1.4
	if b.ice:
		# a ball of ice: faceted, still
		var pts := PackedVector2Array()
		for k in 7:
			var a: float = k * TAU / 7.0 + float(b.ph)
			pts.append(c + Vector2.from_angle(a) * r * (0.9 + 0.12 * sin(a * 3.0 + float(b.ph))))
		pts.append(pts[0])
		draw_polyline(pts, Pal.ink(0.7), 1.1, false)
		draw_line(pts[0], pts[3], Pal.ink(0.25), 1.0, false)
		draw_line(pts[1], pts[5], Pal.ink(0.2), 1.0, false)
		return
	var stuck: bool = int(b.stuck) >= 0
	var n := 10 if r < 4.0 else (16 if r < 10.0 else 24)
	# surface-tension wobble: the fundamental modes, slower and larger for a big globule
	var amp: float = 0.0 if r < 2.5 else clampf(0.02 + r * 0.004, 0.0, 0.12) * exp(-float(b.t) * 0.15) + (0.03 if r > 6.0 else 0.0)
	var freq: float = 9.0 / sqrt(maxf(r, 1.0))
	if look == "mud":
		amp *= 0.3
	var pts2 := PackedVector2Array()
	var t_ax := Vector2.ZERO
	if stuck:
		t_ax = Vector2(-b.nrm.y, b.nrm.x)
	for k in n + 1:
		var a2: float = k * TAU / n
		var rr: float = r * (1.0 + amp * sin(2.0 * a2 + _t * freq + float(b.ph)) + amp * 0.5 * sin(3.0 * a2 - _t * freq * 1.4 + float(b.ph) * 2.0))
		var off: Vector2 = Vector2.from_angle(a2) * rr
		if stuck:
			# wetted on: spread flat along the surface
			var along: float = off.dot(t_ax)
			var out: float = off.dot(b.nrm)
			off = t_ax * along * 1.5 + b.nrm * (out * 0.45 + r * 0.1)
		pts2.append(c + off)
	# its body, faintly filled (the outline closes on itself; the fill must not repeat a point)
	var body: PackedVector2Array = pts2.slice(0, n)
	if r > 2.5 and not Geometry2D.triangulate_polygon(body).is_empty():
		draw_colored_polygon(body, Pal.ink(0.12) if look == "mud" else Color(col.r, col.g, col.b, 0.07))
	draw_polyline(pts2, col, w, false)
	if r < 3.0:
		return
	match look:
		"water", "glycol":
			# the highlight the light makes on a clear sphere
			draw_arc(c + Vector2(-r * 0.28, -r * 0.28), r * 0.42, PI * 1.05, PI * 1.55, 6, Pal.ink(0.55), 1.0, false)
			if look == "glycol":
				draw_arc(c, r * 0.78, 0.0, TAU, n, Color(col.r, col.g, col.b, 0.3), 1.0, false)
		"fuel", "mmh", "nto":
			# the oily film swirling inside
			var sw: float = _t * 0.8 + float(b.ph)
			draw_arc(c, r * 0.55, sw, sw + 2.2, 8, Color(col.r, col.g, col.b, 0.5), 1.0, false)
			draw_arc(c, r * 0.3, -sw * 1.3, -sw * 1.3 + 1.8, 6, Color(col.r, col.g, col.b, 0.35), 1.0, false)
			draw_arc(c + Vector2(-r * 0.3, -r * 0.3), r * 0.35, PI * 1.1, PI * 1.5, 5, Pal.ink(0.4), 1.0, false)
		"lhe", "lh2", "lng", "ln2":
			# boiling: vapour bubbles nucleating inside and rising out of it
			for k in 3:
				var bp: Vector2 = c + Vector2.from_angle(float(b.ph) * 3.0 + k * 2.1 + _t * 2.0) * r * fposmod(_t * 0.9 + k * 0.33, 1.0) * 0.8
				draw_arc(bp, maxf(0.8, r * 0.12), 0.0, TAU, 6, Pal.ink(0.5), 1.0, false)
		"mud":
			for k in mini(8, int(r * 0.6)):
				var gp: Vector2 = c + Vector2.from_angle(k * 2.4 + float(b.ph)) * r * fposmod(k * 0.37, 0.8)
				draw_rect(Rect2(gp, Vector2(1.4, 1.4)), Pal.ink(0.5))
