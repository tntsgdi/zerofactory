class_name Story
extends Node
# A contract ship's chapter, read from ship.story: Liang when the ship comes
# in, the things on board you can inspect (tool 1 on the piece turns its tag
# into a card), the flight recorder (terminal card, a fragment of the
# recording once the player's hands are free, a clue for the archive), and the
# ending: the whole recording over the empty berth, the graded send-off, the
# chapter card and the next contract card. Nothing here changes the ship or
# the books; StoryHud draws it.

const TYPE_CPS := 30.0          # subtitle characters a second
const GAP := 1.3                # silence between recorded lines

var game: Game
var data: Dictionary = {}
var items := {}                 # piece tag -> inspect entry
var found := {}                 # inspect id -> true
var did := {}                   # beats that have happened (saved)
var banner_t := -1.0
var card: Dictionary = {}       # terminal card on screen: {rows, t, dur}
var last_found := ""
var last_found_t := 9.0
# the recorder sequence while playing: "" card wait fragment after
var rec_stage := ""
var rec_t := 0.0
# a recording on screen: {lines, i, t, full}
var rec: Dictionary = {}
# the ending: "" recording settle closing chapter next
var phase := ""
var phase_t := 0.0
var early := false


func setup(g: Game) -> void:
	game = g
	data = g.ship.get("story", {})
	for it in data.get("inspect", []):
		items[it.piece] = it


func active() -> bool:
	return not data.is_empty()


func pair(a) -> String:
	if a is Array and a.size() >= 2:
		return a[0] if Txt.zh else a[1]
	return str(a)


func who(key: String) -> String:
	return pair(data.get("who", {}).get(key, [key, key]))


func _liang(key: String, lines: Array) -> void:
	for i in lines.size():
		game.radio.say_text("st:%s:%d" % [key, i], "liang", lines[i][0], lines[i][1])


func _term(key: String, lines: Array) -> void:
	for i in lines.size():
		game.radio.say_text("st:%s:%d" % [key, i], "term", lines[i][0], lines[i][1])


# ---------------------------------------------------------------- beats

# the ship is towed in (a new contract, not a loaded one)
func on_arrive() -> void:
	if not active() or did.has("arrive"):
		return
	did.arrive = true
	_liang("arrive", data.get("arrive", []))


func on_start() -> void:
	if not active() or did.has("start"):
		return
	did.start = true
	_liang("start", data.get("start", []))
	banner_t = 0.0


# something on board contradicts its records: a word from Liang (a hint, so
# never in hardcore)
func event(key: String) -> void:
	var ln: Dictionary = data.get("lines", {}).get(key, {})
	if ln.is_empty() or did.has("ev:" + key):
		return
	if ln.get("hint", false) and Txt.hint_tier == "hardcore":
		return
	did["ev:" + key] = true
	game.radio.say_text("st:ev:" + key, "liang", ln.zh, ln.en)


func item_for(p):
	if p == null or p.tag == "":
		return null
	return items.get(p.tag)


func on_inspect(p) -> void:
	var it = item_for(p)
	if it == null or found.has(it.id):
		return
	found[it.id] = true
	last_found = it.id
	last_found_t = 0.0
	game.sfx.play("term")


func found_count() -> int:
	return found.size()


func on_delivered(p, zone: String) -> void:
	var rc: Dictionary = data.get("recorder", {})
	if rc.is_empty() or did.has("recorder") or zone != "equip" or p.tag != rc.get("piece", ""):
		return
	did.recorder = true
	rec_stage = "card"
	rec_t = 0.0
	card = {"rows": rc.get("card", []), "t": 0.0, "dur": 4.0}
	game.sfx.play("term")
	_liang("rc_before", rc.get("before", []))


func _clue() -> void:
	var cl: Dictionary = data.get("recorder", {}).get("clue", {})
	if cl.is_empty():
		return
	did.clue = true
	if not cl.id in Txt.clues:
		Txt.clues.append(cl.id)
		Txt.save_settings(game.testing)
	card = {"rows": ["ARCHIVED", pair(cl.title)], "t": 0.0, "dur": 3.0}


# ---------------------------------------------------------------- recordings

func _play(lines: Array, full: bool) -> void:
	rec = {"lines": lines, "i": 0, "t": 0.0, "full": full}


func rec_line() -> Array:
	if rec.is_empty() or rec.i >= rec.lines.size():
		return []
	return rec.lines[rec.i]


func _line_dur(ln: Array) -> float:
	var s: String = ln[2] if Txt.zh else ln[3]
	return s.length() / TYPE_CPS + 1.4 + s.length() * 0.04


