class_name Variant
# A random contract's ship: the factory ship file of its type, changed the
# way a ship that has lived a different life would be — its hazards (room
# pressures, bottles, power, propellant and coolant), its cargo (which
# containers, what is in them, what they are worth), accident damage, and
# where the drawing is wrong — plus the contract's signature traps (see
# traps.gd). The hull never changes, and every part and port keeps the
# factory's name; a trap that adds a fitting gives it a fixed name of its
# own. Built again from the contract's seed every time it is needed, so a
# save only has to name the contract.

# what a container can hold: [stencil, mass t, value $, fragility]
const CARGO := {
	"metal": ["IND. METAL", [1.8, 2.6], [5000.0, 8000.0], 0.15],
	"precision": ["PRECISION", [1.2, 2.0], [9000.0, 14000.0], 0.9],
	"electronic": ["ELECTRONIC", [1.0, 1.8], [6000.0, 9000.0], 0.6],
}
const HEAVY := [3.2, 4.2]          # an overloaded metal container (t): too much for the 3 t grapple
const CONTAINERS := ["C-01", "C-02", "C-03"]
# equipment an accident can have knocked about (never the contract's named items)
const KNOCKABLE := ["CON-A", "NAV-01", "ENV-B", "RM-E", "RAD", "AUX-1", "AUX-2", "ENG-N", "ENG-F", "CP-E"]
# equipment the drawing may show somewhere else
const DRIFT := ["C-01", "C-03", "ENV-B", "CON-A", "RM-E", "TCAB"]


# the ship file a contract plays: its type with this contract's history on top
static func make(base: Dictionary, job: Dictionary) -> Dictionary:
	var d: Dictionary = base.duplicate(true)
	# the hand-made first contract's story stays with the first contract
	d.erase("story")
	d.contract = job.get("id", d.get("contract", ""))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(job.get("variant", 0))
	var traps: Array = job.get("traps", [])
	var notes: Array = []
	if d.has("market"):
		# any other type: its own file says what its life may have changed
		_hazards_by(d, rng)
		_cargo_by(d, rng, notes, int(job.get("stars", 1)))
		_damage(d, rng, notes, d.market.get("knockable", []))
		_drawing(d, rng, d.market.get("drift", []))
	else:
		_hazards(d, rng, traps)
		_cargo(d, rng, notes, int(job.get("stars", 1)))
		_damage(d, rng, notes)
		_drawing(d, rng)
	for t in traps:
		Traps.apply(d, t, rng, notes)
	revalue(d)
	_scope(d, job)
	_goal(d, job)
	d.variant = {"seed": int(job.get("variant", 0)), "traps": traps.duplicate(), "notes": notes, "targets": d.get("variant_targets", {})}
	d.erase("variant_targets")
	return d


# ---------------------------------------------------------------- lookups

static func piece(d: Dictionary, key: String):
	for pd in d.pieces:
		if pd.key == key:
			return pd
	return null


static func ctrl(d: Dictionary, id: String):
	for c in d.ctrls:
		if c.id == id:
			return c
	return null


static func source(d: Dictionary, tag: String):
	for s in d.get("power", {}).get("sources", []):
		if s.piece == tag:
			return s
	return null


# the containers a ship carries cargo in (the Heron's three, or its own file's)
static func containers(d: Dictionary) -> Array:
	return d.get("market", {}).get("cargo", {}).get("containers", CONTAINERS)


# where a section job's boundary is (m from the bow); the part behind it is bought
static func section_x(d: Dictionary) -> float:
	return float(d.get("market", {}).get("section_x", AFT_X))


# ---------------------------------------------------------------- hazards

