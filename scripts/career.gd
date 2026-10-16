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
const BONUS := 0.2                # of the net profit, finished within the standard time
const FIRST := "GR-001"           # the first contract is the hand-made Heron
# reputation points per settlement grade (fail, pass, good, excellent) and the levels
const REP_GAIN := [-1, 1, 2, 3]
const LEVELS := [["trainee", 0], ["certified", 6], ["senior", 16], ["chief", 30]]

static var path := PATH           # tests point this at their own file
static var data: Dictionary = {}
# three save slots, each a career with its own contract and training files;
# slot 1 keeps the file names from before slots, so an old career is slot 1
const SLOTS := 3
static var slot := 1


static func slot_files(n: int) -> Array:
	if n <= 1:
		return [PATH, SaveGame.PATH, SaveGame.TRAIN_PATH]
	return ["user://zp_slot%d_career.json" % n, "user://zp_slot%d_save.json" % n, "user://zp_slot%d_training.json" % n]


static func use_slot(n: int) -> void:
	var f := slot_files(n)
	slot = n
	path = f[0]
	SaveGame.path = f[1]
	SaveGame.train_path = f[2]
	data = {}


# what a slot card shows, read without switching to it ({} when empty;
# a test run never looks at the player's files)
static func peek(n: int) -> Dictionary:
	if _test_run():
		return {}
	var f := slot_files(n)
	if SaveGame.exists(f[0]):
		var d := SaveGame.read_career(f[0])
		if not d.is_empty():
			return d
	if SaveGame.exists(f[1]) or SaveGame.exists(f[2]):
		return {"done": 0, "money": 0.0, "loan": LOAN_START, "time": 0.0, "certified": SaveGame.exists(f[1])}
	return {}


# a slot emptied: its files are moved aside (.old), never deleted
static func clear_slot(n: int) -> void:
	if _test_run():
		return
	for f in slot_files(n):
		for ext in ["", ".bak"]:
			if FileAccess.file_exists(f + ext):
				var full := ProjectSettings.globalize_path(f + ext)
				if FileAccess.file_exists(f + ext + ".old"):
					DirAccess.remove_absolute(full + ".old")
				DirAccess.rename_absolute(full, full + ".old")
	if slot == n:
		data = {}


# a test run never touches the player's own career file
static func _test_run() -> bool:
	for a in OS.get_cmdline_args():
		if a == "-s" or a == "--script" or a.find("tests/") >= 0:
			return true
	return false


static func usable() -> bool:
	return path != PATH or not _test_run()


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
		"company": "",
		"time": 0.0,               # seconds played on this slot (training included)
		"certified": false,        # through the training course, or skipped it
	}


static func exists() -> bool:
	return usable() and SaveGame.exists(path)


static func load_or_new() -> Dictionary:
	if data.is_empty():
		var d := SaveGame.read_career(path) if usable() else {}
		data = d if not d.is_empty() else fresh()
		# a career from before slots: whoever had one had passed or skipped training
		if not d.is_empty() and not d.has("certified"):
			data.certified = true
		for k in fresh():
			if not data.has(k):
				data[k] = fresh()[k]
		_normalize()
	return data


# JSON gives every number back as a float: counts, levels and seeds are whole
static func _normalize() -> void:
	for k in ["rep", "done", "seed", "version"]:
		data[k] = int(data.get(k, 0))
	for bag in ["items", "upgrades"]:
		var b: Dictionary = data.get(bag, {})
		for k in b:
			b[k] = int(b[k])
	for o in data.get("offers", []) + [data.get("active", {})]:
		for k in ["stars", "variant"]:
			if o.has(k):
				o[k] = int(o[k])


# a new career: the old one is kept beside it as .old
static func start_new() -> void:
	if usable() and FileAccess.file_exists(path):
		var full := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path + ".old"):
			DirAccess.remove_absolute(full + ".old")
		DirAccess.rename_absolute(full, full + ".old")
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(full + ".bak")
	data = fresh()
	save()


# through training (or past it): this slot goes straight to the berth from now on
static func certify() -> void:
	if data.is_empty() or not usable():
		return
	data.certified = true
	save()


static func save() -> bool:
	if data.is_empty() or not usable():
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
	# the berth goes to work with what it owns at signing
	o.kit = data.get("upgrades", {}).duplicate()
	o.items = data.get("items", {}).duplicate()
	o.notes = data.get("archive", {}).get(o.get("ship", ""), {}).duplicate(true)
	# what was bought at the terminal since the last contract goes on this one's log
	o.desk = data.get("desk", {}).duplicate()
	data.desk = {}
	data.active = o
	data.offers = []
	save()
	return o


