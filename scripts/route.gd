class_name Route
extends RefCounted
# What the career can reach next (P.8, player 2026-10-18: "I don't know what to
# work towards"): the ships in the order they open, what money buys for the
# drone and the berth, the skill book's volumes; each with its conditions and
# how far along each one is. The player pins up to two of them as the goals the
# terminal keeps showing; the skill book's savings goal is one of them, and an
# empty slot shows whatever is closest.
# Node: {key, kind ship|buy|tier|skill, row, name, conds [{label, now, frac, ok}],
#        done, ready, note}

const MAX_PINS := 2
# the rows of the route page, top to bottom
const ROW_BUY := 0       # and 1: what money buys, cheapest first, two rows
const ROW_SHIP := 2
const ROW_TIER := 3
const PER_ROW := 7
# what each upgrade and facility does, point by point (player 2026-10-18:
# "at least give every upgrade point, the details"); %s is the mark key
const POINTS := {
	"net05": [["碎屑网自动收的碎片：0.1 t → 0.5 t", "Debris the net takes by itself: 0.1 t → 0.5 t"], ["更多碎片不用亲手拖", "More small debris you needn't tow"]],
	"zones": [["现场按 K 划禁入区，最多 3 个", "Press K on site for a keep-out zone, up to 3"], ["搬运机、机械臂、吊车都不进去", "Haulers, the arm and the crane stay out"], ["在区内再按 K 取消", "K inside one clears it"]],
	"pump2": [["抽气速度：1× → 2×", "Gas draw: 1× → 2×"], ["抽液速度：1× → 2×", "Fluid draw: 1× → 2×"]],
	"scan_kit": [["检查设备时显示完好度", "Inspection shows equipment condition"], ["能发现结构暗伤（旧焊缝裂纹）", "Finds hidden structural damage (old weld cracks)"]],
	"buffer": [["船坞近端上方加一个停放台", "A parking deck over the near end of the berth"], ["放上去的件被牵引场定住", "What you leave on it is held by a tractor field"], ["等你或机器来取", "Until you or a machine come for it"]],
	"mouth_rail": [["熔炉口装上导轨", "The furnace mouth goes on a rail"], ["现场按 M 挪到无人机正下方", "Press M on site to run it under the drone"]],
	"grapple5": [["抓钩上限：3 t → 5 t", "Grapple limit: 3 t → 5 t"], ["切下来的大块不用再切小", "Big cut-off chunks needn't be cut smaller"]],
	"hauler": [["一台搬运无人机：用 %s 给漂浮零件打标记", "A hauling drone: mark floating pieces with %s"], ["它自己送到该去的回收口", "It takes them to the right mouth itself"], ["1.5 t 以内", "Up to 1.5 t"]],
	"port2": [["船坞远端上方再开一个设备口", "A second equipment mouth over the far end"], ["长船后半截的设备不用绕远", "No long trip from a long ship's stern"]],
	"hauler2": [["第二台搬运无人机", "A second hauling drone"], ["和第一台分着搬同一张标记清单", "Works the same marks as the first"], ["要先有初级搬运无人机", "Needs the basic hauler first"]],
	"arm": [["悬臂上装一只回收机械臂", "A recovery arm on the boom"], ["自动把废金属送进熔炉", "Feeds scrap to the furnace by itself"], ["初级：慢，1 t 以内", "Basic: slow, up to 1 t"]],
	"crane": [["船坞顶上的门式吊", "An overhead gantry crane"], ["12 t 以内整件吊走", "Lifts whole pieces up to 12 t"], ["用 %s 标记超过 1.5 t 的件给它", "Mark anything over 1.5 t for it with %s"]],
	"berth88": [["船坞延长到约 88 m", "The berth extended to about 88 m"], ["能接 58–82 m 的船：M-14、MED-47、FR-26", "Takes ships of 58–82 m: M-14, MED-47, FR-26"], ["回收口挪到中段", "The mouths move mid-berth"]],
}


