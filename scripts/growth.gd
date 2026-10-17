class_name Growth
# The book is both the catalogue and the authority for purchases/effects.
# Each volume includes the technique and its fitted module; no second currency.
const GROUPS := [["无人机", "DRONE"], ["激光切割", "LASER"], ["抓钩", "GRAPPLE"], ["测量仪", "METER"], ["气液回收", "RECOVERY"], ["维修工具", "SERVICE"]]
# id, group, name zh/en, unit, baseline and three levels, incremental prices, use zh/en
const TRACKS := [
	["armor", 0, ["复合装甲", "Composite armour"], "%", [100, 88, 74, 60], [9000, 48000, 285000], ["承受的所有伤害；越低越耐用。", "All incoming damage; lower means tougher."]],
	["drive", 0, ["矢量推进", "Vector thrusters"], "×", [1.0, 1.15, 1.32, 1.5], [12000, 63000, 375000], ["巡航、冲刺、加速和制动同步增强。", "Cruise, boost, acceleration and braking improve together."]],
	["shield", 0, ["电弧护盾", "Arc shielding"], "%", [100, 75, 50, 30], [16000, 72000, 420000], ["电弧和带电拔线伤害；仍需断电。", "Arc and live unplug damage; isolate power first."]],
	["laser_power", 1, ["切割功率", "Cutting power"], "×", [1.0, 1.25, 1.6, 2.0], [14000, 75000, 435000], ["材料内的实际切割速度。", "Actual beam travel speed through material."]],
	["laser_kerf", 1, ["精细切口", "Fine kerf"], "px", [3.4, 2.8, 2.1, 1.5], [18000, 87000, 495000], ["切口半径；更少材料被烧掉，仍会切断管线。", "Kerf radius; wastes less metal, still severs lines."]],
	["thermal", 1, ["隔热组件", "Thermal insulation"], "%", [100, 80, 55, 35], [10000, 54000, 315000], ["烫伤、火焰和爆燃对无人机的伤害。", "Scald, fire and combustion damage to the drone."]],
	["grapple_mass", 2, ["重载抓钩", "Heavy grapple"], "t", [3, 5, 6.5, 8], [38000, 97500, 465000], ["提高可牵引吨位；高阶同时增强最大牵引力。", "Raises the mass limit; advanced volumes also strengthen towing force."]],
	["grapple_range", 2, ["长距牵引", "Extended tether"], "m", [4, 5, 6.5, 8], [8000, 45000, 270000], ["抓取、拖曳目标和断绳距离同步增加。", "Acquisition, towing target and snap distance grow together."]],
	["grapple_stable", 2, ["牵引阻尼", "Tether damping"], "×", [1.0, 1.12, 1.26, 1.4], [11000, 57000, 330000], ["增加牵引阻尼并减轻无人机受到的反作用力。", "More tether damping and less recoil on the drone."]],
	["meter_range", 3, ["远程读数", "Remote probing"], "m", [6, 8, 10, 12], [6000, 39000, 240000], ["可见目标的读数距离；不透视未打开的舱室。", "Probe visible targets farther away; no seeing through sealed rooms."]],
	["meter_speed", 3, ["精密检测", "Precision inspection"], "s", [0.42, 0.32, 0.22, 0.12], [24000, 69000, 390000], ["检测耗时；首级含原精密套件，可查裂纹和设备状况。读数仍会过期。", "Probe time; volume I includes crack and condition inspection. Readings can still go stale."]],
	["pump_rate", 4, ["高效泵组", "High flow pumps"], "×", [1, 2, 2.8, 3.6], [22000, 81000, 450000], ["每条软管的气体与液体回收速度。", "Gas and liquid recovery speed for each attached hose."]],
	["hose_range", 4, ["延长接管", "Hose reach"], "m", [4, 5.5, 7, 9], [7000, 42000, 255000], ["远处接口的接管距离；已接软管照常独立工作。", "Connect more distant ports; attached hoses keep working independently."]],
	["wrench_speed", 5, ["快拆工法", "Quick service"], "×", [1, 1.25, 1.65, 2.2], [8000, 45000, 285000], ["螺栓、锁、夹具、接头及控制件的操作速度。", "Operate bolts, locks, clamps, connectors and controls faster."]],
	["repair_eff", 5, ["维修剂配方", "Repair compound"], "HP", [50, 65, 80, 100], [6000, 36000, 225000], ["每份维修剂的恢复量；机库维修依旧免费。", "Integrity restored per repair kit; bay repair remains free."]],
]
const LEGACY := {"grapple_mass": "grapple5", "meter_speed": "scan_kit", "pump_rate": "pump2"}
const DONE := [0, 0, 3, 8]
const REP := [0, 0, 6, 16]