# ---------------------------------------------------------------- the engineering archive

# what was checked by hand on a ship goes into the type's notes (newest wins)
static func file_notes(ship: String, verified: Dictionary) -> void:
	var arch: Dictionary = data.get("archive", {})
	var n: Dictionary = arch.get(ship, {"pieces": {}, "ports": {}, "lines": {}, "ctrls": {}, "ships": 0})
	for k in ["pieces", "ports", "lines", "ctrls"]:
		var into: Dictionary = n.get(k, {})
		for id in verified.get(k, {}):
			into[id] = verified[k][id]
		n[k] = into
	n.ships = int(n.get("ships", 0)) + 1
	arch[ship] = n
	data.archive = arch


# ---------------------------------------------------------------- the books

# the time bonus: +20% of a positive net profit within the standard time,
# falling off in a straight line to nothing at twice the standard time
static func time_bonus(net: float, secs: float, standard: float) -> float:
	if standard <= 0.0 or net <= 0.0:
		return 0.0
	return snappedf(net * BONUS * clampf((2.0 * standard - secs) / standard, 0.0, 1.0), 1.0)


# pay off part of the loan from funds now; returns what was paid
static func repay(amount: float) -> float:
	var pay := minf(amount, minf(float(data.money), float(data.loan)))
	if pay <= 0.0:
		return 0.0
	data.money = float(data.money) - pay
	data.loan = float(data.loan) - pay
	_paid_off()
	save()
	return pay


# the loan is gone: BERTH 07 is the operator's (once; later ship types hang on this)
static func _paid_off() -> bool:
	if float(data.loan) > 0.5 or data.get("paid_off", false):
		return false
	data.loan = 0.0
	data.paid_off = true
	data.paid_off_at = int(data.get("done", 0))
	return true


# A short job on part of a ship carries the installment and interest in
# proportion to its standard time against a full contract's (never under 30%).
static func due_share(job: Dictionary) -> float:
	if job.get("scope", "full") == "full":
		return 1.0
	return clampf(float(job.get("time", Market.BASE_TIME)) / Market.BASE_TIME, 0.3, 1.0)


# what a contract would take for the loan at settlement, at today's loan
static func due_for(job: Dictionary) -> float:
	var loan := float(data.get("loan", 0.0))
	var k := due_share(job)
	return minf(INSTALLMENT * k, loan) + snappedf(loan * INTEREST * k, 1.0)


# A contract is over. r: {earned, losses, rate, grade, time, fee, bonus}. Returns
# what the settlement shows.
static func settle(r: Dictionary) -> Dictionary:
	var a: Dictionary = active()
	var fee: float = r.get("fee", a.get("fee", 0.0))
	var prepaid: bool = a.get("fee_paid", false)
	var bonus: float = float(r.get("bonus", 0.0))
	var gross: float = float(r.get("earned", 0.0)) - float(r.get("losses", 0.0)) + bonus
	var money_in := gross - (0.0 if prepaid else fee)
	data.roll_from = {"money": float(data.money), "loan": float(data.loan)}
	var cash: float = float(data.money) + money_in
	# the loan: a fixed installment and interest on what is still owed (a short job's share of them)
	var loan: float = float(data.loan)
	var share := due_share(a)
	var interest := snappedf(loan * INTEREST * share, 1.0) if loan > 0.0 else 0.0
	var inst := minf(INSTALLMENT * share, loan)
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
	# consumables used on the contract come out of stock
	var used: Dictionary = r.get("used", {})
	for k in used:
		data.items[k] = maxi(0, int(data.items.get(k, 0)) - int(used[k]))
	data.market = true
	data.history.append({"id": a.get("id", "?"), "ship": a.get("ship", "gr7"), "net": gross - fee, "rate": r.get("rate", 0.0),
		"grade": grade, "time": r.get("time", 0.0), "stars": a.get("stars", 0), "bonus": bonus, "loan": data.loan, "ops": r.get("ops", {})})
	data.active = {}
	data.offers = []
	var paid_off := _paid_off()
	save()
	return {"installment": inst, "interest": interest, "paid": paid, "gross": gross, "prepaid": prepaid, "fee": fee, "bonus": bonus,
		"short": short, "money": cash, "loan": data.loan, "level_up": level() != rep_before, "level": level(), "paid_off": paid_off, "used": used}


static func ensure_offers(make: Callable) -> void:
	if not data.get("offers", []).is_empty() or not active().is_empty():
		return
	data.seed = int(data.get("seed", 0)) + 1
	data.offers = make.call(int(data.seed), data)
	save()
