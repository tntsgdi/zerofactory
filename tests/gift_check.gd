extends SceneTree
# 开局第一关（第一单合同）结算完，白送一台初级搬运无人机（career.gd GIFT_HAULER_AFTER）：
# 只送一次，而且送完下一单的现场装配里就有它——第二关就能用上拖运，不用先攒 45,000。
# Test files only.
# godot --path . -s tests/gift_check.gd

var fails := 0


func _initialize() -> void:
	Career.path = "user://zp_test_gift_career.json"
	SaveGame.path = "user://zp_test_gift_save.json"
	SaveGame.train_path = "user://zp_test_gift_training.json"
	for f in [Career.path, SaveGame.path, SaveGame.train_path]:
		for ext in ["", ".bak", ".tmp", ".old"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	_run()


func check(ok: bool, message: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		fails += 1


# 一单合同的结算报表，只填结算真正要用的字段
func _report(earned: float) -> Dictionary:
	return {"earned": earned, "losses": 0.0, "rate": 0.99, "grade": 2, "time": 300.0, "fee": 0.0, "bonus": 0.0}


func _run() -> void:
	check(Career.GIFT_HAULER_AFTER == 1, "赠送挂在第一关之后（GIFT_HAULER_AFTER = 1）")
	Career.data = Career.fresh()
	check(not Career.data.upgrades.has("hauler"), "新生涯开局没有搬运无人机")

	# 第一关：工作拖船
	var a := Career.opening(0)
	check(a.get("id", "") == "TUG-001", "第一关是 TUG-001")
	Career.data.active = a
	Career.sign_active()
	check(not Career.data.active.get("kit", {}).has("hauler"), "第一关现场还没有搬运无人机")

	var r: Dictionary = Career.settle(_report(4000.0))
	check(int(Career.data.done) == 1, "第一关已结算")
	check(Career.data.upgrades.has("hauler"), "第一关过了之后白送搬运无人机")
	check(r.get("granted", []) == ["hauler"], "结算结果带上了赠送的 id")
	check(bool(Career.data.get("first_gift", false)), "赠送在生涯里记了一笔")

	# 第二关：现场装配里应该有它
	Career.data.active = Career.opening(1)
	Career.sign_active()
	check(Career.data.active.get("kit", {}).has("hauler"), "第二关的现场装配里有搬运无人机")

	# 再结算一单：不会重复赠送
	var r2: Dictionary = Career.settle(_report(2000.0))
	check(r2.get("granted", []).is_empty(), "第二关结算不再赠送")
	check(int(Career.data.upgrades.get("hauler", 0)) == 1, "升级记录没被写坏")

	# 存档往返：赠送跟着生涯走
	Career.save()
	Career.data = {}
	Career.load_or_new()
	check(Career.data.upgrades.has("hauler"), "重新读档后搬运无人机还在")
	check(bool(Career.data.get("first_gift", false)), "重新读档后赠送记录还在")

	print("GIFT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(0 if fails == 0 else 1)
