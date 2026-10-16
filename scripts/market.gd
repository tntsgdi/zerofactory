class_name Market
# The three offers on the market. Each is a contract on a ship type the
# berth can take (only the Heron class for now): registration, risk stars,
# estimated recoverable value, contract fee, standard time, the scrapping
# reason and 2–3 onboard log lines (copy ids), and the seed its variant is
# built from. One offer is always low risk; reputation opens the riskier ones.

const TYPES := {"gr7": {"class": "GR", "name": ["灰鹭级货船", "HERON-CLASS FREIGHTER"], "length": 42.0, "value": 120000.0}}
const REASONS := 8
const LOGS := 8
const BASE_TIME := 18.0 * 60.0    # s, a one-star contract
const STAR_TIME := 4.0 * 60.0     # s more per extra star


# the highest risk the market will offer at this reputation
static func max_stars(rep: int) -> int:
	if rep >= 16:
		return 3
	if rep >= 6:
		return 2
	return 2


static func make(seed: int, career: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var top := max_stars(int(career.get("rep", 0)))
	var out: Array = []
	var used := {}
	for i in 3:
		var stars := 1 if i == 0 else rng.randi_range(1, top)
		var ship := "gr7"
		var t: Dictionary = TYPES[ship]
		var reg := ""
		while reg == "" or used.has(reg):
			reg = "%s-%d" % [t["class"], rng.randi_range(10, 99)]
		used[reg] = true
		var value: float = t["value"] * rng.randf_range(0.85, 1.15) * (1.0 + 0.12 * (stars - 1))
		# riskier ships come cheaper: 12% of the value at one star, 8% at three
		var fee: float = snappedf(value * (0.12 - 0.02 * (stars - 1)), 500.0)
		var logs: Array = []
		var pool := range(1, LOGS + 1)
		for k in 2 + rng.randi_range(0, 1):
			var n: int = pool.pop_at(rng.randi_range(0, pool.size() - 1))
			logs.append("G_log_%02d" % n)
		out.append({
			"id": "%03d-%s" % [int(career.get("done", 0)) + 2, reg],
			"ship": ship, "reg": reg, "stars": stars,
			"value": snappedf(value, 100.0), "fee": fee,
			"time": BASE_TIME + STAR_TIME * (stars - 1),
			"reason": "R_reason_%02d" % rng.randi_range(1, REASONS),
			"logs": logs, "traps": [], "variant": rng.randi(),
		})
	return out
