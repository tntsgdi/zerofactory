extends RefCounted
# A salvage bot for any contract on a known ship type: it reads the ship's
# own systems data (gas volumes and valves, power sources and their switches,
# fluid ports, the safe-removal procedures) and makes the ship safe through
# the game's own actions, then frees every piece (as the wrench would) and
# puts each body into the mouth it belongs to. Careless: everything into the
# furnace, nothing made safe. Used by the career, contract and money tests.
# Paced: every operation and every haul takes the time it would take a
# player (tool times, travel, hauling slower the heavier the load), the
# grapple's limit holds (heavier equipment has to be cut up and scrapped),
# a crack in the structure is only seen with the precision kit, and loose
# scrap is left to the recovery arm when the berth has one — so contract
# time and income show what the berth's kit is worth.

const M := 48.0
var g                      # the Game
var careless := false
var phase := "prep"
var t := 0
var phase_t := 0
var order: Array = []
var sent := {}
var done_ops := {}         # things already done once
var notes: Array = []      # what the bot did (and anything it had to force)
var forced := 0            # steps it could only do by cheating (a validator failure)
var timeout := 30000
var finished := false
var fast := 8.0            # time warp while it waits
var paced := false
const LOOSE_MAX := 24           # paced: loose bodies before it stops freeing more
var busy := 0.0            # s of sim time the current operation still takes
var last_sim := 0.0
var work := 0.0            # s of hands-on work so far
var hauls := 0             # bodies the drone hauled itself
var scrap_hauls := 0       # of which plain scrap, to the furnace
var scrap_masses: Array = []
var scrapped := 0          # whole equipment it had to cut up (too heavy)
var snapped := 0


var rec: Array = []        # what it did to make the ship safe, in order: ["w"|"h", ctrl] / ["o", room, ctrl] / ["g", guard]
var replay = null          # a remembered order (rec of an earlier ship) done blindly, instead of reading this ship
var replay_wait := 0.0     # sim s it waits after the remembered order before it strips (as long as it took then)
var crane_hauls := 0         # loads too heavy for the grapple that the heavy crane took whole
var safe_at := 0.0         # sim s when it judged the ship safe


func _init(game, opts: Dictionary = {}) -> void:
	g = game
	careless = opts.get("careless", false)
	paced = opts.get("paced", false)
	replay = opts.get("replay", null)
	replay_wait = opts.get("replay_wait", 0.0)


func _w(id: String) -> void:
	rec.append(["w", id])
	g.do_wrench(ctrl(id))


func _h(id: String) -> void:
	rec.append(["h", id])
	g.do_hose(ctrl(id))


# the remembered order, one step every few frames: whatever is missing on this ship is skipped
func _replay() -> void:
	if phase_t % 5 != 0:
		return
	if not replay.is_empty():
		var op: Array = replay.pop_front()
		match op[0]:
			"w":
				if not ctrl(op[1]).is_empty():
					g.do_wrench(ctrl(op[1]))
			"h":
				if not ctrl(op[1]).is_empty():
					g.do_hose(ctrl(op[1]))
			"o":
				if g.world.rooms.has(op[1]):
					_open_room(op[1], op[2])
			"g":
				var gp = g.world.tag(op[1])
				if gp != null:
					for j in g.world.joints_of(gp):
						g.world.kill_joint(j)
		_note("remembered %s" % str(op))
		return
	Engine.time_scale = fast
	if g.sys.time >= replay_wait:
		Engine.time_scale = 1.0
		_note("remembered order done at t=%.1f s sim" % g.sys.time)
		_go_strip()


func _work(sec: float) -> void:
	if paced:
		busy += sec
		work += sec


func _note(s: String) -> void:
	notes.append("[%d] %s" % [t, s])


func ctrl(id: String) -> Dictionary:
	var c = g.world.ctrls.get(id)
	if c == null or not g.world.ctrl_alive(c):
		return {}
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _hidden(id: String) -> bool:
	var c = g.world.ctrls.get(id)
	return c == null or g.world.room_hidden(c.hidden_room)


