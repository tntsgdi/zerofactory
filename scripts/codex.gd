class_name Codex
extends Node
# What the player has not met before, explained the first time it is met
# (design/新手教程与图鉴定案.md, player 2026-10-20: "the structures and details
# a player doesn't understand — teach them"). Four kinds of entry:
#   struct  how a ship is held together (bolts, locks, cut lines, doors...)
#   device  a machine, by the drawing it is drawn with (art id), ~150 of them
#   mech    a ship's own mechanism (a quench, a drill string's trapped torque...)
#   sys     the berth's own systems (pressure, liquids, the furnace, the extension)
# A card slides in under the contract the first time one is met (hovered for
# 0.4 s, its incident happens, or the berth shows it); one at a time, 6 s apart,
# three waiting at most (the rest go straight into the book, marked new). All
# three hint tiers see the same cards; a setting turns them off. The book (I,
# the pause menu, the terminal) keeps every entry met, per save.
# Nothing here changes the ship, the money or the simulation.
# Texts: scripts/codex_txt.gd (cx_<id> title; _a what it is; _b why it is
# dangerous; _c what to do; _x the working, with real numbers).

const CATS := ["struct", "device", "mech", "sys"]
const HOVER_T := 0.4          # s a thing is pointed at before it counts as met
const GAP := 6.0              # s between two cards
const SHOW_T := 12.0          # s a card stays (not while the mouse is on it)
const QUEUE := 3

# the seven special courses (one per family of mechanism) and the ships that need them
const CLASSES := ["energy", "cryo", "fluid", "atmos", "load", "precise", "isolate"]
const CLASS_SHIPS := {
	"energy": ["fx70", "md160", "pt34", "ps12", "h22", "cv138"],
	"cryo": ["qc30", "hg170", "fr26", "cl104", "ic120"],
	"fluid": ["dr150", "vt80", "dc84", "bl88", "fl116"],
	"atmos": ["hb86", "my48", "st40", "nr95", "ev55", "mf126", "med47"],
	"load": ["tw64", "ch110", "cf90", "sa200", "ih55", "tb180", "mt140", "m14", "jd38", "ro128", "sv122", "ark01"],
	"precise": ["ob90", "hb86", "ps12", "bl88"],
	"isolate": ["es112", "lc140"],
}
const BONUS := 3000.0         # first time a course is passed
# what each course's practice rig really carries (ships/sp_<family>.json)
const RIG_MECHS := {
	"energy": ["m_quench", "m_flywheel"],
	"cryo": ["m_boiloff", "m_frozen_valve", "m_dilution"],
	"fluid": ["m_drill_torque", "m_drill_slips", "m_tanknet"],
	"atmos": ["m_o2_flash", "m_composite", "m_decay_heat"],
	"load": ["m_preload", "m_rails"],
	"precise": ["m_mirror_dust", "m_mirror_lock", "m_glass"],
	"isolate": ["m_nested", "m_vault"],
}

static var mem := {"seen": {}, "new": {}, "certs": {}}   # when there is no career to keep it in
static var _by_art := {}
static var _by_joint := {}
static var _by_line := {}
static var _by_kind := {}
static var _by_ctrl := {}
static var _by_inc := {}
static var _by_name := {}     # name_key -> mech entries
static var _built := false


# ---------------------------------------------------------------- the book (per save)

static func _book() -> Dictionary:
	if not Career.data.is_empty() and Career.usable():
		var d: Dictionary = Career.data
		if not d.has("codex"):
			d["codex"] = {"seen": {}, "new": {}}
		return d.codex
	return mem


static func seen(id: String) -> bool:
	return _book().get("seen", {}).has(id)


static func is_new(id: String) -> bool:
	return _book().get("new", {}).has(id)


# met: into the book (true the first time)
static func mark(id: String, keep_new: bool = true) -> bool:
	if not CodexData.E.has(id):
		return false
	var b := _book()
	if not b.has("seen"):
		b["seen"] = {}
	if not b.has("new"):
		b["new"] = {}
	if b.seen.has(id):
		return false
	b.seen[id] = true
	if keep_new:
		b.new[id] = true
	if b != mem:
		Career.save()
	return true


