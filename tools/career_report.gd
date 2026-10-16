extends SceneTree
# A save slot's contracts, for playtest analysis (V2 2.9): per contract the
# net, bonuses, grade, recovery rate, time and where it went (measure, cut,
# maintain, haul, fly, wait, menus), hand-work against engineering decisions
# against machine work, and the incidents by kind; totals at the end.
# Only reads the slot's career file.
# godot --headless --path . -s tools/career_report.gd -- [slot=1] [csv]

const TB := ["measure", "cut", "maintain", "haul", "fly", "wait", "menu"]


func _initialize() -> void:
	var slot := 1
	var csv := false
	var file := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("slot="):
			slot = int(a.substr(5))
		elif a == "csv":
			csv = true
		elif a.begins_with("file="):
			file = a.substr(5)
	var f := FileAccess.open(file if file != "" else Career.slot_files(slot)[0], FileAccess.READ)
	if f == null:
		print("no career in slot %d" % slot)
		quit()
		return
	var d = JSON.parse_string(f.get_as_text())
	var hist: Array = d.get("history", []) if d is Dictionary else []
	if csv:
		print("id,ship,scope,goal,stars,net,bonus,grade,rate,time_s," + ",".join(TB) + ",manual,decision,machine,incidents")
	else:
		print("SLOT %d · %s · %d contracts" % [slot, d.get("company", ""), hist.size()])
	var tot := {"net": 0.0, "time": 0.0, "manual": 0, "decision": 0, "machine": 0, "inc": {}}
	for h in hist:
		var sh: Dictionary = Game.op_share(h.get("ops", {}))
		var tb: Dictionary = h.get("time_by", {})
		var inc := {}
		for i in h.get("incidents", []):
			inc[str(i[1])] = int(inc.get(str(i[1]), 0)) + 1
			tot.inc[str(i[1])] = int(tot.inc.get(str(i[1]), 0)) + 1
		tot.net += float(h.get("net", 0.0))
		tot.time += float(h.get("time", 0.0))
		tot.manual += int(sh.manual)
		tot.decision += int(sh.decision)
		tot.machine += int(sh.machine)
		if csv:
			var cells: Array = [h.get("id", ""), h.get("ship", ""), h.get("scope", "full"), h.get("goal", ""), h.get("stars", 0), int(h.get("net", 0)), int(h.get("bonus", 0)),
				h.get("grade", 0), snappedf(float(h.get("rate", 0.0)), 0.001), int(h.get("time", 0))]
			for k in TB:
				cells.append(int(tb.get(k, 0)))
			cells.append_array([sh.manual, sh.decision, sh.machine, JSON.stringify(inc).replace(",", ";")])
			print(",".join(cells.map(func(x): return str(x))))
			continue
		var tsum := 0.0
		for k in TB:
			tsum += float(tb.get(k, 0.0))
		var parts: Array = []
		for k in TB:
			if float(tb.get(k, 0.0)) > 0.0:
				parts.append("%s %d%%" % [k, int(round(100.0 * float(tb[k]) / maxf(tsum, 1.0)))])
		print("%-12s %-5s %-8s %-9s %d★  net $%7d  bonus $%6d  grade %d  rate %5.1f%%  %5.1f min" % [h.get("id", ""), h.get("ship", ""), h.get("scope", "full"), h.get("goal", ""),
			int(h.get("stars", 0)), int(h.get("net", 0)), int(h.get("bonus", 0)), int(h.get("grade", 0)), float(h.get("rate", 0.0)) * 100.0, float(h.get("time", 0.0)) / 60.0])
		print("    time: %s" % ("  ".join(parts) if not parts.is_empty() else "(not recorded)"))
		print("    hands: %d repetitive / %d decisions / %d by machine (%.0f%% repetitive)   incidents: %s" % [sh.manual, sh.decision, sh.machine, sh.share * 100.0, JSON.stringify(inc)])
	if not csv and not hist.is_empty():
		var hands: int = tot.manual + tot.decision
		print("TOTAL  net $%d  %.1f min  %d repetitive / %d decisions / %d by machine (%.0f%% repetitive)  incidents %s" % [int(tot.net), tot.time / 60.0, tot.manual, tot.decision, tot.machine,
			100.0 * tot.manual / maxf(hands, 1), JSON.stringify(tot.inc)])
	quit()
