extends SceneTree
# Roadmap 1.9: every text the game can show, in both languages. (1) Each
# character exists in the fonts (Chakra Petch, or the Noto Sans SC subset
# behind it). (2) Each text fits the box it is drawn in, at the size it is
# drawn: menus, settings, toolbar, tier buttons, the radio (two lines at
# most), hints, terminal cards, the contract and #002 cards, the review, the
# task list. Prints every offender. No window needed.
# godot --headless --path . -s tests/text_fit.gd

var fonts := {}
var sc: Array = []
var lat: Array = []
var missing := {}
var over: Array = []
var checked := 0


func _initialize() -> void:
	for w in ["Regular", "Medium", "Light"]:
		fonts[w] = Fonts.get_font(w)
	for n in ["Regular", "Light", "Semibold"]:
		sc.append(load("res://assets/fonts/ZeroSC-%s.ttf" % n))
	for n in ["Regular", "Medium", "Light"]:
		lat.append(load("res://assets/fonts/ChakraPetch-%s.ttf" % n))
	_glyphs()
	_fit_all()
	var ok := missing.is_empty() and over.is_empty()
	if not missing.is_empty():
		print("missing glyphs: %d" % missing.size())
		var shown := 0
		for ch in missing:
			if shown < 30:
				print("  %s  U+%04X  in \"%s\"" % [ch, ch.unicode_at(0), missing[ch]])
			shown += 1
	for o in over:
		print("  too wide: %s" % o)
	print("TEXT %s  (%d texts measured, %d missing glyphs, %d too wide)" % ["PASS" if ok else "FAIL", checked, missing.size(), over.size()])
	quit()


# ---------------------------------------------------------------- every string

func _all_strings() -> Array:
	var out: Array = []
	for k in Txt.S:
		var v = Txt.S[k]
		if v is Array:
			for s in v:
				out.append(str(s))
	for f in DirAccess.get_files_at("res://ships"):
		if f.ends_with(".json"):
			_collect(JSON.parse_string(FileAccess.get_file_as_string("res://ships/" + f)), out)
	_collect(JSON.parse_string(FileAccess.get_file_as_string(Copy.FILE)), out)
	return out


func _collect(v, out: Array) -> void:
	if v is String:
		out.append(v)
	elif v is Array:
		for x in v:
			_collect(x, out)
	elif v is Dictionary:
		for k in v:
			_collect(v[k], out)


func _has(ch: String) -> bool:
	var c := ch.unicode_at(0)
	if c < 0x20 or ch == "\n":
		return true
	for f in lat:
		if f.has_char(c):
			return true
	# every SC weight must carry it (Light draws big titles)
	for f in sc:
		if not f.has_char(c):
			return false
	return true


func _glyphs() -> void:
	for s: String in _all_strings():
		for i in s.length():
			var ch: String = s.substr(i, 1)
			if not missing.has(ch) and not _has(ch):
				missing[ch] = s.substr(0, 40)


# ---------------------------------------------------------------- boxes

func _w(s: String, size: int, weight: String = "Regular") -> float:
	return fonts[weight].get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func _both(key: String) -> Array:
	var v = Txt.S.get(key)
	return v if v is Array else []


func _fit(where: String, texts: Array, size: int, max_w: float, weight: String = "Regular") -> void:
	for s in texts:
		var t := str(s)
		if t == "":
			continue
		checked += 1
		var w := _w(t, size, weight)
		if w > max_w:
			over.append("%s: %d px > %d  \"%s\"" % [where, int(w), int(max_w), t.substr(0, 60)])


func _keys(keys: Array) -> Array:
	var out: Array = []
	for k in keys:
		out.append_array(_both(k))
	return out


func _pairs(list: Array) -> Array:
	var out: Array = []
	for p in list:
		if p is Array and p.size() >= 2:
			out.append(p[0])
			out.append(p[1])
	return out


func _prefixed(prefix: String) -> Array:
	var out: Array = []
	for k in Txt.S:
		if str(k).begins_with(prefix):
			out.append_array(_both(k))
	return out


