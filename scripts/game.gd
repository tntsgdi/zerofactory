class_name Game
extends Node2D
# A contract: the dock, the ship, the drone and everything that happens
# between them. Holds the camera, routes input, reacts to every event the
# systems raise (cuts, arcs, leaks, blowouts, recoveries) and keeps the books.
# A career contract (Game.contract) also settles with the career at the end.

const CONTRACT_FEE := 9000.0     # a contract that names no fee of its own
const DRONE_FEE := 2000.0
const CAM_ZOOM := 1.65
const SHIP_CENTER := Vector2(21.0 * 48.0, 0.0)

var world: World
var sys: Systems
var mech: Mech                # magnets and preloaded arms some ship types carry
var munitions: Munitions      # rounds that cook off, knock off and set each other off (PT-34)
var rails: Rails              # cargo held on lock rails (JD-38, RO-128)
var atmos                     # air that isn't plain air: oxygen-rich halls (HB-86), scripts/atmos.gd
var coldchain                 # cold holds that have to stay cold (CL-104), scripts/coldchain.gd
var vault                     # vault doors on two lock circuits and a release (ES-112), scripts/vault.gd
var media                     # look-alike media in crossed branches (FL-116), scripts/media.gd
var furnace                   # a furnace core shut down but not cool (MF-126), scripts/furnace.gd
var bio: Bio                  # biological contamination some ship types carry
var ore: Ore                  # a hopper of loose ore some ship types carry
var cryo: Cryo                # cryogenic tanks some ship types carry
var plan: WorkPlan            # the work plan of this ship type, recorded and replayed
var auto_paused := false      # the operator stopped the berth's machines (arm, hauler, plan)
var mouths := {}              # mouth zone -> the machine dropping into it now
var dock: Dock
var fx: Fx
var drone: Drone
var tools: Tools
var hud: Hud
var blueprint: Blueprint
var sfx: Sfx
var cam: Camera2D
var bot = null               # tests drive the game through this dict
var ship_id := "gr7"         # which ship file this contract is about
var ship: Dictionary = {}
static var start_ship := ""  # the title screen picks the next ship (training, exam, contract)
static var contract: Dictionary = {}   # the career's contract to play next (empty: a contract outside any career)
var job: Dictionary = {}     # the career contract this scene plays
var fee := CONTRACT_FEE
var career_result: Dictionary = {}     # the settlement with the career, once the contract is over
var used: Dictionary = {}    # consumables used up on this contract (the career's stock drops at settlement)
# what the operator checked with their own hands on this ship (factory names only):
# pieces inspected or handled, ports read, lines traced, controls worked. Goes to
# the career's engineering archive at the end; the next ship of the type shows it.
var verified := {"pieces": {}, "ports": {}, "lines": {}, "ctrls": {}}
var _factory := {}           # the type's factory names: what can go in the archive
# The operation log (roadmap 2.9): every action counted under what it is.
# Repetitive hand work: undoing bolts and locks, unplugging, doors, hauling
# ordinary scrap, measuring the same point again, patching the drone.
# Engineering decisions: the first reading of a point, isolating (switches,
# valves, stops), choosing to hose, cutting (whether to cut and where to
# segment), sending whole equipment or hazards to their mouth, firing a
# breaching ring, picking the contract, buying kit. The machine's work (the
# recovery arm) is counted apart and is nobody's hand work.
const OP_CAT := {
	"unfix": "manual", "unplug": "manual", "door": "manual", "haul_scrap": "manual", "remeasure": "manual", "repair": "manual",
	"measure": "decision", "isolate": "decision", "hose": "decision", "cut": "decision", "deliver_equip": "decision",
	"deliver_hazard": "decision", "ring": "decision", "pick_contract": "decision", "buy": "decision",
	"arm_haul": "machine",     # the recovery arm, or a mouth pulling in what drifted close
	"plan": "machine",         # a step of a work plan the berth ran
}
var ops := {}                # kind -> count
var _measured := {}
var done_t := 0.0
var cam_pan := Vector2.ZERO
var rmb_down := false
var rmb_moved := 0.0
var overview := false
var training := false        # the ship file is a training course, not a contract
var tutorial: Tutorial
var assist: Assist
var story: Story
var exam: Exam
var settings_panel: SettingsPanel
var arm: RecoveryArm
var hauler: Hauler
var hauler2: Hauler             # the second hauling drone (roadmap 4.4)
var crane: Crane                # the heavy crane (roadmap 4.4)
var keepout: Array = []         # Rect2 (px): keep-out zones the operator set; no machine goes in
var consoles: Consoles          # the berth's two computers: shop and berth management, on site
var console_ui: Control = null  # the terminal page open over the berth
const KEEPOUT_MAX := 3
const KEEPOUT_SIZE := Vector2(8.0, 8.0)   # m
var radio := Radio.new()      # Liang and the berth terminal
var player_moved := false
var warp := false            # time runs x4 while the player holds =
const WARP := 4.0
const REST_SCRAP := 0.6       # an early end: what is left fetches this share of its scrap value
var testing := false

var state := "intro"         # intro play ending
var state_t := 0.0
var paused_sim := false
var dev_overlay_open := false
var menu_open := false
var contract_open := false

# camera
var cam_pos := Vector2.ZERO
var cam_vel := Vector2.ZERO
var zoom_target := CAM_ZOOM
var zoom_now := 0.62
var trauma := 0.0
var punch := Vector2.ZERO
var cam_override = null      # Vector2 world point (intro / ending)
var zoom_override := -1.0

# input edges
var prev_lmb := false
var ring_armed := false     # 7 readies the breaching ring: it snaps to the nearest member, a click fires it
var ring_aim: Dictionary = {}   # where it would go this frame (ring_target)
var ring_eat := false       # the press that fired (or cancelled) the ring never reaches the tools
var ring_wait := false      # readied by a click: that click has to end first
var prev_keys := {}
var aim := Vector2.ZERO

# economy
var income_equip := 0.0
var income_metal := 0.0
var income_hazard := 0.0
var losses := 0.0
var loss_lines: Array = []   # [text_key, amount]
var devalued: Array = []     # [reason key, tag, amount]: value knocked off what could have been sold
var mandatory_lost := {}     # tag -> reason key: a named piece that can no longer be delivered whole
var income_rest := 0.0       # an early end: what was left, taken as scrap at a discount
var mandatory_ok := {}     # tag -> recovered intact into the equipment bay
var time_by := {}           # where the contract's time went (V2 2.9): measure cut maintain haul fly wait menu
var changed := {}           # what has changed on site since the contract began: "l:q1", "c:K-G" (old notes on it are void)
var must_value := {}         # named pieces delivered whole: tag -> value (for the named-equipment bonus)
var incidents: Array = []  # [playtime, kind, detail]: what went wrong and when (the accident review reads it)
var _mand: Array = []
var _mand_zh := -1
var feed: Array = []         # [text, amount, t] recent income lines for the HUD
var drone_respawn := -1.0
var hurt_cd := {}
var hints_seen := {}
var hints_on := true
var messages: Array = []     # [key, world pos, t, text]
var reveal_count := 0
var ship_offset := 60.0 * 48.0
# between contracts the berth stands empty (player 2026-10-18: "after a job,
# don't go back to the menu, go back into the berth"): the finished ship is towed
# out, the empty berth (ships/berth.json) takes over with the drone where it was
static var carry := {}
const TOW_T := 2.6
var ended := false
var slowmo := 0.0
var hitstop_t := 0.0
var playtime := 0.0
var ledger: Array = []        # [label, zone, value]
var autosave_t := 0.0
var best := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	testing = _is_test()
	Txt.load_settings(testing)
	hints_on = Txt.hints
	fx = Fx.new()
	fx.game = self
	var bg := Backdrop.new()
	bg.game = self
	add_child(bg)
	world = World.new()
	world.game = self
	dock = Dock.new()
	dock.game = self
	dock.world = world
	add_child(dock)
	add_child(world)
	if start_ship != "":
		ship_id = start_ship
		start_ship = ""
	# the assessment draws one of its four problems
	if ship_id == "exam":
		ship_id = Exam.pick()
	job = contract
	contract = {}
	# a contract plays its own ship type
	if job.get("ship", "") != "" and not ship_id in ["exam"]:
		ship_id = job.ship
	var data := {}
	if SaveGame.load_requested and (not testing or SaveGame.allow_test):
		data = SaveGame.read(SaveGame.file_for_ship(Ship.load_data(ship_id)))
		# a save left over from another contract of the career is not this one
		if not job.is_empty() and data.has("job") and data.job.get("id", "") != job.get("id", ""):
			data = {}
	SaveGame.load_requested = false
	if not data.is_empty():
		ship_id = data.get("ship", "gr7")
		if data.has("job"):
			job = data.job
	fit_skills()
	ship = Ship.load_data(ship_id)
	training = ship.get("training", false)
	if training or ship.has("exam"):
		job = {}
	if job.has("variant"):
		ship = Variant.make(ship, job)
	fee = float(job.get("fee", ship.get("fee", CONTRACT_FEE)))
	var base := Ship.load_data(ship_id)
	for pd in base.get("pieces", []):
		if pd.get("tag", "") != "":
			_factory["p:" + pd.tag] = true
	for c in base.get("ctrls", []):
		_factory["c:" + c.id] = true
	for l in base.get("lines", []):
		_factory["l:" + l.id] = true
	# the berth: extended once the career has paid for it, or for a ship too long for the standard one
	var ext := Ship.extent(ship)
	Dock.configure(Dock.length_for(float(ship.get("length", 0.0)), _upgrades_for_berth()), ext.x, ext.y)
	if has_upgrade("port2"):
		Dock.add_port2()
	dock.set_ship(ship)
	if not data.is_empty() and SaveGame.apply(self, data):
		Ship.rooms(world, ship)
	else:
		data = {}
		Ship.build(world, ship)
	sys = Systems.new()
	add_child(sys)
	world.finalize(float(ship.get("value", {}).get("metal", 12000.0)))
	sys.setup(self, world, ship)
	munitions = Munitions.new()
	munitions.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(munitions)
	munitions.setup(self, ship)
	rails = Rails.new()
	rails.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(rails)
	rails.setup(self, ship)
	atmos = preload("res://scripts/atmos.gd").new()
	add_child(atmos)
	atmos.setup(self, ship)
	coldchain = preload("res://scripts/coldchain.gd").new()
	coldchain.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(coldchain)
	coldchain.setup(self, ship)
	vault = preload("res://scripts/vault.gd").new()
	add_child(vault)
	vault.setup(self, ship)
	media = preload("res://scripts/media.gd").new()
	media.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(media)
	media.setup(self, ship)
	furnace = preload("res://scripts/furnace.gd").new()
	furnace.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(furnace)
	furnace.setup(self, ship)
	mech = Mech.new()
	add_child(mech)
	mech.setup(self, ship)
	bio = Bio.new()
	add_child(bio)
	bio.setup(self, ship)
	ore = Ore.new()
	world.add_child(ore)
	ore.setup(self, ship)
	cryo = Cryo.new()
	add_child(cryo)
	cryo.setup(self, ship)
	world.piece_freed.connect(on_body_freed)
	add_child(fx)
	blueprint = Blueprint.new()
	blueprint.game = self
	add_child(blueprint)
	drone = Drone.new()
	drone.game = self
	drone.assist = Txt.assist if bot == null else bot.get("assist", true)
	drone.alive = false
	add_child(drone)
	drone.global_position = Dock.BAY * Geom.M + Vector2(-40, 0)
	tools = Tools.new()
	tools.game = self
	tools.world = world
	world.piece_reframed.connect(tools.on_piece_reframed)
	tools.sys = sys
	tools.drone = drone
	add_child(tools)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = 10
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_strength = 1.05
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.1
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	Settings.env = env
	for lv in 7:
		env.set_glow_level(lv, [0.0, 1.0, 1.0, 0.8, 0.55, 0.3, 0.0][lv])
	we.environment = env
	add_child(we)
	cam = Camera2D.new()
	cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(cam)
	cam.make_current()
	sfx = Sfx.new()
	sfx.game = self
	add_child(sfx)
	radio.sfx = sfx
	hud = Hud.new()
	hud.game = self
	add_child(hud)
	# the industrial recovery arm on the boom, once the berth has bought it
	if has_upgrade("hauler"):
		hauler = Hauler.new()
		hauler.game = self
		hauler.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(hauler)
	if hauler != null and has_upgrade("hauler2"):
		hauler2 = Hauler.new()
		hauler2.game = self
		hauler2.who = "hauler2"
		hauler2.home_off = Vector2(2.2, -1.6)
		hauler2.queue = hauler.queue
		hauler2.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(hauler2)
	if career() and Career.usable():
		consoles = Consoles.new()
		consoles.game = self
		add_child(consoles)
	if has_upgrade("crane"):
		crane = Crane.new()
		crane.game = self
		crane.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(crane)
	if has_upgrade("arm"):
		arm = RecoveryArm.new()
		arm.game = self
		arm.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(arm)
	plan = WorkPlan.new()
	plan.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(plan)
	plan.setup(self)
	if ship.has("exam"):
		exam = Exam.new()
		exam.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(exam)
		exam.setup(self)
		var eh := ExamHud.new()
		eh.game = self
		add_child(eh)
	if not training and exam == null:
		assist = Assist.new()
		assist.game = self
		assist.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(assist)
	if ship.has("story"):
		story = Story.new()
		story.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(story)
		story.setup(self)
		var sh := StoryHud.new()
		sh.game = self
		add_child(sh)
	if training:
		tutorial = Tutorial.new()
		tutorial.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(tutorial)
		tutorial.setup(self, ship_id)
		var th := TutorialHud.new()
		th.game = self
		add_child(th)
	for n in [dock, world, sys, fx, blueprint, drone, tools]:
		n.process_mode = Node.PROCESS_MODE_PAUSABLE
	var dev := DevPanel.new()
	dev.game = self
	dev.where = "game"
	add_child(dev)
	# last child: it sees input first while open
	settings_panel = SettingsPanel.new()
	settings_panel.testing = testing
	add_child(settings_panel)
	Settings.apply_video(get_viewport())
	world.position.x = ship_offset
	cam_pos = Vector2(21.0 * 48.0, -0.5 * 48.0)
	zoom_now = 0.62
	state = "intro"
	state_t = 0.0
	if not data.is_empty():
		SaveGame.apply_late(self, data)
		if data.has("munitions"):
			munitions.load_state(data.munitions)
		if data.has("rails"):
			rails.load_state(data.rails)
		if data.has("atmos") and not (data.atmos as Dictionary).is_empty():
			atmos.load_state(data.atmos)
		if data.has("cold"):
			coldchain.load_state(data.cold)
		if data.has("media"):
			media.load_state(data.media)
		if data.has("furnace"):
			furnace.load_state(data.furnace)
		if data.has("mech"):
			mech.load_state(data.mech)
		if data.has("bio"):
			bio.load_state(data.bio)
		if data.has("ore"):
			ore.load_state(data.ore)
		if data.has("cryo"):
			cryo.load_state(data.cryo)
		if data.has("plan") and plan != null:
			plan.load_state(data.plan)
		for r in data.get("keepout", []):
			keepout.append(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])))
		if tutorial != null and data.has("tutorial"):
			tutorial.load_state(data.tutorial)
		if story != null and data.has("story"):
			story.load_state(data.story)
		if SaveGame.recovered:
			hud.show_hint(txt("save_recovered"))
		world.position.x = 0.0
		state = "play"
		drone.alive = true
		drone.spawn_t = 0.0
		cam_pos = drone.global_position
		zoom_now = CAM_ZOOM
	else:
		# a career contract starts with the choices made at the terminal
		if job.has("reg"):
			log_op("pick_contract")
		for k in job.get("desk", {}):
			log_op(k, int(job.desk[k]))
		if story != null:
			story.on_arrive()
		if bot != null and bot.get("skip_intro", false):
			_end_intro()
	if in_berth():
		_enter_berth()


