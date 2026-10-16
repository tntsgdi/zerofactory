class_name Settings
# Puts the saved settings into effect: the three volumes on the audio buses,
# and the picture quality (glow and anti-aliasing) on the viewport. The values
# themselves live in Txt with the rest of the settings file.

const MUSIC_DB := -5.0
const SFX_DB := -3.0

static var env: Environment = null     # the game's glow, while a game is running


static func _bus(name: String) -> int:
	var i := AudioServer.get_bus_index(name)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, name)
		AudioServer.set_bus_send(i, "Master")
	return i


static func _level(i: int, base_db: float, v: float) -> void:
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, base_db + linear_to_db(maxf(v, 0.001)))


static func apply_audio() -> void:
	_level(0, 0.0, Txt.vol_master)
	_level(_bus("Music"), MUSIC_DB, Txt.vol_music)
	_level(_bus("SFX"), SFX_DB, Txt.vol_sfx)


static func apply_video(vp: Viewport) -> void:
	var high := Txt.quality == "high"
	# full screen or a window (never touched by a headless test)
	if DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if Txt.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		var cur := DisplayServer.window_get_mode()
		var is_full := cur in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
		if is_full != Txt.fullscreen:
			DisplayServer.window_set_mode(want)
	if vp != null:
		vp.msaa_2d = Viewport.MSAA_2X if high else Viewport.MSAA_DISABLED
	if env != null:
		env.glow_enabled = high


static func apply(vp: Viewport) -> void:
	apply_audio()
	apply_video(vp)