func _fit_all() -> void:
	# pause menu items, 440 px buttons at 20 px
	var tiers: Array = []
	for tr in Txt.TIERS:
		for i in 2:
			tiers.append(_both("m_tier")[i] % _both("tier_" + tr)[i])
	_fit("menu", _keys(["m_resume", "m_end", "m_skip", "m_abandon", "m_settings", "m_title", "m_confirm", "m_hints", "m_hints_off"]) + tiers, 20, 420)
	_fit("menu warning", _keys(["end_warn"]), 14, 1500)
	_fit("title menu", _keys(["t_continue", "t_new", "t_train", "m_settings", "t_quit", "t_career_go", "t_career_new", "t_career_confirm"]), 22, 390)
	_fit("title note", _keys(["t_note", "t_career_note"]), 13, 900)
	# the berth terminal
	var tabs: Array = []
	for k in ["tm_tab_market", "tm_tab_shop", "tm_tab_berth"]:
		for x in _both(k):
			tabs.append("1  " + x)
	_fit("terminal tab", tabs, 17, 190, "Medium")
	_fit("terminal top label", _keys(["tm_money", "tm_loan", "tm_due", "tm_rep"]), 13, 230)
	_fit("terminal reputation", _prefixed("rep_"), 26, 230, "Light")
	_fit("terminal rep next", _keys(["tm_rep_next"]), 11, 300)
	_fit("offer card label", _keys(["tm_reason", "tm_logs", "tm_risk", "tm_cargo"]), 12, 500)
	_fit("offer card row", _keys(["tm_value", "tm_fee", "tm_time"]), 14, 360)
	_fit("offer card note", _keys(["tm_logs_note"]), 11, 520)
	_fit("shop item", _prefixed("up_") + _prefixed("it_") + _prefixed("fa_"), 17, 1000, "Medium")
	_fit("terminal keys and messages", _keys(["tm_keys", "tm_borrow", "tm_short", "tm_bought", "tm_none", "tm_later", "tm_owned"]), 16, 1300)
	_fit("terminal button", _keys(["tm_take", "tm_buy"]), 20, 260, "Medium")
	_fit("terminal repay row", _keys(["tm_repay"]), 17, 1000, "Medium")
	_fit("terminal repay row", _keys(["tm_repay_d"]), 13, 1100)
	_fit("survey report (2 lines)", _prefixed("in_"), 14, 1000)
	_fit("terminal intel hint", _keys(["tm_use_intel", "tm_intel", "tm_repaid"]), 13, 1300)
	_fit("milestone", _keys(["tm_paid_off"]), 22, 1700, "Medium")
	_fit("notes panel", _prefixed("nt_"), 16, 600)
	_fit("on-site messages", _keys(["item_none", "item_repaired", "item_spare", "ring_no_target", "ring_fired", "hatch_welded", "snapped"]), 16, 900)
	var copy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Copy.FILE))
	var reasons: Array = []
	var logs: Array = []
	for id in copy:
		if not copy[id] is Array:
			continue
		if id.begins_with("R_"):
			reasons.append_array(copy[id])
		elif id.begins_with("G_log") or id.begins_with("X_log"):
			logs.append_array(copy[id])
	_fit("offer reason (2 lines)", reasons, 15, 1000)
	_fit("offer log (2 lines)", logs, 14, 980)
	# settings rows: label on the left, value between the arrows
	_fit("settings label", _keys(["s_vol_master", "s_vol_music", "s_vol_sfx", "s_quality", "s_lang", "s_back"]), 18, 360)
	_fit("settings value", _keys(["s_q_high", "s_q_low"]) + ["中文", "ENGLISH", "100%"], 18, 140, "Medium")
	_fit("settings keys", _keys(["s_keys"]), 13, 900)
	_fit("toolbar", _keys(["tool_1", "tool_2", "tool_3", "tool_4", "tool_5"]), 15, 122)
	# the tier buttons on the contract card
	var tb: Array = []
	for tr in Txt.TIERS:
		for s in _both("tier_" + tr):
			tb.append("1  " + s)
	_fit("tier button", tb, 15, 228, "Medium")
	_fit("tier description", _prefixed("tier_desc_"), 11, 228)
	_fit("contract card", _keys(["tier_rule", "c_title", "c_title_n", "c_log_n", "c_fee_n"]) + _prefixed("c_req"), 15, 804)
	# Liang's radio: two lines of 700 px at most (keep a margin for wrapping)
	var radio: Array = _prefixed("as_") + _prefixed("rc_") + _prefixed("ex_l") + _keys(["ex_hint_cost", "ex_free", "ex_broken", "ex_a", "ex_bc", "tier_now"])
	var course: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://ships/ts1_course.json"))
	for id in course.get("lines", {}):
		var ln: Dictionary = course.lines[id]
		radio.append(ln.get("zh", ""))
		radio.append(ln.get("en", ""))
	var gr7: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://ships/gr7.json"))
	var st: Dictionary = gr7.get("story", {})
	for k in ["arrive", "start"]:
		radio.append_array(_pairs(st.get(k, [])))
	for k in st.get("lines", {}):
		radio.append(st.lines[k].zh)
		radio.append(st.lines[k].en)
	radio.append_array(_pairs(st.recorder.before) + _pairs(st.recorder.after))
	var ep: Dictionary = st.epilogue
	for g in ep.grade:
		radio.append_array(_pairs(ep.grade[g]))
	radio.append_array(_pairs([ep.echo, ep.echo_arc]) + _pairs(ep.closing) + _pairs(ep.terminal))
	for f in DirAccess.get_files_at("res://ships"):
		if f.begins_with("e07") and f.ends_with(".json"):
			radio.append_array(JSON.parse_string(FileAccess.get_file_as_string("res://ships/" + f)).exam.get("hint", []))
	_fit("radio (2 lines)", radio, 18, 1300)
	# one-off hints: two lines of 920 px
	var hints: Array = _prefixed("hint_")
	for k in gr7.get("hints", {}):
		hints.append_array(gr7.hints[k])
	_fit("hint (2 lines)", hints, 16, 1750)
	# the story's cards and the recording
	var rows: Array = []
	for b in st.banner:
		rows.append_array(b)
	_fit("banner", rows, 24, 540, "Medium")
	_fit("terminal card", st.recorder.card + _pairs([st.recorder.clue.title]), 16, 480, "Medium")
	_fit("recording", _sub(st.recorder.fragment) + _sub(ep.recording), 20, 1400)
	_fit("story card title", _titles(st.inspect), 12, 312)
	# the stamp title shrinks to fit, down to 18 px
	_fit("chapter stamp", _pairs([ep.chapter[0]]), 18, 300, "Medium")
	_fit("#002 card", _pairs(ep.next.rows) + _pairs([ep.next.name]), 16, 552)
	_fit("#002 to be continued", ep.next.tbc, 22, 552, "Medium")
	_fit("epilogue card", ep.card, 18, 1200, "Medium")
	# the assessment
	_fit("exam buttons", _keys(["ex_retake", "tut_contract", "tut_exam"]), 16, 260)
	_fit("exam brief", _keys(["ex_goal"]), 18, 620, "Medium")
	_fit("exam brief", _keys(["ex_known", "ex_q"]), 14, 620)
	_fit("review what", _prefixed("rv_w_"), 16, 680, "Medium")
	_fit("review why", _prefixed("rv_y_"), 13, 680)
	_fit("exam grade line", _prefixed("ex_g_"), 15, 900)
	# settlement rows and the training task list
	_fit("settlement row", _prefixed("e_"), 17, 380)
	var steps: Array = []
	var heads: Array = []
	for l in course.lessons:
		heads.append(l.title.zh)
		heads.append(l.title.en)
		for s in l.steps:
			steps.append(s.text.zh)
			steps.append(s.text.en)
	_fit("task list step", steps, 17, 560)
	_fit("task list lesson", heads, 22, 520, "Medium")


func _sub(lines: Array) -> Array:
	var out: Array = []
	for l in lines:
		out.append(l[2])
		out.append(l[3])
	return out


func _titles(items: Array) -> Array:
	var out: Array = []
	for it in items:
		out.append_array(it.title)
	return out