func _once(key: String) -> bool:
	if done_ops.has(key):
		return false
	done_ops[key] = true
	return true


# one frame of work; true once the contract has ended (or the bot gave up)
func step() -> bool:
	if finished:
		return true
	t += 1
	phase_t += 1
	if t < 3:
		return false
	if paced:
		busy = maxf(0.0, busy - (g.sys.time - last_sim))
		last_sim = g.sys.time
		if busy > 0.0:
			Engine.time_scale = fast
			if g.state == "ending":
				Engine.time_scale = 1.0
				finished = true
			return finished
	match phase:
		"prep":
			if careless:
				_go_strip()
			elif replay != null:
				_replay()
			else:
				_prep()
		"strip":
			_strip()
	if g.state == "ending":
		Engine.time_scale = 1.0
		finished = true
	elif t > timeout:
		_note("TIMEOUT in %s" % phase)
		Engine.time_scale = 1.0
		finished = true
	return finished


# ---------------------------------------------------------------- making it safe

func _prep() -> void:
	var s = g.sys
	var w = g.world
	if phase_t % 5 != 0:
		return
	# a cold chain: the berth's temporary cooling on before anything else is touched
	if g.coldchain != null and g.coldchain.active():
		var cs: String = g.coldchain.cfg.get("supply", "")
		if cs != "" and w.ctrls.has(cs) and not w.ctrls[cs].state and not _hidden(cs) and _once("cold " + cs):
			_w(cs)
			_note("temporary cooling on %s" % cs)
			_work(2.5)
			return
	# a guard over a port comes off first (it is a fixture: its fixings undone)
	for id in g.ship.get("ctrls_cfg", {}):
		var gd: String = g.ship.ctrls_cfg[id].get("blocked_by", "")
		if gd != "" and _once("guard " + gd):
			var gp = w.tag(gd)
			if gp != null:
				for j in w.joints_of(gp):
					w.kill_joint(j)
				rec.append(["g", gd])
				_note("guard %s off" % gd)
				_work(2.5)
			return
	# dead legs: the valve between a test port and its room opens first
	for gv in s.gas_valves:
		if not s.on(gv.ctrl) and not _hidden(gv.ctrl) and _once("valve " + gv.ctrl):
			_w(gv.ctrl)
			_note("open %s" % gv.ctrl)
			_work(2.5)
			return
	# a hopper of loose cargo: both gates open (while there is power to drive them), the heap let run out
	if g.ore != null and g.ore.active() and g.ore.fines > 0.0:
		for gt in g.ore.cfg.get("gates", []):
			var gc = w.ctrls.get(gt)
			if gc != null and not gc.state and not Ship.ctrl_cfg(g.ship, gt).get("stuck", false) and _once("gate " + gt):
				_w(gt)
				_note("open gate %s" % gt)
				_work(2.5)
				return
	# a bent gate that will not open on its drive: torn out once the hopper is half empty (never before)
	if g.ore != null and g.ore.active():
		for gt in g.ore.cfg.get("gates", []):
			if Ship.ctrl_cfg(g.ship, gt).get("stuck", false) and not g.ore._gate_open(gt) and g.ore.fines < 0.4 * g.ore.fines0 and _once("force " + gt):
				var gp = w.tag(gt)
				for j in w.joints_of(gp):
					w.kill_joint(j)
				for l in w.lines_of(gp):
					w.kill_line(l)
				g.log_op("cut")
				_note("force bent gate %s" % gt)
				_work(4.0)
				return
	# anything held under load: its locking pins out first (the tension let off)
	if g.mech != null:
		for l in g.mech.loads:
			if not l.alive or l.fired:
				continue
			for pt in l.cfg.get("pins", []):
				var pj = g.mech._joint(pt)
				if pj != null and _once("pin " + pt):
					g.do_wrench({"kind": "joint", "joint": pj, "pos": w.joint_world(pj)})
					_note("slack %s" % pt)
					_work(2.5)
					return
	# biohazard sealed where it stands, before anything moves it
	for id in w.ctrls:
		var c = w.ctrls[id]
		if c.kind == "seal" and not c.state and not _hidden(id) and w.ctrl_alive(c) and _once("seal " + id):
			_w(id)
			_note("seal %s" % id)
			_work(2.5)
			return
	# look-alike media: one branch at a time, the other branches' valves shut, its port drawn dry
	if g.media != null and g.media.active():
		var br: Dictionary = g.media.branches()
		for b in br.keys():
			var e: Dictionary = br[b]
			if s.fluid(e.vol) <= 0.015:
				continue
			# the last branch's hose off before its valve closes and this one's opens
			var stale := ""
			for o in br.keys():
				if o != b and s.hoses.has(br[o].port):
					stale = br[o].port
			if stale != "":
				_h(stale)
				_note("hose %s off" % stale)
				_work(1.5)
				return
			var wrong := ""
			for o in br.keys():
				var vc: String = br[o].valve
				if w.ctrls.has(vc) and w.ctrls[vc].state != (o == b):
					wrong = vc
					break
			if wrong != "":
				if _hidden(wrong):
					break
				_w(wrong)
				_note("valve %s for branch %s" % [wrong, b])
				_work(2.5)
				return
			if not s.hoses.has(e.port) and not _hidden(e.port):
				_h(e.port)
				_note("hose %s (branch %s)" % [e.port, b])
				_work(2.5)
				return
			break
	# every gas port on something under pressure gets a hose
	for id in w.ctrls:
		var c = w.ctrls[id]
		if c.kind != "port" or s.hoses.has(id) or _hidden(id) or done_ops.has("hose " + id):
			continue
		if g.media != null and g.media.active() and g.media.branch_of_port(id) != "":
			continue
		if not w.ctrl_alive(c) or g.tools._ctrl_blocked(c) != "":
			continue
		var want := false
		if c.medium == "gas":
			want = s.P(c.target) > (1.0 if w.rooms.has(c.target) or s.vessel_cfg.get(c.target, {}).has("dead_leg") else 40.0)
		elif c.medium != "volt":
			var vk: String = s.fluid_at_port(id)
			want = vk != "" and s.fluid(vk) > 0.015
		if want:
			done_ops["hose " + id] = true
			_h(id)
			_note("hose %s" % id)
			_work(2.5)
			return
	# power: open every source switch, send remote stops, then bleed capacitors
	for tg in s.src_order:
		var src: Dictionary = s.src[tg]
		if src.has("switch") and s.on(src.switch) and not _hidden(src.switch) and _once("sw " + src.switch):
			_w(src.switch)
			_note("switch %s off" % src.switch)
			_work(2.5)
			return
		if src.has("remote") and src.running and not _hidden(src.remote) and _once("remote " + src.remote):
			_w(src.remote)
			_note("remote stop %s" % src.remote)
			_work(2.5)
			return
	for tg in s.iso:
		var sw: String = s.iso[tg].get("switch", "")
		if sw != "" and s.on(sw) and not _hidden(sw) and _once("iso " + sw):
			_w(sw)
			_note("own supply %s off" % sw)
			_work(2.5)
			return
	# a capacitor on its own network (a warship's weapons) bleeds only at its own discharge point
	for tg in s.iso:
		var ic: Dictionary = s.iso[tg]
		if ic.get("kind", "") == "cap" and ic.get("discharge", "") != "" and ic.charge > 0.02 and not s.on(ic.discharge) and not _hidden(ic.discharge) and _once("iso dis " + ic.discharge):
			_w(ic.discharge)
			_note("discharge %s" % ic.discharge)
			_work(2.5)
			return
	var fed := false
	for tg in s.src_order:
		if s.src[tg].kind != "cap" and s._feeding(s.src[tg]):
			fed = true
	for tg in s.src_order:
		var src: Dictionary = s.src[tg]
		if src.kind == "cap" and src.has("discharge") and src.charge > 0.02 and not fed and not s.on(src.discharge) and not _hidden(src.discharge):
			_w(src.discharge)
			_note("discharge %s" % src.discharge)
			_work(2.5)
			return
	# heavy parts that must come off together: the hull's support set first
	if g.mech != null and not g.mech.balance.is_empty():
		var sup: String = g.mech.balance.get("support", "")
		if sup != "" and w.ctrls.has(sup) and not s.on(sup) and not _hidden(sup) and _once("support " + sup):
			_w(sup)
			_note("hull support %s set" % sup)
			_work(2.5)
			return
	# cargo on lock rails: its doors open first, then the rail's lock off (the boxes slide out)
	if g.rails != null and g.rails.active():
		for rs in g.rails.cfg:
			var e: Dictionary = g.rails.cfg[rs]
			if g.rails.released.has(rs) or _hidden(e.lock):
				continue
			var shut := ""
			var swinging := false
			for dr in e.get("doors", []):
				if w.ctrls.has(dr) and not w.ctrls[dr].state:
					shut = dr
					break
				var dp = w.tag(dr)
				if dp != null and dp.open_t < 1.0:
					swinging = true
			# a door still swinging open would catch the box
			if shut == "" and swinging:
				continue
			if shut != "":
				if _hidden(shut):
					continue
				# the doors run on the bus: dead, the berth's supply on the outside socket runs them
				if not (s.bus_live or s.aux):
					for sid in w.ctrls:
						var sc = w.ctrls[sid]
						if sc.kind == "socket" and sc.target == "aux" and not sc.state and not _hidden(sid) and _once("aux " + sid):
							_w(sid)
							_note("berth supply on %s for the doors" % sid)
							_work(2.5)
							return
					continue
				if _once("rail door " + shut):
					_w(shut)
					_note("open %s for the rail" % shut)
					_work(2.5)
					return
				continue
			if _once("rail " + e.lock):
				_w(e.lock)
				_note("rail %s released" % rs)
				_work(2.5)
				return
	# a generator that ignored its remote stop: open its room and use the local handle
	for tg in s.src_order:
		var src: Dictionary = s.src[tg]
		if src.kind != "gen" or not src.running or not src.has("local"):
			continue
		var lc = w.ctrls.get(src.local)
		if lc == null:
			continue
		if w.room_hidden(lc.hidden_room):
			# only once the room is empty, the bus is dead (cuts cross its cables) and
			# whatever the ship's procedure waits for before its cuts has happened
			if s.P(lc.hidden_room) < 5.0 and not s.bus_live and _cuts_ready(lc.hidden_room) and _once("open " + lc.hidden_room):
				_open_room(lc.hidden_room, src.local)
			return
		if _once("local " + src.local):
			_w(src.local)
			_note("local stop %s" % src.local)
			_work(2.5)
			return
	# a room with things inside that need a hose or a switch opens once it is empty
	for id in w.ctrls:
		var c = w.ctrls[id]
		if c.kind in ["port", "switch", "seal", "discharge", "valve"] and c.hidden_room != "" and w.room_hidden(c.hidden_room) and not s.hoses.has(id):
			if s.P(c.hidden_room) < 5.0 and _once("open " + c.hidden_room):
				_open_room(c.hidden_room, "")
				return
	Engine.time_scale = fast
	if _safe() or phase_t > 60 * 60 * 6:
		if not _safe():
			_note("prep gave up: %s" % _unsafe())
			forced += 1
		Engine.time_scale = 1.0
		_note("safe at t=%.1f s sim" % s.time)
		safe_at = s.time
		_go_strip()


