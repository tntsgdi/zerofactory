extends SceneTree
# Stills of the shared transition (UI animation, 2026-10-17): the heat line
# closing with sparks, the flare as it shuts, the blueprint opening, between
# two stand-in screens. No saves or settings are touched.
# tools/run_test.sh tests/wipe_shot.gd

const Cap = preload("res://tests/cap.gd")
var screen: Node2D
var which := 0


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _draw_screen() -> void:
	var s := Vector2(1920, 1080)
	screen.draw_rect(Rect2(Vector2.ZERO, s), Color(0.03, 0.035, 0.04) if which == 0 else Color(0.02, 0.025, 0.03))
	for i in 12:
		var r := Rect2(120 + (i % 4) * 430, 140 + (i / 4) * 300, 380, 240)
		screen.draw_rect(r, Pal.ink(0.1 if which == 0 else 0.05))
		screen.draw_rect(r, Pal.ink(0.5) if which == 0 else Pal.tint(Pal.AIR, 0.6), false, 2.0)
	screen.draw_string(Fonts.get_font("Medium"), Vector2(120, 100), "SCREEN A" if which == 0 else "SCREEN B", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Pal.ink(0.9))


func _run() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.1
	env.glow_intensity = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	we.environment = env
	root.add_child(we)
	screen = Node2D.new()
	screen.draw.connect(_draw_screen)
	root.add_child(screen)
	await _frames(4)
	Wipe.go(self, func():
		which = 1
		screen.queue_redraw())
	var marks := [[0.2, "close"], [0.38, "closing"], [0.45, "shut"], [0.62, "open1"], [0.8, "open2"], [1.0, "open3"]]
	var t := 0.0
	var k := 0
	while k < marks.size():
		await process_frame
		t += 1.0 / 60.0
		if t >= marks[k][0]:
			Cap.save(root, "res://tests/out/wipe_%s.png" % marks[k][1])
			k += 1
	print("WIPE done, busy after: %s" % Wipe.busy())
	quit()
