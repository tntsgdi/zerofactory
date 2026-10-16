class_name Radio
extends RefCounted
# Liang's radio and the berth terminal: one line at a time, about 0.075 s a
# character (2.5–12 s), queued while the player's hands are busy (cutting,
# hauling), never the same line twice in a row, dropped after waiting 20 s.
# Lines come either by id from a table (the training course) or as ready
# text (the contract assistant).

const MAX_WAIT := 60.0
const BUSY_HOLD := 2.5        # a line waits this long at most for the hands to be free
var history: Array = []       # what was said: [text, who], newest last

var lines: Dictionary = {}     # id -> {who, zh, en}
var queue: Array = []          # [line dict, queued at]
var now := {}                  # {line, t, dur}
var said := {}
var last := ""
var t := 0.0
var sfx: Sfx


func say(id: String, once: bool = true) -> void:
	if not lines.has(id):
		return
	_push(id, lines[id], once)


# a line that is not in the table: who is "liang" or "term"
func say_text(key: String, who: String, zh: String, en: String, once: bool = true) -> void:
	_push(key, {"who": who, "zh": zh, "en": en}, once)


func _push(key: String, line: Dictionary, once: bool) -> void:
	if once and said.has(key):
		return
	if key == last and not now.is_empty():
		return
	for q in queue:
		if q[0].key == key:
			return
	said[key] = true
	var l := line.duplicate()
	l.key = key
	queue.append([l, t])


func forget(key: String) -> void:
	said.erase(key)
	if last == key:
		last = ""


func text(l: Dictionary) -> String:
	return l.get("zh", "") if Txt.zh else l.get("en", "")


func step(dt: float, busy: bool) -> void:
	t += dt
	if not now.is_empty():
		now.t += dt
		if now.t >= now.dur:
			now = {}
		return
	queue = queue.filter(func(q): return t - q[1] < MAX_WAIT)
	if queue.is_empty():
		return
	if busy and queue[0][0].get("who", "liang") == "liang" and t - queue[0][1] < BUSY_HOLD:
		return
	var q = queue.pop_front()
	var n := text(q[0]).length()
	now = {"line": q[0], "t": 0.0, "dur": clampf(1.6 + n * 0.075, 2.5, 12.0)}
	last = q[0].key
	history.append([text(q[0]), q[0].get("who", "liang")])
	if history.size() > 30:
		history.pop_front()
	if sfx != null:
		sfx.play("radio_on" if q[0].get("who", "liang") == "liang" else "term")


func idle() -> bool:
	return now.is_empty() and queue.is_empty()
