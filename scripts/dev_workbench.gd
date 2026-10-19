class_name DevWorkbench
extends Control
# A modal tool surface; DevPanel owns simulation state and mutations.
var dev: DevPanel
var page := 0
var persistent := false
var content: VBoxContainer
var heading: Label
var metrics: HBoxContainer
var tabs: HBoxContainer
var footer: Label
var scroll: ScrollContainer
var lab_bar: HBoxContainer
var lab_status: Label
var cash_step := 100000.0
var rep_step := 5
var buttons := {} # stable action ids for input checks

func words(zh: String, en: String) -> String:
	return zh if Txt.zh else en

func plate(color: Color = Color("141b21"), edge: Color = Color("35414b")) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(16)
	return box

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var skin := Theme.new()
	skin.default_font = Fonts.get_font("Regular")
	skin.default_font_size = 18
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var edge := Color("df9d61") if state in ["pressed", "focus"] else Color("46525c")
		var bg := Color("303a43") if state in ["hover", "pressed"] else Color("1a242c")
		skin.set_stylebox(state, "Button", plate(bg, edge))
	theme = skin
	var shade := ColorRect.new()
	shade.color = Color(0.005, 0.009, 0.014, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 64)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", plate(Color("10171e"), Color("64727d")))
	margin.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)
	var header := HBoxContainer.new()
	col.add_child(header)
	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_col)
	var eyebrow := label("BERTH 07  /  ENGINEERING ACCESS", 14)
	eyebrow.modulate = Color("e5a368")
	title_col.add_child(eyebrow)
	title_col.add_child(label(words("开发者工作台", "DEVELOPER WORKBENCH"), 32))
	var disable_button := button(words("退出开发模式", "DISABLE DEV"), dev.disable, "disable")
	disable_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	header.add_child(disable_button)
	var close_button := button(words("收起  F12 / Esc", "CLOSE  F12 / Esc"), func(): dev.set_open(false), "close")
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	header.add_child(close_button)
	metrics = HBoxContainer.new()
	metrics.add_theme_constant_override("separation", 12)
	col.add_child(metrics)
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	col.add_child(tabs)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	scroll.add_child(content)
	lab_bar = HBoxContainer.new()
	lab_bar.add_theme_constant_override("separation", 14)
	col.add_child(lab_bar)
	footer = label("", 16)
	col.add_child(footer)
	resized.connect(func(): if visible: refresh())

func label(text: String, px: int = 18) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", px)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node

