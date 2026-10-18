class_name SkillBook
extends Control

var selected := "drive"
var list: VBoxContainer
var detail: VBoxContainer
var status: Label
var progress_label: Label
var diagram: Control
var changed: Callable
const DArt = preload("res://scripts/drone_art.gd")


# the terminal's look (P.7, industrial HMI): keys standing out of the console
static func _key_box(state: String) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	var down := state in ["pressed"]
	box.bg_color = Color(0.16, 0.165, 0.18) if down else (Color(0.13, 0.135, 0.15) if state in ["hover", "focus"] else (Color(0.08, 0.084, 0.092) if state == "disabled" else Hmi.PANEL))
	box.border_color = Pal.heat(1.0, 1.3) if down or state == "focus" else Color(0, 0, 0, 0.7)
	box.set_border_width_all(2 if down or state == "focus" else 1)
	box.border_width_bottom = 4 if down else 3
	box.content_margin_left = 44
	box.content_margin_right = 16
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


static func _plate_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Hmi.PLATE
	box.border_color = Color(1, 1, 1, 0.2)
	box.set_border_width_all(1)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


# a skill's lamp: all three volumes learned, the next one can be had now, or not yet
func _lamp_for(b: Button, id: String) -> void:
	var n := Growth.level(Career.data.upgrades, id)
	var col := Hmi.ok_col() if n >= 3 else (Hmi.can_col() if Growth.reason(id) == "" else Hmi.warn_col())
	Hmi.lamp(b, Vector2(22, b.size.y * 0.5), col, true, 1.0, 6.0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var skin := Theme.new()
	skin.default_font = Fonts.get_font("Regular")
	skin.default_font_size = 18
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		skin.set_stylebox(state, "Button", _key_box(state))
	skin.set_color("font_color", "Button", Pal.ink(0.85))
	skin.set_color("font_hover_color", "Button", Pal.ink(0.98))
	skin.set_color("font_pressed_color", "Button", Pal.ink(1.0))
	skin.set_color("font_disabled_color", "Button", Pal.ink(0.45))
	theme = skin
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)
	progress_label = _label("", 20)
	progress_label.add_theme_stylebox_override("normal", _plate_box())
	progress_label.add_theme_font_override("font", Fonts.get_font("SemiBold"))
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
	progress_label.text = Growth.text(["技能书  /  已掌握 %d / %d 级 · 资金 %s", "FIELD MANUAL  /  %d / %d levels · Funds %s"]) % [Growth.progress(), Growth.TRACKS.size() * 3, Pal.money(float(Career.data.money))]
	var selection := ButtonGroup.new()
	for group in Growth.GROUPS.size():
		var heading := _label("%02d  %s" % [group + 1, Growth.text(Growth.GROUPS[group])], 16)
		heading.add_theme_stylebox_override("normal", _plate_box())
		heading.add_theme_font_override("font", Fonts.get_font("SemiBold"))
		heading.add_theme_color_override("font_color", Pal.tint(Pal.AIR, 0.95, 1.2))
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
			b.draw.connect(_lamp_for.bind(b, id))
			list.add_child(b)
	refresh_detail()

func refresh_detail() -> void:
	for node in detail.get_children():
		detail.remove_child(node)
		node.queue_free()
	var row := Growth.find_track(selected)
	var n := Growth.level(Career.data.upgrades, selected)
	var title := _label(Growth.text(row[2]), 32)
	title.add_theme_font_override("font", Fonts.get_font("SemiBold"))
	detail.add_child(title)
	detail.add_child(_label(Growth.text(row[6]), 18))
	detail.add_child(_label(Growth.text(["当前 %s   →   下一级 %s", "NOW %s   →   NEXT %s"]) % [Growth.display(row, n), Growth.display(row, mini(n + 1, 3))], 22))
	for tier in range(1, 4):
		var line := _label("%s  %s  ·  %s  ·  %s" % ["✓" if n >= tier else ("→" if tier == n + 1 else "·"), ["I", "II", "III"][tier - 1], Growth.display(row, tier), Pal.money(float(row[5][tier - 1]))], 20)
		line.modulate = Pal.heat(1.0, 1.15) if tier == n + 1 else (Pal.tint(Pal.FLUID, 1.0, 1.05) if n >= tier else Color("9ea6ad"))
		detail.add_child(line)
		if tier > 1:
			detail.add_child(_label(Growth.text(["前置：上一卷 · 完成 %d 单 · 声望 %d", "Previous volume · %d completed jobs · %d reputation"]) % [Growth.DONE[tier], Growth.REP[tier]], 15))
	var reason := Growth.reason(selected)
	var buy := Button.new()
	buy.text = Growth.text(["购买并装配 %s", "BUY & FIT %s"]) % Pal.money(Growth.price(selected)) if reason == "" else reason
	buy.custom_minimum_size.y = 60
	buy.disabled = reason != ""
	buy.add_theme_font_override("font", Fonts.get_font("SemiBold"))
	buy.add_theme_font_size_override("font_size", 22)
	buy.draw.connect(func():
		Hmi.lamp(buy, Vector2(24, buy.size.y * 0.5), Hmi.ok_col() if reason == "" else Pal.ink(0.3), true, 1.0, 9.0))
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
	diagram.custom_minimum_size.y = 250
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
	var own: Dictionary = Career.data.upgrades
	var r := Rect2(Vector2.ZERO, diagram.size)
	Hmi.screen(diagram, r, 1.0, true)
	var c := Vector2(r.size.x * 0.5, 74)
	var xf := Transform2D(0.0, Vector2(2.4, 2.4), 0.0, c)
	diagram.draw_set_transform_matrix(xf)
	DArt.tint = Color(Pal.AIR.r * 1.1, Pal.AIR.g * 1.1, Pal.AIR.b * 1.1)
	DArt.draw(diagram, "arrowring", {"heading": -PI / 2.0, "tool": 0, "open": 0.4, "t": 1.0, "thrust": Vector2.ZERO, "dash": false, "design": "arrowring", "base_xf": xf})
	DArt.tint = Color(1, 1, 1)
	diagram.draw_set_transform_matrix(Transform2D.IDENTITY)
	# each group's volumes as a lamp row under the airframe
	var groups := Growth.GROUPS.size()
	var gw := (r.size.x - 40.0) / groups
	for g in groups:
		var n := 0
		var top := 0
		for row in Growth.TRACKS:
			if row[1] == g:
				n += Growth.level(own, row[0])
				top += 3
		var x := 20.0 + g * gw
		diagram.draw_string(Fonts.get_font("Medium"), Vector2(x, r.size.y - 60), Growth.text(Growth.GROUPS[g]), HORIZONTAL_ALIGNMENT_LEFT, gw - 6, 14, Pal.ink(0.8))
		Hmi.gauge(diagram, Rect2(x, r.size.y - 50, gw - 14, 16), float(n) / maxf(1.0, top), Pal.tint(Pal.AIR, 1.0, 1.3), 1.0, top)
		diagram.draw_string(Fonts.get_font("Medium"), Vector2(x, r.size.y - 14), "%d / %d" % [n, top], HORIZONTAL_ALIGNMENT_LEFT, gw - 6, 12, Pal.ink(0.55))
