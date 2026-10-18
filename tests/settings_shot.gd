extends SceneTree
# Still of the settings panel (the animation intensity row, 2026-10-17).
# tools/run_test.sh tests/settings_shot.gd

const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _run() -> void:
	var panel := SettingsPanel.new()
	panel.testing = true
	root.add_child(panel)
	panel.open()
	for i in 40:
		await process_frame
	Cap.save(root, "res://tests/out/settings.png")
	quit()