# every wait in the procedure that opens this room, up to its first cut, is satisfied
func _cuts_ready(room: String) -> bool:
	for k in g.ship.get("procedures", {}):
		var steps: Array = g.ship.procedures[k]
		if not steps.any(func(st): return st.do == "wait" and st.until.has("open") and st.until.open[0] == room):
			continue
		for st in steps:
			if st.do == "cut":
				break
			if st.do == "wait" and not _cond_ok(st.until):
				return false
	return true


func _cond_ok(until: Dictionary) -> bool:
	var s = g.sys
	for k in until:
		var a: Array = until[k]
		var v := 0.0
		var op: String
		var lim
		match k:
			"P":
				v = s.P(a[0])
				op = a[1]
				lim = a[2]
			"charge":
				v = s.charge(a[0])
				op = a[1]
				lim = a[2]
			"fluid":
				v = s.fluid(a[0])
				op = a[1]
				lim = a[2]
			"T":
				v = s.loop_T
				op = a[0]
				lim = a[1]
			_:
				continue
		if (op == "<" and v >= lim) or (op == ">" and v <= lim):
			return false
	return true


# opens a room the way the ship's procedure does it (its cuts), or by force
func _open_room(room: String, for_ctrl: String) -> void:
	var w = g.world
	if replay == null:
		rec.append(["o", room, for_ctrl])
	for k in g.ship.get("procedures", {}):
		var steps: Array = g.ship.procedures[k]
		var cuts: Array = []
		var uses := false
		for st in steps:
			if st.do == "cut":
				cuts.append(st)
			if st.do == "wait" and st.until.has("open") and st.until.open[0] == room:
				uses = true
		if uses and not cuts.is_empty():
			for st in cuts:
				var at := Vector2(st.at[0], st.at[1]) * M
				var p = w.piece_at(at)
				if p == null:
					continue
				var pl := PackedVector2Array()
				for q in st.kerf:
					pl.append(Vector2(q[0], q[1]) * M)
				g.cut_kerf(p, pl)
				_work(3.0)
			_note("cut open %s (%s)" % [room, k])
			return
	w.reveal(room, w.rooms[room].from)
	_note("opened %s" % room)