func speaking() -> bool:
	var ln := rec_line()
	if ln.is_empty():
		return false
	var s: String = ln[2] if Txt.zh else ln[3]
	return rec.t < s.length() / TYPE_CPS


# the music goes quiet under a recording
func hush() -> bool:
	return not rec.is_empty() or phase == "recording"


func _step_rec(dt: float) -> bool:
	if rec.is_empty():
		return true
	rec.t += dt
	var ln := rec_line()
	if ln.is_empty():
		rec = {}
		return true
	if rec.t >= _line_dur(ln) + GAP:
		rec.i += 1
		rec.t = 0.0
		var nx := rec_line()
		if not nx.is_empty() and nx.size() > 4 and nx[4] == "burst":
			game.sfx.play("blowout")
			game.shake(0.3)
	return false


# ---------------------------------------------------------------- the ending

func wants_epilogue() -> bool:
	return active() and data.has("epilogue")


func start_epilogue(was_early: bool) -> void:
	early = was_early
	rec_stage = ""
	card = {}
	if did.has("recorder"):
		phase = "recording"
		phase_t = 0.0
		_play(data.epilogue.get("recording", []), true)
	else:
		_settle()


func _settle() -> void:
	phase = "settle"
	phase_t = 0.0
	rec = {}
	game.hud.start_ending(early)


func grade_lines() -> Array:
	var ep: Dictionary = data.get("epilogue", {})
	var gr: int = maxi(1, game.hud.grade())
	var out: Array = ep.get("grade", {}).get(str(gr), []).duplicate()
	var arc := game.incidents.any(func(i): return i[1] == "arc")
	var echo = ep.get("echo_arc" if arc else "echo")
	if echo != null:
		out.append(echo)
	return out


# keys while the ending runs; true when the story took the key
func ending_key(k: int) -> bool:
	if phase == "" or not wants_epilogue():
		return false
	match phase:
		"recording":
			_settle()
		"settle":
			if game.hud.end_t < 1.0 or k == KEY_R:
				return false
			if game.hud.end_t < 6.0:
				game.hud.end_t = 9.0
				return true
			_closing()
		"closing":
			_chapter()
		"chapter":
			if phase_t > 0.4:
				_next()
		"next":
			if phase_t > 0.8:
				game.leave()
	return true


func _closing() -> void:
	phase = "closing"
	phase_t = 0.0
	game.radio.queue = []
	game.radio.now = {}
	var ep: Dictionary = data.epilogue
	_liang("closing", ep.get("closing", []))
	_term("terminal", ep.get("terminal", []))


func _chapter() -> void:
	phase = "chapter"
	phase_t = 0.0
	game.radio.queue = []
	game.radio.now = {}


func _next() -> void:
	phase = "next"
	phase_t = 0.0
	game.sfx.play("term")
	if not Txt.chapter_done:
		Txt.chapter_done = true
		Txt.save_settings(game.testing)


func _process(dt: float) -> void:
	if game == null or not active():
		return
	var rdt := dt / maxf(Engine.time_scale, 0.01)
	if banner_t >= 0.0:
		banner_t += rdt
		if banner_t > 4.0:
			banner_t = -1.0
	last_found_t += rdt
	if not card.is_empty():
		card.t += rdt
		if card.t > card.dur:
			card = {}
	phase_t += rdt
	match phase:
		"recording":
			if _step_rec(rdt):
				_settle()
		"settle":
			# the send-off once the stamp is down
			if game.hud.end_t > 6.2 and not did.has("send_off"):
				did.send_off = true
				_liang("grade", grade_lines())
		"closing":
			if game.radio.idle() and phase_t > 1.0:
				_chapter()
		"chapter":
			if phase_t > 3.6:
				_next()
	if phase != "" or game.state != "play":
		return
	match rec_stage:
		"card":
			rec_t += rdt
			if rec_t > 1.0 and game.radio.idle():
				rec_stage = "wait"
		"wait":
			# the fragment waits for the player's hands
			var busy: bool = game.tools.cutting or (game.tools.held_piece != null and game.tools.tether_force > 0.2)
			if not busy:
				rec_stage = "fragment"
				_play(data.recorder.get("fragment", []), false)
		"fragment":
			if _step_rec(rdt):
				rec_stage = ""
				_liang("rc_after", data.recorder.get("after", []))
				_clue()


# ---------------------------------------------------------------- save

func save_state() -> Dictionary:
	return {"found": found.keys(), "did": did.keys()}


func load_state(d: Dictionary) -> void:
	for k in d.get("found", []):
		found[k] = true
	for k in d.get("did", []):
		did[k] = true
	# a fragment cut off by quitting plays again from the start
	if did.has("recorder") and not did.has("clue"):
		rec_stage = "wait"
	if did.has("start"):
		did.arrive = true
