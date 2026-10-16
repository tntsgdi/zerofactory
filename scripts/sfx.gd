class_name Sfx
extends Node
# One-shot sounds through a voice pool, plus a handful of loops whose volume
# follows the game: the cutting hiss, gas jets, thrusters, pumps, the
# generator hum and the dock's ambience (or the user's music, if present).

const VOICES := 20
const LOOPS := ["cut_loop", "jet_loop", "thrust_loop", "pump_loop", "hum_loop", "tether_loop", "ambience"]

var game: Game
var streams := {}
var voices: Array[AudioStreamPlayer] = []
var next := 0
var loops := {}
var loop_level := {}
var jet_acc := 0.0
var last_play := {}
var sfx_bus := 0
var music_bus := 0
var ending_player: AudioStreamPlayer
var ending_level := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	sfx_bus = _bus("SFX", Settings.SFX_DB)
	music_bus = _bus("Music", Settings.MUSIC_DB)
	Settings.apply_audio()
	# ResourceLoader, not DirAccess: in an exported build the folder holds
	# only "x.ogg.import" / "x.ogg.remap", and a plain listing finds no sounds
	for f in ResourceLoader.list_directory("res://assets/audio"):
		if f.ends_with(".ogg"):
			streams[f.get_basename()] = load("res://assets/audio/" + f)
	for i in VOICES:
		var v := AudioStreamPlayer.new()
		v.bus = "SFX"
		add_child(v)
		voices.append(v)
	if ResourceLoader.exists("res://assets/music/ending.ogg"):
		ending_player = AudioStreamPlayer.new()
		ending_player.bus = "Music"
		var es: AudioStreamOggVorbis = load("res://assets/music/ending.ogg")
		es.loop = false
		ending_player.stream = es
		ending_player.volume_db = -80.0
		add_child(ending_player)
	for n in LOOPS:
		var p := AudioStreamPlayer.new()
		p.bus = "Music" if n == "ambience" else "SFX"
		var s = streams.get(n)
		if n == "ambience":
			s = _music()
		if s != null:
			if s is AudioStreamOggVorbis:
				s.loop = true
			p.stream = s
			p.volume_db = -80.0
			add_child(p)
			p.play()
			loops[n] = p
			loop_level[n] = 0.0


func _music():
	for f in ["res://assets/music/main.ogg", "res://assets/music/main.mp3"]:
		if ResourceLoader.exists(f):
			return load(f)
	return streams.get("ambience")


func _bus(name: String, db: float) -> int:
	var i := AudioServer.get_bus_index(name)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, name)
		AudioServer.set_bus_send(i, "Master")
	AudioServer.set_bus_volume_db(i, db)
	return i


func play(name: String, pos: Vector2 = Vector2.INF, vol: float = 1.0, pitch: float = 1.0) -> void:
	var s = streams.get(name)
	if s == null:
		return
	var now := Time.get_ticks_msec()
	if now - last_play.get(name, -1000) < 40:
		return
	last_play[name] = now
	var att := 1.0
	if pos != Vector2.INF and game != null and game.cam != null:
		var d: float = pos.distance_to(game.cam.position) / maxf(game.cam_zoom(), 0.3)
		att = clampf(1.15 - d / 2200.0, 0.25, 1.0)
	var v := voices[next]
	next = (next + 1) % VOICES
	v.stream = s
	v.volume_db = linear_to_db(maxf(0.0001, vol * att))
	v.pitch_scale = pitch * randf_range(0.96, 1.04)
	v.play()


func jet(strength: float) -> void:
	jet_acc = maxf(jet_acc, strength)


func _process(dt: float) -> void:
	if game == null:
		return
	var want := {}
	var playing: bool = game.state == "play" and not game.menu_open
	want["cut_loop"] = game.tools.material_k * (1.0 if game.tools.cutting else 0.0) if playing else 0.0
	want["jet_loop"] = clampf(jet_acc, 0.0, 1.0) if playing else 0.0
	jet_acc = 0.0
	var fl := 0.0
	if game.drone.alive:
		for f in game.drone.flame:
			fl = maxf(fl, f)
	want["thrust_loop"] = fl * 0.6 if playing else 0.0
	want["pump_loop"] = (0.35 if not game.sys.hoses.is_empty() else 0.0) if playing else 0.0
	var hum := 0.0
	for t in game.sys.src_order:
		if not game.sys.running(t):
			continue
		var g = game.world.tag(t)
		if g != null and not g.gone:
			var d: float = game.drone.global_position.distance_to(game.world.frame(g) * Geom.centroid(g.poly))
			hum = maxf(hum, clampf(1.0 - d / (10.0 * 48.0), 0.0, 1.0) * 0.5)
	want["hum_loop"] = hum if playing else 0.0
	want["tether_loop"] = (0.25 + 0.5 * game.tools.tether_force) if playing and game.tools.held_piece != null else 0.0
	var hush: bool = game.story != null and game.story.hush()
	var ending: bool = game.state == "ending" and ending_player != null and not hush
	want["ambience"] = 0.0 if ending or hush else (0.85 if game.state != "intro" else 0.6)
	if ending:
		if not ending_player.playing and ending_level == 0.0:
			ending_player.play()
		ending_level = Pal.damp(ending_level, 1.0, 1.2, dt) + 0.0001
		ending_player.volume_db = linear_to_db(clampf(ending_level, 0.0001, 1.0))
	for n in loops:
		var target: float = want.get(n, 0.0)
		loop_level[n] = Pal.damp(loop_level[n], target, 14.0 if n != "ambience" else (2.5 if ending else 1.5), dt)
		loops[n].volume_db = linear_to_db(maxf(0.0001, loop_level[n]))
		if n == "thrust_loop":
			loops[n].pitch_scale = 0.9 + fl * 0.25 + (0.15 if game.drone.dashing else 0.0)
		if n == "tether_loop":
			loops[n].pitch_scale = 0.8 + game.tools.tether_force * 0.5 + game.tools.strain * 0.4
