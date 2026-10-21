extends SceneTree
# The first-meeting cards and the book (scripts/codex.gd, design/新手教程与图鉴定案.md).
# Static: every entry has its name, three card sentences and its working in both
# languages; no text is left over; every machine drawing the fleet uses has an entry
# (or is plain furniture); every ship with a mechanism of its own has its entries;
# every card sentence fits its card (three lines at most), every name its card and
# the book. Live, on GR-7 and FX-70 with a bot: pointing at a machine for 0.4 s puts
# up its card (a glance does not); an incident puts up its mechanism's; the queue
# holds three, the rest go into the book marked new; cards come 6 s apart and stay
# 12 s; the setting turns them off (still into the book); all three hint tiers see
# the same cards; the contract card's mechanisms are in the book from the start.
# tools/run_test.sh tests/codex_check.gd --fixed-fps 60

const M := 48.0
# drawings that are furniture or plain cargo: no card
const PLAIN := ["lamp", "cabinet", "locker", "seat", "bunk", "plants", "table", "desk", "shelf", "toolwall", "galley", "bed",
	"ladder", "grating", "suit", "bench", "medcab", "op_table", "bar", "piano", "wine_rack", "mail_sorter", "beehive",
	"gun_rack", "harness", "screen", "spray_bar", "food_module", "composter", "growlamp", "biobox", "ingot_rack", "beacon",
	"barrel", "shell", "missile", "ice", "drum", "glove"]
# every ship with a mechanism of its own (design/ships/00_一批交审总表.md, and the early ones)
const SPECIAL := ["pt34", "jd38", "tw64", "hb86", "cl104", "es112", "fl116", "sv122", "mf126", "ro128", "cv138", "vt80", "ps12",
	"cf90", "sa200", "nr95", "ih55", "mt140", "md160", "tb180", "ch110", "my48", "ic120", "ark01", "qc30", "st40", "ev55",
	"dc84", "ob90", "fx70", "bl88", "lc140", "dr150", "hg170", "h22", "m14", "med47", "fr26"]

var fails: Array = []
var game
var bot := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "codex": true}
var finished := false


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _process(_dt: float) -> bool:
	return finished


func _fail(s: String) -> void:
	fails.append(s)
	print("  FAIL ", s)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	_texts()
	_coverage()
	_fit()
	await _live()
	print("CODEX %s  (%d entries, %d problems)" % ["PASS" if fails.is_empty() else "FAIL", CodexData.E.size(), fails.size()])
	finished = true


# ---------------------------------------------------------------- texts

func _texts() -> void:
	var counts := {}
	for id in CodexData.E:
		var e: Dictionary = CodexData.E[id]
		if not e.cat in Codex.CATS:
			_fail("%s: unknown kind %s" % [id, e.cat])
		counts[e.cat] = counts.get(e.cat, 0) + 1
		for part in ["", "_a", "_b", "_c", "_x"]:
			var k: String = "cx_" + id + part
			var v = CodexTxt.S.get(k)
			if v == null or not v is Array or v.size() != 2 or str(v[0]).strip_edges() == "" or str(v[1]).strip_edges() == "":
				_fail("text missing: " + k)
			elif str(v[0]).find("【待写】") >= 0 or str(v[1]).find("【待写】") >= 0:
				_fail("placeholder: " + k)
		if e.cat == "mech":
			if e.get("ships", []).is_empty():
				_fail("%s: a mechanism with no ship" % id)
			if not e.get("cls", "") in Codex.CLASSES:
				_fail("%s: no special course" % id)
			if e.get("inc", []).is_empty() and e.get("arts", []).is_empty() and e.get("names", []).is_empty() and e.get("kinds", []).is_empty() and id != "m_workday":
				_fail("%s: nothing on site shows it" % id)
		if e.cat == "sys" and not e.has("ev") and e.get("inc", []).is_empty() and e.get("arts", []).is_empty():
			_fail("%s: a system nothing shows" % id)
	# no text without its entry
	for k in CodexTxt.S:
		if not k.begins_with("cx_"):
			continue
		var base: String = k.substr(3)
		for suf in ["_a", "_b", "_c", "_x"]:
			if base.ends_with(suf):
				base = base.substr(0, base.length() - 2)
				break
		if not CodexData.E.has(base):
			_fail("text with no entry: " + k)
	print("entries: ", counts)