func _is_test() -> bool:
	for a in OS.get_cmdline_args():
		if a == "-s" or a == "--script" or a.begins_with("res://tests/") or a.find("tests/") >= 0:
			return true
	return bot != null


func txt(key: String) -> String:
	return Txt.t(key)


# the contract's named items: [tag, name text], in ship-file order
func mandatory_items() -> Array:
	if _mand_zh == int(Txt.zh):
		return _mand
	_mand = []
	_mand_zh = int(Txt.zh)
	for pd in ship.get("pieces", []):
		if pd.get("mandatory", false):
			_mand.append([pd.get("tag", ""), txt(pd.get("name_key", ""))])
	return _mand


func all_mandatory_ok() -> bool:
	for it in mandatory_items():
		if not mandatory_ok.get(it[0], false):
			return false
	return true


func set_tier(tr: String) -> void:
	Txt.hint_tier = tr
	Txt.save_settings(testing)
	sfx.play("tool")


# the training course: Liang's automatic help when you're stuck, on or off
# (Q still asks for it either way)
func toggle_hints() -> void:
	hints_on = not hints_on
	Txt.hints = hints_on
	Txt.save_settings(testing)
	say("hints_auto_on" if hints_on else "hints_auto_off", drone.global_position + Vector2(0, -44))
	sfx.play("switch")


func cycle_tier() -> void:
	set_tier(Txt.TIERS[(Txt.TIERS.find(Txt.hint_tier) + 1) % Txt.TIERS.size()])
	say("tier_now", drone.global_position + Vector2(0, -44), txt("tier_" + Txt.hint_tier))


func room_name(room: String) -> String:
	return txt(Ship.room_name_key(ship, room))


# the ship as the player reads it: registration and type, in their language
func ship_title() -> String:
	var ty: Dictionary = Market.type_of(ship_id)
	var tn: String = ((ty.name[0] if Txt.zh else ty.name[1]) if ty.has("name") else "")
	var reg: String = job.get("reg", ship.get("name", "").split(" ")[0])
	return ("%s · %s" % [reg, tn]) if tn != "" else ship.get("name", "")


func cam_zoom() -> float:
	return zoom_now


# ---------------------------------------------------------------- frame

func _process(dt: float) -> void:
	if dev_overlay_open:
		return
	var rdt := dt / maxf(Engine.time_scale, 0.01)
	state_t += rdt
	if state == "play" and not menu_open:
		playtime += dt
		# the end is checked when something is delivered; once a second as well, for a
		# last piece that went some other way (and for a contract loaded with nothing left)
		done_t += rdt
		if done_t > 1.0:
			done_t = 0.0
			_check_done()
		if (training or career()) and not Career.data.is_empty() and Career.usable():
			Career.data.time = float(Career.data.get("time", 0.0)) + rdt
		if standard_time() > 0.0 and playtime > standard_time() and not hints_seen.has("late"):
			hints_seen["late"] = true
			Copy.say(radio, "L_late")
		autosave_t += rdt
		if autosave_t > 25.0 and not in_berth():
			autosave_t = 0.0
			SaveGame.save(self)
			hud.toast_saved()
	if state == "play" and bot == null and not in_berth():
		_account(dt, rdt)
	_read_input()
	var dev_warp: bool = DevPanel.warp_on() and bot == null
	var want_warp: bool = state == "play" and not menu_open and (Keys.down("warp") or dev_warp or (bot != null and bot.get("warp", false)))
	if want_warp != warp:
		warp = want_warp
		if hitstop_t <= 0.0 and slowmo <= 0.0:
			Engine.time_scale = _warp_k() if warp else 1.0
	match state:
		"intro":
			_intro(rdt)
		"play":
			if not menu_open and not contract_open:
				tools.aim = aim
				tools.step(dt)
			_drone_upkeep(dt)
		"ending":
			_ending(rdt)
		"towout":
			_towout(rdt)
	fx.step(dt)
	if not menu_open:
		radio.step(rdt, tools.cutting or (tools.held_piece != null and tools.tether_force > 0.2))
	_age_messages(rdt)
	if hitstop_t > 0.0:
		hitstop_t -= rdt
		Engine.time_scale = 0.05 if hitstop_t > 0.0 else (0.28 if slowmo > 0.0 else (_warp_k() if warp else 1.0))
	elif slowmo > 0.0:
		slowmo -= rdt
		Engine.time_scale = 0.28 if slowmo > 0.0 else (_warp_k() if warp else 1.0)


# one frame of the contract, booked to what the operator was doing
func _account(dt: float, rdt: float) -> void:
	var k := "wait"
	var sec := dt
	if menu_open or contract_open or (blueprint != null and blueprint.on):
		k = "menu"
		sec = rdt
	elif tools.cutting:
		k = "cut"
	elif tools.held_body != null or tools.held_piece != null:
		k = "haul"
	elif not tools.job.is_empty():
		k = "measure" if tools.job.kind == "measure" else "maintain"
	elif drone.alive and drone.linear_velocity.length() > 20.0:
		k = "fly"
	time_by[k] = float(time_by.get(k, 0.0)) + sec


func _warp_k() -> float:
	return DevPanel.time_k if DevPanel.warp_on() and bot == null else WARP


func _physics_process(dt: float) -> void:
	if dev_overlay_open:
		return
	_camera(dt / maxf(Engine.time_scale, 0.01))
	if state == "play" and not menu_open:
		tools.physics_step(dt)
		_bodies_upkeep(dt)


func _read_input() -> void:
	var mpos := get_global_mouse_position()
	var b: Dictionary = bot if bot != null else {}
	aim = b.get("aim", mpos)
	var lmb: bool = b.get("lmb", Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	var blocked: bool = menu_open or contract_open or (bot == null and hud.pointer_over_ui())
	# the press that readied the ring (on its slot) must let go before one can fire it
	if ring_wait and not lmb:
		ring_wait = false
	if blocked:
		lmb = false
	# a readied ring takes the click from the tools (and the rest of that press)
	if ring_armed:
		if state != "play" or not drone.alive or menu_open or contract_open or stock("ring") <= 0:
			ring_armed = false
		else:
			ring_aim = ring_target(aim)
			ring_eat = true
			if lmb and not prev_lmb and not ring_wait and breaching_ring():
				ring_armed = false
	if ring_eat and not ring_armed and not lmb:
		ring_eat = false
	tools.lmb_pressed = lmb and not prev_lmb and not ring_eat
	tools.lmb = lmb and not ring_eat
	prev_lmb = lmb
	var mv := Vector2.ZERO
	if b.has("move"):
		mv = b.move
	elif not menu_open and not contract_open:
		if Keys.down("left"):
			mv.x -= 1
		if Keys.down("right"):
			mv.x += 1
		if Keys.down("up"):
			mv.y -= 1
		if Keys.down("down"):
			mv.y += 1
	player_moved = mv != Vector2.ZERO
	# Q hint in the training course: the drone flies itself to where the target shows
	if tutorial != null and tutorial.autopilot != null and not player_moved:
		var to: Vector2 = tutorial.autopilot - drone.global_position
		mv = to.normalized() * clampf(to.length() / 90.0, 0.25, 1.0)
	drone.input.move = mv if state == "play" else Vector2.ZERO
	drone.input.dash = b.get("dash", Keys.down("dash")) and state == "play"
	drone.input.brake = b.get("brake", Keys.down("brake")) and state == "play"
	drone.input.hold = b.get("hold", Keys.down("hold") and not menu_open) and state == "play"
	overview = bot == null and state == "play" and not menu_open and not contract_open and Keys.down("overview")
	drone.aim = aim


func _unhandled_input(ev: InputEvent) -> void:
	# a berth computer is open over the berth: it has the keys
	if console_ui != null or dev_overlay_open:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var k: int = ev.physical_keycode
		if state == "intro":
			if k in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER]:
				_end_intro()
			return
		if state == "ending":
			if exam != null:
				if exam.result_t > 1.0 and k in [KEY_1, KEY_2]:
					exam_choice(k - KEY_1)
				return
			if story == null or not story.ending_key(k):
				hud.ending_key(k)
			return
		if k == KEY_ESCAPE:
			if ring_armed:
				arm_ring(false)
			elif contract_open:
				close_contract()
			else:
				toggle_menu()
			return
		if menu_open:
			return
		if contract_open:
			if k in [KEY_SPACE, KEY_ENTER]:
				close_contract()
			elif k in [KEY_1, KEY_2, KEY_3]:
				set_tier(Txt.TIERS[k - KEY_1])
			return
		if exam != null and k == KEY_Q:
			exam.request_hint()
			return
		if tutorial != null:
			if tutorial.choice_open() and k in [KEY_1, KEY_2]:
				tutorial.pick("a" if k == KEY_1 else "b")
				return
			if k == KEY_Q:
				tutorial.request_hint()
				return
			if tutorial.done and k in [KEY_1, KEY_2]:
				after_training("exam" if k == KEY_1 else "contract")
				return
		match Keys.action_of(ev):
			"tool1": tools.set_tool(1, false, true)
			"tool2": tools.set_tool(2, false, true)
			"tool3": tools.set_tool(3, false, true)
			"tool4": tools.set_tool(4, false, true)
			"tool5": tools.set_tool(5, false, true)
			"blueprint": blueprint.toggle()
			"repair": repair_kit()
			"ring": arm_ring(not ring_armed)
			"assist":
				drone.assist = not drone.assist
				Txt.assist = drone.assist
				Txt.save_settings(testing)
				say("assist_on" if drone.assist else "assist_off", drone.global_position + Vector2(0, -44))
				sfx.play("switch")
			"contract": open_contract()
			"log": hud.show_log = not hud.show_log
			"auto": toggle_auto()
			"plan":
				if plan != null:
					if auto_paused and not plan.running:
						auto_paused = false
					say(plan.toggle(), drone.global_position + Vector2(0, -44))
					sfx.play("switch")
			"mouth":
				# the equipment bay always runs on its rail; the furnace with the rail upgrade
				dock.move_equip(drone.global_position.x / Geom.M)
				if has_upgrade("mouth_rail"):
					dock.move_mouth(drone.global_position.x / Geom.M)
					say("mouth_moving_both", drone.global_position + Vector2(0, -44))
				else:
					say("mouth_moving_equip", drone.global_position + Vector2(0, -44))
				sfx.play("switch")
			"mark": mark_salvage()
			"use":
				if consoles != null and state == "play" and consoles.near() != "":
					open_console(consoles.near())
			"terminal":
				# the same terminal from anywhere in the berth
				if consoles != null and state == "play":
					open_console("terminal")
			"zone":
				if has_upgrade("zones"):
					say(toggle_keepout(aim), aim + Vector2(0, -30))
					sfx.play("switch")
			"hints":
				if training:
					toggle_hints()
	elif ev is InputEventMouseButton and ev.pressed:
		if state == "intro":
			_end_intro()
			return
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_target = clampf(zoom_target * 1.1, zoom_min(), 2.6)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_target = clampf(zoom_target / 1.1, zoom_min(), 2.6)
		elif ev.button_index == MOUSE_BUTTON_RIGHT and state == "play" and not menu_open and not contract_open:
			# A short click releases and marks; a drag only pans the view.
			rmb_down = true
			rmb_moved = 0.0
	elif ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		if rmb_down and rmb_moved < 10.0 and ring_armed:
			arm_ring(false)
		elif rmb_down and rmb_moved < 10.0 and state == "play" and not menu_open and not contract_open:
			if tools.held_piece != null:
				tools.release_grab(true)
			tools.job = {}
			if Keys.RIGHT_MOUSE in Keys.codes("mark"):
				mark_salvage()
		rmb_down = false
	elif ev is InputEventMouseMotion and rmb_down:
		rmb_moved += ev.relative.length()
		if rmb_moved >= 10.0:
			cam_pan -= ev.relative / maxf(zoom_now, 0.1)


func mark_salvage() -> void:
	var under: Array = world.pieces_at(aim)
	var mb = under[0].body if not under.is_empty() else null
	var key := ""
	# too heavy for the haulers (or none aboard): the crane's, if the berth has one
	if crane != null and mb != null and (hauler == null or mb.total_mass() > Hauler.MAX_T or crane.queue.has(mb)):
		key = crane.toggle(mb)
	elif hauler != null:
		key = hauler.toggle(mb)
	if key != "":
		say(key, aim + Vector2(0, -30))


func toggle_menu() -> void:
	menu_open = not menu_open
	get_tree().paused = menu_open
	paused_sim = menu_open
	hud.menu_changed()
	sfx.play("menu")


# one of the berth's computers: its terminal page over the berth, play stopped
# while it is open (the operator is at the desk, not at the controls)
func open_console(which: String) -> void:
	if console_ui != null or menu_open:
		return
	var term = load("res://scenes/terminal.tscn").instantiate()
	term.overlay = true
	term.between = in_berth()
	term.tab = -1
	term.game_ref = self
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	term.on_skill_changed = fit_skills
	term.on_close = func():
		fit_skills()
		console_ui = null
		layer.queue_free()
		get_tree().paused = false
		paused_sim = false
		sfx.play("menu")
	get_tree().paused = true
	paused_sim = true
	layer.add_child(term)
	console_ui = term
	sfx.play("menu")


func open_contract() -> void:
	if in_berth():
		return
	contract_open = true
	hud.contract_changed()


func close_contract() -> void:
	contract_open = false
	hud.contract_changed()
	sfx.play("ok")
	hint("start")
	# Liang on the risk the operator just signed for
	match int(job.get("stars", 0)):
		1: Copy.say(radio, "L_accept_low")
		3: Copy.say(radio, "L_accept_high")
	# an opening ship: Liang's lines as it comes in (empty slots say nothing)
	if job.has("intro"):
		for i in 3:
			Copy.say(radio, "%s_%d" % [job.intro, i + 1])
	if story != null:
		story.on_start()


# ---------------------------------------------------------------- camera

