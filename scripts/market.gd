class_name Market
# The three offers on the market. Each is a contract on a ship type the
# berth can take (only the Heron class for now): registration, risk stars,
# the signature traps it carries, estimated recoverable value, contract fee,
# standard time, the scrapping reason, 2–3 onboard log lines (copy ids), the
# cargo manifest, and the seed its variant is built from. One offer is
# always low risk; reputation opens the riskier ones.

const TYPES := {"gr7": {"class": "GR", "name": ["灰鹭级货船", "HERON-CLASS FREIGHTER"], "length": 42.0, "value": 120000.0}}
const REASONS := 8
const LOGS := 8
const GOALS := ["safe", "fast", "valuable"]
const FAST_TIME := 0.75          # a fast job's standard time, of the usual
const BASE_TIME := 18.0 * 60.0    # s, a one-star contract
const STAR_TIME := 4.0 * 60.0     # s more per extra star
# the short jobs on part of a ship: standard time (the hold's is also its hard stop)
const SHORT_TIME := {"section": 12.0 * 60.0, "rescue": 8.0 * 60.0}
const RESCUE_FEE := 0.05           # a rescue's fee: of what its pieces pay
const TRIES := 30                 # draws per offer before the market gives up on that slot

static var stats := {"made": 0, "discarded": 0, "reasons": {}}   # what the contract validator threw away
# the ship types on the market and how often each comes up ([type, weight, reputation needed])
const POOL := [["gr7", 4, 0], ["s09", 3, 0], ["pod", 3, 0], ["tug", 1, 0], ["h22", 3, 6], ["m14", 3, 8], ["med47", 3, 10], ["fr26", 3, 12], ["pt34", 3, 16], ["jd38", 3, 2], ["tw64", 3, 7], ["hb86", 3, 11], ["cl104", 3, 13], ["es112", 3, 15], ["fl116", 3, 17], ["sv122", 3, 19], ["mf126", 3, 21], ["ro128", 3, 23], ["cv138", 3, 25], ["vt80", 3, 27], ["ps12", 3, 29], ["cf90", 3, 31], ["sa200", 3, 33], ["nr95", 3, 35], ["ih55", 3, 26], ["mt140", 3, 37], ["md160", 3, 39], ["tb180", 3, 41], ["ch110", 3, 43], ["my48", 3, 14], ["ic120", 3, 45]]


# a type's card data: class letters, name, length, value (the Heron's here, the rest from their files)
static func type_of(ship: String) -> Dictionary:
	if ship == "":
		return {}
	if TYPES.has(ship):
		return TYPES[ship]
	var d := Ship.load_data(ship)
	var m: Dictionary = d.get("market", {})
	if m.is_empty():
		return {}
	return {"class": m.get("class", ship.to_upper()), "name": m.get("name", [ship, ship]), "length": float(d.get("length", 20.0)),
		"value": float(d.get("value", {}).get("total", 0.0)), "time": float(m.get("time", 18.0)) * 60.0}


# a one-star full strip's standard time for a type (s); short jobs and stars scale with it
static func base_time(ship: String) -> float:
	return float(type_of(ship).get("time", BASE_TIME))


# which type an offer is: drawn from its own generator, seeded from the market's,
# so adding types never shifts the Heron contracts' other draws
static func pick_ship(rng: RandomNumberGenerator, career: Dictionary) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = hash([rng.state, "ship"])
	var rep := int(career.get("rep", 0))
	var pool: Array = []
	var total := 0
	for e in POOL:
		if rep >= int(e[2]) and FileAccess.file_exists(Ship.DIR + e[0] + ".json") and fits(e[0], career):
			pool.append(e)
			total += int(e[1])
	var k := r.randi_range(1, maxi(1, total))
	for e in pool:
		k -= int(e[1])
		if k <= 0:
			return e[0]
	return "gr7"


# a ship the berth can take: anything up to the standard berth, longer ones once it is extended
static func fits(ship: String, career: Dictionary) -> bool:
	return float(type_of(ship).get("length", 0.0)) <= Dock.owned(career.get("upgrades", {})) - 6.0