# its points in the current language
static func points(id: String) -> Array:
	var out: Array = []
	for p in POINTS.get(id, []):
		var s: String = p[0] if Txt.zh else p[1]
		if s.contains("%s"):
			s = s % Keys.label("mark")
		out.append(s)
	return out


static func _tx(pair: Array) -> String:
	return str(pair[0]) if Txt.zh else str(pair[1])


static func _cond(label: String, now: String, frac: float, ok: bool) -> Dictionary:
	return {"label": label, "now": now, "frac": clampf(frac, 0.0, 1.0), "ok": ok}


# the ships in the order a career meets them: the opening first, then by reputation
static func ships() -> Array:
	var order: Array = []
	for e in Market.POOL:
		var oi := 99
		for i in Career.OPENING.size():
			if Career.OPENING[i].ship == e[0]:
				oi = i
		order.append([int(e[2]), oi, order.size(), e])
	order.sort_custom(func(p, q): return p[0] < q[0] if p[0] != q[0] else (p[1] < q[1] if p[1] != q[1] else p[2] < q[2]))
	return order.map(func(o): return o[3])


static func ship_node(e: Array) -> Dictionary:
	var d := Career.data
	var id: String = e[0]
	var rep := int(d.get("rep", 0))
	var ty := Market.type_of(id)
	var conds: Array = []
	if int(e[2]) > 0:
		conds.append(_cond(Txt.t("rt_rep"), "%d / %d" % [rep, int(e[2])], float(rep) / float(e[2]), rep >= int(e[2])))
	if float(ty.get("length", 0.0)) > Dock.STANDARD - 6.0:
		var has: bool = d.get("upgrades", {}).has("berth88")
		conds.append(_cond(Txt.t("rt_berth"), Txt.t("rt_have") if has else Txt.t("rt_need_berth"), 1.0 if has else 0.0, has))
	var opening := false
	for o in Career.OPENING:
		if o.ship == id:
			opening = true
	var market: bool = d.get("market", false)
	if not opening:
		conds.append(_cond(Txt.t("rt_market"), Txt.t("rt_have") if market else Txt.t("rt_market_after"), 1.0 if market else 0.0, market))
	var stripped := 0
	for h in d.get("history", []):
		if str(h.get("ship", "")) == id:
			stripped += 1
	var done := conds.all(func(c): return c.ok)
	var title: Array = Ship.load_data(id).get("title", [id, id])
	return {"key": "ship:" + id, "kind": "ship", "row": ROW_SHIP, "id": id, "name": _tx(title),
		"cls": str(ty.get("class", id.to_upper())), "short": _tx(ty.get("name", [id, id])), "length": float(ty.get("length", 0.0)),
		"conds": conds, "done": done, "ready": done, "stripped": stripped, "opening": opening,
		"note": Txt.t("rt_ship_" + id) if Txt.has("rt_ship_" + id) else ""}


# what money buys: the upgrades and the berth's facilities, owned ones too (the map stays put)
static func buys() -> Array:
	var list: Array = []
	for it in Terminal.SHOP + Terminal.BERTH:
		if it[1] in ["upgrade", "facility"]:
			list.append(it)
	list.sort_custom(func(p, q): return float(p[2]) < float(q[2]) if float(p[2]) != float(q[2]) else str(p[0]) < str(q[0]))
	return list


static func buy_node(it: Array) -> Dictionary:
	var d := Career.data
	var money := float(d.get("money", 0.0))
	var price := float(it[2])
	var owned: bool = d.get("upgrades", {}).has(it[0])
	var conds: Array = []
	conds.append(_cond(Txt.t("rt_money"), "%s / %s" % [Pal.money(money), Pal.money(price)], 1.0 if owned else money / price, owned or money >= price))
	if Terminal.REQUIRES.has(it[0]):
		var need: String = Terminal.REQUIRES[it[0]]
		var has: bool = d.get("upgrades", {}).has(need)
		conds.append(_cond(Txt.t("rt_first"), _need_name(need), 1.0 if has else 0.0, has))
	return {"key": "buy:" + str(it[0]), "kind": "buy", "row": ROW_BUY, "id": it[0], "name": Txt.t(it[3]), "price": price,
		"conds": conds, "done": owned, "ready": not owned and conds.all(func(c): return c.ok), "note": Txt.t(it[4]) if it.size() > 4 else "",
		"page": 1}