# the zoom that fits the whole berth and the ship in it: the wheel goes all the
# way out to it (P.6), and the hold-to-look overview uses it
const ZOOM_FOLLOW := 0.85    # below this the view starts leaving the drone for the berth's middle


func zoom_min() -> float:
	var vs := get_viewport().get_visible_rect().size
	return minf(vs.x / ((Dock.FLOOR_X1 - Dock.TOWER_X + 3.0) * Geom.M), vs.y / (26.0 * Geom.M))


func _camera(dt: float) -> void:
	_pan(dt)
	var target := cam_pos
	if cam_override != null:
		target = cam_override
	elif overview:
		target = Dock.centre() * Geom.M
	elif drone != null and (drone.alive or state == "play"):
		var dp: Vector2 = drone.global_position
		var lead := drone.linear_velocity * 0.22
		var look: Vector2 = (aim - dp).limit_length(380.0) * 0.18
		target = dp + lead + look
		if tools.held_piece != null and not tools.held_piece.gone:
			target = target.lerp(tools.grab_point(), 0.18)
		target += cam_pan
		# zoomed right out the view settles on the berth: the whole ship in sight
		var zm := zoom_min()
		if zoom_target < ZOOM_FOLLOW and zm < ZOOM_FOLLOW:
			target = target.lerp(Dock.centre() * Geom.M, clampf((ZOOM_FOLLOW - zoom_target) / (ZOOM_FOLLOW - zm), 0.0, 1.0))
	# a critically damped follow: soft, never laggy
	var k := 38.0
	var c := 2.0 * sqrt(k)
	var n := maxi(1, ceili(dt / (1.0 / 240.0)))
	var h := dt / n
	for i in n:
		cam_vel += ((target - cam_pos) * k - cam_vel * c) * h
		cam_pos += cam_vel * h
	var zt := zoom_override if zoom_override > 0.0 else zoom_target
	if overview and zoom_override <= 0.0:
		# the whole ship and the berth in view
		zt = zoom_min()
	if state == "play" and drone.alive:
		zt *= lerpf(1.0, 0.86, clampf(drone.linear_velocity.length() / 700.0, 0.0, 1.0))
		if zoom_override <= 0.0:
			zt = maxf(zt, minf(zoom_min(), zoom_target))
	zoom_now = Pal.damp(zoom_now, zt, 4.0 if zoom_override > 0.0 else 6.0, dt)
	trauma = maxf(0.0, trauma - dt * 1.6)
	punch = Pal.damp2(punch, Vector2.ZERO, 12.0, dt)
	var sh := trauma * trauma
	var tt := Time.get_ticks_msec() / 1000.0
	var off := Vector2(sin(tt * 47.0) + sin(tt * 31.0) * 0.5, cos(tt * 41.0) + sin(tt * 23.0) * 0.5) * 14.0 * sh
	cam.position = cam_pos + off + punch
	cam.zoom = Vector2(zoom_now, zoom_now)
	cam.rotation = sin(tt * 37.0) * 0.006 * sh


# the view leaves the drone while the right button drags it or the pointer
# rests on a screen edge, and drifts back when let go
func _pan(dt: float) -> void:
	var edge := Vector2.ZERO
	if bot == null and state == "play" and not menu_open and not contract_open and not rmb_down and DisplayServer.window_is_focused():
		var vs := get_viewport().get_visible_rect().size
		var m := get_viewport().get_mouse_position()
		if Rect2(Vector2.ZERO, vs).has_point(m):
			if m.x < 6.0: edge.x = -1.0
			elif m.x > vs.x - 6.0: edge.x = 1.0
			if m.y < 6.0: edge.y = -1.0
			elif m.y > vs.y - 6.0: edge.y = 1.0
	if edge != Vector2.ZERO:
		cam_pan += edge * 1100.0 / maxf(zoom_now, 0.1) * dt
	elif not (rmb_down and rmb_moved >= 10.0):
		cam_pan = Pal.damp2(cam_pan, Vector2.ZERO, 5.0, dt)
	cam_pan = cam_pan.limit_length(40.0 * Geom.M)


# a few frames of near-freeze that sell an impact
func hitstop(sec: float) -> void:
	if state != "play" or bot != null or Txt.no_flash():
		return
	hitstop_t = maxf(hitstop_t, sec)


func shake(amount: float, dir: Vector2 = Vector2.ZERO) -> void:
	if Txt.no_flash():
		return
	trauma = minf(1.0, trauma + amount)
	punch += dir * 12.0 * amount


# ---------------------------------------------------------------- intro & ending

func _intro(dt: float) -> void:
	var t := state_t
	# the tug pushes GR-7 into the dock
	var k := Pal.ease_io(clampf(t / 3.4, 0.0, 1.0))
	world.position.x = ship_offset * (1.0 - k)
	cam_override = Vector2(21.0 * 48.0 + world.position.x * 0.35, -0.5 * 48.0)
	zoom_override = 0.62
	for i in dock.clamps.size():
		var on := clampf((t - 3.5 - i * 0.22) / 0.3, 0.0, 1.0)
		dock.clamp_t[i] = 1.0 - Pal.ease_out(on)
		if on > 0.0 and not dock.has_meta("cl%d" % i):
			dock.set_meta("cl%d" % i, true)
			var p: Vector2 = dock.clamps[i] * 48.0
			fx.flash(p, 60.0, 0.35, Pal.ink(0.8, 1.6))
			fx.sparks(p, Vector2.UP, 10, Pal.heat(1.0, 2.0), 260.0, 0.35, 1.2)
			shake(0.15)
			sfx.play("clamp")
	if t > 4.7 and not drone.alive:
		_launch_drone()
	if t > 5.0:
		cam_override = null
		zoom_override = -1.0
	if t > 6.2:
		_end_intro()


# the empty berth comes up as it was left: no tug, no contract card, the drone flying on
func _enter_berth() -> void:
	world.position.x = 0.0
	for i in dock.clamps.size():
		dock.clamp_t[i] = 1.0
	state = "play"
	state_t = 0.0
	if not carry.is_empty():
		drone.alive = true
		drone.integrity = float(carry.get("integrity", 100.0))
		drone.spawn_t = 3.0
		drone.global_position = carry.pos
		drone.linear_velocity = carry.vel
		drone.reset_physics_interpolation()
		cam_pos = carry.cam
		zoom_now = float(carry.zoom)
		zoom_target = CAM_ZOOM
		carry = {}
	elif not drone.alive:
		_launch_drone()
		cam_pos = drone.global_position
		zoom_now = CAM_ZOOM
	if hud != null:
		hud.show_hint(txt("berth_hint") % Keys.label("terminal"))


# what the berth's length goes by: the career's purchases (and the developer's kit)
func _upgrades_for_berth() -> Dictionary:
	var u: Dictionary = {}
	for k in ["berth88", "berth120", "berth200"]:
		if has_upgrade(k):
			u[k] = true
	return u


# no ship in: the berth between contracts
func in_berth() -> bool:
	return ship.get("berth", false)


func _end_intro() -> void:
	if state != "intro":
		return
	world.position.x = 0.0
	for i in dock.clamps.size():
		dock.clamp_t[i] = 0.0
	if not drone.alive:
		_launch_drone()
	cam_override = null
	zoom_override = -1.0
	state = "play"
	state_t = 0.0
	if exam != null:
		exam.on_start()
	elif (bot == null or not bot.get("skip_contract", false)) and not training:
		open_contract()


func _launch_drone() -> void:
	drone.alive = true
	drone.integrity = 100.0
	drone.spawn_t = 0.0
	drone.global_position = Dock.BAY * Geom.M + Vector2(-30, 0)
	drone.reset_physics_interpolation()
	drone.linear_velocity = Vector2(520, 0)
	fx.flash(drone.global_position, 50.0, 0.3, Pal.heat(0.6, 1.8))
	fx.ring(drone.global_position, 10.0, 60.0, 0.4, Pal.ink(0.6))
	sfx.play("launch")


func finish_contract(early: bool) -> void:
	if ended:
		return
	ended = true
	if early and not training and exam == null:
		var rest := 0.0
		for p in pieces_left():
			rest += p.mass * world.metal_price
		income_rest = snappedf(rest * REST_SCRAP, 1.0)
	state = "ending"
	state_t = 0.0
	tools.release_grab(false)
	if tools.cutting:
		tools._finish_cut()
	if not early:
		slowmo = 0.5
	cam_override = Vector2(21.0 * 48.0, -0.2 * 48.0)
	zoom_override = 0.6
	if story != null and story.wants_epilogue():
		story.start_epilogue(early)
	else:
		hud.start_ending(early)
	sfx.play("end")
	# a developer's test contract leaves the career's save and records alone
	if (not testing or SaveGame.allow_test) and not dev_job():
		SaveGame.clear()
	if not testing and not dev_job():
		best = SaveGame.record_best(recovery_rate(), net(), playtime, hud.grade())
	if career() and Career.usable():
		Career.load_or_new()
		Career.file_notes(ship_id, verified)
		if plan != null and not early:
			plan.commit()
		career_result = Career.settle(settle_report())
		if job.has("outro") and not early:
			Copy.say(radio, job.outro)
		if career_result.installment + career_result.interest > 0.0:
			Copy.say(radio, "T_loan_installment", "term")
		if career_result.bonus > 0.0 and playtime <= standard_time():
			Copy.say(radio, "L_bonus")
		if career_result.short > 0.5:
			Copy.say(radio, "L_loan_short")


# what the career needs to know about how this contract went
func settle_report() -> Dictionary:
	var tb := {}
	for k in time_by:
		tb[k] = snappedf(float(time_by[k]), 0.1)
	return {"earned": earned(), "losses": losses, "rate": recovery_rate(), "grade": hud.grade(), "time": playtime, "fee": fee, "bonus": bonus(), "used": used, "ops": ops,
		"bonuses": bonuses(), "incidents": incidents.duplicate(true), "time_by": tb}


# the contract's standard time (0: none, like the first contract)
func standard_time() -> float:
	return float(job.get("time", 0.0))


# what the contract pays on top of the books (V2 2.2 / 2.6): [label key, amount]
#   time     finished within the standard time (a fast job pays a bigger share)
#   rate     the recovery rate reached 70 / 80 / 92 %
#   named    each named piece of equipment delivered whole (a rescue pays per piece already)
#   safe     a safe-recovery job with no incident at all
func bonuses() -> Array:
	if job.is_empty() or training or exam != null:
		return []
	var out: Array = []
	var g: String = goal()
	if standard_time() > 0.0:
		out.append(["e_bonus", Career.time_bonus(net(), playtime, standard_time(), Career.FAST_BONUS if g == "fast" else Career.BONUS)])
	var r := recovery_rate()
	for th in RATE_BONUS:
		if r >= th[0]:
			out.append(["e_rate_bonus", snappedf(earned() * th[1], 1.0)])
			break
	if scope() != "rescue":
		var named := 0.0
		for tg in must_value:
			named += maxf(MUST_MIN, float(must_value[tg]) * (MUST_VALUABLE if g == "valuable" else MUST_SHARE))
		if named > 0.0:
			out.append(["e_must_bonus", snappedf(named, 1.0)])
	if g == "safe" and incidents.is_empty():
		out.append(["e_safe_bonus", snappedf(earned() * SAFE_SHARE, 1.0)])
	return out


func bonus() -> float:
	var sum := 0.0
	for b in bonuses():
		sum += float(b[1])
	return sum


# the order's goal on top of its scope: "safe", "fast", "valuable" (or none, like the opening contracts)
func goal() -> String:
	return job.get("goal", "")


func career() -> bool:
	return (not job.is_empty() and not dev_job()) or (in_berth() and Career.usable())


# a contract the developer built and started (DevPanel): played like any other, settled into nothing
func dev_job() -> bool:
	return job.get("dev", false)


func _ending(_dt: float) -> void:
	pass


func restart() -> void:
	# a developer's test contract comes back as it was built
	if dev_job():
		contract = job.duplicate(true)
		start_ship = ship_id
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()


# the course is over: the apprentice assessment, or straight to the first contract
func after_training(where: String) -> void:
	SaveGame.clear(SaveGame.train_path)
	Engine.time_scale = 1.0
	get_tree().paused = false
	if where != "exam" and Career.usable():
		play_career(get_tree())
		return
	start_ship = "exam" if where == "exam" else "gr7"
	SaveGame.load_requested = false
	get_tree().reload_current_scene()


# after the assessment: 0 take it again, 1 on to the first contract
func exam_choice(i: int) -> void:
	if i == 0:
		Engine.time_scale = 1.0
		get_tree().paused = false
		start_ship = "exam"
		SaveGame.load_requested = false
		get_tree().reload_current_scene()
	else:
		after_training("contract")


func skip_training() -> void:
	if not Txt.certified:
		Txt.certified = true
		Txt.cert_kind = "skipped"
		Txt.save_settings(testing)
	Career.certify("skipped")
	after_training("contract")


func to_title() -> void:
	if state == "play":
		SaveGame.save(self)
	if (training or career()) and not Career.data.is_empty():
		Career.save()
	Engine.time_scale = 1.0
	get_tree().paused = false
	var tree := get_tree()
	Wipe.go(tree, func(): tree.change_scene_to_file("res://scenes/title.tscn"))


# the contract is over and settled: a career goes back to the berth terminal
func leave() -> void:
	if dev_job():
		# back to where the developer started it from
		Engine.time_scale = 1.0
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/terminal.tscn" if job.get("dev_from", "") == "terminal" and Career.usable() else "res://scenes/title.tscn")
		return
	if not career():
		to_title()
		return
	Engine.time_scale = 1.0
	get_tree().paused = false
	# the tug takes what is left of the ship out, and the berth stays: the next
	# contract is picked at the berth's computer (or with the terminal key)
	_tow_out()


func _tow_out() -> void:
	if state == "towout":
		return
	state = "towout"
	state_t = 0.0
	hud.ending = false
	tools.release_grab(false)
	# what's still loose rides out with the hull
	for b in world.bodies:
		if is_instance_valid(b):
			b.set_deferred("freeze", true)
	cam_override = Vector2(21.0 * 48.0, -0.5 * 48.0)
	zoom_override = 0.62
	sfx.play("clamp")


# the hull goes out the way it came in: the tug pulls it away, speeding up
func _towout(rdt: float) -> void:
	var k := clampf(state_t / TOW_T, 0.0, 1.0)
	world.position.x = ship_offset * pow(k, 3.0)
	for i in dock.clamps.size():
		dock.clamp_t[i] = clampf(state_t / 0.4 - i * 0.25, 0.0, 1.0)
	if state_t >= TOW_T and not _berth_asked:
		_berth_asked = true
		_to_berth()


var _berth_asked := false


func _to_berth() -> void:
	carry = {"pos": drone.global_position, "vel": drone.linear_velocity, "cam": cam.position if cam != null else cam_pos,
		"zoom": zoom_now, "integrity": drone.integrity if drone.alive else 100.0}
	Game.start_ship = "berth"
	Game.contract = {}
	SaveGame.load_requested = false
	var tree := get_tree()
	Wipe.go(tree, func(): tree.change_scene_to_file("res://scenes/main.tscn"))