static func read(id: String) -> void:
	var b := _book()
	if b.get("new", {}).has(id):
		b.new.erase(id)


static func count(cat: String) -> Vector2i:
	var n := 0
	var have := 0
	for id in CodexData.E:
		if CodexData.E[id].cat == cat:
			n += 1
			if seen(id):
				have += 1
	return Vector2i(have, n)


static func ids(cat: String) -> Array:
	var out: Array = []
	for id in CodexData.E:
		if CodexData.E[id].cat == cat:
			out.append(id)
	return out


# ---------------------------------------------------------------- certificates (special courses)

static func _certs() -> Dictionary:
	if not Career.data.is_empty() and Career.usable():
		if not Career.data.has("certs"):
			Career.data["certs"] = {}
		return Career.data.certs
	return mem.certs


static func certified(cls: String) -> bool:
	return _certs().has(cls)


# passed (kind "full") or granted to an old save that had done such a ship ("auto");
# returns the bonus owed (only the first time it is earned by passing)
static func certify(cls: String, kind: String = "full") -> float:
	var c := _certs()
	if c.has(cls):
		return 0.0
	c[cls] = kind
	if c != mem.certs:
		Career.save()
	return BONUS if kind == "full" else 0.0


static func classes_of(ship: String) -> Array:
	var out: Array = []
	for cls in CLASSES:
		if ship in CLASS_SHIPS[cls]:
			out.append(cls)
	return out


static func missing(ship: String) -> Array:
	var out: Array = []
	for cls in classes_of(ship):
		if not certified(cls):
			out.append(cls)
	return out


# a ship's type code as the player reads it: fx70 -> FX-70
static func code(ship: String) -> String:
	for i in ship.length():
		if ship[i].is_valid_int():
			return ship.substr(0, i).to_upper() + "-" + ship.substr(i)
	return ship.to_upper()


static func course_ship(cls: String) -> String:
	return "sp_" + cls


static func class_of_course(ship: String) -> String:
	return ship.substr(3) if ship.begins_with("sp_") and ship.substr(3) in CLASSES else ""


# an old save: every family of ship already worked through comes certified (no bonus)
static func grant_veteran() -> Array:
	var got: Array = []
	if Career.data.is_empty():
		return got
	for h in Career.data.get("history", []):
		if str(h.get("scope", "full")) != "full" or int(h.get("grade", 0)) < 1:
			continue
		for cls in classes_of(str(h.get("ship", ""))):
			if not certified(cls):
				certify(cls, "auto")
				got.append(cls)
	return got


# ---------------------------------------------------------------- what an entry is about

static func _build() -> void:
	if _built:
		return
	_built = true
	for id in CodexData.E:
		var e: Dictionary = CodexData.E[id]
		var into := func(table: Dictionary, k):
			if not table.has(k):
				table[k] = []
			table[k].append(id)
		for a in e.get("arts", []):
			if e.cat == "mech":
				continue
			into.call(_by_art, a)
		for j in e.get("joints", []):
			into.call(_by_joint, j)
		for l in e.get("lines", []):
			into.call(_by_line, l)
		for k in e.get("kinds", []):
			into.call(_by_kind, k)
		for c in e.get("ctrls", []):
			into.call(_by_ctrl, c)
		for i in e.get("inc", []):
			into.call(_by_inc, i)
		for n in e.get("names", []):
			into.call(_by_name, n)


# the drawing a piece is drawn with (the same choice art_equip.gd makes)
static func art_of(p) -> String:
	if p == null:
		return ""
	var nk: String = p.name_key
	if Art.SH.BY_NAME.has(nk):
		return Art.SH.BY_NAME[nk]
	if Art.EQ.BY_NAME.has(nk):
		return Art.EQ.BY_NAME[nk]
	return str(p.art)


static func device_entry(art: String) -> String:
	_build()
	var l: Array = _by_art.get(art, [])
	return l[0] if not l.is_empty() else ""


