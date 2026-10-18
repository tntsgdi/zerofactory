class_name Keys
# Rebindable keys (design/体验打磨定案.md §5): every action the player presses
# on site, by name, with its physical keys. The settings file keeps what the
# player changed ("keys" section); the first key of an action is the one the
# HUD shows. A gamepad comes later.

const RIGHT_MOUSE := -2

const ORDER := ["up", "down", "left", "right", "dash", "brake", "hold", "overview",
	"tool1", "tool2", "tool3", "tool4", "tool5", "blueprint", "contract", "repair", "ring", "assist", "hints", "warp", "mouth", "mark", "log", "auto", "plan", "zone", "use", "terminal"]
const DEFAULTS := {
	"up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT],
	"dash": [KEY_SHIFT], "brake": [KEY_SPACE], "hold": [KEY_V], "overview": [KEY_Z],
	"tool1": [KEY_1], "tool2": [KEY_2], "tool3": [KEY_3], "tool4": [KEY_4], "tool5": [KEY_5],
	"blueprint": [KEY_TAB], "contract": [KEY_C], "repair": [KEY_6], "ring": [KEY_7],
	"assist": [KEY_F], "hints": [KEY_H], "warp": [KEY_EQUAL], "mouth": [KEY_M], "mark": [RIGHT_MOUSE], "log": [KEY_L], "auto": [KEY_J], "plan": [KEY_P], "zone": [KEY_K], "use": [KEY_E], "terminal": [KEY_B],
}

static var map := {}


static func codes(action: String) -> Array:
	return map.get(action, DEFAULTS.get(action, []))


static func down(action: String) -> bool:
	for k in codes(action):
		if (k == RIGHT_MOUSE and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)) or (k >= 0 and Input.is_physical_key_pressed(k)):
			return true
	return false


static func pressed(ev: InputEvent, action: String) -> bool:
	return ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode in codes(action)


# the action a key press stands for ("" if none)
static func action_of(ev: InputEvent) -> String:
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return ""
	for a in ORDER:
		if ev.physical_keycode in codes(a):
			return a
	return ""


# the key replaces the action's first key; taken from any other action that had it
static func bind(action: String, key: int) -> void:
	for a in ORDER:
		if a != action and key in codes(a):
			var rest: Array = codes(a).duplicate()
			rest.erase(key)
			map[a] = rest
	var mine: Array = codes(action).duplicate()
	mine.erase(key)
	mine.push_front(key)
	map[action] = mine.slice(0, 2)


static func reset() -> void:
	map = {}


static func label(action: String) -> String:
	var c := codes(action)
	if c.is_empty():
		return "—"
	if c[0] == RIGHT_MOUSE:
		return "鼠标右键" if Txt.zh else "RMB"
	return OS.get_keycode_string(c[0])


static func load_from(cf: ConfigFile) -> void:
	map = {}
	for a in ORDER:
		if not cf.has_section_key("keys", a):
			continue
		var v = cf.get_value("keys", a)
		if v is Array and not v.is_empty():
			var arr: Array = []
			for k in v:
				arr.append(int(k))
			# Migrate the old default, keeping deliberately customized shortcuts.
			if a == "mark" and arr == [KEY_G]:
				continue
			map[a] = arr


static func store(cf: ConfigFile) -> void:
	for a in ORDER:
		if map.has(a):
			cf.set_value("keys", a, map[a])
		elif cf.has_section_key("keys", a):
			cf.erase_section_key("keys", a)