static func _hazards(d: Dictionary, rng: RandomNumberGenerator, traps: Array) -> void:
	var gas: Dictionary = d.gas
	# A and B share the open door between them
	var ab := 0.0 if rng.randf() < 0.25 else rng.randf_range(60.0, 100.0)
	gas.rooms.A = snappedf(ab, 0.1)
	gas.rooms.B = snappedf(ab, 0.1)
	gas.rooms.C = 0.0 if rng.randf() < 0.2 and not "wrong_valve" in traps else snappedf(rng.randf_range(80.0, 115.0), 0.1)
	gas.rooms.D = 0.0 if rng.randf() < 0.3 else snappedf(rng.randf_range(50.0, 90.0), 0.1)
	# the bottles: anything from empty to full
	for k in ["T1", "T2"]:
		gas.vessels[k].kpa = snappedf(rng.randf_range(20.0, 140.0) if rng.randf() < 0.3 else rng.randf_range(1200.0, 2000.0), 1.0)
	# the test port's valve: shut only when the contract's trap says so
	var vc = ctrl(d, "V-C01")
	if vc != null and not "wrong_valve" in traps:
		vc.state = true
		gas.vessels.SC.kpa = gas.rooms.C
	# power: was the generator left running, and does the remote stop reach it
	var gen = source(d, "G-01")
	if gen != null:
		gen.running = "fake_stop" in traps or rng.randf() < 0.75
		gen.remote_works = not "fake_stop" in traps
	var bat = source(d, "B-01")
	if bat != null:
		bat.charge = snappedf(rng.randf_range(0.15, 1.0), 0.01)
	var cap = source(d, "CAP-01")
	if cap != null:
		cap.charge = snappedf(rng.randf_range(0.4, 1.0), 0.01)
	# propellant and coolant left aboard
	var fl: Dictionary = d.fluids.volumes
	fl.fuel.amount = snappedf(rng.randf_range(0.05, 0.6), 0.01)
	fl.fuel_line.amount = minf(0.04, fl.fuel.amount)
	fl.cool.amount = snappedf(rng.randf_range(0.08, 0.25), 0.01)
	fl.cool_broken.amount = snappedf(rng.randf_range(0.0, 0.08), 0.01)
	fl.cool_broken.drip = snappedf(rng.randf_range(0.0008, 0.003), 0.0001)


# A ship's hazards from its own rules (meta "market"):
#   rooms    {"A,B": [chance empty, lo, hi]}  kPa, rooms in one key share a value
#   vessels  {"H2": [chance low, low lo, low hi, lo, hi]}  kPa
#   charge   {"PWR-B": [lo, hi]}       a battery's or capacitor's charge
#   running  {"FC-01": chance}         a generator left running
#   fluids   {"rcs1": [lo, hi]}        m³ left aboard; "fill" {"rcs_line": "rcs1"} caps a line at its tank
static func _hazards_by(d: Dictionary, rng: RandomNumberGenerator) -> void:
	var r: Dictionary = d.market
	var gas: Dictionary = d.get("gas", {})
	for k in r.get("rooms", {}):
		var spec: Array = r.rooms[k]
		var v := 0.0 if rng.randf() < float(spec[0]) else snappedf(rng.randf_range(spec[1], spec[2]), 0.1)
		for n in str(k).split(","):
			gas.rooms[n.strip_edges()] = v
	for k in r.get("vessels", {}):
		var spec: Array = r.vessels[k]
		if gas.get("vessels", {}).has(k):
			gas.vessels[k].kpa = snappedf(rng.randf_range(spec[1], spec[2]) if rng.randf() < float(spec[0]) else rng.randf_range(spec[3], spec[4]), 1.0)
	for k in r.get("charge", {}):
		var s = source(d, k)
		if s != null:
			s.charge = snappedf(rng.randf_range(r.charge[k][0], r.charge[k][1]), 0.01)
		for iso in d.get("power", {}).get("isolated", []):
			if iso.piece == k:
				iso.charge = snappedf(rng.randf_range(r.charge[k][0], r.charge[k][1]), 0.01)
	for k in r.get("running", {}):
		var s = source(d, k)
		if s != null:
			s.running = rng.randf() < float(r.running[k])
	var fl: Dictionary = d.get("fluids", {}).get("volumes", {})
	for k in r.get("fluids", {}):
		if fl.has(k):
			fl[k].amount = snappedf(rng.randf_range(r.fluids[k][0], r.fluids[k][1]), 0.001)
	for k in r.get("fill", {}):
		if fl.has(k) and fl.has(r.fill[k]):
			fl[k].amount = minf(float(fl[k].amount), float(fl[r.fill[k]].amount))


# ---------------------------------------------------------------- cargo

