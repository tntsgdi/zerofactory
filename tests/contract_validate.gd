extends SceneTree
# Roadmap 2.3 acceptance (and 2.4 with trap=<id>): random contracts drawn the
# way the market draws them go through VALIDATE CONTRACT. The static half
# (scripts/contract_validator.gd) throws some away — counted by reason. Every
# contract that passes it is then played for real: a save / load round trip,
# twenty seconds left alone (8× warp) with nothing happening, and the salvage bot
# taking the whole ship apart with no incident and nothing forced. Shards run
# side by side and write tests/out/contracts_<shard>.json; "report" adds them up.
# godot --headless --path . --fixed-fps 60 -s tests/contract_validate.gd -- from=0 count=250 [play_every=4] [trap=<id>] [shard=a]
# godot --headless --path . -s tests/contract_validate.gd -- report [prefix=contracts]

const Bot = preload("res://tests/salvage_bot.gd")
const Snap = preload("res://tests/snap_util.gd")
const BOT := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
var from := 0
var count := 10
var trap := ""
var ship := "gr7"              # the type drawn: one type, or "mix" the way the market mixes them
var shard := "a"
var prefix := "contracts"
var play_every := 1            # play only every n-th contract that passed the static checks
var only := ""                 # play just the contract with this id (replaying a failure)
var res := {"drawn": 0, "discarded": 0, "reasons": {}, "examples": {}, "played": 0, "passed": 0, "failed": [], "traps": {}, "problems": {}, "rates": []}
var finished := false


func _initialize() -> void:
	var report := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("from="):
			from = int(a.substr(5))
		elif a.begins_with("count="):
			count = int(a.substr(6))
		elif a.begins_with("ship="):
			ship = a.substr(5)
		elif a.begins_with("trap="):
			trap = a.substr(5)
		elif a.begins_with("shard="):
			shard = a.substr(6)
		elif a.begins_with("play_every="):
			play_every = int(a.substr(11))
		elif a.begins_with("only="):
			only = a.substr(5)
		elif a.begins_with("prefix="):
			prefix = a.substr(7)
		elif a == "report":
			report = true
	if report:
		_report()
		finished = true
		return
	SaveGame.path = "user://zp_test_contract_%s.json" % shard
	SaveGame.allow_test = true
	_run()


func _process(_dt: float) -> bool:
	return finished


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _spawn(job: Dictionary, load_it: bool) -> Node:
	Game.contract = job
	SaveGame.load_requested = load_it
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = BOT.duplicate()
	root.add_child(scene)
	return scene


