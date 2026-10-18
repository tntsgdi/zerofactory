extends SceneTree
# Still of the market right after the tug (2026-10-17: the market opens after
# the first contract, the next opening contract pinned first). Test files only.
# tools/run_test.sh tests/story_card_shot.gd

const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_story_card.json"
	SaveGame.path = "user://zp_test_story_card_save.json"
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _run() -> void:
	Career.data = {}
	Career.start_new()
	# as if the tug had just been settled
	Career.data.done = 1
	Career.data.money = 33700.0
	Career.data.active = {}
	Career.data.market = true
	Career.data.story_job = Career.opening(1)
	Career.data.offers = []
	Career.save()
	var term: Node = load("res://scenes/terminal.tscn").instantiate()
	root.add_child(term)
	for i in 90:
		await process_frame
	print("cards: %s" % [term.offers().map(func(o): return str(o.get("id", "")) + (" (pinned)" if o.get("story_card", false) else ""))])
	Cap.save(root, "res://tests/out/story_card.png")
	quit()