# the highest risk the market will offer at this reputation
static func max_stars(rep: int) -> int:
	return 3 if level_index(rep) >= 2 else 2


static func level_index(rep: int) -> int:
	var lv := 0
	for i in Career.LEVELS.size():
		if rep >= int(Career.LEVELS[i][1]):
			lv = i
	return lv


static func make(seed: int, career: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var top := max_stars(int(career.get("rep", 0)))
	var out: Array = []
	var used := {}
	# three cards that differ: a plain full strip, a short job, and a third
	# that is neither of those again (more stars, or the other kind of job)
	var shorts := ["section", "rescue"]
	var short1: String = shorts[rng.randi_range(0, 1)]
	shorts.erase(short1)
	for i in 3:
		var stars := 1 if i == 0 else rng.randi_range(1, top)
		var scope := "full"
		if i == 1:
			scope = short1
		elif i == 2:
			scope = "full" if top > 1 and rng.randf() < 0.5 else shorts[0]
			if scope == "full":
				stars = maxi(2, stars)
		var o := valid_offer(rng, career, stars, used, scope)
		if not o.is_empty():
			out.append(o)
	return out


# an offer that passed the contract validator (failures are counted and drawn again)
static func valid_offer(rng: RandomNumberGenerator, career: Dictionary, stars: int, used: Dictionary = {}, scope: String = "") -> Dictionary:
	for k in TRIES:
		var o := offer(rng, career, stars, used, scope, pick_ship(rng, career))
		stats.made += 1
		var v := ContractValidator.check(o._ship)
		o.erase("_ship")
		if v.ok:
			return o
		stats.discarded += 1
		used.erase(o.reg)
		for r in v.reasons:
			stats.reasons[r] = stats.reasons.get(r, 0) + 1
	return {}


# what a contract's scope pays for, in a line
static func goal_text(o: Dictionary) -> String:
	var g: String = o.get("goal", "")
	# a rescue is a valuable-equipment job already, paid piece by piece: its scope says it all
	return Txt.t("goal_" + g + "_d") if g != "" and o.get("scope", "full") != "rescue" else ""


static func _named(d: Dictionary) -> Array:
	var out: Array = []
	for pd in d.pieces:
		if pd.get("mandatory", false):
			out.append(pd.get("tag", ""))
	return out


static func scope_text(o: Dictionary) -> String:
	match o.get("scope", "full"):
		"section": return Txt.t("sc_section_d")
		"rescue": return Txt.t("sc_rescue_d") % " · ".join(o.get("scope_tags", []))
	return ""


# one offer at a given risk; `used` keeps registrations apart on one market
static func offer(rng: RandomNumberGenerator, career: Dictionary, stars: int, used: Dictionary = {}, want_scope: String = "", ship: String = "gr7") -> Dictionary:
	var t: Dictionary = type_of(ship)
	var base := Ship.load_data(ship)
	var tk := base_time(ship) / BASE_TIME
	var reg := ""
	while reg == "" or used.has(reg):
		reg = "%s-%d" % [t["class"], rng.randi_range(10, 99)]
	used[reg] = true
	var traps := pick_traps(rng, stars, int(career.get("rep", 0)), Traps.allowed(base))
	# how much of the ship is bought: the whole of it, or a short job on part of it
	var scope: String = want_scope if want_scope != "" else ["full", "full", "section", "rescue"][rng.randi_range(0, 3)]
	var o := {
		"id": "%03d-%s" % [int(career.get("done", 0)) + 2, reg],
		"ship": ship, "reg": reg, "stars": stars, "traps": traps,
		"time": snappedf((BASE_TIME + STAR_TIME * (stars - 1) if scope == "full" else SHORT_TIME[scope]) * tk, 30.0),
		"scope": scope,
		"reason": "R_reason_%02d" % rng.randi_range(1, REASONS),
		"variant": rng.randi(),
	}
	# the order's goal: a second dimension over its scope (a rescue is a valuable-equipment job by nature);
	# drawn from the contract's own seed, so it never shifts the market's other draws
	o.goal = "valuable" if scope == "rescue" else GOALS[int(o.variant) % GOALS.size()]
	if o.goal == "fast":
		o.time = snappedf(float(o.time) * FAST_TIME, 60.0)
	var d := Variant.make(base, o)
	# the estimate is the broker's, not the truth: within 8% either way
	# a riskier contract pays a little more for the same ship (and takes a smaller share in fees)
	var value: float = float(d.value.total) * rng.randf_range(0.92, 1.08) * (1.0 + 0.05 * (stars - 1))
	o.value = snappedf(value, 100.0)
	# riskier ships come cheaper: 12% of the value at one star, 8% at three
	o.fee = snappedf(value * (0.12 - 0.02 * (stars - 1)), 500.0)
	if scope == "rescue":
		# a rescue costs little to take: the pieces are paid one by one
		o.fee = snappedf(float(d.value.total) * RESCUE_FEE, 100.0)
	o.scope_tags = d.get("scope", {}).get("tags", [])
	o.named = _named(d)
	o.logs = _logs(rng, traps)
	var cargo: Array = []
	for c in Variant.containers(d):
		if Variant.piece(d, c) != null:
			cargo.append([c, d.labels.get(c, "")])
	o.cargo = cargo
	o._ship = d
	return o


# The traps a contract carries. One star: one plain trap. Two: two, and the
# subtle ones once the berth is certified. Three (senior and up): two or three,
# at least one of them subtle; a chief gets three.
static func pick_traps(rng: RandomNumberGenerator, stars: int, rep: int, allowed: Array = Traps.ALL) -> Array:
	var lv := level_index(rep)
	var plain: Array = []
	var subtle: Array = []
	for t in allowed:
		(plain if Traps.TIER[t] == 0 else subtle).append(t)
	if plain.is_empty() and subtle.is_empty():
		return []
	# a type with no subtle slots: its plain ones stand in; with no plain ones, the subtle
	if subtle.is_empty():
		subtle = plain.duplicate()
	if plain.is_empty():
		plain = subtle.duplicate()
	var out: Array = []
	match stars:
		1:
			out.append(plain[rng.randi_range(0, plain.size() - 1)])
		2:
			var pool: Array = plain + (subtle if lv >= 1 else [])
			for i in 2:
				if not pool.is_empty():
					var t: String = pool.pop_at(rng.randi_range(0, pool.size() - 1))
					if not t in out:
						out.append(t)
		_:
			var first: String = subtle.pop_at(rng.randi_range(0, subtle.size() - 1))
			out.append(first)
			var pool2: Array = plain + subtle
			pool2.erase(first)
			for i in (2 if lv >= 3 else rng.randi_range(1, 2)):
				if not pool2.is_empty():
					var t: String = pool2.pop_at(rng.randi_range(0, pool2.size() - 1))
					if not t in out:
						out.append(t)
	return out


# 2–3 lines from the ship's own logs: one per trap where the author wrote it, ordinary ones besides
static func _logs(rng: RandomNumberGenerator, traps: Array) -> Array:
	var logs: Array = []
	for t in traps:
		logs.append("X_log_%s_%d" % [t, rng.randi_range(1, 2)])
	var pool := range(1, LOGS + 1)
	while logs.size() < 2 + rng.randi_range(0, 1) and not pool.is_empty():
		logs.append("G_log_%02d" % pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	logs = logs.slice(0, 3)
	# the trap's line is not always first
	for i in range(logs.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = logs[i]
		logs[i] = logs[j]
		logs[j] = tmp
	return logs


# for tests: the offer a seed makes at a given risk
static func offer_for(seed: int, career: Dictionary, stars: int = 1, scope: String = "full", ship: String = "gr7") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var o := offer(rng, career, stars, {}, scope, ship)
	o.erase("_ship")
	return o