# the parts a marked-line cut made come off next, each on its own (left for later, they
# would go out with whatever they are still bolted to, as one lump of scrap)
func _requeue_parts(p) -> void:
	var origin: String = p.get_meta("origin", p.tag)
	order.push_front(p.id)
	for id in g.world.order:
		var q = g.world.pieces[id]
		if q != p and not q.gone and q.body == null and q.get_meta("origin", "") == origin and not order.has(q.id):
			order.push_front(q.id)


# cut a heavy piece along its marked lines (each line on whichever part now holds it)
func _cut_segments(p) -> bool:
	if p.get_meta("segments", []).is_empty() or not p.intact or _once_done("seg " + str(p.id)):
		return false
	var w = g.world
	# its pipes and cables off first: a line left on would tie the parts together again
	for l in w.lines_of(p):
		w.kill_line(l)
		g.log_op("unplug")
	for sg in p.get_meta("segments"):
		var a := Vector2(sg[0], sg[1]) * M
		var b := Vector2(sg[2], sg[3]) * M
		var on = w.piece_at(w.frame(p) * a.lerp(b, 0.5))
		if on == null or not on.intact:
			continue
		g.cut_kerf(on, PackedVector2Array([w.frame(on) * a, w.frame(on) * b]))
		_work(4.0)
	_note("cut %s along its marked lines" % p.tag)
	return true


