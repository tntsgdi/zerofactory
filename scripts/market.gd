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
const BASE_TIME := 18.0 * 60.0    # s, a one-star contract
const STAR_TIME := 4.0 * 60.0     # s more per extra star
const TRIES := 30                 # draws per offer before the market gives up on that slot

static var stats := {"made": 0, "discarded": 0, "reasons": {}}   # what the contract validator threw away


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
	for i in 3:
		var stars := 1 if i == 0 else rng.randi_range(1, top)
		var o := valid_offer(rng, career, stars, used)
		if not o.is_empty():
			out.append(o)
	return out


# an offer that passed the contract validator (failures are counted and drawn again)
static func valid_offer(rng: RandomNumberGenerator, career: Dictionary, stars: int, used: Dictionary = {}) -> Dictionary:
	for k in TRIES:
		var o := offer(rng, career, stars, used)
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


# one offer at a given risk; `used` keeps registrations apart on one market
static func offer(rng: RandomNumberGenerator, career: Dictionary, stars: int, used: Dictionary = {}) -> Dictionary:
	var ship := "gr7"
	var t: Dictionary = TYPES[ship]
	var reg := ""
	while reg == "" or used.has(reg):
		reg = "%s-%d" % [t["class"], rng.randi_range(10, 99)]
	used[reg] = true
	var traps := pick_traps(rng, stars, int(career.get("rep", 0)))
	var o := {
		"id": "%03d-%s" % [int(career.get("done", 0)) + 2, reg],
		"ship": ship, "reg": reg, "stars": stars, "traps": traps,
		"time": BASE_TIME + STAR_TIME * (stars - 1),
		"reason": "R_reason_%02d" % rng.randi_range(1, REASONS),
		"variant": rng.randi(),
	}
	var d := Variant.make(Ship.load_data(ship), o)
	# the estimate is the broker's, not the truth: within 8% either way
	var value: float = float(d.value.total) * rng.randf_range(0.92, 1.08)
	o.value = snappedf(value, 100.0)
	# riskier ships come cheaper: 12% of the value at one star, 8% at three
	o.fee = snappedf(value * (0.12 - 0.02 * (stars - 1)), 500.0)
	o.logs = _logs(rng, traps)
	var cargo: Array = []
	for c in Variant.CONTAINERS:
		if Variant.piece(d, c) != null:
			cargo.append([c, d.labels.get(c, "")])
	o.cargo = cargo
	o._ship = d
	return o


# The traps a contract carries. One star: one plain trap. Two: two, and the
# subtle ones once the berth is certified. Three (senior and up): two or three,
# at least one of them subtle; a chief gets three.
static func pick_traps(rng: RandomNumberGenerator, stars: int, rep: int) -> Array:
	var lv := level_index(rep)
	var plain: Array = []
	var subtle: Array = []
	for t in Traps.ALL:
		(plain if Traps.TIER[t] == 0 else subtle).append(t)
	var out: Array = []
	match stars:
		1:
			out.append(plain[rng.randi_range(0, plain.size() - 1)])
		2:
			var pool: Array = plain + (subtle if lv >= 1 else [])
			for i in 2:
				out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
		_:
			out.append(subtle.pop_at(rng.randi_range(0, subtle.size() - 1)))
			var pool2: Array = plain + subtle
			for i in (2 if lv >= 3 else rng.randi_range(1, 2)):
				out.append(pool2.pop_at(rng.randi_range(0, pool2.size() - 1)))
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
static func offer_for(seed: int, career: Dictionary, stars: int = 1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var o := offer(rng, career, stars)
	o.erase("_ship")
	return o
