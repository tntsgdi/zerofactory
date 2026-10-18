extends SceneTree
# Roadmap 1.9: settings survive a restart. Changes go through the settings
# panel (as the player makes them), land in a test-only settings file, are
# read back into fresh values, and take effect on the audio buses and the
# viewport. The real settings file is never touched.
# godot --headless --path . -s tests/settings_persist.gd

const TEST_CFG := "user://zp_test_settings.cfg"
var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	var real := ProjectSettings.globalize_path(Txt.CFG)
	var real_t := FileAccess.get_modified_time(Txt.CFG) if FileAccess.file_exists(Txt.CFG) else -1
	Txt.cfg_path = TEST_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CFG))
	var panel := SettingsPanel.new()
	panel.testing = false
	root.add_child(panel)
	Txt.vol_master = 1.0
	Txt.vol_music = 0.8
	Txt.vol_sfx = 0.9
	Txt.quality = "high"
	Txt.zh = true
	Txt.anim = "full"
	Txt.calm = false
	# what a player does: master down 3, music down 8, sfx up 1, quality, language
	for i in 3:
		panel.change("vol_master", -1)
	for i in 8:
		panel.change("vol_music", -1)
	panel.change("vol_sfx", 1)
	panel.change("quality", 1)
	panel.change("lang", 1)
	panel.change("anim", -1)
	panel.change("anim", -1)
	var want := {"master": 0.7, "music": 0.0, "sfx": 1.0, "quality": "low", "zh": false, "anim": "off"}
	_check(Txt.no_flash(), "animation off turns shake and flashes off with it")
	_check(FileAccess.file_exists(TEST_CFG), "settings written to the test file")
	# a restart: fresh values, then the file
	Txt.vol_master = 0.123
	Txt.vol_music = 0.456
	Txt.vol_sfx = 0.789
	Txt.quality = "high"
	Txt.zh = true
	Txt.anim = "full"
	Txt.load_settings(false)
	var got := {"master": snappedf(Txt.vol_master, 0.01), "music": snappedf(Txt.vol_music, 0.01), "sfx": snappedf(Txt.vol_sfx, 0.01), "quality": Txt.quality, "zh": Txt.zh, "anim": Txt.anim}
	_check(str(got) == str(want), "read back after restart: %s" % str(got))
	Settings.apply(root)
	var mi := AudioServer.get_bus_index("Music")
	_check(AudioServer.is_bus_mute(mi), "music at 0% mutes the music bus")
	_check(absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.7)) < 0.05, "master bus at 70%% (%.1f dB)" % AudioServer.get_bus_volume_db(0))
	_check(root.msaa_2d == Viewport.MSAA_DISABLED, "low quality turns anti-aliasing off")
	var real_after := FileAccess.get_modified_time(Txt.CFG) if FileAccess.file_exists(Txt.CFG) else -1
	_check(real_after == real_t, "the real settings file is untouched (%s)" % real)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CFG))
	print("SETTINGS %s  (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()