func _once_done(k: String) -> bool:
	if done_ops.has(k):
		return true
	done_ops[k] = true
	return false


func _unsafe() -> Array:
	var s = g.sys
	var out: Array = []
	for n in g.world.rooms:
		if s.P(n) > 5.0:
			out.append("room %s %.0f kPa" % [n, s.P(n)])
	for k in s.vessel_cfg:
		if s.P(k) > 50.0 and not s.vessel_cfg[k].has("dead_leg"):
			out.append("vessel %s %.0f kPa" % [k, s.P(k)])
	for tg in s.src_order:
		var src: Dictionary = s.src[tg]
		if src.kind == "cap" and src.charge > 0.05:
			out.append("cap %s" % tg)
		# a generator with no stop of its own is safe once its switch is open
		if src.kind == "gen" and src.running and (src.has("local") or not src.has("switch") or s.on(src.switch)):
			out.append("gen %s" % tg)
	for tg in s.iso:
		if s.iso[tg].get("switch", "") != "" and s.on(s.iso[tg].switch) and s.iso[tg].charge > 0.0:
			out.append("own supply %s" % tg)
		if s.iso[tg].get("kind", "") == "cap" and s.iso[tg].charge > 0.05:
			out.append("cap %s" % tg)
	for k in s.fvol:
		if s.fvol[k].amount > 0.02:
			out.append("fluid %s %.3f" % [k, s.fvol[k].amount])
	if g.ore != null and g.ore.active():
		for gt in g.ore.cfg.get("gates", []):
			if Ship.ctrl_cfg(g.ship, gt).get("stuck", false) and not g.ore._gate_open(gt):
				out.append("bent gate %s" % gt)
	if g.ore != null and g.ore.active() and g.ore.fines > 0.3:
		var can := false
		for gt in g.ore.cfg.get("gates", []):
			if g.ore._gate_open(gt):
				can = true
		if can:
			out.append("ore %.1f t" % g.ore.fines)
	for id in g.world.ctrls:
		var c = g.world.ctrls[id]
		if c.kind == "seal" and not c.state and g.world.ctrl_alive(c):
			out.append("unsealed %s" % c.target)
	if not s.heat.is_empty() and s.loop_T > 60.0:
		out.append("loop %.0f C" % s.loop_T)
	if g.rails != null and g.rails.active():
		for rs in g.rails.cfg:
			if not g.rails.released.has(rs):
				out.append("rail %s locked" % rs)
	if s.bus_live:
		out.append("bus live")
	return out