# the career's contract in hand (the first one after training), or the terminal when there is none
static func play_career(tree: SceneTree) -> void:
	Career.load_or_new()
	var a: Dictionary = Career.sign_active()
	if a.is_empty():
		start_ship = "berth"
		contract = {}
		SaveGame.load_requested = false
		tree.change_scene_to_file("res://scenes/main.tscn")
		return
	contract = a
	start_ship = a.get("ship", "gr7")
	var saved := SaveGame.read(SaveGame.path) if SaveGame.exists() else {}
	SaveGame.load_requested = not saved.is_empty() and saved.get("job", a).get("id", "") == a.get("id", "")
	tree.change_scene_to_file("res://scenes/main.tscn")


# ---------------------------------------------------------------- economy

func earned() -> float:
	# a part-ship contract buys pieces, not the ship's gas and fluids
	if scope() != "full":
		return income_equip + income_metal + income_hazard + income_rest
	return income_equip + income_metal + income_hazard + income_rest + sys.gas_value() + sys.fluid_value()


# pieces of the contract still to come off (in scope, not yet delivered)
func pieces_left() -> Array:
	var out: Array = []
	for id in world.order:
		var p = world.pieces[id]
		if not p.gone and p.scope:
			out.append(p)
	return out


# "full" | "section" | "rescue" (Variant._scope)
func scope() -> String:
	return ship.get("scope", {}).get("kind", "full")


# a section contract's boundary (m), or -1
func boundary() -> float:
	return float(ship.get("scope", {}).get("boundary", -1.0))


# what a piece would have fetched (whole equipment at its value and condition, the rest as scrap)
func worth(p) -> float:
	if p.cls == "equip" and p.intact:
		return p.value * clampf(p.cond, 0.0, 1.0)
	return p.mass * world.metal_price


# taken from outside a section contract's section, or cut there: the breach is charged
func breach(p, cut: bool, at: Vector2) -> void:
	if scope() != "section" or p.scope:
		return
	var amount: float
	if cut:
		amount = worth(p) * Variant.BREACH_CUT if p.cls == "equip" and p.intact else Variant.BREACH_CUT_METAL
	else:
		amount = worth(p)
	if amount > 0.5:
		lose("loss_breach_cut" if cut else "loss_breach_take", snappedf(amount, 10.0), at)


func recovery_rate() -> float:
	return earned() / float(ship.get("value", {}).get("total", 120000.0))


func net() -> float:
	return earned() - losses - fee


func incident(kind: String, detail: String = "") -> void:
	incidents.append([snappedf(playtime, 0.1), kind, detail])
	if assist != null:
		assist.on_incident(kind)


# value knocked off a piece (it still sells, for less): kept for the settlement's review
func note_loss(reason: String, tag: String, amount: float) -> void:
	if amount >= 1.0:
		devalued.append([reason, tag, snappedf(amount, 1.0)])


func _dent(p, new_cond: float, reason: String) -> void:
	if p.cls == "equip" and p.intact and new_cond < p.cond:
		note_loss(reason, p.tag, (p.cond - new_cond) * p.value)
	p.cond = new_cond


# a named piece of the contract is past saving: say so now, not at the settlement
func mandatory_gone(p, reason: String) -> void:
	if not p.mandatory or mandatory_lost.has(p.tag) or mandatory_ok.get(p.tag, false):
		return
	mandatory_lost[p.tag] = reason
	incident("mandatory_lost", p.tag)
	hud.mandatory_alert(p.tag, reason)
	sfx.play("warn")
	shake(0.2)


func lose(key: String, amount: float, at: Vector2) -> void:
	# the training rig is insured: a mistake costs a tenth
	if training or exam != null:
		amount *= 0.1
	losses += amount
	loss_lines.append([key, amount])
	fx.number(at, "−" + Pal.money(amount).trim_prefix("$"), Pal.heat(1.0, 1.4), 22)
	feed.push_front([txt(key), -amount, 0.0])
	hud.pop_credits(-amount)


# ore pouring out of a hopper gate into the trough: paid by the tonne, booked a second at a time
var _ore_due := 0.0
var _ore_t := 0.0


func on_ore_in(v: float) -> void:
	# a part-ship contract buys pieces: the hopper's fines run out unpaid
	if scope() != "full":
		return
	_ore_due += v
	if playtime - _ore_t < 1.0:
		return
	_ore_t = playtime
	var at := Vector2(Dock.metal_x, Dock.TROUGH_Y - 1.0) * Geom.M
	ledger.append([txt("ore_fines"), "metal", _ore_due])
	gain("metal", _ore_due, at, txt("ore_fines"))
	log_op("arm_haul")
	_ore_due = 0.0


func gain(kind: String, amount: float, at: Vector2, label: String) -> void:
	match kind:
		"equip": income_equip += amount
		"metal": income_metal += amount
		"hazard": income_hazard += amount
	fx.number(at, "+" + Pal.money(amount), Pal.ink(1.0, 1.5), 26 if amount > 3000 else 20)
	feed.push_front([label, amount, 0.0])
	hud.fly_credits(at, amount)


func piece_value(p, zone: String) -> float:
	if not p.scope:
		return 0.0
	# a rescue pays each named piece its fixed fee, whole at the equipment mouth, and nothing else
	if scope() == "rescue":
		if zone == "equip" and p.cls == "equip" and p.intact:
			return float(ship.scope.get("pay", {}).get(p.tag, 0.0))
		return 0.0
	return _piece_value(p, zone)


func _piece_value(p, zone: String) -> float:
	var scrap: float = p.mass * world.metal_price
	var dest: String = sys.dest_of(p)
	var v := 0.0
	if p.cls == "equip" and p.intact:
		var full: float = p.value * clampf(p.cond, 0.0, 1.0)
		match zone:
			"equip": v = full if dest == "equip" else full * 0.4
			"metal": v = scrap
			"hazard": v = full * 0.4 if dest == "hazard" else full * 0.3
	else:
		v = scrap * (0.5 if zone == "hazard" else (1.0 if zone == "metal" else 0.8))
	if p.contam:
		v *= 0.75
	return v


func judge(b, zone: String) -> Dictionary:
	var total := 0.0
	var metal_m := 0.0
	var all_m := 0.0
	var hazard := false
	var equip_intact := false
	for p in b.pieces:
		all_m += p.mass
		var d: String = sys.dest_of(p)
		if d == "hazard":
			hazard = true
		if p.cls != "equip" or not p.intact:
			metal_m += p.mass
		else:
			equip_intact = true
		total += piece_value(p, zone)
	match zone:
		"equip":
			if hazard:
				return {"ok": false, "reason": "rej_hazard"}
			if not equip_intact:
				return {"ok": false, "reason": "rej_scrap"}
			if metal_m > all_m * 0.2:
				return {"ok": false, "reason": "rej_mixed"}
		"hazard":
			if equip_intact and not hazard:
				return {"ok": false, "reason": "rej_not_hazard"}
	return {"ok": true, "value": total, "hazard": hazard, "equip": equip_intact}


func on_reject(b, zone: String, verdict: Dictionary) -> void:
	say(verdict.reason, Dock.zpos(zone) - Dock.ZONES[zone].face * 20.0)
	sfx.play("reject")
	fx.flash(Dock.zpos(zone), 80.0, 0.3, Pal.heat(0.5, 1.4))


func on_swallow_start(b, zone: String) -> void:
	sfx.play("swallow_" + Dock.kind(zone))


func on_swallowed(b, mouth: String) -> void:
	# a second equipment bay pays and counts as the first; the effects play where it is
	var zone := Dock.kind(mouth)
	var at: Vector2 = Dock.zpos(mouth) - Dock.ZONES[mouth].face * 30.0
	var names: Array = []
	var v := 0.0
	var boom := false
	for p in b.pieces:
		v += piece_value(p, zone)
		if p.tag != "" and p.cls == "equip":
			names.append(p.tag)
			verify("pieces", p.tag, {"to": zone})
		if zone == "equip" and p.intact and p.cls == "equip" and p.mandatory:
			mandatory_ok[p.tag] = true
			must_value[p.tag] = float(p.value)
		elif p.mandatory and p.cls == "equip":
			mandatory_gone(p, "mg_wrong_mouth")
		if story != null and p.intact:
			story.on_delivered(p, zone)
		if zone == "metal" and sys.dest_of(p) == "hazard":
			boom = true
		# whatever it held goes with it
		var fv: String = sys.fluid_in_piece(p)
		if fv != "":
			sys.set_fluid(fv, 0.0)
		if sys.src.has(p.tag) and sys.src[p.tag].kind == "cap":
			sys.drain_source(p.tag)
	for p in b.pieces:
		breach(p, false, at)
	var label := ", ".join(names) if not names.is_empty() else txt("scrap_metal")
	if not b.pieces.any(func(p): return p.scope):
		label = txt("sc_out")
	ledger.append([label, zone, v])
	if b.get_meta("arm_drop", -1.0) >= 0.0 or not b.get_meta("hauled", false):
		# the arm brought it, or it drifted in on the mouth's own pull: nobody's hands
		log_op("arm_haul")
	elif zone == "hazard":
		log_op("deliver_hazard")
	elif b.pieces.any(func(p): return p.cls == "equip" and p.intact):
		log_op("deliver_equip")
	else:
		log_op("haul_scrap")
	if zone == "metal" and b.pieces.any(func(p): return p.cls == "equip" and p.intact):
		say("equip_as_scrap", at)
	if tutorial != null:
		tutorial.on_recovered(b, zone)
	if exam != null:
		exam.on_delivered(b, zone)
	gain("equip" if zone == "equip" else ("hazard" if zone == "hazard" else "metal"), v, at, label)
	var col := Pal.heat(1.0, 2.2) if zone == "metal" else (Pal.tint(Pal.FLUID, 0.9, 1.4) if zone == "hazard" else Pal.ink(0.9, 1.5))
	fx.flash(Dock.zpos(mouth), 140.0, 0.5, col)
	fx.ring(Dock.zpos(mouth), 20.0, 140.0, 0.5, col, 2.0)
	fx.sparks(Dock.zpos(mouth), -Dock.ZONES[mouth].face, 30, col, 480.0, 0.55, 0.9)
	var face: Vector2 = Dock.ZONES[mouth].face
	match zone:
		"metal":
			for i in 46:
				fx.molten(Dock.zpos(mouth) + Vector2(randf_range(-80, 80), 0), (-face * randf_range(160, 520)).rotated(randf_range(-0.5, 0.5)), randf_range(1.2, 2.4))
			fx.flash(Dock.zpos(mouth) - face * 40.0, 320.0, 0.8, Pal.heat(0.7, 3.0))
		"equip":
			for i in 3:
				fx.ring(Dock.zpos(mouth) - face * 30.0, 10.0 + i * 20.0, 150.0 + i * 50.0, 0.5 + i * 0.15, Pal.ink(0.7, 1.8), 1.6)
		"hazard":
			for i in 24:
				fx.puff(Dock.zpos(mouth), (-face * 200.0).rotated(randf_range(-1.2, 1.2)), 0.9, 8.0, 40.0, Pal.tint(Pal.FLUID, 0.12))
	hitstop(0.04)
	shake(0.12 + minf(0.25, b.total_mass() * 0.06))
	sfx.play("eat_" + zone)
	if boom:
		_furnace_boom()
	world.remove_body(b)
	_check_done()


func _furnace_boom() -> void:
	incident("furnace")
	var p := Dock.zpos("metal")
	fx.flash(p, 260.0, 0.7, Pal.heat(1.0, 3.0))
	fx.ring(p, 20.0, 300.0, 0.6, Pal.heat(0.9, 2.0), 3.0)
	fx.burst_shards(p, 24, 600.0, Pal.heat(0.9, 1.6), 12.0)
	shake(0.7)
	sfx.play("boom")
	lose("loss_furnace", 3000.0, p + Vector2(0, -60))


# the recovery arm let a load go over the furnace (the operation log counts it as the machine's)
func on_arm_drop(_b) -> void:
	sfx.play("release")


func on_debris_in(value: float, at: Vector2) -> void:
	income_metal += value
	hud.fly_credits(at, value)
	sfx.play("net")
	_check_done()


func _check_done() -> void:
	if state != "play" or training or exam != null or in_berth():
		return
	for id in world.order:
		if not world.pieces[id].gone and world.pieces[id].scope:
			return
	if not dock.debris.is_empty() or not dock.swallowing.is_empty():
		await get_tree().create_timer(0.8).timeout
	finish_contract(false)


# ---------------------------------------------------------------- bodies

func on_body_freed(b) -> void:
	if bio != null:
		bio.on_freed(b)
	if media != null:
		for q in b.pieces:
			media.on_manifold(q)
	if rails != null:
		rails.on_freed(b)
	if furnace != null:
		furnace.on_freed(b)
	var m: float = b.total_mass()
	for p in b.pieces:
		if p.has_meta("snap_kick"):
			b.linear_velocity = p.get_meta("snap_kick") * 260.0
			b.angular_velocity = randf_range(-1.5, 1.5)
			p.remove_meta("snap_kick")
	var all_metal := true
	for p in b.pieces:
		if p.cls == "equip" and p.intact:
			all_metal = false
	if all_metal and m < debris_max():
		# tiny cut-offs go straight to the debris net
		var vel: Vector2 = (b.global_position - SHIP_CENTER).normalized() * randf_range(60, 140)
		for p in b.pieces:
			dock.add_debris(world.world_poly(p), vel, p.mass * world.metal_price if p.scope and scope() != "rescue" else 0.0)
			breach(p, false, world.frame(p) * Geom.centroid(p.poly))
		world.remove_body(b)
		sfx.play("debris")
		return
	# its outline lights up and spreads out: it is free
	for p in b.pieces:
		fx.outline_pulse(world.world_poly(p), 0.6, Pal.ink(0.95, 2.0))
	# a gentle shove away from the hull so it reads as free
	var away: Vector2 = (b.global_position - SHIP_CENTER).normalized()
	b.linear_velocity += away * 10.0
	b.angular_velocity += randf_range(-0.05, 0.05)
	sfx.play("free", b.global_position, clampf(m / 2.0, 0.3, 1.0))
	# the last kerf flashes white-hot along its length and sheds sparks
	var now := Time.get_ticks_msec() / 1000.0
	var lit := 0
	for p in b.pieces:
		for h in p.heat:
			if now - h[1] > 0.6:
				continue
			var pl: PackedVector2Array = b.global_transform * (h[0] as PackedVector2Array)
			for i in range(0, pl.size(), 3):
				fx.sparks(pl[i], Vector2.from_angle(randf() * TAU), 2, Pal.heat(1.0, 3.2), 260.0, 0.45, PI)
				if randf() < 0.4:
					fx.molten(pl[i], Vector2.from_angle(randf() * TAU) * randf_range(30, 110), 1.8)
				lit += 1
	var com: Vector2 = b.global_transform * b.center_of_mass
	fx.flash(com, 70.0 + 60.0 * minf(m, 2.0), 0.35, Pal.heat(0.55, 2.4))
	fx.ring(com, 10.0, 90.0 + 40.0 * minf(m, 2.0), 0.45, Pal.ink(0.5, 1.6), 1.6)
	fx.burst_shards(com, 6 + int(m * 4), 160.0, Pal.ink(0.7), 6.0)
	shake(0.1 + minf(0.25, m * 0.06), away)
	if m > 0.5:
		hitstop(0.045 + minf(0.05, m * 0.015))
	fx.puff(com, Vector2.ZERO, 0.9, 14.0, 80.0, Pal.ink(0.05))
	hint("free_body")