# every entry a piece stands for: its ship mechanism first, then its machine, then its kind
static func entries_for_piece(p, ship: String) -> Array:
	_build()
	var out: Array = []
	if p == null:
		return out
	var art := art_of(p)
	for id in _by_name.get(p.name_key, []):
		if _on_ship(id, ship):
			out.append(id)
	for id in CodexData.E:
		var e: Dictionary = CodexData.E[id]
		if e.cat == "mech" and art != "" and art in e.get("arts", []) and _on_ship(id, ship) and not id in out:
			out.append(id)
	for id in _by_art.get(art, []):
		if not id in out:
			out.append(id)
	for id in _by_kind.get(str(p.kind), []):
		if not id in out:
			out.append(id)
	return out


static func _on_ship(id: String, ship: String) -> bool:
	var rig := class_of_course(ship)
	if rig != "":
		return id in RIG_MECHS.get(rig, [])
	return ship in CodexData.E[id].get("ships", [])


# the ship mechanisms a contract card lists
static func ship_entries(ship: String) -> Array:
	var out: Array = []
	for id in CodexData.E:
		var e: Dictionary = CodexData.E[id]
		if e.cat == "mech" and _on_ship(id, ship):
			out.append(id)
	return out


# the drawing on an entry's card ("" for none)
static func draw_art(id: String) -> String:
	var e: Dictionary = CodexData.E.get(id, {})
	if e.has("draw"):
		return e.draw
	var a: Array = e.get("arts", [])
	return a[0] if not a.is_empty() else ""


static func title(id: String) -> String:
	return Txt.t("cx_" + id)


static func line(id: String, part: String) -> String:
	return Txt.t("cx_%s_%s" % [id, part])


# ---------------------------------------------------------------- on site

var game: Game
var queue: Array = []         # entry ids waiting for their card
var card := ""                # the card on screen
var card_t := 0.0
var gap_t := GAP
var held := false             # the mouse is on the card
var last := ""                # the card shown last (I opens the book there)
var _hover_key := ""
var _hover_t := 0.0
var _inc_seen := 0
var _poll := 0.0
var _flags := {}
var shown_log: Array = []     # [id, how] every card that went up (tests read it)


func setup(g: Game) -> void:
	game = g
	_build()
	_inc_seen = game.incidents.size()
	# the contract card names the ship's own mechanisms: in the book from the start
	for id in ship_entries(game.ship_id):
		mark(id)


static func cards_on() -> bool:
	return Txt.codex_cards


func meet(id: String, how: String = "") -> void:
	if id == "" or not CodexData.E.has(id):
		return
	mark(id)
	if carded(id) or not cards_on() or (game.bot != null and not game.bot.get("codex", false)):
		return
	if id == card or id in queue:
		return
	_book_set("carded", id)
	# more than three waiting: it goes straight into the book, marked new
	if queue.size() >= QUEUE:
		return
	queue.append(id)
	shown_log.append([id, how])


static func carded(id: String) -> bool:
	return _book().get("carded", {}).has(id)


static func _book_set(set_name: String, id: String) -> void:
	var b := _book()
	if not b.has(set_name):
		b[set_name] = {}
	b[set_name][id] = true


func _process(dt: float) -> void:
	if game == null:
		return
	if game.state == "build":
		_flags["built"] = true
	if game.state != "play" or game.menu_open:
		return
	# the card on screen
	if card != "":
		if not held:
			card_t += dt
		if card_t >= SHOW_T:
			_close()
	else:
		gap_t += dt
		if gap_t >= GAP and not queue.is_empty():
			card = queue.pop_front()
			card_t = 0.0
			last = card
			if game.sfx != null:
				game.sfx.play("ok", Vector2.INF, 0.5)
	_hover(dt)
	_poll -= dt
	if _poll <= 0.0:
		_poll = 0.2
		_watch()


func _close() -> void:
	if card != "":
		last = card
	card = ""
	card_t = 0.0
	gap_t = 0.0
	held = false


# dismissed by the player (the card goes, it stays in the book)
func dismiss() -> void:
	_close()


