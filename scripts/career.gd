class_name Career
# The salvage business between contracts: money, the loan, reputation,
# upgrades and stock, the three offers on the market, the contract in
# progress and the books of every contract done. Its own file next to the
# contract save, written the same way (checksum, tmp swap, .bak fallback).
# A new career moves the old one aside, never deletes it.

const PATH := "user://zeropower_career.json"
const VERSION := 1
const LOAN_START := 300000.0
const INSTALLMENT := 20000.0      # taken at every settlement
const INTEREST := 0.02            # of the principal still owed, every settlement
const FIRST := "GR-001"           # the first contract is the hand-made Heron
# reputation points per settlement grade (fail, pass, good, excellent) and the levels
const REP_GAIN := [-1, 1, 2, 3]
const LEVELS := [["trainee", 0], ["certified", 6], ["senior", 16], ["chief", 30]]

static var path := PATH           # tests point this at their own file
static var data: Dictionary = {}


static func fresh() -> Dictionary:
	return {
		"version": VERSION,
		"money": 0.0,
		"loan": LOAN_START,
		"rep": 0,
		"upgrades": {},
		"items": {},
		"done": 0,
		"history": [],
		"offers": [],
		"active": {"id": FIRST, "ship": "gr7", "first": true, "fee": 9000.0, "fee_paid": false},
		"market": false,           # opens once the first contract is done
		"seed": randi(),
		"archive": {},
		"log": [],
	}


static func exists() -> bool:
	return SaveGame.exists(path)


static func load_or_new() -> Dictionary:
	if data.is_empty():
		var d := SaveGame.read(path)
		data = d if not d.is_empty() else fresh()
		for k in fresh():
			if not data.has(k):
				data[k] = fresh()[k]
	return data


# a new career: the old one is kept beside it as .old
static func start_new() -> void:
	if FileAccess.file_exists(path):
		var full := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path + ".old"):
			DirAccess.remove_absolute(full + ".old")
		DirAccess.rename_absolute(full, full + ".old")
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(full + ".bak")
	data = fresh()
	save()


static func save() -> bool:
	if data.is_empty():
		return false
	return SaveGame.write_file(path, data)


static func level() -> String:
	var lv: String = LEVELS[0][0]
	for l in LEVELS:
		if int(data.get("rep", 0)) >= l[1]:
			lv = l[0]
	return lv


# points still needed for the next level (0 at the top)
static func to_next() -> int:
	for l in LEVELS:
		if int(data.get("rep", 0)) < l[1]:
			return l[1] - int(data.rep)
	return 0


static func active() -> Dictionary:
	return data.get("active", {})


# ---------------------------------------------------------------- the market

# take an offer: the contract fee is paid now (what money can't cover is borrowed)
static func accept(i: int) -> Dictionary:
	var offers: Array = data.get("offers", [])
	if i < 0 or i >= offers.size() or not active().is_empty():
		return {}
	var o: Dictionary = offers[i].duplicate(true)
	var fee: float = o.get("fee", 0.0)
	var short := maxf(0.0, fee - float(data.money))
	data.money = float(data.money) - fee + short
	data.loan = float(data.loan) + short
	o.fee_paid = true
	o.borrowed = short
	data.active = o
	data.offers = []
	save()
	return o


# ---------------------------------------------------------------- the books

# A contract is over. r: {earned, losses, rate, grade, time, fee}. Returns the
# settlement lines the ending shows: [text key, amount].
static func settle(r: Dictionary) -> Dictionary:
	var a: Dictionary = active()
	var fee: float = r.get("fee", a.get("fee", 0.0))
	var prepaid: bool = a.get("fee_paid", false)
	var gross: float = float(r.get("earned", 0.0)) - float(r.get("losses", 0.0))
	var money_in := gross - (0.0 if prepaid else fee)
	var cash: float = float(data.money) + money_in
	# the loan: a fixed installment and interest on what is still owed
	var loan: float = float(data.loan)
	var interest := snappedf(loan * INTEREST, 1.0) if loan > 0.0 else 0.0
	var inst := minf(INSTALLMENT, loan)
	var due := inst + interest
	var paid := minf(due, maxf(cash, 0.0))
	var short := due - paid
	cash -= paid
	loan = loan - inst + short
	if cash < 0.0:
		# a loss bigger than the cash goes onto the loan too
		loan += -cash
		short += -cash
		cash = 0.0
	var rep_before: String = level()
	var grade: int = int(r.get("grade", 0))
	data.rep = maxi(0, int(data.rep) + REP_GAIN[clampi(grade, 0, 3)])
	data.money = cash
	data.loan = maxf(0.0, loan)
	data.done = int(data.done) + 1
	data.market = true
	data.history.append({"id": a.get("id", "?"), "ship": a.get("ship", "gr7"), "net": gross - fee, "rate": r.get("rate", 0.0),
		"grade": grade, "time": r.get("time", 0.0), "stars": a.get("stars", 0)})
	data.active = {}
	data.offers = []
	save()
	return {"installment": inst, "interest": interest, "paid": paid, "gross": gross, "prepaid": prepaid, "fee": fee,
		"short": short, "money": cash, "loan": data.loan, "level_up": level() != rep_before, "level": level()}


static func ensure_offers(make: Callable) -> void:
	if not data.get("offers", []).is_empty() or not active().is_empty():
		return
	data.seed = int(data.get("seed", 0)) + 1
	data.offers = make.call(int(data.seed), data)
	save()