# ---------------------------------------------------------------- the fleet is covered

func _coverage() -> void:
	var drawn := {}
	var ship_mechs := {}
	for f in DirAccess.get_files_at("res://ships"):
		if not f.ends_with(".json") or f.ends_with("_course.json"):
			continue
		var sid := f.get_basename()
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://ships/" + f))
		for pd in d.get("pieces", []):
			var nk: String = pd.get("name_key", "")
			var art: String = Art.SH.BY_NAME.get(nk, Art.EQ.BY_NAME.get(nk, str(pd.get("art", ""))))
			if art == "" or art in PLAIN:
				continue
			if Codex.device_entry(art) == "":
				var hit := false
				for id in CodexData.E:
					if art in CodexData.E[id].get("arts", []):
						hit = true
				if not hit:
					drawn[art] = drawn.get(art, []) + [sid]
		ship_mechs[sid] = Codex.ship_entries(sid)
	for art in drawn:
		_fail("a drawing with no entry: %s (%s)" % [art, ", ".join(drawn[art].slice(0, 4))])
	for sid in SPECIAL:
		if ship_mechs.get(sid, []).is_empty():
			_fail("%s has no mechanism entry" % sid)
	# every ship a course is needed for, and every course's ships, have their mechanisms
	for cls in Codex.CLASSES:
		for sid in Codex.CLASS_SHIPS[cls]:
			if not sid in SPECIAL:
				_fail("%s needs course %s but has no mechanism listed" % [sid, cls])
	for sid in SPECIAL:
		if Codex.classes_of(sid).is_empty():
			_fail("%s has a mechanism of its own but needs no course" % sid)


# ---------------------------------------------------------------- the cards fit