func button(text: String, action: Callable, id: String = "", selected: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 42
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if selected:
		node.add_theme_stylebox_override("normal", plate(Color("353b3c"), Color("e5a368")))
	node.pressed.connect(action)
	if id != "":
		buttons[id] = node
	return node

func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func box(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", plate())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	return col

func refresh() -> void:
	if content == null:
		return
	var disable_button = buttons.get("disable")
	var close_button = buttons.get("close")
	buttons.clear()
	if is_instance_valid(disable_button): buttons.disable = disable_button
	if is_instance_valid(close_button): buttons.close = close_button
	clear(metrics)
	clear(tabs)
	clear(content)
	clear(lab_bar)
	lab_status = null
	lab_bar.visible = page == 2
	var kit: Dictionary = dev.game.job.get("kit", {}) if dev.game != null else Career.data.get("upgrades", {})
	var progress := 0
	for row in Growth.TRACKS:
		progress += Growth.level(kit, row[0])
	var context := words("标题 / 独立试验", "TITLE / SANDBOX")
	if dev.game != null:
		context = dev.game.ship_title()
	elif dev.terminal != null:
		context = words("生涯船坞终端", "CAREER TERMINAL")
	var values := [[words("当前环境", "CONTEXT"), context], [words("生涯资金 / 声望", "CAREER FUNDS / REP"), "%s  /  %d" % [Pal.money(float(Career.data.get("money", 0))), int(Career.data.get("rep", 0))]], [words("已装配技能", "FITTED SKILLS"), "%d / %d" % [progress, Growth.TRACKS.size() * 3]], [words("模拟状态", "SIMULATION"), words("已暂停 · 关闭后恢复", "PAUSED · CLOSE TO RESUME") if dev.game != null else words("终端待命", "TERMINAL IDLE")]]
	if dev.game != null:
		values[3][1] = words("暂停 · 耐久 %d%% · %s", "PAUSED · HP %d%% · %s") % [int(dev.game.drone.integrity), dev._time_text()]
	for value in values:
		var card := box(metrics)
		var caption := label(value[0], 14)
		caption.modulate = Color("94a4af")
		card.add_child(caption)
		card.add_child(label(value[1], 21))
	for index in 3:
		var title: String = [words("作业控制", "OPERATIONS"), words("成长调试", "PROGRESSION"), words("合同试验", "CONTRACT LAB")][index]
		tabs.add_child(button("0%d   %s" % [index + 1, title], func():
			page = index
			dev.builder = index == 2
			scroll.scroll_vertical = 0
			refresh(), "page_%d" % index, page == index))
	match page:
		0: operations()
		1: progression()
		2: contract_lab()
	footer.text = dev.toast if dev.toast_t < 3.0 else words("F12 / Esc 收起工作台 · 收起后保留调试开关 · “退出开发模式”恢复正常模拟", "F12 / Esc closes the workbench · Debug switches remain active · DISABLE DEV restores normal simulation")

func action_card(grid: GridContainer, title: String, detail: String, action: Callable, id: String, on: bool = false, key: String = "") -> void:
	var card := box(grid)
	var cap := label((key + "   " if key != "" else "") + title, 20)
	cap.modulate = Color("e5a368") if on else Color("e3e9ee")
	card.add_child(cap)
	var description := label(detail, 16)
	description.custom_minimum_size.y = 38
	description.modulate = Color("a1b0ba")
	card.add_child(description)
	card.add_child(button(words("已开启 · 点击关闭", "ON · TURN OFF") if on else words("执行", "APPLY"), action, id, on))

func operations() -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	content.add_child(grid)
	var descriptions := {
		"dev_xray": words("查看舱压、带电线路、流体和危险目标。", "Reveal pressures, live circuits, fluids and hazard targets."),
		"dev_safe": words("清空气液与储能、停机，便于验证拆解流程。", "Drain fluids and gas, discharge and stop sources."),
		"dev_free": words("移除固定件与管线；会改变本单结构。", "Remove fixings and lines; changes this contract's structure."),
		"dev_sort": words("漂浮零件自己飞进该去的回收口：设备进设备口，危险品进危险品口，龙骨、甲板和废料进熔炉。", "Loose pieces fly to their own mouth: equipment, hazards, and keels, decks and scrap to the furnace."),
		"dev_god": words("保护无人机，保留原有事故与回收判定。", "Protect the drone while keeping accidents and salvage rules."),
		"dev_time": words("依次切换 1× / 2× / 4× / 8× / ¼× 模拟。", "Cycle simulation speed: 1× / 2× / 4× / 8× / ¼×."),
		"dev_rooms": words("展开所有舱室，检查内部设备与结构。", "Reveal every room to inspect equipment and structure."),
		"dev_items": words("补充维修剂、切割环与备用无人机。", "Restock repairs, breaching rings and spare drones."),
		"dev_end": words("立即结束并结算当前正式合同。", "End and settle the current career contract immediately."),
		"dev_inspect": words("收起面板后，指向设备读取真实状态。", "Close the panel and point at equipment for its true state."),
		"dev_again": words("从头重开当前船与配置。", "Restart this ship and its loadout from the beginning."),
		"dev_money": words("为当前生涯增加 100,000。成长页可自定金额。", "Add 100,000 to this career; choose other amounts in Progression."),
		"dev_loan": words("清零当前生涯债务。", "Clear this career's debt."),
		"dev_rep": words("为当前生涯增加 5 点声望。", "Add 5 reputation to this career."),
		"dev_upgrades": words("解锁全部设备、设施及 %d 级技能书。" % (Growth.TRACKS.size() * 3), "Unlock every facility and all %d skill levels." % (Growth.TRACKS.size() * 3)),
		"dev_offers": words("刷新当前市场可选合同。", "Regenerate the available market offers."),
		"dev_trap": words("生成只包含一种指定事故的合同卡。", "Generate an offer containing a single accident type."),
		"dev_opening": words("跳过开局合同，打开三份报价的市场。", "Skip the opening jobs and open the three-offer market."),
		"dev_plans": words("清除当前生涯保存的拆解工单。", "Clear this career's saved work plans."),
		"dev_certify": words("将当前存档标为已通过训练。", "Mark the selected save as having completed training."),
	}
	for index in dev.rows().size():
		var row: Array = dev.rows()[index]
		if row[1] == "dev_builder":
			continue
		action_card(grid, dev._row_label(row), descriptions.get(row[1], ""), func(): dev.run(index + 1), row[1], row[2] == true, row[0])
	if dev.game != null:
		action_card(grid, words("恢复无人机", "RESTORE DRONE"), words("满耐久、停止漂移，不消耗物资。", "Full integrity and zero drift, without consuming stock."), func(): dev.restore_drone(), "restore")
		action_card(grid, words("返回机库", "RETURN TO BAY"), words("将无人机安全放回左侧机库并修复。", "Move the drone to the left bay and repair it."), func(): dev.restore_drone(true), "home")
	else:
		action_card(grid, words("独立试验合同", "SANDBOX CONTRACT"), words("选船、选事故、选装配，直接进入测试。", "Choose a ship, hazards and loadout for a sandbox run."), func(): page = 2; refresh(), "lab")

func progression() -> void:
	if Career.data.is_empty() and dev.game == null:
		content.add_child(label(words("先选择生涯存档，再调整资金与成长。合同试验可直接使用。", "Select a career save to edit funds and progression. The contract lab is available now."), 24))
		return
	if dev.game == null:
		persistent = true
	var scope := HBoxContainer.new()
	content.add_child(scope)
	scope.add_child(label(words("修改对象", "EDIT TARGET")))
	if dev.game != null:
		scope.add_child(button(words("当前作业装配", "CURRENT JOB LOADOUT"), func(): persistent = false; refresh(), "session_scope", not persistent))
		var career_choice := button(words("生涯永久等级", "PERMANENT CAREER LEVELS"), func(): persistent = true; refresh(), "career_scope", persistent)
		career_choice.disabled = Career.data.is_empty()
		scope.add_child(career_choice)
	else:
		scope.add_child(label(words("当前生涯 · 修改后保存", "CURRENT CAREER · SAVED ON APPLY"), 18))
	var presets := HBoxContainer.new()
	content.add_child(presets)
	for level in range(4):
		presets.add_child(button([words("技能全原装", "STOCK SKILLS"), words("技能全 I 级", "ALL SKILLS I"), words("技能全 II 级", "ALL SKILLS II"), words("技能全 III 级", "ALL SKILLS III")][level], func(): dev.tune_skills(level, persistent), "preset_%d" % level))
	content.add_child(label(words("永久等级写入当前生涯；当前作业只改现场装配。调试调整不收费，不受购买门槛限制。", "Permanent levels are saved to this career. Current-job edits change the live loadout. Debug edits bypass costs and purchase gates."), 16))
	var economy := HBoxContainer.new()
	economy.add_theme_constant_override("separation", 12)
	content.add_child(economy)
	var cash := SpinBox.new()
	cash.min_value = 1000
	cash.max_value = 10000000
	cash.step = 1000
	cash.value = cash_step
	cash.custom_minimum_size.x = 190
	cash.value_changed.connect(func(value): cash_step = value)
	economy.add_child(cash)
	economy.add_child(button(words("增加生涯资金", "ADD CAREER FUNDS"), func(): dev.adjust_funds(cash_step), "add_funds"))
	economy.add_child(button(words("扣除生涯资金", "REMOVE FUNDS"), func(): dev.adjust_funds(-cash_step), "remove_funds"))
	var rep := SpinBox.new()
	rep.min_value = 1
	rep.max_value = 100
	rep.value = rep_step
	rep.custom_minimum_size.x = 110
	rep.value_changed.connect(func(value): rep_step = int(value))
	economy.add_child(rep)
	economy.add_child(button(words("增加声望", "ADD REPUTATION"), func(): dev.adjust_funds(0, rep_step), "add_rep"))
	for id in ["add_funds", "remove_funds", "add_rep"]:
		buttons[id].disabled = Career.data.is_empty()
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	content.add_child(grid)
	var kit: Dictionary = Career.data.get("upgrades", {}) if persistent else dev.game.job.get("kit", {})
	for group in Growth.GROUPS.size():
		var card := box(grid)
		card.add_child(label("0%d   %s" % [group + 1, Growth.text(Growth.GROUPS[group])], 22))
		for track in Growth.TRACKS:
			if track[1] != group:
				continue
			var id: String = track[0]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 5)
			card.add_child(row)
			row.add_child(label(Growth.text(track[2]), 16))
			for level in 4:
				var pick := button(["0", "I", "II", "III"][level], func(): dev.tune_skills(level, persistent, id), "skill_%s_%d" % [id, level], Growth.level(kit, id) == level)
				pick.size_flags_horizontal = Control.SIZE_SHRINK_END
				pick.custom_minimum_size = Vector2(42, 38)
				row.add_child(pick)

func choices(parent: VBoxContainer, title: String, entries: Array) -> void:
	parent.add_child(label(title, 16))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 7)
	flow.add_theme_constant_override("v_separation", 7)
	parent.add_child(flow)
	for entry in entries:
		var choice := button(entry[0], entry[2], "", entry[1])
		choice.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		flow.add_child(choice)