# riskier contracts come with richer holds: +15% cargo value a star
static func _cargo(d: Dictionary, rng: RandomNumberGenerator, notes: Array, stars: int) -> void:
	var keep: Array = []
	for c in CONTAINERS:
		if rng.randf() < 0.85:
			keep.append(c)
	if keep.is_empty():
		keep.append(CONTAINERS[rng.randi_range(0, 2)])
	for c in CONTAINERS:
		if not c in keep:
			_remove_piece(d, c)
			notes.append("no " + c)
	for c in keep:
		var pd = piece(d, c)
		# the wired container is always electronics; the others can be anything
		var kind: String = "electronic" if c == "C-03" else ["metal", "precision", "electronic"][rng.randi_range(0, 2)]
		var cg: Array = CARGO[kind]
		var mass := rng.randf_range(cg[1][0], cg[1][1])
		var value := rng.randf_range(cg[2][0], cg[2][1])
		if kind == "metal" and rng.randf() < 0.15:
			mass = rng.randf_range(HEAVY[0], HEAVY[1])
			value *= 1.4
			notes.append("heavy " + c)
		pd.mass = snappedf(mass, 0.01)
		pd.value = snappedf(value * (1.0 + 0.15 * (stars - 1)), 100.0)
		pd.fragile = cg[3]
		d.labels[c] = cg[0]


# A ship's cargo from its own rules: market.cargo = {containers, keep, scale,
# fixed: {tag: "heavy" | "dg" | kind}}. Containers not kept are taken off;
# the rest get a kind, a mass (× scale) and a value; "heavy" ones are too much
# for the 3 t grapple, "dg" ones carry dangerous goods under their own stencil.
static func _cargo_by(d: Dictionary, rng: RandomNumberGenerator, notes: Array, stars: int) -> void:
	var cg: Dictionary = d.market.get("cargo", {})
	var all: Array = cg.get("containers", [])
	if all.is_empty():
		return
	var fixed: Dictionary = cg.get("fixed", {})
	var keep: Array = []
	for c in all:
		if rng.randf() < float(cg.get("keep", 0.85)):
			keep.append(c)
	if keep.is_empty():
		keep.append(all[rng.randi_range(0, all.size() - 1)])
	for c in all:
		if not c in keep:
			_remove_piece(d, c)
			notes.append("no " + c)
	var scale := float(cg.get("scale", 1.0))
	for c in keep:
		var pd = piece(d, c)
		if pd == null:
			continue
		var f: String = fixed.get(c, "")
		var kind: String = f if CARGO.has(f) else ["metal", "precision", "electronic"][rng.randi_range(0, 2)]
		var spec: Array = CARGO[kind]
		var mass := rng.randf_range(spec[1][0], spec[1][1]) * scale
		var value := rng.randf_range(spec[2][0], spec[2][1]) * scale
		var label: String = spec[0]
		if f == "heavy":
			mass = rng.randf_range(3.5, 4.2)
			value = rng.randf_range(spec[2][0], spec[2][1]) * 1.4
			label = "HEAVY"
			notes.append("heavy " + c)
		elif f == "dg":
			pd.hazard = "explosive"
			label = "DG"
		pd.mass = snappedf(mass, 0.01)
		pd.value = snappedf(value * (1.0 + 0.15 * (stars - 1)), 100.0)
		pd.fragile = spec[3]
		d.labels[c] = label


# a part that is not aboard: it, its fixings, its lines and its controls
static func _remove_piece(d: Dictionary, key: String) -> void:
	d.pieces = d.pieces.filter(func(pd): return pd.key != key)
	d.joints = d.joints.filter(func(j): return j.a != key and j.b != key)
	var gone_lines := {}
	for l in d.lines:
		if l.a == key or l.b == key:
			gone_lines[l.id] = true
	d.lines = d.lines.filter(func(l): return not gone_lines.has(l.id))
	d.ctrls = d.ctrls.filter(func(c): return c.piece != key)
	d.labels.erase(key)
	d.get("procedures", {}).erase(key)
	var bp: Dictionary = d.get("blueprint", {})
	bp.get("design", {}).erase(key)


# ---------------------------------------------------------------- accident damage

static func _damage(d: Dictionary, rng: RandomNumberGenerator, notes: Array, knockable: Array = KNOCKABLE) -> void:
	var n := rng.randi_range(0, 3)
	var pool: Array = knockable.duplicate()
	for i in mini(n, pool.size()):
		var t: String = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		var pd = piece(d, t)
		if pd == null:
			continue
		pd.cond = snappedf(rng.randf_range(0.35, 0.85), 0.01)
		notes.append("damaged " + t)