func _safe() -> bool:
	return _unsafe().is_empty()


func _go_strip() -> void:
	var s = g.sys
	for id in s.hoses.keys():
		g.do_hose(ctrl(id))
	for n in g.world.rooms:
		g.world.reveal(n, g.world.rooms[n].from)
	var rank := {"equip": 0, "fixture": 1, "strut": 2, "rail": 3, "rib": 3, "beam": 4, "door": 5, "bulkhead": 5, "deck": 5, "hatch": 6, "hull": 6, "keel": 7}
	order = g.world.order.duplicate()
	var rk := func(id) -> int:
		var p = g.world.pieces[id]
		# a player opens a room from the top first: the roof plates come off before what is inside
		if paced and p.kind == "hull" and Geom.centroid(p.poly).y < -3.5 * M:
			return -1
		return rank.get(p.kind, 5)
	order.sort_custom(func(a, b): return rk.call(a) < rk.call(b))
	if g.scope() != "full":
		# a part-ship contract: only what it pays for, and the roof plates over it to get in
		var lo := INF
		var hi := -INF
		for id in order:
			var p = g.world.pieces[id]
			if p.scope:
				var cx: float = Geom.centroid(p.poly).x
				lo = minf(lo, cx)
				hi = maxf(hi, cx)
		order = order.filter(func(id):
			var p = g.world.pieces[id]
			var c: Vector2 = Geom.centroid(p.poly)
			return p.scope or (p.kind == "hull" and c.y < -3.5 * M and c.x > lo - M and c.x < hi + M))
	phase = "strip"
	phase_t = 0
	Engine.time_scale = 1.0


# ---------------------------------------------------------------- taking it apart