func _fit() -> void:
	var f: Font = Fonts.get_font("Regular")
	var fb: Font = Fonts.get_font("Medium")
	var worst := 0
	for lang in [true, false]:
		Txt.zh = lang
		for id in CodexData.E:
			for part in ["a", "b", "c"]:
				var n := CodexHud.wrap_lines(f, Codex.line(id, part), CodexHud.TXT_W - CodexHud.label_w(), CodexHud.FS)
				worst = maxi(worst, n)
				# a ship's own mechanism may take a fourth line in English
				if n > (4 if CodexData.E[id].cat == "mech" and not lang else 3):
					_fail("card sentence over three lines (%s): cx_%s_%s" % ["zh" if lang else "en", id, part])
			var tw := fb.get_string_size(Codex.title(id), HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
			if tw > CodexHud.W - 60.0:
				_fail("card title too wide (%s): %s %.0f px" % ["zh" if lang else "en", id, tw])
			var lw := f.get_string_size(Codex.title(id), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			if lw > CodexPage.LIST_W - 40.0:
				_fail("book row too wide (%s): %s" % ["zh" if lang else "en", id])
			if CodexHud.wrap_lines(f, Codex.line(id, "x"), 1200.0, 16) > 9:
				_fail("the working runs too long (%s): %s" % ["zh" if lang else "en", id])
	Txt.zh = Txt.test_zh
	print("longest card sentence: %d lines" % worst)


# ---------------------------------------------------------------- live

func _spawn(ship: String) -> void:
	if game != null:
		game.queue_free()
		await process_frame
	Codex.mem = {"seen": {}, "new": {}, "certs": {}}
	Game.start_ship = ship
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene
	await _frames(30)


func _piece_with_art(art: String):
	for id in game.world.order:
		var p = game.world.pieces[id]
		var a := Codex.art_of(p)
		var want: bool = Codex.device_entry(a) != "" if art == "" else a == art
		if not p.gone and want and not game.world.room_hidden(p.room):
			return p
	return null


func _aim_at(p, frames: int) -> void:
	var at: Vector2 = game.world.frame(p) * Geom.centroid(p.poly)
	game.tools.set_tool(1)
	game.drone.global_position = at + Vector2(-1.5, -1.8) * M
	game.drone.linear_velocity = Vector2.ZERO
	game.drone.reset_physics_interpolation()
	bot.aim = at
	await _frames(frames)


func _live() -> void:
	Txt.hint_tier = "standard"
	Txt.codex_cards = true
	await _spawn("gr7")
	var cx: Codex = game.codex
	# the contract card's mechanisms (GR-7 has none of its own) — and FX-70's later
	if not Codex.ship_entries("gr7").is_empty():
		_fail("GR-7 lists mechanisms of its own")
	# a glance is not a meeting; 0.4 s is (any machine in plain sight)
	var mach = _piece_with_art("")
	if mach == null:
		_fail("no machine in sight on GR-7 to point at")
	else:
		var mid := Codex.device_entry(Codex.art_of(mach))
		await _aim_at(mach, 6)
		if Codex.seen(mid):
			_fail("a glance at %s counted as meeting it" % mid)
		await _aim_at(mach, 40)
		if not Codex.seen(mid):
			_fail("pointing at %s for 0.4 s did not meet it (hover %s)" % [mid, str(game.tools.hover.get("kind", ""))])
		elif not (mid in cx.queue or cx.card == mid):
			_fail("meeting %s put up no card" % mid)
		print("pointed at: ", mid)
	# the queue holds three; the rest go straight into the book, new
	cx.queue.clear()
	cx.card = ""
	cx.gap_t = 0.0
	var five := ["pump", "hx", "radiator", "chiller", "filter"]
	for id in five:
		cx.meet(id, "test")
	if cx.queue.size() != Codex.QUEUE:
		_fail("queue holds %d, not %d" % [cx.queue.size(), Codex.QUEUE])
	for id in five:
		if not Codex.seen(id) or not Codex.is_new(id):
			_fail("%s not in the book as new" % id)
	# a card met again never comes back
	cx.meet("pump", "again")
	if cx.queue.count("pump") > 1:
		_fail("the same card queued twice")
	# 6 s between cards, each up 12 s (the time it stays, not while held)
	var t0 := 0.0
	var first := ""
	for i in 60 * 8:
		await process_frame
		if cx.card != "" and first == "":
			first = cx.card
			t0 = float(i) / 60.0
			break
	if first == "":
		_fail("no card came up after the gap")
	elif t0 < Codex.GAP - 0.5:
		_fail("first card came after %.1f s, not %.0f s" % [t0, Codex.GAP])
	await _frames(int(60 * (Codex.SHOW_T + 0.5)))
	if cx.card == first:
		_fail("a card stayed past %.0f s" % Codex.SHOW_T)
	await _frames(60 * 2)
	if cx.card != "":
		_fail("the next card came within the gap")
	# the setting off: into the book, no card
	Txt.codex_cards = false
	cx.queue.clear()
	cx.meet("gen", "off")
	if not cx.queue.is_empty() or not Codex.seen("gen"):
		_fail("with cards off: queued %d, in the book %s" % [cx.queue.size(), str(Codex.seen("gen"))])
	Txt.codex_cards = true
	# the same in every hint tier
	for tr in Txt.TIERS:
		Txt.hint_tier = tr
		cx.queue.clear()
		var id: String = {"guided": "duct_fan", "standard": "trap", "hardcore": "manifold"}[tr]
		cx.meet(id, tr)
		if not id in cx.queue:
			_fail("no card in the %s tier" % tr)
	Txt.hint_tier = "standard"
	# an incident shows its system
	cx.queue.clear()
	game.incident("fire", "test")
	await _frames(20)
	if not Codex.seen("s_fire"):
		_fail("a fire did not show the fire entry")
	# FX-70: its mechanisms are in the book from the contract card; a quench shows its card
	await _spawn("fx70")
	cx = game.codex
	for id in Codex.ship_entries("fx70"):
		if not Codex.seen(id):
			_fail("FX-70's %s not in the book from the start" % id)
	if not "m_quench" in Codex.ship_entries("fx70"):
		_fail("FX-70 does not list the quench")
	cx.queue.clear()
	game.incident("magnet_quench", "test")
	await _frames(20)
	if not ("m_quench" in cx.queue or cx.card == "m_quench"):
		_fail("a quench put up no quench card")
	# a coil pointed at: the device and the mechanism
	var coil = _piece_with_art("tf_coil")
	if coil != null:
		Codex.mem.erase("x")
		await _aim_at(coil, 40)
		if not Codex.seen("tf_coil"):
			_fail("pointing at a TF coil did not meet it")
	# GR-7's incident of an FX-70 mechanism shows nothing there
	await _spawn("gr7")
	game.incident("magnet_quench", "test")
	await _frames(20)
	if Codex.seen("m_quench"):
		_fail("a quench entry met on a ship without magnets")
	game.queue_free()
