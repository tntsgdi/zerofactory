extends SceneTree
# Roadmap 2.6 acceptance: the same contract, taken apart by the paced bot
# (every operation and haul takes its time) with no upgrades and then with
# each of the first four on its own. Each must change the contract's time or
# its income by 10% or more. The contract is a market Heron chosen for the
# things the upgrades answer: an overloaded container (5 t grapple), a
# cracked rib in the hold (precision kit), gas and fluids to draw (pump),
# loose scrap (recovery arm).
# godot --headless --path . --fixed-fps 60 -s tests/upgrade_check.gd -- [only=<upgrade>]

const Bot = preload("res://tests/salvage_bot.gd")
const BOT := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
const KITS := [[], ["pump2"], ["scan_kit"], ["grapple5"], ["arm"]]
var fails := 0
var finished := false


func _initialize() -> void:
	_run()


func _process(_dt: float) -> bool:
	return finished


# The contracts measured: one market Heron with a pressurised hold, a cracked
# roof plate over a precision container and an overloaded container; for the
# 5 t grapple, one whose hold carries two overloaded containers.
func pick(heavy_n: int) -> Dictionary:
	for seed in range(1, 20000):
		var o := Market.offer_for(seed, {"rep": 30, "done": 5}, 2)
		o.traps = ["hidden_damage"]
		var d := Variant.make(Ship.load_data("gr7"), o)
		if not ContractValidator.check(d).ok:
			continue
		var heavy := 0
		var cargo := 0
		for c in Variant.CONTAINERS:
			var pd = Variant.piece(d, c)
			if pd != null:
				cargo += 1
				if float(pd.mass) > 3.0:
					heavy += 1
		var p7 = Variant.piece(d, "p7")
		var under: bool = p7 != null and Variant._bbox(p7.poly).position.x < 13.6
		if heavy >= heavy_n and cargo == 3 and d.variant.targets.hidden_damage == "p7" and under and d.labels.get("C-01", "") == "PRECISION" and float(d.gas.rooms.C) > 90.0:
			print("contract %s seed %d: %s" % [o.id, int(o.variant), str(d.variant.notes)])
			return o
		if heavy_n >= 2 and heavy >= 2 and cargo >= 2:
			print("contract %s seed %d: %s" % [o.id, int(o.variant), str(d.variant.notes)])
			return o
	return {}


func _play(o: Dictionary, kit: Array) -> Dictionary:
	var job := o.duplicate(true)
	job.kit = {}
	for k in kit:
		job.kit[k] = 1
	Game.contract = job
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = BOT.duplicate()
	root.add_child(scene)
	var bot = Bot.new(scene, {"paced": true})
	bot.timeout = 60000
	while not bot.step():
		await process_frame
	var s: Dictionary = bot.summary()
	s.income = scene.earned() - scene.losses
	scene.queue_free()
	for i in 3:
		await process_frame
	return s


func _run() -> void:
	var one := pick(1)
	var two := pick(2)
	print("  kit                time      income   hauls  arm  scrapped  snapped  incidents")
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5)
	for kit in KITS:
		if only != "" and (kit.is_empty() or kit[0] != only):
			continue
		var o: Dictionary = two if kit == ["grapple5"] else one
		var base: Dictionary = await _play(o, [])
		if not kit.is_empty():
			print("  (none)         %8.0f s  $%8d   %5d  %3d  %8d  %7d  %9d   %s" % [base.time, int(base.income), base.hauls, base.arm, base.scrapped, base.snapped, base.incidents, o.id])
		else:
			continue
		var s: Dictionary = await _play(o, kit)
		print("  %-14s %8.0f s  $%8d   %5d  %3d  %8d  %7d  %9d" % [",".join(kit), s.time, int(s.income), s.hauls, s.arm, s.scrapped, s.snapped, s.incidents])
		var dt: float = (base.time - s.time) / base.time
		var di: float = (s.income - base.income) / base.income
		var ok: bool = s.ended and (absf(dt) >= 0.1 or absf(di) >= 0.1)
		if not ok:
			fails += 1
		print("  [%s] %s: time %+.1f%%, income %+.1f%%" % ["PASS" if ok else "FAIL", kit[0], -dt * 100.0, di * 100.0])
	print("UPGRADES %s" % ("PASS" if fails == 0 else "FAIL"))
	finished = true
