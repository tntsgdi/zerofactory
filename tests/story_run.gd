extends SceneTree
# Roadmap 1.7 acceptance on GR-7. Liang's arrival and start lines, the seven
# inspectable things (each room opened, tool 1 on each piece -> a card), the
# flight recorder into the equipment bay (terminal card -> Liang -> fragment
# once the hands are free -> Liang -> clue), then the ending: the whole
# recording (skippable), the graded send-off, closing lines, chapter stamp and
# the #002 card. A second run ends early without the recorder: no recording,
# straight to the settlement.
# tools/run_test.sh tests/story_run.gd --fixed-fps 60 [-- shots]

const Cap = preload("res://tests/cap.gd")
const M := 48.0
var game
var bot := {"skip_intro": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
var shots := false
var fails := 0
var finished := false


func _initialize() -> void:
	shots = "shots" in OS.get_cmdline_user_args()
	Txt.test_zh = not "en" in OS.get_cmdline_user_args()
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _process(_dt: float) -> bool:
	return finished


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _until(cond: Callable, max_s: float) -> bool:
	var t0 := Time.get_ticks_msec()
	var n := 0
	while not cond.call():
		await process_frame
		n += 1
		if n / 60.0 > max_s or Time.get_ticks_msec() - t0 > max_s * 4000.0:
			return false
	return true


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		fails += 1


func _spawn() -> void:
	if game != null:
		game.queue_free()
		await process_frame
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene


func _said(prefix: String) -> int:
	var n := 0
	for k in game.radio.said:
		if str(k).begins_with(prefix):
			n += 1
	return n


func _shot(name: String) -> void:
	if shots:
		await _frames(2)
		Cap.save(root, "res://tests/out/story_%s%s.png" % [name, "" if Txt.zh else "_en"])


func _run() -> void:
	Txt.hint_tier = "standard"
	await _spawn()
	await _frames(5)
	var st: Story = game.story
	var w = game.world
	_check(st != null and st.active(), "GR-7 carries its story")
	_check(_said("st:arrive:") == 3, "Liang's three arrival lines queued")
	await _until(func(): return game.contract_open, 3.0)
	await _frames(50)
	await _shot("contract")
	game.close_contract()
	game.settings_panel.open()
	await _frames(30)
	await _shot("settings")
	game.settings_panel.close()
	await _frames(3)
	_check(_said("st:start:") == 4 and st.banner_t >= 0.0, "start lines and the CONTRACT ACTIVE banner")
	# the seven things on board
	for it in game.ship.story.inspect:
		var p = w.tag(it.piece)
		if p == null:
			_check(false, "story piece %s exists" % it.piece)
			continue
		var room = w.rooms.get(it.room)
		if room != null and not room.revealed:
			w.reveal(it.room, room.from)
		await _frames(20)
		var at: Vector2 = w.frame(p) * Geom.centroid(p.poly)
		game.do_measure({"kind": "inspect", "piece": p, "pos": at})
		await _frames(2)
		if it.id == "steps" or it.id == "seal" or it.id == "note":
			game.drone.global_position = at + Vector2(-60, 140)
			game.drone.reset_physics_interpolation()
			game.cam_pos = at
			await _frames(30)
			await _shot("card_" + it.id)
	_check(st.found_count() == 7, "all seven inspected (%d / 7)" % st.found_count())
	var drew: bool = game.hud.has_method("_story_card")
	_check(drew, "HUD draws story cards")
	# the flight recorder into the equipment bay
	var bb = w.tag(st.data.recorder.piece)
	for j in w.joints_of(bb):
		w.kill_joint(j)
	var cov = w.tag("COV-A")
	if cov != null:
		for j in w.joints_of(cov):
			w.kill_joint(j)
	await _frames(10)
	_check(bb.body != null, "recorder came free")
	game.radio.queue = []
	game.radio.now = {}
	game.on_swallowed(bb.body, "equip")
	await _frames(3)
	_check(not st.card.is_empty() and st.rec_stage == "card", "FLIGHT RECORDER RECOVERED card")
	await _shot("recorder_card")
	# hands busy: the fragment waits
	# hands busy (cutting): Liang holds his lines and the fragment waits
	game.tools.set_tool(1)
	for i in 600:
		game.tools.cutting = true
		await process_frame
	_check(st.rec.is_empty() and st.rec_stage in ["card", "wait"], "fragment waits while the player is cutting")
	game.tools.cutting = false
	await _until(func(): return not st.rec.is_empty(), 30.0)
	_check(st.rec_stage == "fragment", "fragment plays once the hands are free")
	await _frames(70)
	await _shot("fragment")
	var ok: bool = await _until(func(): return st.did.has("clue"), 40.0)
	_check(ok and _said("st:rc_after:") == 2, "Liang after the fragment, clue filed")
	_check("gr7_fdr" in Txt.clues, "clue in the archive")
	# save and load mid-contract keeps what was found
	var sd: Dictionary = st.save_state()
	var st2 := Story.new()
	st2.data = st.data
	st2.load_state(sd)
	_check(st2.found_count() == 7 and st2.did.has("recorder") and st2.rec_stage == "", "story state survives a save")
	st2.free()
	# the ending
	game.finish_contract(false)
	await _frames(5)
	_check(st.phase == "recording" and st.rec.full, "the whole recording plays over the empty berth")
	_check(st.hush(), "music hushed under the recording")
	await _until(func(): return st.rec.get("i", 0) >= 3, 30.0)
	await _frames(40)
	await _shot("epilogue")
	var han: bool = st.who(st.rec_line()[1]) == ("韩彻" if Txt.zh else "HAN CHE")
	# the contract card and its tier buttons, for the record
	_check(han, "the voice from the fragment now has a name")
	game.story.ending_key(KEY_SPACE)
	await _frames(3)
	_check(st.phase == "settle" and game.hud.ending, "any key skips to the settlement")
	await _until(func(): return st.did.has("send_off"), 12.0)
	await _frames(2)
	_check(_said("st:grade:") >= 3, "graded send-off + echo line (%d)" % _said("st:grade:"))
	await _frames(120)
	await _shot("settle")
	st.ending_key(KEY_SPACE)
	await _frames(3)
	_check(st.phase == "closing", "closing lines")
	await _until(func(): return st.phase == "chapter", 40.0)
	_check(_said("st:closing:") == 2 and _said("st:terminal:") == 3, "Liang's goodbye and the terminal lines")
	await _frames(40)
	await _shot("chapter")
	await _until(func(): return st.phase == "next", 6.0)
	await _frames(150)
	_check(st.phase == "next", "#002 contract card")
	await _shot("next")
	# early end without the recorder: no recording, straight to the books
	await _spawn()
	await _frames(5)
	game.finish_contract(true)
	await _frames(3)
	_check(game.story.phase == "settle" and game.hud.ending, "early end without the recorder skips the recording")
	print("STORY %s  (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