func contract_lab() -> void:
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 24)
	content.add_child(split)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.8
	split.add_child(left)
	left.add_child(label(words("01 / 选择船体", "01 / SELECT HULL"), 22))
	var hull := Control.new()
	hull.custom_minimum_size.y = 200
	hull.draw.connect(func(): draw_ship(hull))
	left.add_child(hull)
	var ships := GridContainer.new()
	ships.columns = 2
	ships.add_theme_constant_override("h_separation", 10)
	ships.add_theme_constant_override("v_separation", 10)
	left.add_child(ships)
	for id in DevPanel.SHIPS:
		var type := Market.type_of(id)
		var title: String = "%s · %s\n%d m" % [str(type.get("class", id)), Growth.text(type.get("name", [id, id])), int(type.get("length", 0))]
		var pick := button(title, func():
			DevPanel.b_ship = id
			DevPanel.b_traps = DevPanel.b_traps.filter(func(tr): return tr in Traps.allowed(Ship.load_data(id)))
			refresh(), "ship_" + id, DevPanel.b_ship == id)
		pick.custom_minimum_size.y = 68
		ships.add_child(pick)
	var right := box(split)
	right.size_flags_stretch_ratio = 1.2
	right.add_child(label(words("02 / 配置试验", "02 / CONFIGURE TEST"), 22))
	var stars := []
	for n in [1, 2, 3]:
		stars.append(["★".repeat(n), DevPanel.b_stars == n, func(): DevPanel.b_stars = n; refresh()])
	choices(right, Txt.t("dev_b_stars"), stars)
	var scopes := []
	for kind in DevPanel.SCOPES:
		scopes.append([Txt.t("sc_" + kind), DevPanel.b_scope == kind, func(): DevPanel.b_scope = kind; refresh()])
	choices(right, Txt.t("dev_b_scope"), scopes)
	var goals := []
	for goal in DevPanel.GOALS:
		goals.append([Txt.t("goal_" + goal) if goal != "" else Txt.t("dev_b_drawn"), DevPanel.b_goal == goal, func(): DevPanel.b_goal = goal; refresh()])
	choices(right, Txt.t("dev_b_goal"), goals)
	var traps := []
	for trap in Traps.allowed(Ship.load_data(DevPanel.b_ship)):
		traps.append([Txt.t("dt_" + trap), trap in DevPanel.b_traps, func():
			if trap in DevPanel.b_traps: DevPanel.b_traps.erase(trap)
			else: DevPanel.b_traps.append(trap)
			refresh()])
	choices(right, Txt.t("dev_b_traps"), traps)
	var kits := []
	for kv in DevPanel.KIT:
		var id: String = kv[0]
		kits.append([Txt.t(kv[1]), DevPanel.b_kit.has(id), func():
			var next := not DevPanel.b_kit.has(id)
			if next: DevPanel.b_kit[id] = 1
			else: DevPanel.b_kit.erase(id)
			for track in Growth.LEGACY:
				if Growth.LEGACY[track] == id:
					DevPanel._set_skill(DevPanel.b_kit, track, 1 if next else 0)
			refresh()])
	choices(right, Txt.t("dev_b_kit"), kits)
	var levels := []
	for tier in range(4):
		levels.append([words("技能 %d 级", "SKILLS LEVEL %d") % tier, false, func():
			for track in Growth.TRACKS: DevPanel._set_skill(DevPanel.b_kit, track[0], tier)
			refresh()])
	choices(right, words("技能书装配预设", "SKILL LOADOUT PRESET"), levels)
	var seed_row := HBoxContainer.new()
	right.add_child(seed_row)
	seed_row.add_child(label(Txt.t("dev_b_seed"), 16))
	var seed_input := SpinBox.new()
	seed_input.min_value = 1
	seed_input.max_value = 99999
	seed_input.value = DevPanel.b_seed
	seed_input.custom_minimum_size.x = 160
	seed_input.value_changed.connect(func(value): DevPanel.b_seed = int(value))
	seed_row.add_child(seed_input)
	seed_row.add_child(button(Txt.t("dev_b_random"), func(): DevPanel.b_seed = randi_range(1, 99999); refresh(), "random_seed"))
	var result := dev._checked()
	lab_status = label("", 18)
	lab_bar.add_child(lab_status)
	var start := button(Txt.t("dev_b_start"), dev._start, "start_sandbox")
	start.disabled = not result.ok
	start.size_flags_horizontal = Control.SIZE_SHRINK_END
	lab_bar.add_child(start)
	if dev.terminal != null:
		var offer := button(Txt.t("dev_b_card"), dev._to_card, "to_offer")
		offer.disabled = not result.ok
		offer.size_flags_horizontal = Control.SIZE_SHRINK_END
		lab_bar.add_child(offer)
	right.add_child(label(Txt.t("dev_b_note"), 15))
	_update_validation()