# ---------------------------------------------------------------- the drawing is wrong

static func _drawing(d: Dictionary, rng: RandomNumberGenerator, drift: Array = DRIFT) -> void:
	var bp: Dictionary = d.get("blueprint", {})
	var design: Dictionary = bp.get("design", {})
	for i in rng.randi_range(0, 2):
		if drift.is_empty():
			break
		var t: String = drift[rng.randi_range(0, drift.size() - 1)]
		var pd = piece(d, t)
		if pd == null or design.has(t):
			continue
		var bb := _bbox(pd.poly)
		var dx := rng.randf_range(0.5, 1.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		design[t] = [snappedf(bb.position.x + dx, 0.05), bb.position.y, snappedf(bb.end.x + dx, 0.05), bb.end.y]
	bp.design = design
	d.blueprint = bp


static func _bbox(poly: Array) -> Rect2:
	var r := Rect2(Vector2(poly[0][0], poly[0][1]), Vector2.ZERO)
	for q in poly:
		r = r.expand(Vector2(q[0], q[1]))
	return r


# ---------------------------------------------------------------- the books

# the contract's total: scrap metal, gas, fluids and every piece of equipment
static func revalue(d: Dictionary) -> void:
	var sum := float(d.value.get("metal", 0.0)) + float(d.get("gas", {}).get("value", 0.0))
	for f in d.get("fluids", {}).get("value", {}):
		sum += float(d.fluids.value[f])
	for pd in d.pieces:
		if pd.get("cls", "") == "equip":
			# explosives only ever go to the hazard mouth, which pays 40 %
			sum += float(pd.get("value", 0.0)) * (0.4 if pd.get("hazard", "") == "explosive" else 1.0)
	d.value.total = snappedf(sum, 1.0)


# ---------------------------------------------------------------- contract scope

# Not every contract is the whole ship (design/体验打磨定案.md, section 4).
# "section": only the aft section, behind frame 27 (rooms D, E, the engines
# and the hull round them). The rest of the ship may be moved, but a piece
# from outside the section that is taken away or cut costs a breach penalty.
# "rescue": three named pieces of equipment, each paid a fixed fee when it
# arrives whole at the equipment mouth; done when all three are in; the rest
# of the hull is not the berth's (the tug takes it away). The hull itself
# never changes; only what is bought.
const SCOPES := ["full", "section", "rescue"]
const AFT_X := 27.0                 # m, frame 27: the section boundary
const RESCUE_PAY := 1.2             # a rescued piece pays its value × this, whatever its condition
const BREACH_CUT := 0.5             # cutting into whole equipment outside the section: half its value
const BREACH_CUT_METAL := 300.0     # cutting into structure outside the section, per piece cut


static func _scope(d: Dictionary, job: Dictionary) -> void:
	var kind: String = job.get("scope", "full")
	if kind == "full" or not kind in SCOPES:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(job.get("variant", 0)) + 7919
	var metal_m := 0.0
	for pd in d.pieces:
		if pd.get("cls", "metal") == "metal":
			metal_m += _mass(pd)
	var price: float = float(d.value.get("metal", 12000.0)) / maxf(1.0, metal_m)
	var keep := {}
	var picked: Array = []
	var pay := {}
	match kind:
		"section":
			var sx := section_x(d)
			for pd in d.pieces:
				if _cx(pd) > sx:
					keep[pd.key] = true
		"rescue":
			var pool: Array = []
			for pd in d.pieces:
				if pd.get("cls", "") == "equip" and float(pd.get("value", 0.0)) >= 2000.0 and pd.get("tag", "") != "" and pd.get("hazard", "") == "":
					pool.append(pd)
			for i in mini(3, pool.size()):
				var pd = pool.pop_at(rng.randi_range(0, pool.size() - 1))
				keep[pd.key] = true
				picked.append(pd.tag)
				pay[pd.tag] = snappedf(float(pd.value) * RESCUE_PAY, 100.0)
	var total := 0.0
	for pd in d.pieces:
		var inside: bool = keep.has(pd.key)
		pd.scope = inside
		if not inside:
			pd.mandatory = false
		elif kind == "rescue":
			pd.mandatory = true
		if inside:
			if kind == "rescue":
				total += float(pay[pd.tag])
			else:
				total += float(pd.get("value", 0.0)) if pd.get("cls", "") == "equip" else _mass(pd) * price
	d.value.total = snappedf(total, 1.0)
	d.scope = {"kind": kind, "tags": picked, "pay": pay, "boundary": section_x(d) if kind == "section" else -1.0}


# a valuable-equipment job names two more pieces: the most valuable whole, safe equipment in scope
static func _goal(d: Dictionary, job: Dictionary) -> void:
	if job.get("goal", "") != "valuable" or job.get("scope", "full") == "rescue":
		return
	var pool: Array = []
	for pd in d.pieces:
		if pd.get("cls", "") == "equip" and pd.get("scope", true) and not pd.get("mandatory", false) and pd.get("tag", "") != "" \
				and pd.get("hazard", "") == "" and float(pd.get("mass", 0.0)) <= 3.0 and float(pd.get("cond", 1.0)) >= 0.99:
			pool.append(pd)
	pool.sort_custom(func(x, y): return float(x.get("value", 0.0)) > float(y.get("value", 0.0)))
	for pd in pool.slice(0, 2):
		pd.mandatory = true


static func _cx(pd: Dictionary) -> float:
	var x := 0.0
	for q in pd.poly:
		x += float(q[0])
	return x / maxf(1.0, pd.poly.size())


static func _mass(pd: Dictionary) -> float:
	if pd.has("mass"):
		return float(pd.mass)
	var pts := PackedVector2Array()
	for q in pd.poly:
		pts.append(Vector2(q[0], q[1]))
	return absf(Geom.area(pts)) * float(pd.get("density", 1.0))


# ---------------------------------------------------------------- what a ship asks of you

# The kinds of dismantling problem a ship file holds, read from its data
# (not from how it was made): the 2.2 acceptance counts these.
static func problems(d: Dictionary) -> Array:
	var out := {}
	var gas: Dictionary = d.get("gas", {})
	for n in gas.get("rooms", {}):
		if float(gas.rooms[n]) > 5.0:
			out["room_pressure"] = true
	for k in gas.get("vessels", {}):
		var v: Dictionary = gas.vessels[k]
		if v.has("dead_leg"):
			var vc = ctrl(d, v.dead_leg)
			if vc != null and not vc.get("state", false) and float(gas.rooms.get("C", 0.0)) > 5.0:
				out["dead_leg"] = true
		elif float(v.kpa) > float(v.get("burst", 200.0)):
			out["stored_gas"] = true
	for s in d.get("power", {}).get("sources", []):
		if s.kind == "gen" and s.get("running", false):
			out["live_generator"] = true
			if not s.get("remote_works", true):
				out["remote_stop_fails"] = true
			if not s.has("remote"):
				out["second_source"] = true
		if s.kind in ["battery", "cap"] and float(s.get("charge", 0.0)) > 0.05:
			out["stored_charge"] = true
	for s in d.get("power", {}).get("isolated", []):
		if s.has("switch"):
			out["own_supply"] = true
	var fl: Dictionary = d.get("fluids", {}).get("volumes", {})
	if float(fl.get("fuel", {}).get("amount", 0.0)) > 0.02:
		out["propellant"] = true
	if float(fl.get("cool", {}).get("amount", 0.0)) > 0.02:
		out["hot_coolant"] = true
	for pd in d.pieces:
		if pd.get("cls", "") == "equip" and float(pd.get("mass", 0.0)) > 3.0:
			out["overweight"] = true
		if pd.get("hazard", "") == "explosive":
			out["dangerous_cargo"] = true
		if float(pd.get("cond", 1.0)) < 0.9:
			out["accident_damage"] = true
		if pd.has("hidden_by"):
			out["hidden_fixing"] = true
	for j in d.joints:
		if j.type == "seam":
			out["sealed_hatch"] = true
		if j.type == "crack":
			out["cracked_structure"] = true
	var bp: Dictionary = d.get("blueprint", {})
	if not bp.get("design", {}).is_empty() or not bp.get("lines", {}).is_empty():
		out["drawing_wrong"] = true
	for t in bp.get("hide", []):
		if piece(d, t) != null and piece(d, t).get("cls", "") == "equip":
			out["undeclared_equipment"] = true
	return out.keys()