# the contract a seed draws, the way the market draws it
func draw(seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var stars := rng.randi_range(1, 3)
	var career := {"rep": 30, "done": 5}
	var o := Market.offer(rng, career, stars, {}, "", Market.pick_ship(rng, career) if ship == "mix" else ship)
	if trap != "":
		# one trap on its own, on a fresh ship
		o.traps = [trap]
		o.erase("_ship")
		o._ship = Variant.make(Ship.load_data(o.ship), o)
	return o


func _run() -> void:
	# with a trap on its own, keep drawing until `count` ships have passed the static checks
	var i := from
	while (trap == "" and i < from + count) or (trap != "" and res.played < count and i < from + count * 4):
		var o := draw(7919 * (i + 1))
		i += 1
		var d: Dictionary = o._ship
		o.erase("_ship")
		res.drawn += 1
		for t in o.traps:
			res.traps[t] = res.traps.get(t, 0) + 1
		var v := ContractValidator.check(d)
		if not v.ok:
			res.discarded += 1
			for r in v.reasons:
				res.reasons[r] = res.reasons.get(r, 0) + 1
				if not res.examples.has(r):
					res.examples[r] = "%s %s: %s" % [o.id, str(o.traps), str(v.detail.slice(0, 2))]
			continue
		for p in Variant.problems(d):
			res.problems[p] = res.problems.get(p, 0) + 1
		res.accepted = int(res.get("accepted", 0)) + 1
		if (int(res.accepted) - 1) % play_every != 0 or (only != "" and o.id != only):
			continue
		var bad: Array = await _play(o)
		res.played += 1
		if bad.is_empty():
			res.passed += 1
		else:
			res.failed.append("%s %s seed %d: %s" % [o.id, str(o.traps), int(o.variant), "; ".join(bad)])
			print("  FAIL ", res.failed.back())
		if res.played % 10 == 0:
			print("  [%s] %d drawn, %d played, %d passed" % [shard, res.drawn, res.played, res.passed])
	var f := FileAccess.open(ProjectSettings.globalize_path("res://tests/out/%s_%s.json" % [prefix, shard]), FileAccess.WRITE)
	f.store_string(JSON.stringify(res))
	f.close()
	print("SHARD %s: %d drawn, %d discarded, %d played, %d passed" % [shard, res.drawn, res.discarded, res.played, res.passed])
	finished = true


# the dynamic checks; returns what went wrong
func _play(o: Dictionary) -> Array:
	var bad: Array = []
	# save round trip
	var g = _spawn(o, false)
	await _frames(40)
	SaveGame.save(g)
	var before := Snap.snap(g)
	g.queue_free()
	await _frames(1)
	Ship.clear_cache()
	g = _spawn(o, true)
	await _frames(1)
	var diff: Array = Snap.diff(before, Snap.snap(g))
	if not diff.is_empty():
		bad.append("save round trip: %s" % str(diff.slice(0, 2)))
	if g.job.get("id", "") != o.id:
		bad.append("loaded as another contract")
	# left alone
	var p0 := {}
	for n in g.world.rooms:
		p0[n] = g.sys.P(n)
	Engine.time_scale = 8.0
	await _frames(150)
	Engine.time_scale = 1.0
	if not g.incidents.is_empty():
		bad.append("left alone: %s" % str(g.incidents))
	if not g.world.bodies.is_empty():
		bad.append("left alone: %d pieces broke loose" % g.world.bodies.size())
	for n in p0:
		if p0[n] > 1.0 and absf(g.sys.P(n) - p0[n]) > p0[n] * 0.02:
			bad.append("left alone: room %s %.0f -> %.0f kPa" % [n, p0[n], g.sys.P(n)])
	# the bot takes it apart
	var bot = Bot.new(g)
	while not bot.step():
		await process_frame
	await _frames(3)
	var s: Dictionary = bot.summary()
	res.rates.append(snappedf(s.rate, 0.001))
	if not s.ended:
		var left: Array = []
		for b in g.world.bodies:
			if is_instance_valid(b) and left.size() < 3:
				left.append("%s at %s%s" % [str(b.pieces.map(func(p): return p.tag)), str(((b.global_transform * b.center_of_mass) / Geom.M).snapped(Vector2(0.1, 0.1))), " (taken)" if b.capture != null else ""])
		bad.append("bot did not finish (%s; still loose: %s)" % [str(bot.notes.slice(-3)), str(left)])
	if s.incidents > 0:
		bad.append("incidents: %s" % str(g.incidents))
	if s.forced > 0:
		bad.append("bot had to force: %s" % str(bot.notes.slice(-3)))
	if not g.all_mandatory_ok():
		bad.append("named items not recovered whole")
	g.queue_free()
	await _frames(2)
	for ext in ["", ".bak", ".tmp", ".done", ".bak.done"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.path + ext))
	return bad


func _report() -> void:
	var tot := {"drawn": 0, "discarded": 0, "reasons": {}, "examples": {}, "played": 0, "passed": 0, "failed": [], "traps": {}, "problems": {}, "rates": []}
	for f in DirAccess.get_files_at("res://tests/out"):
		if not f.begins_with(prefix + "_") or not f.ends_with(".json"):
			continue
		var r: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/out/" + f))
		for k in ["drawn", "discarded", "played", "passed", "accepted"]:
			tot[k] = int(tot.get(k, 0)) + int(r.get(k, 0))
		for k in ["reasons", "traps", "problems"]:
			for x in r[k]:
				tot[k][x] = tot[k].get(x, 0) + int(r[k][x])
		tot.examples.merge(r.examples)
		tot.failed.append_array(r.failed)
		tot.rates.append_array(r.rates)
	print("VALIDATE CONTRACT: %d contracts drawn" % tot.drawn)
	print("  discarded by the static checks: %d (%.1f%%)" % [tot.discarded, tot.discarded * 100.0 / maxi(1, tot.drawn)])
	for k in tot.reasons:
		print("    %-22s %4d   e.g. %s" % [k, tot.reasons[k], tot.examples.get(k, "")])
	print("  traps drawn: ", tot.traps)
	print("  passed the static checks: %d" % int(tot.get("accepted", 0)))
	print("  played by the bot: %d, taken apart safely: %d (%.1f%%)" % [tot.played, tot.passed, tot.passed * 100.0 / maxi(1, tot.played)])
	if not tot.rates.is_empty():
		var s := 0.0
		var lo := 1.0
		for x in tot.rates:
			s += x
			lo = minf(lo, x)
		print("  recovery: mean %.1f%%, lowest %.1f%%" % [s * 100.0 / tot.rates.size(), lo * 100.0])
	for f in tot.failed.slice(0, 20):
		print("    FAIL ", f)
	var ok: bool = tot.played > 0 and tot.passed == tot.played
	print("CONTRACTS %s" % ("PASS" if ok else "FAIL"))
	quit()