func _hover(dt: float) -> void:
	var h: Dictionary = game.tools.hover if game.tools != null else {}
	var key := ""
	var ids: Array = []
	if not h.is_empty():
		match h.get("kind", ""):
			"piece", "inspect":
				key = "p%d" % h.piece.id
				ids = entries_for_piece(h.piece, game.ship_id)
			"joint":
				key = "j" + str(h.joint.type)
				ids = _by_joint.get(str(h.joint.type), [])
				var jp = game.world.pieces.get(h.joint.a)
				if jp != null:
					ids = ids + entries_for_piece(jp, game.ship_id).filter(func(x): return CodexData.E[x].cat == "mech")
			"connector", "line":
				key = "l" + str(h.line.kind)
				ids = _by_line.get(str(h.line.kind), [])
			"ctrl":
				key = "c" + str(h.ctrl.id)
				ids = _by_ctrl.get(str(h.ctrl.kind), []).duplicate()
				var cp = game.world.pieces.get(h.ctrl.piece) if h.ctrl.piece != null else null
				if cp != null:
					for id in entries_for_piece(cp, game.ship_id):
						if CodexData.E[id].cat == "mech":
							ids.append(id)
	if key != _hover_key:
		_hover_key = key
		_hover_t = 0.0
		return
	if key == "":
		return
	var was := _hover_t
	_hover_t += dt
	if was < HOVER_T and _hover_t >= HOVER_T:
		for id in ids:
			meet(id, "hover")


# incidents and what the berth is doing
func _watch() -> void:
	var inc: Array = game.incidents
	while _inc_seen < inc.size():
		var e: Array = inc[_inc_seen]
		_inc_seen += 1
		for id in _by_inc.get(str(e[1]), []):
			if CodexData.E[id].cat != "mech" or _on_ship(id, game.ship_id):
				meet(id, "incident")
	for id in CodexData.E:
		var e: Dictionary = CodexData.E[id]
		if e.cat == "sys" and e.has("ev") and not _flags.has("ev:" + id) and _event(str(e.ev)):
			_flags["ev:" + id] = true
			meet(id, "event")


func _event(ev: String) -> bool:
	var g = game
	match ev:
		"pressure":
			for k in g.sys.readings:
				if g.sys.readings[k].kind == "pressure":
					return true
		"volts":
			for k in g.sys.readings:
				if g.sys.readings[k].kind == "volts":
					return true
		"temp":
			for k in g.sys.readings:
				if g.sys.readings[k].kind == "temp":
					return true
		"stale":
			for k in g.sys.readings:
				if g.sys.stale(g.sys.readings[k]):
					return true
		"contents":
			for k in g.sys.readings:
				if str(g.sys.readings[k].get("inst", "")) == "inst_contents":
					return true
		"o2_rich":
			for r in g.sys.o2:
				if g.sys.o2_frac(str(r)) > 0.3:
					return true
		"liquid":
			return g.liquids != null and not g.liquids.blobs.is_empty()
		"cloud":
			return not g.sys.clouds.is_empty()
		"hose":
			return not g.sys.hoses.is_empty()
		"free":
			return g.world.bodies.size() > 0
		"built":
			return _flags.has("built")
		"furnace":
			return g.income_metal > 0.0
		"equip_mouth":
			return g.income_equip > 0.0
		"hazard_mouth":
			return g.income_hazard > 0.0
		"held":
			return g.tools.held_piece != null
		"overweight":
			return g.tools.overweight
		"blueprint":
			return g.blueprint.on
		"overview":
			return g.overview
		"field":
			# out past the berth's edge, where the tractor field pulls things back
			var inner := Rect2((Dock.BOUNDS.position + Vector2(0.0, 2.0)) * Geom.M, (Dock.BOUNDS.size - Vector2(2.5, 2.0)) * Geom.M)
			return g.drone.alive and not inner.has_point(g.drone.global_position)
		"scope":
			return g.scope() != "full"
		"hauler":
			return g.hauler != null
	return false


# ---------------------------------------------------------------- save

func save_state() -> Dictionary:
	return {"flags": _flags.duplicate()}


func load_state(d: Dictionary) -> void:
	_flags = d.get("flags", {})
	_inc_seen = game.incidents.size()