func _bodies_upkeep(dt: float) -> void:
	for b in world.bodies:
		if not is_instance_valid(b) or b.capture != null:
			continue
		b.age += dt
		var dv: float = b.hit_imp / maxf(b.mass, 0.05)
		if dv > 55.0 and b.age > 0.4:
			_impact(b, dv)
		b.hit_imp = 0.0


func _impact(b, dv: float) -> void:
	var at: Vector2 = b.hit_pos
	var k := clampf((dv - 55.0) / 260.0, 0.0, 1.0)
	fx.sparks(at, Vector2.from_angle(randf() * TAU), 3 + int(k * 10), Pal.ink(0.8, 1.4), 200.0 + 200.0 * k, 0.3, 1.4)
	sfx.play("clank", at, 0.3 + 0.7 * k)
	var lost := 0.0
	for p in b.pieces:
		if p.cls == "equip" and p.intact:
			var before: float = p.cond
			_dent(p, maxf(0.0, p.cond - p.fragile * k * 0.5), "dv_impact")
			lost += (before - p.cond) * p.value
	if lost > 150.0:
		incident("impact", "%d" % int(lost))
		fx.number(at + Vector2(0, -20), "−" + Pal.money(lost).trim_prefix("$"), Pal.heat(0.9, 1.3), 18)
		say("impact_damage", at)
		hint("impact")
	if k > 0.3:
		shake(k * 0.2)


# ---------------------------------------------------------------- drone

func _drone_upkeep(dt: float) -> void:
	if not drone.alive:
		if drone_respawn > 0.0:
			drone_respawn -= dt
			if drone_respawn <= 0.0:
				_launch_drone()
		return
	var pull := dock.field_pull(drone.global_position)
	if pull != Vector2.ZERO:
		drone.external += pull * drone.mass * 3.0
		hint("field")
	var bay := Dock.BAY * Geom.M
	if drone.global_position.distance_to(bay) < 2.6 * Geom.M and drone.integrity < 100.0:
		drone.integrity = minf(100.0, drone.integrity + dt * 55.0)
		if randf() < 0.3:
			fx.sparks(drone.global_position, Vector2.UP, 1, Pal.ink(0.6, 1.2), 60.0, 0.3)


func hurt_drone(amount: float, from: Vector2, key: String, cd_key: String = "", cd: float = 1.0) -> void:
	if not drone.alive or drone.spawn_t < 1.0 or (Txt.dev and DevPanel.god and bot == null):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if cd_key != "" and now - hurt_cd.get(cd_key, -99.0) < cd:
		return
	if cd_key != "":
		hurt_cd[cd_key] = now
	incident("drone_hit", key)
	amount *= skill_value("armor") / 100.0
	if key in ["arc_hit", "live_unplug"]:
		amount *= skill_value("shield") / 100.0
	if key in ["scald", "fire_hit"]:
		amount *= skill_value("thermal") / 100.0
	drone.hurt(amount, from)
	shake(0.25 + amount / 100.0, (drone.global_position - from).normalized())
	sfx.play("hurt")
	say(key, drone.global_position + Vector2(0, -40))
	hud.hurt_flash(amount)


func on_drone_impact(pos: Vector2, dv: float) -> void:
	if dv > 175.0:
		var dmg := clampf((dv - 175.0) / 18.0, 1.0, 14.0)
		if dmg >= 8.0:
			hurt_drone(dmg, pos, "hit_hard", "impact", 0.7)
		elif drone.alive and not DevPanel.god:
			drone.integrity = maxf(1.0, drone.integrity - dmg * skill_value("armor") / 100.0)
			hud.hurt_flash(dmg)
	fx.sparks(pos, (drone.global_position - pos).normalized(), 6, Pal.ink(0.8, 1.3), 220.0, 0.3, 1.0)


func on_drone_destroyed() -> void:
	incident("drone_lost")
	var p := drone.global_position
	fx.flash(p, 200.0, 0.6, Pal.heat(1.0, 2.6))
	fx.ring(p, 10.0, 180.0, 0.6, Pal.heat(0.9, 1.8), 2.4)
	fx.burst_shards(p, 18, 380.0, Pal.ink(0.9), 9.0)
	fx.sparks(p, Vector2.UP, 30, Pal.heat(1.0, 2.2), 420.0, 0.6, PI)
	shake(0.8)
	sfx.play("boom")
	tools.release_grab(false)
	if tools.cutting:
		tools._finish_cut()
	# a spare drone in stock replaces it at no charge
	if use_item("spare"):
		say("item_spare", p + Vector2(0, -50))
	else:
		lose("loss_drone", DRONE_FEE, p + Vector2(0, -50))
	drone_respawn = 1.4 if training else 2.0
	drone.linear_velocity = Vector2.ZERO
	hint("drone_lost")


# ---------------------------------------------------------------- tool events

func on_laser_near_equipment(p, pos: Vector2) -> void:
	say("laser_near", pos, p.tag if p.tag != "" else Txt.piece_name(p))
	sfx.play("warn")
	hint("equip_cut")


func on_cut_into(p, pos: Vector2) -> void:
	if bio != null:
		bio.on_cut(p)
	breach(p, true, pos)
	if rails != null:
		rails.on_cut(p)
	if atmos != null:
		atmos.on_cut(p, pos)
	if media != null:
		media.on_manifold(p)
	if p.cls != "equip":
		return
	var was_value: float = p.value * p.cond
	var volts: float = sys.piece_volts(p)
	var fv: String = sys.fluid_in_piece(p)
	if p.hazard == "explosive" and p.intact and (munitions == null or munitions.live(p)):
		_blast(p, pos)
	elif sys.bursts(p):
		_burst(p, pos)
	elif fv != "" and sys.fluid(fv) > 0.02:
		_leak(sys.fvol[fv].fluid, fv, pos, p)
	if volts > 30.0:
		_arc(pos, volts, p)
		# the arc empties whatever stored it
		sys.drain_source(p.tag)
	elif volts > 0.0:
		fx.sparks(pos, Vector2.UP, 8, Pal.tint(Pal.VOLT, 1.0, 2.0), 160.0, 0.3, PI)
		sfx.play("zap_small")
	if p.intact:
		note_loss("dv_cut", p.tag, was_value - p.mass * world.metal_price)
		mandatory_gone(p, "mg_cut")
	if was_value > 200.0:
		incident("equip_cut", p.tag)
		fx.number(pos + Vector2(0, -30), "−" + Pal.money(was_value).trim_prefix("$"), Pal.heat(0.9, 1.3), 18)
		say("equip_ruined", pos, Txt.piece_name(p))
	# one touch of the beam and it is scrap
	if p.intact:
		p.intact = false
		world.redraw_all()


func _arc(pos: Vector2, volts: float, p = null) -> void:
	incident("arc", "%d V%s" % [int(volts), (" " + p.tag) if p != null and p.tag != "" else ""])
	var k := clampf(volts / 400.0, 0.3, 1.0)
	for i in 3 + int(k * 3):
		fx.arc(pos, pos + Vector2.from_angle(randf() * TAU) * randf_range(40, 120) * k, randf_range(0.18, 0.35), k)
	if drone.alive and drone.global_position.distance_to(pos) < 3.0 * 48.0:
		fx.arc(pos, drone.global_position, 0.3, 1.0)
		hurt_drone(40.0 * k, pos, "arc_hit", "arc", 0.6)
	fx.flash(pos, 220.0 * k, 0.4, Pal.tint(Pal.VOLT, 1.0, 2.4))
	fx.sparks(pos, Vector2.from_angle(randf() * TAU), 24, Pal.tint(Pal.VOLT, 1.0, 2.2), 420.0, 0.4, PI)
	hud.white_flash(0.35 * k)
	shake(0.35 * k)
	hitstop(0.06 * k)
	sfx.play("arc")
	hint("arc")


func _burst(p, pos: Vector2) -> void:
	incident("burst", p.tag)
	var v: String = sys.tank_vol(p)
	sys.gas_lost += sys.vols[v].n
	sys.vols[v].n = 0.0
	var c := world.frame(p) * Geom.centroid(p.poly)
	fx.flash(c, 240.0, 0.5, Pal.ink(1.0, 2.0))
	fx.ring(c, 10.0, 220.0, 0.5, Pal.ink(0.9), 3.0)
	for i in 40:
		var d := Vector2.from_angle(randf() * TAU)
		fx.puff(c, d * randf_range(200, 600), randf_range(0.5, 1.1), 6.0, 40.0, Pal.tint(Pal.AIR, 0.12))
	fx.burst_shards(c, 14, 420.0, Pal.ink(0.8), 8.0)
	for b in world.bodies:
		var d2: Vector2 = b.global_position - c
		if d2.length() < 4.0 * 48.0:
			b.apply_central_impulse(d2.normalized() * b.mass * 260.0 * (1.0 - d2.length() / 192.0))
	if drone.alive and drone.global_position.distance_to(c) < 3.0 * 48.0:
		hurt_drone(25.0, c, "burst_hit", "burst", 0.5)
	for q in _equip_near(c, 1.6 * 48.0):
		if q != p:
			_dent(q, maxf(0.0, q.cond - 0.2 * q.fragile), "dv_burst")
	shake(0.6)
	hud.white_flash(0.25)
	hitstop(0.07)
	sfx.play("burst")
	hint("burst")


# dangerous goods under the beam
func _blast(p, pos: Vector2) -> void:
	incident("blast", p.tag)
	var c := world.frame(p) * Geom.centroid(p.poly)
	fx.flash(c, 360.0, 0.7, Pal.heat(1.0, 3.0))
	fx.ring(c, 20.0, 340.0, 0.6, Pal.heat(0.9, 2.2), 3.0)
	fx.burst_shards(c, 26, 620.0, Pal.heat(0.9, 1.6), 12.0)
	fx.sparks(c, Vector2.UP, 50, Pal.heat(1.0, 2.4), 560.0, 0.6, PI)
	for b in world.bodies:
		var d2: Vector2 = b.global_position - c
		if d2.length() < 5.0 * 48.0:
			b.apply_central_impulse(d2.normalized() * b.mass * 320.0)
	if drone.alive and drone.global_position.distance_to(c) < 3.5 * 48.0:
		hurt_drone(40.0, c, "fire_hit", "blast", 1.0)
	for q in _equip_near(c, 3.0 * 48.0):
		if q != p:
			_dent(q, maxf(0.0, q.cond - 0.4 * q.fragile), "dv_blast")
	shake(0.8)
	hud.white_flash(0.35)
	hitstop(0.08)
	sfx.play("boom")
	lose("loss_blast", 2500.0, c + Vector2(0, -60))
	p.intact = false
	if munitions != null:
		munitions.on_blast(p, c)


# a cracked piece of structure gives way under the grapple
func on_snap(j) -> void:
	var at: Vector2 = world.joint_world(j)
	var pa = world.pieces.get(j.a)
	incident("snap", pa.get_meta("origin", pa.tag) if pa != null else "")
	world.kill_joint(j)
	# the part that let go drops away from the pull: a roof plate's half falls into the room below
	# the half the grapple is not holding is the one that drops
	var held = tools.held_piece
	var pb = world.pieces.get(j.a if held != null and held.id == j.b else j.b) if held != null else world.pieces.get(j.a)
	if pb != null:
		pb.set_meta("snap_kick", Vector2(0, 1) if pb.kind == "hull" else Vector2.from_angle(randf() * TAU))
		if pb.kind == "hull":
			_falls_in(pb)
	fx.flash(at, 120.0, 0.35, Pal.ink(0.9, 1.8))
	fx.burst_shards(at, 12, 360.0, Pal.ink(0.8), 7.0)
	fx.sparks(at, Vector2.from_angle(randf() * TAU), 18, Pal.ink(0.9, 1.4), 320.0, 0.35, PI)
	var lost := 0.0
	for q in _equip_near(at, 3.0 * 48.0):
		var before: float = q.cond
		_dent(q, maxf(0.0, q.cond - 0.25 * q.fragile), "dv_snap")
		lost += (before - q.cond) * q.value
	if lost > 50.0:
		fx.number(at + Vector2(0, -30), "−" + Pal.money(lost).trim_prefix("$"), Pal.heat(0.9, 1.3), 18)
	if drone.alive and drone.global_position.distance_to(at) < 2.0 * 48.0:
		hurt_drone(10.0, at, "hit_hard", "snap", 1.0)
	shake(0.4)
	hitstop(0.05)
	sfx.play("snap")
	say("snapped", at)


# half a roof plate drops into the room below: whatever stands under it takes the blow
func _falls_in(p) -> void:
	var bb := Geom.bbox(world.world_poly(p))
	var room := world.room_at(bb.get_center() + Vector2(0, 1.5 * Geom.M))
	if room == "":
		return
	var lost := 0.0
	for id in world.order:
		var q = world.pieces[id]
		if q.gone or q.body != null or q.cls != "equip" or not q.intact or q.room != room:
			continue
		var qb := Geom.bbox(q.poly)
		if qb.end.x < bb.position.x or qb.position.x > bb.end.x:
			continue
		var before: float = q.cond
		# a tonne of plate dropping the height of the hold: what is fragile is finished
		_dent(q, maxf(0.0, q.cond - q.fragile), "dv_fall")
		lost += (before - q.cond) * q.value
		fx.sparks(Vector2(qb.get_center().x, qb.position.y), Vector2.UP, 16, Pal.ink(0.9, 1.4), 280.0, 0.35, PI)
	if lost > 50.0:
		incident("impact", "%d" % int(lost))
		fx.number(bb.get_center() + Vector2(0, 2.0 * Geom.M), "−" + Pal.money(lost).trim_prefix("$"), Pal.heat(0.9, 1.3), 20)
		shake(0.3)


func _equip_near(c: Vector2, r: float) -> Array:
	var out: Array = []
	for id in world.order:
		var q = world.pieces[id]
		if q.gone or q.cls != "equip" or not q.intact:
			continue
		if (world.frame(q) * Geom.centroid(q.poly)).distance_to(c) < r:
			out.append(q)
	return out


