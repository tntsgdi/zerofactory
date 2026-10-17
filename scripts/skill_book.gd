class_name SkillBook
extends Control

var selected := "drive"
var list: VBoxContainer
var detail: VBoxContainer
var status: Label
var progress_label: Label
var diagram: Control
var changed: Callable

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var skin := Theme.new()
	skin.default_font = Fonts.get_font("Regular")
	skin.default_font_size = 18
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("252b30") if state in ["hover", "pressed"] else Color("14191e")
		box.border_color = Color("e4a56b") if state in ["focus", "pressed"] else Color("3b4248")
		box.set_border_width_all(1)
		box.content_margin_left = 16
		box.content_margin_right = 16
		box.content_margin_top = 10
		box.content_margin_bottom = 10
		skin.set_stylebox(state, "Button", box)
	theme = skin
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)
	progress_label = _label("", 22)
	column.add_child(progress_label)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 36)
	column.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 0.9
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_stretch_ratio = 1.3
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(right_scroll)
	detail = VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 10)
	right_scroll.add_child(detail)
	status = _label(Growth.text(["鼠标选择 / 滚轮翻页 · Tab 切换焦点 · Enter 确认 · Esc 返回", "Select / scroll · Tab focus · Enter confirm · Esc return"]), 16)
	column.add_child(status)
	refresh()

func _label(text: String, font_size: int = 18) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func refresh() -> void:
	for node in list.get_children():
		list.remove_child(node)
		node.queue_free()
	progress_label.text = Growth.text(["技能书  /  已掌握 %d / 45 级 · 资金 %s", "FIELD MANUAL  /  %d / 45 levels · Funds %s"]) % [Growth.progress(), Pal.money(float(Career.data.money))]
	var selection := ButtonGroup.new()
	for group in Growth.GROUPS.size():
		var heading := _label("%02d  %s" % [group + 1, Growth.text(Growth.GROUPS[group])], 16)
		heading.modulate = Color("e4a56b")
		list.add_child(heading)
		for row in Growth.TRACKS:
			if row[1] != group:
				continue
			var id: String = row[0]
			var n := Growth.level(Career.data.upgrades, id)
			var b := Button.new()
			b.text = "%s   %d / 3" % [Growth.text(row[2]), n]
			b.toggle_mode = true
			b.button_group = selection
			b.button_pressed = id == selected
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.custom_minimum_size.y = 48
			b.pressed.connect(func():
				selected = id
				refresh_detail()
			)
			list.add_child(b)
	refresh_detail()

func refresh_detail() -> void:
	for node in detail.get_children():
		detail.remove_child(node)
		node.queue_free()
	var row := Growth.find_track(selected)
	var n := Growth.level(Career.data.upgrades, selected)
	detail.add_child(_label(Growth.text(row[2]), 30))
	detail.add_child(_label(Growth.text(row[6]), 18))
	detail.add_child(_label(Growth.text(["当前 %s   →   下一级 %s", "NOW %s   →   NEXT %s"]) % [Growth.display(row, n), Growth.display(row, mini(n + 1, 3))], 22))
	for tier in range(1, 4):
		var line := _label("%s  %s  ·  %s  ·  %s" % ["✓" if n >= tier else ("→" if tier == n + 1 else "·"), ["I", "II", "III"][tier - 1], Growth.display(row, tier), Pal.money(float(row[5][tier - 1]))], 20)
		line.modulate = Color("e4a56b") if tier == n + 1 else Color("9ea6ad")
		detail.add_child(line)
		if tier > 1:
			detail.add_child(_label(Growth.text(["前置：上一卷 · 完成 %d 单 · 声望 %d", "Previous volume · %d completed jobs · %d reputation"]) % [Growth.DONE[tier], Growth.REP[tier]], 15))
	var reason := Growth.reason(selected)
	var buy := Button.new()
	buy.text = Growth.text(["购买并装配 %s", "BUY & FIT %s"]) % Pal.money(Growth.price(selected)) if reason == "" else reason
	buy.custom_minimum_size.y = 56
	buy.disabled = reason != ""
	buy.pressed.connect(purchase)
	detail.add_child(buy)
	if n < 3:
		var after := float(Career.data.money) - Growth.price(selected)
		var balance := Growth.text(["购后资金 %s", "Funds after %s"]) % Pal.money(after) if after >= 0.0 else Growth.text(["还需攒 %s", "Save %s more"]) % Pal.money(-after)
		detail.add_child(_label(balance + Growth.text([" · 永久生效 · 本单立即可用", " · Permanent · Fits this job"]), 16))
		var goal := Button.new()
		goal.text = Growth.text(["★ 当前攒钱目标", "★ CURRENT SAVINGS GOAL"]) if Career.data.get("growth_goal", "") == selected else Growth.text(["设为攒钱目标", "SET SAVINGS GOAL"])
		goal.pressed.connect(func():
			if not Growth.set_goal(selected):
				status.text = Growth.text(["目标未能保存，请重试。", "Could not save goal; please retry."])
			refresh_detail()
		)
		detail.add_child(goal)
	diagram = Control.new()
	diagram.custom_minimum_size.y = 190
	diagram.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diagram.draw.connect(_draw_diagram)
	detail.add_child(diagram)
	detail.add_child(_label(Growth.text(["I 基础改装 → II 专业工法（3 单 / 声望 6）→ III 专家模块（8 单 / 声望 16）。训练和考核使用标准设备。", "I Basic → II Professional (3 jobs / rep 6) → III Expert (8 jobs / rep 16). Training and exams use standard equipment."]), 15))

