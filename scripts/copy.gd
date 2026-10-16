class_name Copy
# The author's phase-two copy (data/copy.json, ids as in
# design/阶段二文案_提示词.md): Liang's lines, terminal lines, offer card
# reasons and onboard logs, trap names and review notes. A line not written
# yet is not spoken; a card slot not written yet shows 【待写】.

const FILE := "res://data/copy.json"
const TODO := ["【待写】", "[TO BE WRITTEN]"]

static var _t: Dictionary = {}
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(FILE):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	if typeof(d) == TYPE_DICTIONARY:
		_t = d


static func has(id: String) -> bool:
	_load()
	var v = _t.get(id)
	return v is Array and v.size() >= 1 and str(v[0]) != ""


# [zh, en]; English falls back to the Chinese until it is translated
static func pair(id: String) -> Array:
	_load()
	if not has(id):
		return []
	var v: Array = _t[id]
	return [str(v[0]), str(v[1]) if v.size() > 1 and str(v[1]) != "" else str(v[0])]


# for a card or a panel: the text, or the placeholder
static func slot(id: String) -> String:
	var p := pair(id)
	if p.is_empty():
		return TODO[0] if Txt.zh else TODO[1]
	return p[0] if Txt.zh else p[1]


# Liang (or the terminal) says it, if it has been written; a {name} in the
# line is filled by the game (the new reputation level, say): [zh, en]
static func say(radio: Radio, id: String, who: String = "liang", fill: Array = []) -> bool:
	var p := pair(id)
	if p.is_empty():
		return false
	var zh: String = p[0]
	var en: String = p[1]
	if fill.size() == 2:
		zh = zh.replace("{name}", fill[0])
		en = en.replace("{name}", fill[1])
	radio.say_text("cp:" + id, who, zh, en)
	return true