func _leak(fluid: String, src: String, at: Vector2, piece = null) -> void:
	incident("leak", src)
	var lk := {"pos": at, "dir": Vector2.from_angle(randf() * TAU), "fluid": fluid, "rate": 1.0, "src": src, "t": 0.0, "piece": piece, "local": Vector2.ZERO}
	if piece != null:
		lk.local = world.frame(piece).affine_inverse() * at
		lk.dir = (at - world.frame(piece) * Geom.centroid(piece.poly)).normalized()
	sys.leaks.append(lk)
	sfx.play("leak")
	say("leak_" + fluid, at)
	hint("leak_" + fluid)
	if fluid == "lng":
		# a cryogenic spray: whatever equipment stands close freezes and cracks
		for id in world.order:
			var q = world.pieces[id]
			if q.gone or q.cls != "equip" or not q.intact or q == piece:
				continue
			if (world.frame(q) * Geom.centroid(q.poly)).distance_to(at) < 3.0 * Geom.M:
				_dent(q, q.cond * 0.7, "dv_frost")


func leak_pos(lk: Dictionary) -> Vector2:
	if lk.piece != null and not lk.piece.gone:
		return world.frame(lk.piece) * lk.local
	return lk.pos


func on_line_cut(l, at: Vector2) -> void:
	changed["l:" + l.id] = true
	if l.kind == "cable":
		var volts: float = sys.line_volts(l) if l.id != "" else 0.0
		# line_volts reads alive lines; it has just been cut, so ask about the source side
		volts = _cut_cable_volts(l)
		if volts > 30.0:
			_arc(at, volts)
		elif volts > 0.0:
			fx.sparks(at, Vector2.UP, 10, Pal.tint(Pal.VOLT, 1.0, 2.0), 160.0, 0.3, PI)
			sfx.play("zap_small")
		else:
			fx.sparks(at, Vector2.UP, 4, Pal.ink(0.8, 1.3), 120.0, 0.2, PI)
		say("cable_cut", at, l.id.to_upper())
		return
	var vk: String = sys.fluid_of_net(l.net)
	if vk != "":
		var v: Dictionary = sys.fvol[vk]
		if sys.fluid_behind(vk) > float(v.get("leak_min", 0.02)):
			_leak(v.fluid, vk, at)
			if v.fluid != "fuel":
				# hot coolant scalds and fouls what it lands on
				if sys.line_temp(l) > 60.0 and drone.alive and drone.global_position.distance_to(at) < 2.5 * 48.0:
					hurt_drone(25.0, at, "scald", "scald", 1.0)
				var fouled := 0.0
				var names: Array = []
				for q in _equip_near(at, 2.0 * 48.0):
					if not q.contam and q.intact:
						fouled += q.value * clampf(q.cond, 0.0, 1.0) * 0.25
						note_loss("dv_contam", q.tag, q.value * clampf(q.cond, 0.0, 1.0) * 0.25)
						names.append(q.tag)
					q.contam = true
				if fouled > 50.0:
					fx.number(at + Vector2(0, -40), "−" + Pal.money(fouled).trim_prefix("$"), Pal.heat(0.9, 1.3), 20)
					say("contaminated", at + Vector2(0, -60), ", ".join(names))
				world.redraw_all()
	elif l.net == "gas":
		for i in 10:
			fx.puff(at, Vector2.from_angle(randf() * TAU) * 120.0, 0.6, 4.0, 22.0, Pal.tint(Pal.AIR, 0.1))
		sfx.play("hiss")
	fx.sparks(at, Vector2.UP, 3, Pal.ink(0.7, 1.2), 100.0, 0.2, PI)


func _cut_cable_volts(l) -> float:
	var was: bool = l.alive
	l.alive = true
	var v: float = sys.line_volts(l)
	l.alive = was
	return v


func on_ignite(cl: Dictionary, pos: Vector2) -> void:
	incident("fire")
	sys.clouds.erase(cl)
	var c: Vector2 = cl.pos
	fx.flash(c, cl.r * 2.2, 0.7, Pal.heat(1.0, 3.0))
	fx.ring(c, 10.0, cl.r * 1.6, 0.6, Pal.heat(0.9, 2.2), 3.0)
	for i in 50:
		var d := Vector2.from_angle(randf() * TAU)
		fx.puff(c + d * randf() * cl.r * 0.5, d * randf_range(80, 320), randf_range(0.4, 0.9), 8.0, 50.0, Pal.heat(0.25, 1.8))
	fx.sparks(c, Vector2.UP, 40, Pal.heat(1.0, 2.4), 500.0, 0.6, PI)
	if drone.alive and drone.global_position.distance_to(c) < cl.r + 1.5 * 48.0:
		hurt_drone(25.0, c, "fire_hit", "fire", 1.0)
	for q in _equip_near(c, cl.r + 48.0):
		_dent(q, maxf(0.0, q.cond - 0.3), "dv_fire")
	for b in world.bodies:
		var d2: Vector2 = b.global_position - c
		if d2.length() < cl.r * 2.0:
			b.apply_central_impulse(d2.normalized() * b.mass * 200.0)
	shake(0.7)
	hud.white_flash(0.3)
	sfx.play("ignite")
	lose("loss_fire", 1500.0, c + Vector2(0, -60))
	hint("fire")


# a finished laser stroke through one attached piece (pl in world space), as
# the laser would make it: equipment it touches, lines it crosses, the kerf
func cut_kerf(p, pl: PackedVector2Array) -> void:
	if pl.is_empty():
		return
	log_op("cut")
	if world.segment_cut(p, pl) and not _holds(p):
		# along its marked line: it comes apart as planned, nothing ruined
		fx.sparks(pl[0], Vector2.UP, 10, Pal.heat(1.0, 2.0), 160.0, 0.3, PI)
		say("seg_cut", pl[0], p.tag)
	else:
		on_cut_into(p, pl[0])
	if pl.size() >= 2:
		for hit in world.cut_lines(pl):
			on_line_cut(hit[0], hit[1])
	on_kerf(p, world.commit_cut(p, world.frame(p).affine_inverse() * pl))


# a marked line only takes an empty vessel apart cleanly: one still under
# pressure or holding liquid is ruined like any other cut
func _holds(p) -> bool:
	var fv: String = sys.fluid_in_piece(p)
	return sys.bursts(p) or (fv != "" and sys.fluid(fv) > 0.02)


func on_kerf(p, res: Dictionary) -> void:
	for j in res.killed:
		var jp: Vector2 = world.joint_world(j)
		fx.sparks(jp, Vector2.from_angle(randf() * TAU), 4, Pal.heat(1.0, 2.0), 160.0, 0.25, PI)
	for l in res.lines:
		on_line_cut(l, world.frame(p) * Geom.centroid(p.poly))
	if res.split > 1:
		sfx.play("crack", world.frame(p) * Geom.centroid(p.poly), 0.8)


func on_grab(p) -> void:
	if p.body == null:
		var fixed := 0
		for j in world.joints_of(p):
			if j.type in ["bolt", "weld", "clamp", "seam", "crack"]:
				fixed += 1
		var locks := 0
		for j in world.joints_of(p):
			if j.type == "lock":
				locks += 1
		var lines_n: int = world.lines_of(p).size()
		var live := 0.0
		for l in world.lines_of(p):
			if l.kind == "cable":
				live = maxf(live, _cut_cable_volts(l))
		if fixed > 0:
			say("still_fixed", aim, str(fixed))
			hint("fixings")
		elif locks > 0 or lines_n > 0:
			# these give way if you pull: say it before they do
			say("tear_warn_live" if live > 30.0 else "tear_warn", aim, "%d" % (locks + lines_n) if live <= 30.0 else "%d · %d V" % [locks + lines_n, int(live)])
		elif world.group_mass(p) > grab_max():
			say("too_heavy", aim, "%.1f" % world.group_mass(p))
	elif p.body.total_mass() > grab_max():
		say("too_heavy", aim, "%.1f" % p.body.total_mass())
		hint("heavy")
	elif p.cls == "equip" and p.intact:
		# whole equipment far from its bay: the bay comes to you
		var bay := Dock.zpos(Dock.nearest("equip", aim))
		if absf(bay.x - aim.x) > 10.0 * Geom.M:
			hint("equip_rail")


func on_tear(p, weak: Array, lines_held: Array, at: Vector2) -> void:
	# what held it: a fixing behind a cover, or lines (the accident review reads this)
	var held := ""
	if weak.any(func(j): return world.joint_covered(j)):
		held = " hidden"
	elif not lines_held.is_empty():
		held = " lines"
	incident("torn", p.tag + held)
	var dmg := 0.0
	for j in weak:
		world.kill_joint(j)
		dmg += 0.12
	if p.cls == "equip" and p.intact and p.mandatory and dmg >= 0.5:
		mandatory_gone(p, "mg_torn")
	for l in lines_held:
		var volts := _cut_cable_volts(l) if l.kind == "cable" else 0.0
		world.kill_line(l, world.line_end_world(l, 0 if l.a == p.id else 1))
		dmg += 0.15
		if volts > 30.0:
			_arc(at, volts * 0.5)
		elif l.kind == "pipe":
			on_line_cut(l, at)
	if p.cls == "equip" and p.intact:
		var before: float = p.cond
		_dent(p, maxf(0.0, p.cond - dmg * (0.5 + p.fragile)), "dv_tear")
		var lost: float = (before - p.cond) * p.value
		if lost > 50.0:
			fx.number(at + Vector2(0, -24), "−" + Pal.money(lost).trim_prefix("$"), Pal.heat(0.9, 1.3), 18)
	fx.sparks(at, Vector2.from_angle(randf() * TAU), 14, Pal.ink(0.9, 1.4), 300.0, 0.35, PI)
	shake(0.25)
	sfx.play("snap")
	say("torn_free", at)
	hint("torn")


# ---------------------------------------------------------------- measure / wrench / hose

func do_measure(tg: Dictionary) -> void:
	var mkey: String = str(tg.ctrl.id) if tg.kind == "ctrl" else (str(tg.line.id) if tg.kind == "line" else ("P:%d" % tg.piece.id if tg.has("piece") else ""))
	log_op("remeasure" if _measured.has(mkey) else "measure")
	_measured[mkey] = true
	match tg.kind:
		"ctrl":
			var c = tg.ctrl
			verify("ports", c.id, c.target)
			if c.kind == "discharge":
				sys.measure(c.id, "volts", c.id, "inst_volts", {"ctrl": c, "volts_fn": _ctrl_volts_fn(c)})
			else:
				match c.medium:
					"bio":
						sys.measure(c.id, "bio", c.id, "inst_bio", {"ctrl": c, "room": c.target})
					"o2":
						sys.measure(c.id, "o2", c.id, "inst_o2", {"ctrl": c, "room": c.target})
					"cold":
						sys.measure(c.id, "temp", c.id, "inst_hold_temp", {"ctrl": c, "temp_fn": func(): return coldchain.room_temp(c.target)})
					"sample":
						sys.measure(c.id, "sample", c.id, "inst_sample", {"ctrl": c, "sample_fn": func(): return media.sample(c.id)})
					"core":
						sys.measure(c.id, "temp", c.id, "inst_core", {"ctrl": c, "temp_fn": func(): return furnace.core_temp()})
					"mag":
						sys.measure(c.id, "field", c.id, "inst_field", {"ctrl": c, "field_fn": func(): return mech.field(c.target)})
					"heat":
						sys.measure(c.id, "temp", c.id, "inst_temp", {"ctrl": c, "temp_fn": func(): return munitions.room_temp(c.target)})
					"cryo":
						sys.measure(c.id, "temp", c.id, "inst_cryo", {"ctrl": c, "temp_fn": func(): return cryo.temp(c.target)})
					"tension":
						sys.measure(c.id, "field", c.id, "inst_tension", {"ctrl": c, "field_fn": func(): return mech.tension(c.target), "unit": "kN"})
					"gas":
						sys.measure(c.id, "pressure", c.id, "inst_pressure", {"ctrl": c, "vol": c.target})
						if sys.dead_leg_closed(c):
							hint("dead_leg")
					"volt":
						sys.measure(c.id, "volts", c.id, "inst_volts", {"ctrl": c, "volts_fn": _ctrl_volts_fn(c)})
						if sys.remote_sent and sys.bus_live:
							hint("not_off")
							if story != null:
								story.event("fake_off")
					_:
						if sys.fluid_at_port(c.id) != "":
							sys.measure(c.id, "fluid", c.id, "inst_fluid", {"ctrl": c, "fluid_fn": func(): return sys.port_level(c.id)})
						if sys.is_heat_port(c.id):
							sys.measure(c.id + "/T", "temp", c.id, "inst_temp", {"ctrl": c, "temp_fn": func(): return sys.loop_T})
		"line":
			var l = tg.line
			verify("lines", l.id, [tag_of(l.a), tag_of(l.b)])
			if l.kind == "cable":
				sys.measure("L:" + l.id, "volts", l.id.to_upper(), "inst_volts", {"anchor_pos": tg.pos, "volts_fn": func(): return sys.line_volts(l)})
			else:
				sys.measure("L:" + l.id, "temp", l.id.to_upper(), "inst_temp", {"anchor_pos": tg.pos, "temp_fn": func(): return sys.line_temp(l)})
		"inspect", "piece":
			var p = tg.piece
			verify("pieces", p.tag, {"fix": _inspect_text(p)})
			var key := "P:%d" % p.id
			var local: Vector2 = world.frame(p).affine_inverse() * tg.pos
			var label: String = p.tag if p.tag != "" else Txt.piece_name(p)
			sys.measure(key, "temp", label, "inst_inspect", {"piece": p, "local": local, "inspect": _inspect_text(p), "temp_fn": func(): return p.temp})
			if story != null:
				story.on_inspect(p)
			if sys.electric_piece(p):
				sys.measure(key + "/V", "volts", label, "inst_volts", {"piece": p, "local": local + Vector2(0, 16), "volts_fn": func(): return sys.piece_volts(p)})
	sfx.play("measure")
	fx.ring(tg.pos, 4.0, 26.0, 0.35, Pal.ink(0.8, 1.3), 1.4)
	hint("measured")