func _strip() -> void:
	if paced:
		_strip_paced()
		return
	var w = g.world
	if phase_t % 3 == 0:
		for b in w.bodies:
			if not is_instance_valid(b) or b.capture != null or sent.has(b):
				continue
			var zone := zone_for(b)
			sent[b] = zone
			var mouth: Vector2 = Dock.zpos(zone)
			var com_off: Vector2 = b.global_transform.basis_xform(b.center_of_mass)
			b.global_position = mouth - com_off
			b.linear_velocity = Vector2.ZERO
			b.angular_velocity = 0.0
			b.reset_physics_interpolation()
			break
	if phase_t % 2 != 0:
		return
	while not order.is_empty():
		var id = order.pop_front()
		var p = w.pieces.get(id)
		if p == null or p.gone or p.body != null:
			continue
		# with the heavy crane a piece it can lift goes out whole; without, along its marked lines
		if not (g.crane != null and p.mass <= g.crane.MAX_T) and _cut_segments(p):
			_requeue_parts(p)
			return
		for j in w.joints_of(p):
			w.kill_joint(j)
		for l in w.lines_of(p):
			w.kill_line(l)
		break
	if order.is_empty() and w.bodies.is_empty() and phase_t % 120 == 0:
		# anything left over (split off by a cut) comes away too
		for id in w.order:
			var p = w.pieces[id]
			if not p.gone and p.body == null:
				order.append(id)


# the heaviest plain scrap worth cutting down for the berth's machines (0: don't):
# the hauler takes it by itself and quickly; for the slow arm alone, more and
# smaller loads only lengthen its queue
func _machine_max() -> float:
	return g.hauler.MAX_T if g.hauler != null else 0.0