static func text(pair: Array) -> String:
	return str(pair[0] if Txt.zh else pair[1])

static func find_track(id: String) -> Array:
	for row in TRACKS:
		if row[0] == id:
			return row
	return []

static func level(kit: Dictionary, id: String) -> int:
	var n := clampi(int(kit.get("skill_" + id, 0)), 0, 3)
	if LEGACY.has(id) and int(kit.get(LEGACY[id], 0)) > 0:
		n = maxi(n, 1)
	return n

static func value(kit: Dictionary, id: String) -> float:
	var row := find_track(id)
	return float(row[4][level(kit, id)]) if not row.is_empty() else 1.0

static func display(row: Array, n: int) -> String:
	if row[0] == "laser_kerf":
		return "%.1f cm" % (float(row[4][clampi(n, 0, 3)]) / Geom.M * 100.0)
	return "%s %s" % [str(row[4][clampi(n, 0, 3)]), row[3]]

static func price(id: String) -> float:
	var row := find_track(id)
	var n := level(Career.data.get("upgrades", {}), id)
	return float(row[5][n]) if not row.is_empty() and n < 3 else 0.0

# Lock/funds status is shared by the UI and purchase transaction.
static func reason(id: String) -> String:
	var row := find_track(id)
	if row.is_empty():
		return text(["未知技能", "Unknown skill"])
	var n := level(Career.data.get("upgrades", {}), id)
	if n >= 3:
		return text(["已学满", "MASTERED"])
	var target := n + 1
	if int(Career.data.get("done", 0)) < DONE[target] or int(Career.data.get("rep", 0)) < REP[target]:
		return text(["需要完成 %d 单、声望 %d", "Requires %d completed jobs, %d reputation"]) % [DONE[target], REP[target]]
	if float(Career.data.get("money", 0.0)) < price(id):
		return text(["还差 %s", "Need %s more"]) % Pal.money(price(id) - float(Career.data.money))
	return ""

static func buy(id: String) -> String:
	var why := reason(id)
	if why != "":
		return why
	# Work on a candidate: a live Game.job can reference the old active job.
	# Failed persistence must not mutate that job through a shared dictionary.
	var before := Career.data
	Career.data = before.duplicate(true)
	var n := level(Career.data.get("upgrades", {}), id) + 1
	Career.data.money = float(Career.data.money) - price(id)
	Career.data.upgrades["skill_" + id] = n
	if LEGACY.has(id):
		Career.data.upgrades[LEGACY[id]] = 1
	var desk: Dictionary = Career.data.get("desk", {})
	desk.buy = int(desk.get("buy", 0)) + 1
	Career.data.desk = desk
	sync_kit(Career.data.active)
	if not Career.save():
		Career.data = before
		return text(["保存失败，未扣款。", "Save failed; no funds spent."])
	return ""

static func set_goal(id: String) -> bool:
	if find_track(id).is_empty():
		return false
	var old: String = str(Career.data.get("growth_goal", ""))
	Career.data.growth_goal = id
	if Career.save():
		return true
	Career.data.growth_goal = old
	return false

# Only skills and their legacy aliases are fitted mid-contract. Facilities keep
# their existing next-contract installation rule. Training/exams stay standard.
static func sync_kit(job: Dictionary) -> void:
	if job.is_empty():
		return
	var kit: Dictionary = job.get("kit", {}).duplicate()
	var own: Dictionary = Career.data.get("upgrades", {})
	for row in TRACKS:
		var id: String = row[0]
		if own.has("skill_" + id):
			kit["skill_" + id] = level(own, id)
			if LEGACY.has(id):
				if level(own, id) > 0:
					kit[LEGACY[id]] = 1
				else:
					kit.erase(LEGACY[id])
	job.kit = kit

static func progress() -> int:
	var n := 0
	for row in TRACKS:
		n += level(Career.data.get("upgrades", {}), row[0])
	return n