func purchase() -> void:
	var id := selected
	var result := Growth.buy(id)
	if result == "":
		if changed.is_valid():
			changed.call()
		refresh()
		status.text = Growth.text(["已掌握 %s · %d 级，模块已装配。", "%s volume %d learned and fitted."]) % [Growth.text(Growth.find_track(id)[2]), Growth.level(Career.data.upgrades, id)]
	else:
		status.text = result

func _draw_diagram() -> void:
	var c := Vector2(diagram.size.x * 0.5, 70)
	var own: Dictionary = Career.data.upgrades
	var col := Color("d0d7dc")
	# Fitted equipment is expressed in geometry, not just a colour change.
	diagram.draw_rect(Rect2(c - Vector2(38, 28), Vector2(76, 56)), col, false, 2)
	var armor := Growth.level(own, "armor")
	for i in armor:
		diagram.draw_rect(Rect2(c - Vector2(43 + i * 5, 33 + i * 5), Vector2(86 + i * 10, 66 + i * 10)), col * Color(1, 1, 1, 0.6), false, 1.5)
	for side in [-1, 1]:
		for i in range(1 + Growth.level(own, "drive")):
			var p := c + Vector2(side * 58, -24 + i * 16)
			diagram.draw_line(p, p + Vector2(side * 20, 0), Color("e4a56b"), 3)
	for i in 3:
		var p := c + Vector2(-150 + i * 150, 66)
		diagram.draw_line(c, p, Color("59636b"), 1)
		var count := 0
		for row in Growth.TRACKS:
			if int(row[1]) % 3 == i:
				count += Growth.level(own, row[0])
		for tick in count:
			diagram.draw_rect(Rect2(p + Vector2((tick % 8) * 7 - 25, (tick / 8) * 8), Vector2(4, 5)), col)
	var shield := Growth.level(own, "shield")
	for i in shield:
		diagram.draw_arc(c, 62 + i * 7, -0.7, 0.7, 24, Color("e4a56b"), 1.5)
	# The remaining modules are connected to a visible position on the airframe.
	for group in range(1, 6):
		var n := 0
		for row in Growth.TRACKS:
			if row[1] == group:
				n += Growth.level(own, row[0])
		var p := c + Vector2((group - 3) * 108, 52)
		diagram.draw_line(c + Vector2(0, 20), p, Color("59636b"), 1)
		diagram.draw_string(Fonts.get_font("Regular"), p + Vector2(-35, 40), "%s %d" % [Growth.text(Growth.GROUPS[group]), n], HORIZONTAL_ALIGNMENT_LEFT, 105, 14, col)