func restore_reading(rd: Dictionary) -> void:
	var key: String = rd.key
	var extra := {}
	if key.begins_with("L:"):
		var l = world.lines.get(key.substr(2))
		if l == null:
			return
		extra = {"anchor_pos": world.line_path_world(l)[0]}
		if rd.kind == "volts":
			extra.volts_fn = func(): return sys.line_volts(l)
		else:
			extra.temp_fn = func(): return sys.line_temp(l)
	elif key.begins_with("P:"):
		var pid := int(key.substr(2).split("/")[0])
		var p = world.pieces.get(pid)
		if p == null or p.gone:
			return
		extra = {"piece": p, "local": Geom.centroid(p.poly)}
		if rd.kind == "volts":
			extra.local += Vector2(0, 16)
			extra.volts_fn = func(): return sys.piece_volts(p)
		else:
			extra.inspect = _inspect_text(p)
			extra.temp_fn = func(): return p.temp
	else:
		var cid: String = key.split("/")[0]
		var c = world.ctrls.get(cid)
		if c == null:
			return
		extra = {"ctrl": c, "vol": rd.vol}
		match rd.kind:
			"volts":
				extra.volts_fn = _ctrl_volts_fn(c)
			"fluid":
				extra.fluid_fn = func(): return sys.port_level(c.id)
			"temp":
				if c.medium == "cryo":
					extra.temp_fn = func(): return cryo.temp(c.target)
				elif c.medium == "heat":
					extra.temp_fn = func(): return munitions.room_temp(c.target)
				elif c.medium == "cold":
					extra.temp_fn = func(): return coldchain.room_temp(c.target)
				elif c.medium == "core":
					extra.temp_fn = func(): return furnace.core_temp()
				else:
					extra.temp_fn = func(): return sys.loop_T
			"field":
				if c.medium == "tension":
					extra.field_fn = func(): return mech.tension(c.target)
					extra.unit = "kN"
				else:
					extra.field_fn = func(): return mech.field(c.target)
			"bio", "o2":
				extra.room = c.target
			"sample":
				extra.sample_fn = func(): return media.sample(c.id)
	var r := {"key": key, "kind": rd.kind, "at": rd.at, "inst": rd.inst, "t": rd.t, "val": rd.val, "text": rd.text, "ver": int(rd.ver), "vk": ""}
	r.merge(extra, true)
	sys.readings[key] = r


# What a volt probe on this control shows: a discharge plug reads its
# capacitor's own cable, a test point reads the bus.
func _ctrl_volts_fn(c) -> Callable:
	if c.kind == "discharge":
		var cap_tag: String = sys.discharge_source(c.id)
		# an isolated capacitor: its own reading
		if cap_tag != "" and sys.iso.has(cap_tag):
			var cp = world.tag(cap_tag)
			return func(): return sys.piece_volts(cp) if cp != null and not cp.gone else 0.0
		var l3 = world.lines.get(sys.src[cap_tag].cable) if cap_tag != "" else null
		return func(): return sys.line_volts(l3) if l3 != null and l3.alive else 0.0
	# a test point on a piece with its own supply (a pod's battery) reads that piece
	if c.kind == "test" and c.target != "" and c.target != "bus":
		var tp = world.tag(c.target)
		return func(): return sys.piece_volts(tp) if tp != null and not tp.gone else 0.0
	return func(): return sys.bus_volts()


func _inspect_text(p) -> String:
	var counts := {}
	for j in world.joints_of(p):
		counts[j.type] = counts.get(j.type, 0) + 1
	var nl := world.lines_of(p).size()
	var parts: Array = ["%.2f t" % world.group_mass(p)]
	for k in ["bolt", "weld", "lock", "clamp", "seam"]:
		if counts.has(k):
			parts.append("%d %s" % [counts[k], txt("j_" + k)])
	# a crack in the structure only shows to the precision kit
	if counts.has("crack") and has_upgrade("scan_kit"):
		parts.append("%d %s" % [counts.crack, txt("j_crack")])
	if nl > 0:
		parts.append("%d %s" % [nl, txt("j_line")])
	var behind := lines_behind(p)
	if behind > 0:
		parts.append("%d %s" % [behind, txt("j_behind")])
	if p.hazard == "explosive" and p.intact:
		parts.append(txt("j_wet") if munitions != null and munitions.wet.has(p.id) else txt("j_explosive"))
	# an armour plate: with the precision kit you can tell what is fixed behind it
	if p.art == "armor":
		var fb: int = world.fixings_behind(p) if has_upgrade("scan_kit") else 0
		parts.append(txt("j_armor") if fb == 0 else txt("j_armor_fix") % fb)
	# a bent gate or door shows it to anyone who looks
	if p.door and p.tag != "" and Ship.ctrl_cfg(ship, p.tag).get("stuck", false):
		parts.append(txt("insp_stuck"))
	if p.has_meta("segments") and p.intact:
		parts.append(txt("j_segments") % p.get_meta("segments").size())
	if p.cls == "equip" and p.intact and has_upgrade("scan_kit"):
		parts.append(txt("j_cond") % int(round(p.cond * 100.0)))
	if parts.size() == 1 and p.body == null:
		parts.append(txt("j_none"))
	return " · ".join(parts)


# cables and pipes that run behind an attached plate of the hull or a deck
func lines_behind(p) -> int:
	if p.body != null or not p.kind in ["hull", "deck", "bulkhead"]:
		return 0
	var n := 0
	# a probe senses what runs within a hand's breadth of the plate
	var grown: Array = Geometry2D.offset_polygon(p.poly, 0.25 * Geom.M)
	var near: PackedVector2Array = grown[0] if not grown.is_empty() else p.poly
	for id in world.lines:
		var l = world.lines[id]
		if not l.alive or l.a == p.id or l.b == p.id:
			continue
		var path: PackedVector2Array = world.line_path_world(l)
		for i in path.size() - 1:
			if Geometry2D.is_point_in_polygon(path[i], near) or not Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([path[i], path[i + 1]]), near).is_empty():
				n += 1
				break
	return n


# ---------------------------------------------------------------- the operation log

func log_op(kind: String, n: int = 1) -> void:
	ops[kind] = int(ops.get(kind, 0)) + n


# {manual, decision, machine, share (manual / (manual + decision))}
static func op_share(counts: Dictionary) -> Dictionary:
	var out := {"manual": 0, "decision": 0, "machine": 0}
	for k in counts:
		out[OP_CAT.get(k, "manual")] += int(counts[k])
	var hands: int = out.manual + out.decision
	out.share = float(out.manual) / hands if hands > 0 else 0.0
	return out


# ---------------------------------------------------------------- the engineering archive

# something checked by hand: kind pieces / ports / lines / ctrls, a factory name, what was found
func verify(kind: String, id: String, info) -> void:
	var pre: String = {"pieces": "p:", "ports": "c:", "lines": "l:", "ctrls": "c:"}[kind]
	if id == "" or not _factory.has(pre + id):
		return
	var was = verified[kind].get(id)
	if was is Dictionary and info is Dictionary:
		was.merge(info, true)
	else:
		verified[kind][id] = info


func tag_of(piece_id: int) -> String:
	var p = world.pieces.get(piece_id)
	return p.get_meta("origin", p.tag) if p != null else ""


# notes from earlier ships of this type, as the contract was signed with them
func notes() -> Dictionary:
	return job.get("notes", {})


# ---------------------------------------------------------------- consumables

# what is left of a consumable for this contract: the stock it was signed with, less what is used
func stock(id: String) -> int:
	var have: Dictionary = job.get("items", {}) if bot == null or not bot.has("items") else bot.items
	return int(have.get(id, 0)) - int(used.get(id, 0))


func use_item(id: String) -> bool:
	if stock(id) <= 0:
		return false
	used[id] = int(used.get(id, 0)) + 1
	return true


# +50 integrity on the spot
func repair_kit() -> void:
	if state != "play" or not drone.alive or drone.integrity >= 100.0:
		return
	if not use_item("repair"):
		say("item_none", drone.global_position + Vector2(0, -44), txt("it_repair"))
		sfx.play("deny")
		return
	drone.integrity = minf(100.0, drone.integrity + skill_value("repair_eff"))
	log_op("repair")
	fx.ring(drone.global_position, 10.0, 60.0, 0.4, Pal.ink(0.8, 1.6), 2.0)
	fx.sparks(drone.global_position, Vector2.UP, 14, Pal.ink(0.9, 1.4), 160.0, 0.4, PI)
	say("item_repaired", drone.global_position + Vector2(0, -44))
	sfx.play("ok")


const RING_REACH := 6.0 * Geom.M   # the ring is placed by the drone: as far as the measuring reach
const RING_SNAP := 1.6 * Geom.M    # the pointer this close to a member finds it


# 7 (or its slot) readies the ring; again, Esc or a right click puts it away
func arm_ring(on: bool) -> void:
	if on == ring_armed:
		return
	if on:
		if state != "play" or not drone.alive:
			return
		if stock("ring") <= 0:
			say("item_none", drone.global_position + Vector2(0, -44), txt("it_ring"))
			sfx.play("deny")
			return
		ring_aim = ring_target(aim)
		ring_wait = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	ring_armed = on
	sfx.play("switch")


# the keel, beam or rail nearest the pointer, the point on it the ring would
# clamp to and the cut it would make: {piece, at, line, ok, why}
func ring_target(at: Vector2) -> Dictionary:
	var best = null
	var best_d := RING_SNAP
	var best_at := at
	for id in world.order:
		var p = world.pieces[id]
		if p.gone or p.body != null or not p.kind in ["keel", "beam", "rail"]:
			continue
		var bb := Geom.bbox(p.poly)
		if not bb.grow(best_d).has_point(at):
			continue
		var q := at
		var d := 0.0
		if not world.piece_contains(p, at):
			d = INF
			var poly: PackedVector2Array = p.poly
			for i in poly.size():
				var e := Geometry2D.get_closest_point_to_segment(at, poly[i], poly[(i + 1) % poly.size()])
				if at.distance_to(e) < d:
					d = at.distance_to(e)
					q = e
			# a little way into the member, not on its edge
			var mid := Vector2(q.x, bb.get_center().y) if bb.size.x >= bb.size.y else Vector2(bb.get_center().x, q.y)
			q += (mid - q).limit_length(4.0)
		if d < best_d and not world.hidden(q):
			best = p
			best_d = d
			best_at = q
	if best == null:
		return {"ok": false, "why": "ring_no_target"}
	var bb := Geom.bbox(best.poly)
	var pl: PackedVector2Array
	if bb.size.x >= bb.size.y:
		pl = PackedVector2Array([Vector2(best_at.x, bb.position.y - 6.0), Vector2(best_at.x, bb.end.y + 6.0)])
	else:
		pl = PackedVector2Array([Vector2(bb.position.x - 6.0, best_at.y), Vector2(bb.end.x + 6.0, best_at.y)])
	var near: bool = drone.alive and drone.global_position.distance_to(best_at) <= RING_REACH
	return {"piece": best, "at": best_at, "line": pl, "ok": near, "why": "" if near else "ring_far"}


# clamped on a thick member at (or next to) the cursor, it cuts clean through in one flash
func breaching_ring() -> bool:
	if state != "play" or not drone.alive:
		return false
	var tg := ring_target(aim)
	if not tg.ok:
		say(tg.why, aim)
		sfx.play("deny")
		return false
	if not use_item("ring"):
		say("item_none", aim, txt("it_ring"))
		sfx.play("deny")
		return false
	var at: Vector2 = tg.at
	cut_kerf(tg.piece, tg.line)
	log_op("ring")
	fx.flash(at, 260.0, 0.5, Pal.heat(1.0, 3.0))
	fx.ring(at, 10.0, 160.0, 0.45, Pal.heat(0.9, 2.2), 3.0)
	fx.sparks(at, Vector2.UP, 40, Pal.heat(1.0, 2.6), 480.0, 0.5, PI)
	hud.white_flash(0.2)
	shake(0.4)
	sfx.play("boom")
	say("ring_fired", at)
	return true


# what the grapple can haul (the 5 t tractor grapple lifts the limit)
func grab_max() -> float:
	return skill_value("grapple_mass")


# the berth's upgrades this contract was taken with
# what goes straight to the debris net (t): 0.1, or 0.5 with the net upgrade
func debris_max() -> float:
	return 0.5 if has_upgrade("net05") else 0.1


func skill_value(id: String) -> float:
	var kit: Dictionary = job.get("kit", {})
	if bot != null and not bot.get("kit", {}).is_empty():
		kit = kit.duplicate()
		kit.merge(bot.get("kit", {}), true)
	return Growth.value(kit, id)


func fit_skills() -> void:
	if career() and Career.usable() and Career.active().get("id", "") == job.get("id", ""):
		Growth.sync_kit(job)
		if drone != null:
			drone.queue_redraw()


func has_upgrade(id: String) -> bool:
	# between contracts there's no contract's kit: the berth has what the career bought
	if ship.get("berth", false) and Career.data.get("upgrades", {}).has(id):
		return true
	return job.get("kit", {}).has(id) or (bot != null and bot.get("kit", {}).has(id))


func do_wrench(tg: Dictionary) -> void:
	if tg.get("kind", "") == "ctrl" and tg.has("ctrl"):
		changed["c:" + tg.ctrl.id] = true
	# the training interlock looks at what the wrench is about to undo
	if tutorial != null:
		var on_piece = null
		match tg.kind:
			"joint":
				on_piece = world.pieces.get(tg.joint.a)
			"connector":
				on_piece = world.pieces.get(tg.line.a if tg.end == 0 else tg.line.b)
		if on_piece != null and tutorial.interlock(on_piece):
			return
		tutorial.progress()
	match tg.kind:
		"joint":
			var j = tg.joint
			# a box on a locked rail: the rail's lock holds it, not a bolt
			if rails != null and rails.holds(j):
				say(rails.locked_msg(j), world.joint_world(j))
				sfx.play("deny")
				return
			log_op("unfix")
			verify("pieces", tag_of(j.a), {"held": j.type})
			var p: Vector2 = world.joint_world(j)
			world.kill_joint(j)
			fx.shard(p, Vector2(-3, 0), Vector2(3, 0), Vector2.from_angle(randf() * TAU) * 120.0, randf_range(-12, 12), 0.7, Pal.ink(0.9), 2.0)
			fx.ring(p, 3.0, 18.0, 0.3, Pal.ink(0.7, 1.2))
			sfx.play("unbolt" if j.type != "clamp" else "clamp_off")
			if j.type == "clamp":
				shake(0.2)
				say("clamp_off", p, j.get_meta("tag", ""))
		"connector":
			var l = tg.line
			log_op("unplug")
			verify("lines", l.id, [tag_of(l.a), tag_of(l.b)])
			if l.kind == "pipe":
				var amt: float = sys.line_fluid(l)
				if amt > 0.02:
					say("pipe_full", tg.pos)
					sfx.play("deny")
					hint("pipe_full")
					return
				if sys.line_temp(l) > 60.0:
					say("pipe_hot", tg.pos, str(int(sys.line_temp(l))))
					sfx.play("deny")
					hint("pipe_hot")
					return
			else:
				var volts := _cut_cable_volts(l)
				if volts > 30.0:
					fx.arc(tg.pos, tg.pos + Vector2.from_angle(randf() * TAU) * 30.0, 0.25, 0.6)
					fx.flash(tg.pos, 80.0, 0.25, Pal.tint(Pal.VOLT, 1.0, 2.0))
					hurt_drone(15.0, tg.pos, "live_unplug", "unplug", 0.5)
			world.kill_line(l, tg.pos)
			sfx.play("unplug")
			fx.sparks(tg.pos, Vector2.UP, 4, Pal.ink(0.8, 1.2), 90.0, 0.2, PI)
		"ctrl":
			verify("ctrls", tg.ctrl.id, tg.ctrl.kind)
			log_op("door" if tg.ctrl.kind in ["door", "hatch", "jam"] else "isolate")
			if plan != null:
				plan.on_player("w", tg.ctrl)
			_operate(tg.ctrl, tg.pos)