static func _need_name(id: String) -> String:
	for it in Terminal.SHOP + Terminal.BERTH:
		if it[0] == id:
			return Txt.t(it[3])
	return id


# the skill book's volumes II and III: completed jobs and reputation
static func tier_node(n: int) -> Dictionary:
	var d := Career.data
	var jobs := int(d.get("done", 0))
	var rep := int(d.get("rep", 0))
	var conds := [
		_cond(Txt.t("rt_jobs"), "%d / %d" % [jobs, Growth.DONE[n]], float(jobs) / float(Growth.DONE[n]), jobs >= Growth.DONE[n]),
		_cond(Txt.t("rt_rep"), "%d / %d" % [rep, Growth.REP[n]], float(rep) / float(Growth.REP[n]), rep >= Growth.REP[n]),
	]
	var done := conds.all(func(c): return c.ok)
	return {"key": "tier:%d" % n, "kind": "tier", "row": ROW_TIER, "id": str(n), "name": Txt.t("rt_tier_%d" % n),
		"conds": conds, "done": done, "ready": done, "note": Txt.t("rt_tier_d")}


# a skill pinned from the skill book: its next volume
static func skill_node(id: String) -> Dictionary:
	var row := Growth.find_track(id)
	if row.is_empty():
		return {}
	var d := Career.data
	var n := Growth.level(d.get("upgrades", {}), id)
	if n >= 3:
		return {"key": "skill:" + id, "kind": "skill", "row": -1, "id": id, "name": Growth.text(row[2]), "conds": [], "done": true, "ready": false, "note": ""}
	var target := n + 1
	var conds: Array = []
	if Growth.DONE[target] > 0:
		var jobs := int(d.get("done", 0))
		conds.append(_cond(Txt.t("rt_jobs"), "%d / %d" % [jobs, Growth.DONE[target]], float(jobs) / float(Growth.DONE[target]), jobs >= Growth.DONE[target]))
	if Growth.REP[target] > 0:
		var rep := int(d.get("rep", 0))
		conds.append(_cond(Txt.t("rt_rep"), "%d / %d" % [rep, Growth.REP[target]], float(rep) / float(Growth.REP[target]), rep >= Growth.REP[target]))
	var money := float(d.get("money", 0.0))
	var price := Growth.price(id)
	conds.append(_cond(Txt.t("rt_money"), "%s / %s" % [Pal.money(money), Pal.money(price)], money / price, money >= price))
	return {"key": "skill:" + id, "kind": "skill", "row": -1, "id": id, "name": Growth.text(row[2]) + " " + ["I", "II", "III"][target - 1],
		"conds": conds, "done": false, "ready": conds.all(func(c): return c.ok), "note": "", "page": 3}


# everything on the route page, in drawing order: two rows of buys, the ships, the volumes
static func nodes() -> Array:
	var out: Array = []
	var bs := buys()
	for i in bs.size():
		var n := buy_node(bs[i])
		n.row = ROW_BUY + i / PER_ROW
		n.col = i % PER_ROW
		out.append(n)
	var sh := ships()
	for i in sh.size():
		var n := ship_node(sh[i])
		n.col = i
		out.append(n)
	for k in [2, 3]:
		var n := tier_node(k)
		n.col = k - 2
		out.append(n)
	return out


static func find(key: String) -> Dictionary:
	if key.begins_with("skill:"):
		return skill_node(key.substr(6))
	for n in nodes():
		if n.key == key:
			return n
	return {}


# how far along: the least advanced of its conditions
static func progress(n: Dictionary) -> float:
	var k := 1.0
	for c in n.get("conds", []):
		k = minf(k, float(c.frac))
	return k