func _process(_dt: float) -> void:
	if visible and page == 2 and lab_status != null:
		_update_validation()

func _update_validation() -> void:
	var result := dev._checked()
	lab_status.text = words("✓ 合同有效 · 独立测试不结算到生涯", "✓ VALID · SANDBOX DOES NOT SETTLE INTO CAREER") if result.ok else words("配置不可用：", "INVALID CONFIGURATION: ") + ", ".join(result.reasons.slice(0, 3))
	lab_status.modulate = Color("a8d4bd") if result.ok else Color("efa16e")
	buttons.start_sandbox.disabled = not result.ok
	if buttons.has("to_offer"):
		buttons.to_offer.disabled = not result.ok or not Career.active().is_empty()
		buttons.to_offer.tooltip_text = words("无在手合同后才能放入市场报价", "Finish the active job before adding a market offer") if not Career.active().is_empty() else ""

func draw_ship(canvas: Control) -> void:
	var ship := Ship.load_data(DevPanel.b_ship)
	var bounds := Rect2()
	var first := true
	for piece in ship.get("pieces", []):
		for point in piece.get("poly", []):
			var p := Vector2(point[0], point[1])
			if first: bounds = Rect2(p, Vector2.ZERO); first = false
			else: bounds = bounds.expand(p)
	if first:
		return
	var scale_k := minf((canvas.size.x - 36) / maxf(bounds.size.x, 1), (canvas.size.y - 36) / maxf(bounds.size.y, 1))
	var origin := canvas.size * 0.5 - bounds.get_center() * scale_k
	for piece in ship.get("pieces", []):
		var polygon := PackedVector2Array()
		for point in piece.get("poly", []):
			polygon.append(origin + Vector2(point[0], point[1]) * scale_k)
		if polygon.size() < 3:
			continue
		polygon.append(polygon[0])
		canvas.draw_polyline(polygon, Color("b4c5d1"), 1.2, true)