# one operation at a time, each taking its time: haul a body that is free, else free the next piece
func _strip_paced() -> void:
	var w = g.world
	if phase_t % 2 != 0:
		return
	for b in w.bodies:
		if not is_instance_valid(b) or b.capture != null or sent.has(b) or b.get_meta("arm", false):
			continue
		if g.arm != null and g.arm.takes(b):
			continue
		if g.hauler != null and (g.hauler.auto_takes(b) or g.hauler.body == b):
			continue
		# outside a part-ship contract's scope: pushed aside, not hauled
		if not b.pieces.any(func(q): return q.scope):
			continue
		# hauling a piece with a crack nobody has seen: it gives way on the way
		var crack = _crack_in(b)
		if crack != null:
			g.on_snap(crack)
			snapped += 1
			_work(3.0)
			return
		# still plugged into something by a line (a pipe between two parts): unplug it first
		var plugged := false
		for p in b.pieces:
			for l in w.lines_of(p):
				w.kill_line(l)
				plugged = true
		if plugged:
			g.log_op("unplug")
			_work(0.7)
			return
		var m: float = b.total_mass()
		var zone := zone_for(b)
		# plain scrap too heavy for the berth's machines: cut it down to their size and leave it to them
		if zone == "metal" and _machine_max() > 0.0 and m > _machine_max() and int(b.get_meta("bot_cuts", 0)) < 4:
			var big = null
			for q in b.pieces:
				if big == null or q.mass > big.mass:
					big = q
			if big != null and big.mass > 0.25:
				b.set_meta("bot_cuts", int(b.get_meta("bot_cuts", 0)) + 1)
				var bb := Geom.bbox(w.world_poly(big))
				var c := bb.get_center()
				var kerf := PackedVector2Array([c + Vector2(0, -bb.size.y), c + Vector2(0, bb.size.y)]) if bb.size.x >= bb.size.y else PackedVector2Array([c + Vector2(-bb.size.x, 0), c + Vector2(bb.size.x, 0)])
				g.cut_kerf(big, kerf)
				_work(4.0)
				return
		var k := 1
		if m > g.grab_max() + 0.001 and g.crane != null and m <= g.crane.MAX_T:
			# the crane's: whole, however heavy, at the crane's pace
			crane_hauls += 1
		elif m > g.grab_max() + 0.001:
			# too heavy for the grapple: cut into pieces it can take (whole equipment becomes scrap)
			k = ceili(m / g.grab_max())
			g.log_op("cut", k - 1)
			g.log_op("haul_scrap", k - 1)
			for p in b.pieces:
				if p.cls == "equip" and p.intact:
					p.intact = false
					scrapped += 1
			zone = zone_for(b)
		var mouth: Vector2 = Dock.zpos(zone)
		# one load at a time into a mouth: the last one in first (two dropped on the same spot fly apart)
		for o in sent:
			if is_instance_valid(o) and o.capture == null and sent[o] == zone and g.sys.time - float(o.get_meta("sent_t", -99.0)) < 3.0 and (o.global_transform * o.center_of_mass).distance_to(mouth) < 4.0 * M:
				return
		sent[b] = zone
		b.set_meta("sent_t", g.sys.time)
		# a body that drifted off is fetched from the berth's edge, not from wherever it went
		var com: Vector2 = b.global_transform * b.center_of_mass
		var d: float = minf(com.distance_to(mouth) / M, 50.0)
		if zone == "metal":
			# scrap is pushed down into the trough, or thrown into the furnace's reach
			d = minf(maxf(0.0, d - Dock.SCRAP_FIELD + 1.0), com.distance_to(Dock.trough_below(com)) / M)
		var mk := m / k
		_work(k * (d / (6.0 / (1.0 + mk)) + d / 6.0 + 2.0) + (k - 1) * 2.5)
		hauls += k
		if zone == "metal":
			scrap_hauls += k
			scrap_masses.append(snappedf(m, 0.01))
		b.set_meta("hauled", true)
		b.global_position = mouth - b.global_transform.basis_xform(b.center_of_mass)
		b.linear_velocity = Vector2.ZERO
		b.angular_velocity = 0.0
		b.reset_physics_interpolation()
		return
	# a player doesn't knock a hundred pieces loose at once: with the berth's machines
	# behind, wait for them to catch up (a big ship otherwise fills the berth with drift)
	if w.bodies.size() >= LOOSE_MAX:
		return
	while not order.is_empty():
		var id = order.pop_front()
		var p = w.pieces.get(id)
		if p == null or p.gone or p.body != null:
			continue
		# with the heavy crane a piece it can lift goes out whole; without, along its marked lines
		if not (g.crane != null and p.mass <= g.crane.MAX_T) and _cut_segments(p):
			_requeue_parts(p)
			return
		var sec := 1.0
		var cut := false
		for j in w.joints_of(p):
			if j.type == "crack" and not g.has_upgrade("scan_kit"):
				continue
			sec += {"bolt": 0.55, "lock": 0.45, "clamp": 0.95}.get(j.type, 1.2) + 0.3
			if j.type in ["bolt", "lock", "clamp"]:
				g.log_op("unfix")
			else:
				cut = true
			w.kill_joint(j)
		if cut:
			g.log_op("cut")
		for l in w.lines_of(p):
			sec += 0.7
			g.log_op("unplug")
			w.kill_line(l)
		_work(sec)
		return
	if phase_t % 120 == 0 and not w.bodies.any(func(b): return is_instance_valid(b) and b.pieces.any(func(q): return q.scope)):
		for id in w.order:
			var p = w.pieces[id]
			if not p.gone and p.body == null and p.scope:
				order.append(id)


func _crack_in(b):
	for j in g.world.joints:
		if j.alive and j.type == "crack" and b.pieces.any(func(q): return q.id == j.a or q.id == j.b):
			return j
	return null


func zone_for(b) -> String:
	if careless:
		return "metal"
	var hazard := false
	var equip := false
	var metal := 0.0
	var m := 0.0
	for p in b.pieces:
		m += p.mass
		var d: String = g.sys.dest_of(p)
		if d == "hazard":
			hazard = true
		elif d == "equip":
			equip = true
		else:
			metal += p.mass
	if hazard:
		return "hazard"
	if equip and metal <= m * 0.2:
		return "equip"
	return "metal"


func summary() -> Dictionary:
	return {"rate": g.recovery_rate(), "net": g.net(), "earned": g.earned(), "losses": g.losses, "grade": g.hud.grade(),
		"incidents": g.incidents.size(), "time": g.playtime, "ended": g.state == "ending", "forced": forced,
		"work": work, "hauls": hauls, "scrap_hauls": scrap_hauls, "arm": g.arm.carried if g.arm != null else 0, "hauler": g.hauler.carried if g.hauler != null else 0, "scrapped": scrapped, "snapped": snapped, "crane": crane_hauls}