# what the player pinned; the skill book's savings goal counts as one of them
static func pins() -> Array:
	var d := Career.data
	var out: Array = []
	for k in d.get("route_goals", []):
		if str(k) not in out:
			out.append(str(k))
	var g: String = str(d.get("growth_goal", ""))
	if g != "" and ("skill:" + g) not in out and out.size() < MAX_PINS:
		out.append("skill:" + g)
	return out.slice(0, MAX_PINS)


static func pinned(key: String) -> bool:
	return key in pins()


# pin or unpin; a third pin pushes the oldest out. Returns false if it could not be saved.
static func toggle(key: String) -> bool:
	var d := Career.data
	var before_goals: Array = d.get("route_goals", []).duplicate()
	var before_growth: String = str(d.get("growth_goal", ""))
	var list := pins()
	if key in list:
		list.erase(key)
	else:
		list.append(key)
		while list.size() > MAX_PINS:
			list.remove_at(0)
	d.route_goals = list
	# the skill book shows the pinned skill as its savings goal
	var skill := ""
	for k in list:
		if str(k).begins_with("skill:"):
			skill = str(k).substr(6)
	d.growth_goal = skill
	if Career.save():
		return true
	d.route_goals = before_goals
	d.growth_goal = before_growth
	return false


# the skill book set its savings goal: it takes the skill slot among the pins
static func pin_skill(id: String) -> void:
	var d := Career.data
	var list: Array = pins().filter(func(k): return not str(k).begins_with("skill:"))
	list.append("skill:" + id)
	while list.size() > MAX_PINS:
		list.remove_at(0)
	d.route_goals = list


# the one or two goals the terminal shows: the pins still open, then the closest
static func goals() -> Array:
	var out: Array = []
	for k in pins():
		var n := find(k)
		if not n.is_empty() and not n.done:
			n.pinned = true
			out.append(n)
	if out.size() >= MAX_PINS:
		return out
	var rest: Array = nodes().filter(func(n): return not n.done and not out.any(func(o): return o.key == n.key))
	# what is still to be earned comes first; ready ones only fill what's left
	rest.sort_custom(func(p, q):
		if p.ready != q.ready:
			return q.ready
		return progress(p) > progress(q))
	for n in rest:
		if out.size() >= MAX_PINS:
			break
		n.pinned = false
		out.append(n)
	return out


# one line for a goal: what's still missing, or that it's ready
static func missing(n: Dictionary) -> String:
	if n.get("done", false):
		return Txt.t("rt_done")
	if n.get("ready", false):
		return Txt.t("rt_ready_buy") if n.kind in ["buy", "skill"] else Txt.t("rt_ready")
	var d := Career.data
	# a ship names everything it still waits for; the rest their first want
	if n.kind == "ship":
		var parts: Array = []
		for c in n.conds:
			if c.ok:
				continue
			if c.label == Txt.t("rt_rep"):
				parts.append(Txt.t("rt_short_rep") % (int(str(c.now).split(" / ")[1]) - int(d.get("rep", 0))))
			elif c.label == Txt.t("rt_berth"):
				parts.append(Txt.t("rt_short_berth"))
			else:
				parts.append(Txt.t("rt_short_market"))
		return " · ".join(parts)
	for c in n.conds:
		if c.ok:
			continue
		if c.label == Txt.t("rt_money"):
			var price := float(n.get("price", 0.0)) if n.kind == "buy" else Growth.price(str(n.id))
			return Txt.t("rt_short_money") % Pal.money(price - float(d.get("money", 0.0)))
		if c.label == Txt.t("rt_rep"):
			var need := int(str(c.now).split(" / ")[1])
			return Txt.t("rt_short_rep") % (need - int(d.get("rep", 0)))
		if c.label == Txt.t("rt_jobs"):
			var need := int(str(c.now).split(" / ")[1])
			return Txt.t("rt_short_jobs") % (need - int(d.get("done", 0)))
		return str(c.label) + " · " + str(c.now)
	return ""