func _operate(c, at: Vector2) -> void:
	match c.kind:
		"valve":
			c.state = not c.state
			sys.set_switch(c.id, c.state)
			say("valve_open" if c.state else "valve_closed", at, c.id)
			sfx.play("valve")
			# a magazine's flood valve: every round in it wet, safe and worthless
			if c.state and munitions != null and munitions.flood(c.id):
				say("mag_flooded", at, c.id)
				log_op("flood")
		"switch":
			if vault != null and vault.blocks_switch(c, at):
				return
			c.state = not c.state
			sys.set_switch(c.id, c.state)
			say("sw_on" if c.state else "sw_off", at, c.id)
			sfx.play("switch")
			if rails != null:
				rails.on_switch(c)
		"remote":
			# a remote stop may or may not reach the machine: the ship file says
			sys.remote_sent = true
			c.state = true
			var rt: String = Ship.ctrl_cfg(ship, c.id).get("target", "")
			if sys.src.has(rt) and sys.src[rt].get("remote_works", true):
				sys.stop_source(rt)
			say("remote_sent", at)
			sfx.play("switch")
			hint("remote")
		"stop":
			var st: String = Ship.ctrl_cfg(ship, c.id).get("target", "")
			if sys.running(st):
				sys.stop_source(st)
				say("gen_stopped", at)
				sfx.play("gen_down")
				shake(0.15)
		"socket":
			# the berth's temporary cooling (CL-104's cold holds), not its power
			if c.target == "cold":
				c.state = not c.state
				sys.set_switch(c.id, c.state)
				say("cold_on" if c.state else "cold_off", at)
				sfx.play("plug")
				return
			sys.aux = not sys.aux
			c.state = sys.aux
			sys.set_switch(c.id, sys.aux)
			say("aux_on" if sys.aux else "aux_off", at)
			sfx.play("plug")
		"discharge":
			c.state = not c.state
			sys.set_switch(c.id, c.state)
			say("discharge_on" if c.state else "discharge_off", at)
			sfx.play("plug")
		"door":
			if vault != null and vault.operate(c, at):
				return
			if Ship.ctrl_cfg(ship, c.id).get("stuck", false):
				say("door_stuck", at, c.id)
				sfx.play("deny")
				return
			if not (sys.bus_live or sys.aux):
				say("no_power", at)
				sfx.play("deny")
				hint("no_power")
				return
			var dp = world.tag(c.target)
			if dp == null:
				return
			dp.door_open = not dp.door_open
			c.state = dp.door_open
			sfx.play("door")
		"degauss":
			var dc := Ship.ctrl_cfg(ship, c.id)
			if not mech.degauss(dc.get("magnets", []), dc.get("supply", "")):
				say("degauss_live", at)
				sfx.play("deny")
				hint("degauss_live")
				return
			c.state = true
			say("degaussed", at)
			sfx.play("discharge")
			fx.ring(at, 6.0, 90.0, 0.6, Pal.tint(Pal.AIR, 0.8, 1.4), 2.0)
		"seal":
			if c.state:
				say("bio_sealed_already", at)
				return
			if not bio.seal(c.target):
				say("bio_seal_fail", at)
				sfx.play("deny")
				return
			c.state = true
			say("bio_sealed", at, c.target)
			sfx.play("clamp_off")
			fx.ring(at, 4.0, 40.0, 0.4, Pal.tint(Pal.FLUID, 0.8, 1.3), 1.5)
		"jam":
			if c.state:
				return
			c.state = true
			say("jam_cleared", at)
			sfx.play("unjam")
			fx.sparks(at, Vector2.UP, 12, Pal.ink(0.9, 1.4), 200.0, 0.3, 1.2)
		"hatch":
			var hc := Ship.ctrl_cfg(ship, c.id)
			var jam = world.ctrls.get(hc.get("jam", ""))
			if jam != null and not jam.state:
				say("hatch_jammed", at)
				sfx.play("deny")
				hint("hatch_jam")
				return
			var feed = world.lines.get(hc.get("cable", ""))
			var powered: bool = (sys.bus_live and (feed == null or feed.alive)) or sys.aux
			if not powered:
				say("no_power", at)
				sfx.play("deny")
				hint("no_power")
				return
			# a seam welded shut: the drive strains against it and burns out
			var sealed := false
			for t in hc.get("doors", []):
				var hp = world.tag(t)
				if hp != null and world.joints_of(hp).any(func(j): return j.type == "seam"):
					sealed = true
			if sealed:
				say("hatch_welded", at)
				sfx.play("deny")
				if not c.get_meta("burnt", false):
					c.set_meta("burnt", true)
					incident("motor", c.id)
					fx.sparks(at, Vector2.UP, 20, Pal.heat(1.0, 2.0), 260.0, 0.4, PI)
					lose("loss_motor", 2500.0, at + Vector2(0, -40))
				return
			for t in hc.get("doors", []):
				var hp = world.tag(t)
				if hp != null and hp.body == null:
					hp.door_open = not hp.door_open
			sfx.play("hatch")
			shake(0.2)


func do_hose(tg: Dictionary, by_plan := false) -> void:
	var c = tg.ctrl
	log_op("plan" if by_plan else "hose")
	if plan != null and not by_plan:
		plan.on_player("h", c)
	if sys.hoses.has(c.id):
		sys.hoses.erase(c.id)
		dock.hose_detach(c.id)
		say("hose_off", tg.pos, c.id)
		sfx.play("unplug")
		return
	var mode := tools.hose_mode if c.medium == "gas" else "recover"
	if sys.dead_leg_closed(c):
		hint("dead_leg_hose")
	sys.hoses[c.id] = {"mode": mode, "t": 0.0}
	dock.hose_attach(c.id, tg.pos)
	say("hose_on_" + mode, tg.pos, c.id)
	sfx.play("hose_on")
	hint("hose")


# a step of the work plan, done by the berth: the same control, worked as the operator did it
func plan_do(kind: String, c) -> void:
	var at: Vector2 = world.ctrl_world(c)
	fx.ring(at, 4.0, 26.0, 0.35, Pal.ink(0.8, 1.3))
	if kind == "h":
		do_hose({"ctrl": c, "pos": at}, true)
		return
	changed["c:" + c.id] = true
	log_op("plan")
	_operate(c, at)


# one machine at a time over a mouth: the arm and the hauler queue for it
func mouth_take(zone: String, who: String) -> bool:
	var h: String = mouths.get(zone, "")
	if h == "" or h == who:
		mouths[zone] = who
		return true
	return false


func mouth_release(zone: String, who: String) -> void:
	if mouths.get(zone, "") == who:
		mouths.erase(zone)


# where the berth's machines can fly round the ship (scripts/nav.gd), made when first wanted
var _nav = null


func nav_grid():
	if _nav == null:
		_nav = preload("res://scripts/nav.gd").new(self)
	return _nav


# the hauling drones aboard (one or two)
func haulers() -> Array:
	var out: Array = []
	for h in [hauler, hauler2]:
		if h != null:
			out.append(h)
	return out


# the keep-out key: a zone round the pointer, or off again if the pointer is in one
func toggle_keepout(at: Vector2) -> String:
	for r in keepout:
		if r.has_point(at):
			keepout.erase(r)
			dock.queue_redraw()
			return "keepout_off"
	var sz := KEEPOUT_SIZE * Geom.M
	keepout.append(Rect2(at - sz * 0.5, sz))
	if keepout.size() > KEEPOUT_MAX:
		keepout.pop_front()
	dock.queue_redraw()
	return "keepout_on"


# would a machine at `from` making for `to` cross into a keep-out zone? (one already
# inside is let out)
func keepout_blocks(from: Vector2, to: Vector2) -> bool:
	for r in keepout:
		if r.has_point(from):
			continue
		if r.has_point(to) or _seg_rect(from, to, r):
			return true
	return false


func _seg_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
	var c := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, c[i], c[(i + 1) % 4]) != null:
			return true
	return false


# a machine keeps clear of the operator's drone: is the drone close and on the way it is going?
func drone_near(at: Vector2, r: float, going: Vector2 = Vector2.ZERO) -> bool:
	if drone == null or not drone.alive:
		return false
	var d: Vector2 = drone.global_position - at
	if d.length() >= r:
		return false
	return going == Vector2.ZERO or d.dot(going - at) > 0.0


# the automation key: every machine of the berth stops where it is, or goes on
func toggle_auto() -> void:
	auto_paused = not auto_paused
	if auto_paused:
		if plan != null:
			plan.cancel()
		if arm != null and arm.has_method("halt"):
			arm.halt()
		for h in haulers():
			h.halt()
		if crane != null:
			crane.halt()
	say("auto_off" if auto_paused else "auto_on", drone.global_position + Vector2(0, -44))
	sfx.play("switch")


# ---------------------------------------------------------------- gas & room events

func on_reveal(room: String, from: Vector2) -> void:
	reveal_count += 1
	if assist != null:
		assist.on_reveal(room)
	if state == "play":
		sfx.play("reveal", from)
		say("room_open", from, room_name(room))


func on_blowout(room: String, pos: Vector2, dir: Vector2, p0: float) -> void:
	incident("blowout", room)
	shake(0.55, dir)
	hitstop(0.06)
	fx.flash(pos, 260.0, 0.6, Pal.tint(Pal.AIR, 0.6, 1.8))
	fx.ring(pos, 10.0, 260.0, 0.6, Pal.tint(Pal.AIR, 0.7, 1.5), 3.0)
	for i in 40:
		var d := dir.rotated(randf_range(-0.5, 0.5))
		fx.spark(pos, d * randf_range(500, 1100), randf_range(0.3, 0.7), Pal.tint(Pal.AIR, 0.8, 1.6), 1.4, 16.0, 1.2)
	fx.burst_shards(pos, 12, 500.0, Pal.ink(0.8), 7.0)
	hud.white_flash(0.12)
	sfx.play("blowout", pos)
	say("blowout", pos, room_name(room))
	var k := clampf(p0 / 108.0, 0.2, 1.2)
	var lost := 0.0
	for id in world.order:
		var q = world.pieces[id]
		if q.gone or q.room != room or q.cls != "equip" or not q.intact:
			continue
		var before: float = q.cond
		_dent(q, maxf(0.0, q.cond - q.fragile * 0.45 * k), "dv_blowout")
		lost += (before - q.cond) * q.value
	if lost > 100.0:
		fx.number(pos + Vector2(0, -40), "−" + Pal.money(lost).trim_prefix("$"), Pal.heat(0.9, 1.3), 20)
	for b in world.bodies:
		var d: Vector2 = pos - b.global_position
		if world.room_at(b.global_position) == room or d.length() < 4.0 * 48.0:
			b.apply_central_impulse((d.normalized() + dir) * b.mass * 180.0 * k)
	hint("blowout")


func on_jet(room: String, pos: Vector2, dir: Vector2, p: float, g: float) -> void:
	var strength := clampf(p / 100.0, 0.0, 1.2) * clampf(g / 8.0, 0.1, 1.5)
	if strength < 0.01:
		return
	var n := int(strength * 6.0) + (1 if randf() < strength * 6.0 - int(strength * 6.0) else 0)
	for i in n:
		var d := dir.rotated(randf_range(-0.35, 0.35))
		fx.puff(pos + Vector2(randf_range(-6, 6), randf_range(-6, 6)), d * randf_range(260, 620) * (0.5 + strength), randf_range(0.35, 0.8), 3.0, 18.0 + 30.0 * strength, Pal.tint(Pal.AIR, 0.09 + 0.06 * strength))
	if randf() < strength:
		fx.spark(pos, dir.rotated(randf_range(-0.3, 0.3)) * 500.0, 0.25, Pal.tint(Pal.AIR, 0.6, 1.2), 1.0, 8.0, 2.0)
	sfx.jet(strength)
	# the stream shoves what is in it
	for b in world.bodies:
		var rel: Vector2 = b.global_position - pos
		if rel.length() < 3.5 * 48.0 and rel.dot(dir) > -20.0:
			b.apply_central_force(dir * b.mass * 600.0 * strength)
		elif world.room_at(b.global_position) == room and rel.length() < 6.0 * 48.0:
			b.apply_central_force(-rel.normalized() * b.mass * 300.0 * strength)
	if drone.alive:
		var rd := drone.global_position - pos
		if rd.length() < 3.0 * 48.0 and rd.normalized().dot(dir) > 0.4:
			drone.external += dir * drone.mass * 900.0 * strength
			if strength > 0.5 and rd.length() < 1.6 * 48.0:
				hurt_drone(25.0, pos, "jet_hit", "jet", 1.5)


func on_discharge_refused(ctrl_id: String) -> void:
	var c = world.ctrls.get(ctrl_id)
	if c != null:
		c.state = false
		say("discharge_refused", world.ctrl_world(c))
	sfx.play("deny")
	hint("discharge_refused")


# ---------------------------------------------------------------- messages & hints

func say(key: String, at: Vector2, arg: String = "") -> void:
	var text := txt(key)
	if text.find("%s") >= 0:
		text = text % arg
	for m in messages:
		if m[3] == text and m[2] < 1.2:
			m[2] = 0.0
			m[1] = at
			return
	messages.append([key, at, 0.0, text])
	while messages.size() > 6:
		messages.remove_at(0)


func _age_messages(dt: float) -> void:
	for m in messages:
		m[2] += dt
	messages = messages.filter(func(m): return m[2] < 2.6)
	for f in feed:
		f[2] += dt
	feed = feed.filter(func(f): return f[2] < 5.0)
	while feed.size() > 5:
		feed.pop_back()


# how the controls work: these stay on in the standard tier
const RATE_BONUS := [[0.92, 0.04], [0.80, 0.02], [0.70, 0.01]]   # recovery rate -> share of what was earned
const MUST_SHARE := 0.10        # a named piece delivered whole: this share of its value...
const MUST_VALUABLE := 0.25     # ...or this, on a valuable-equipment job
const MUST_MIN := 500.0
const SAFE_SHARE := 0.05        # a safe-recovery job with no incident: this share of what was earned
const UI_HINTS := ["field", "hose", "measured", "drone_lost", "free_body", "equip_cut", "equip_rail"]
var hint_log: Array = []


# One-off explanations. Guided: all of them. Standard: only how the controls
# work (never how to solve the ship). Hardcore: none. The training course has
# Liang instead.
func hint(key: String) -> void:
	if training or exam != null or hints_seen.has(key):
		return
	var tr := Txt.hint_tier
	if tr == "hardcore" or (tr == "standard" and not key in UI_HINTS):
		return
	var own: Array = ship.get("hints", {}).get(key, [])
	var text: String = (own[0] if Txt.zh else own[1]) if own.size() == 2 else (txt("hint_" + key) if Txt.has("hint_" + key) else "")
	if text == "":
		return
	hints_seen[key] = true
	hint_log.append([key, tr])
	hud.show_hint(text)
