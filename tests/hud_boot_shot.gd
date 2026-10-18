extends SceneTree
# Stills of the HUD booting as the drone comes out (UI animation, 2026-10-17),
# and a piece's outline pulsing as it comes free.
# tools/run_test.sh tests/hud_boot_shot.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
const M := 48.0


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(4)
	g.hud.in_t = 0.0
	var marks := [0.35, 0.6, 0.85, 1.2]
	var t := 0.0
	var k := 0
	while k < marks.size():
		await process_frame
		t += 1.0 / 60.0
		if g.hud.in_t >= marks[k]:
			Cap.save(root, "res://tests/out/hudboot_%d.png" % k)
			k += 1
	# a loose piece comes free
	var c := Vector2(30.0, -6.0) * M
	var poly := PackedVector2Array([c + Vector2(-60, -16), c + Vector2(60, -16), c + Vector2(60, 16), c + Vector2(-60, 16)])
	var p = g.world.add_piece("hull", poly, {"density": 1.0, "tag": "HB-1"})
	g.world.make_body([p], null)
	g.on_body_freed(p.body)
	g.zoom_override = 2.0
	g.zoom_now = 2.0
	g.cam_override = c
	g.cam_pos = c
	g.cam_vel = Vector2.ZERO
	await _frames(12)
	print("piece body %s at %s m, gone %s, outlines %d, cam %s" % [p.body != null, (p.body.global_position / M) if p.body != null else Vector2.ZERO, p.gone, g.fx.outlines.size(), g.cam.global_position / M])
	Cap.save(root, "res://tests/out/free_pulse.png")
	quit()
