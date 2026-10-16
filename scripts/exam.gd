class_name Exam
extends Node
# The apprentice assessment (TUT_EXAM): one module, one piece of equipment to
# recover whole, one of four hidden problems. Liang keeps quiet except when
# asked (Q: a hint, and the grade remembers), when the unit comes free, and
# when it gets damaged. The grade: A done alone, safely, intact; B recovered
# but with a hint, an incident or light damage; C recovered badly damaged.
# Anything short of A comes with an accident review built from the incident
# log, one row per thing that went wrong: when, what, which judgement was off.
# The review is generic: a contract settlement can show the same rows.

const VARIANTS := ["e07a", "e07b", "e07c", "e07d"]

var game: Game
var cfg: Dictionary = {}
var hints := 0
var said := {}
var t := 0.0
var result: Dictionary = {}    # {grade, review, cond, zone} once it is over
var result_t := 0.0


static func pick() -> String:
	return VARIANTS[randi() % VARIANTS.size()]


func setup(g: Game) -> void:
	game = g
	cfg = g.ship.get("exam", {})


func target():
	return game.world.tag(cfg.get("target", ""))


func _say(key: String) -> void:
	game.radio.say_text("ex:" + key, "liang", Txt.S[key][0], Txt.S[key][1])


func on_start() -> void:
	if said.has("start"):
		return
	said.start = true
	for k in ["ex_l1", "ex_l2", "ex_l3"]:
		_say(k)


func request_hint() -> void:
	if not result.is_empty():
		return
	hints += 1
	if hints == 1:
		_say("ex_hint_cost")
	var h: Array = cfg.get("hint", [])
	if h.size() == 2:
		game.radio.forget("ex:hint")
		game.radio.say_text("ex:hint", "liang", h[0], h[1], false)


func _process(dt: float) -> void:
	if game == null or cfg.is_empty():
		return
	if not result.is_empty():
		result_t += dt / maxf(Engine.time_scale, 0.01)
		return
	if game.state != "play":
		return
	t += dt
	var p = target()
	if p == null:
		return
	if p.body != null and p.intact and not said.has("free"):
		said.free = true
		_say("ex_free")
	if (not p.intact or p.cond < 0.6) and not said.has("broken"):
		said.broken = true
		_say("ex_broken")


# whatever swallowed the target ends the assessment
func on_delivered(b, zone: String) -> void:
	if not result.is_empty():
		return
	for p in b.pieces:
		if p.tag == cfg.get("target", ""):
			finish(p, zone)
			return


func finish(p, zone: String) -> void:
	var cond: float = p.cond if p.intact else 0.0
	var grade := "C"
	var clean := game.incidents.is_empty() and hints == 0
	if zone == "equip" and p.intact and cond > 0.95 and clean:
		grade = "A"
	elif p.intact and cond >= 0.6:
		grade = "B"
	result = {"grade": grade, "cond": cond, "zone": zone, "review": review(game.incidents, hints), "time": t}
	result_t = 0.0
	if Txt.exam_grade == "" or grade < Txt.exam_grade:
		Txt.exam_grade = grade
		Career.store_story()
		Txt.save_settings(game.testing)
	game.state = "ending"
	game.tools.release_grab(false)
	game.sfx.play("end")
	game.radio.queue = []
	game.radio.now = {}
	_say("ex_a" if grade == "A" else "ex_bc")


func abandon() -> void:
	if not result.is_empty():
		return
	result = {"grade": "", "cond": 0.0, "zone": "", "review": review(game.incidents, hints), "time": t}
	result_t = 0.0
	game.state = "ending"
	game.tools.release_grab(false)
	game.radio.queue = []
	game.radio.now = {}


# ---------------------------------------------------------------- the review

# One row per incident that tells something about a judgement:
# {t, step, what, why}. step names the check that was skipped.
static func review(incidents: Array, hints_used: int = 0) -> Array:
	var rows: Array = []
	var seen := {}
	for inc in incidents:
		var kind: String = inc[1]
		var detail: String = str(inc[2]) if inc.size() > 2 else ""
		var step := ""
		match kind:
			"blowout":
				step = "pressure"
			"burst":
				step = "tank"
			"arc":
				step = "power"
			"drone_hit":
				# what hurt the drone says which check was skipped
				var by := {"live_unplug": "power", "arc_hit": "power", "jet_hit": "pressure", "burst_hit": "tank", "scald": "drain", "fire_hit": "hazard"}
				if not by.has(detail):
					continue
				step = by[detail]
			"torn":
				step = "tied_hidden" if detail.ends_with(" hidden") else ("tied_lines" if detail.ends_with(" lines") else "tied")
			"leak":
				step = "drain"
			"equip_cut":
				step = "cut"
			"impact":
				step = "impact"
			"furnace", "fire":
				step = "hazard"
			_:
				continue
		# the same mistake twice is one row
		if seen.has(step):
			continue
		seen[step] = true
		rows.append({"t": float(inc[0]), "step": step, "what": "rv_w_" + step, "why": "rv_y_" + step, "detail": detail.split(" ")[0]})
	if hints_used > 0:
		rows.append({"t": -1.0, "step": "hint", "what": "rv_w_hint", "why": "rv_y_hint", "detail": str(hints_used)})
	return rows
