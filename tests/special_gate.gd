extends SceneTree
# The special courses' gate (design/新手教程与图鉴定案.md Q10/Q15/Q16/Q17/Q23), on a
# test career: which families a ship needs; a contract taken on HB-86 (two families)
# runs both courses back to back and then the contract itself; the bonus is paid
# the first time only; an old save that already worked an FX-70 comes certified for
# stored energy, without the bonus; a family never worked still needs its course.
# godot --headless --path . -s tests/special_gate.gd

var fails: Array = []
var step := 0
var t := 0


func _fail(s: String) -> void:
	fails.append(s)
	print("  FAIL ", s)


func _initialize() -> void:
	Career.path = "user://zp_test_gate_career.json"
	SaveGame.path = "user://zp_test_gate_save.json"
	SaveGame.train_path = "user://zp_test_gate_training.json"
	for f in [Career.path, SaveGame.path, SaveGame.train_path]:
		for ext in ["", ".bak", ".tmp", ".old"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	Codex.mem = {"seen": {}, "new": {}, "certs": {}}
	# which families each ship needs
	var want := {"fx70": ["energy"], "hb86": ["atmos", "precise"], "ps12": ["energy", "precise"], "gr7": [], "s09": [], "tug": [], "dr150": ["fluid"], "lc140": ["isolate"]}
	for sid in want:
		if Codex.classes_of(sid) != want[sid]:
			_fail("%s needs %s, not %s" % [sid, str(Codex.classes_of(sid)), str(want[sid])])
	# a career with HB-86 taken (fee paid), no certificates yet
	Career.data = Career.fresh()
	Career.data.certs_checked = true
	Career.data.market = true
	Career.data.money = 10000.0
	Career.data.active = {"id": "T-HB", "ship": "hb86", "fee": 0.0, "fee_paid": true, "time": 3600.0, "value": 1.0}
	Career.save()
	if Codex.missing("hb86") != ["atmos", "precise"]:
		_fail("missing for HB-86: %s" % str(Codex.missing("hb86")))
	Game.play_career(self)


func _process(_dt: float) -> bool:
	t += 1
	var g = current_scene
	match step:
		0:
			if t > 30 and g != null and g.get("ship_id") != null:
				if g.ship_id != "sp_atmos":
					_fail("HB-86 taken: the first course is %s, not sp_atmos" % g.ship_id)
				if Game.course_chain != ["precise"] or Game.course_then != "contract":
					_fail("chain %s then %s" % [str(Game.course_chain), Game.course_then])
				if g.menu_open == false and g.hud != null:
					var items: Array = g.hud._menu_items().map(func(it): return it[0])
					if "skip" in items:
						_fail("a special course offers to skip it")
				# pass it: the certificate, the bonus
				var m0 := float(Career.data.money)
				g.tutorial._finish()
				if not Codex.certified("atmos"):
					_fail("atmos not certified after its course")
				if absf(float(Career.data.money) - m0 - Codex.BONUS) > 0.5:
					_fail("first pass paid %.0f, not %.0f" % [float(Career.data.money) - m0, Codex.BONUS])
				if Codex.certify("atmos") != 0.0:
					_fail("a second pass would pay again")
				g.after_special()
				step = 1
				t = 0
		1:
			if t > 30 and g != null and g.get("ship_id") != null:
				if g.ship_id != "sp_precise":
					_fail("the second course is %s, not sp_precise" % g.ship_id)
				g.tutorial._finish()
				g.after_special()
				step = 2
				t = 0
		2:
			if t > 30 and g != null and g.get("ship_id") != null:
				if g.ship_id != "hb86":
					_fail("after both courses the contract did not start (%s)" % g.ship_id)
				if g.job.get("id", "") != "T-HB":
					_fail("the contract that started is %s, not T-HB" % str(g.job.get("id", "")))
				_veteran()
				print("SPECIAL GATE %s  (%d problems)" % ["PASS" if fails.is_empty() else "FAIL", fails.size()])
				for f in [Career.path, SaveGame.path, SaveGame.train_path]:
					for ext in ["", ".bak", ".tmp"]:
						DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
				return true
	if t > 60 * 30:
		_fail("timed out at step %d" % step)
		print("SPECIAL GATE FAIL")
		return true
	return false


# an old save: the history decides
func _veteran() -> void:
	Career.data = Career.fresh()
	Career.data.erase("certs_checked")
	Career.data.history = [{"id": "A", "ship": "fx70", "grade": 2, "scope": "full"}, {"id": "B", "ship": "dr150", "grade": 0, "scope": "full"}, {"id": "C", "ship": "ob90", "grade": 2, "scope": "section"}]
	Career.save()
	Career.data = {}
	var m0 := 0.0
	Career.load_or_new()
	m0 = float(Career.data.money)
	if str(Codex._certs().get("energy", "")) != "auto":
		_fail("an old save with an FX-70 done is not certified for stored energy")
	if Codex.certified("fluid"):
		_fail("a failed DR-150 certified fluids")
	if Codex.certified("precise"):
		_fail("a section job on OB-90 certified precision parts")
	if float(Career.data.money) != m0:
		_fail("the old save was paid a bonus")
	if not Codex.missing("cl104").has("cryo"):
		_fail("a family never worked does not need its course")
