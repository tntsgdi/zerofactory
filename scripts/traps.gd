class_name Traps
# The signature traps a contract can carry (design/DECISIONS.md, contract
# loop v2): what each does to the ship file, the fixed names of what it adds,
# and what a careful operator finds it by. Every one can be found by
# measuring or looking before it bites. Tier 0 traps are plain to read and
# come from the first contract on; tier 1 ones only once the berth has a
# name (reputation "certified" and up).
#   wrong_valve     the test port's valve is shut: the port reads its own empty stub
#   fake_stop       the remote stop is "sent" and the generator keeps turning
#   hidden_tank     an undeclared bottle under pressure in the hold
#   live_cargo      a reefer container on its own supply, plugged into the hull
#   welded_hatch    the cargo hatch's seams welded shut; the drive burns out on it
#   rerouted_line   a coolant run moved under the engine room's roof
#   second_source   an emergency generator feeding the bus from the stern
#   hidden_damage   a hold roof plate cracked along an old seam: hauled off, it snaps and half drops in
#   explosive_cargo a container of dangerous goods under an ordinary stencil
#   fire_system     the fire suppression bottle never discharged
# and, only where a ship type has a slot for it (EXTRA, never on the Heron):
#   bio_breach      an isolation pod's negative-pressure valve has failed: its air is dirty and
#                   above the corridor's, so opening its hatch blows it into the corridor
#   gate_jam        one of a hopper's two discharge gates is bent: its drive will not open it;
#                   forced while the hopper is still full, the load goes one way and tears it
#   psv_stuck       a cryogenic tank's relief valve is frozen shut and the tank already over its
#                   set pressure: it cannot relieve itself; warmed further, it ruptures
#   heater_live     the anti-freeze heater left switched on, on its own supply, warming its tank
#   jacket_loss     a tank's vacuum jacket has let air in: heat leaks in fast, the cargo is warmer

const ALL := ["wrong_valve", "fake_stop", "hidden_tank", "live_cargo", "welded_hatch",
	"rerouted_line", "second_source", "hidden_damage", "explosive_cargo", "fire_system"]
const EXTRA := ["bio_breach", "gate_jam", "psv_stuck", "heater_live", "jacket_loss"]
const TIER := {
	"gate_jam": 0, "heater_live": 0, "jacket_loss": 0, "psv_stuck": 1,
	"bio_breach": 0,
	"wrong_valve": 0, "fake_stop": 0, "hidden_tank": 0, "live_cargo": 0, "welded_hatch": 0,
	"explosive_cargo": 0, "fire_system": 0, "rerouted_line": 1, "second_source": 1, "hidden_damage": 1,
}
# the names a trap may add to the factory ship (and the structure it may reshape)
const FITTINGS := {
	"hidden_tank": {"pieces": ["TK-X1"], "ctrls": ["TK-X1"]},
	"live_cargo": {"ctrls": ["K-RF"], "lines": ["cr"]},
	"second_source": {"pieces": ["EG-01"], "ctrls": ["K-EG"], "lines": ["ce"]},
	"hidden_damage": {"pieces": ["p7~", "p10~", "p11~"], "reshaped": ["p7", "p10", "p11"]},
	"fire_system": {"pieces": ["FX-01"], "ctrls": ["FX-P"]},
}
const TANK_SLOTS := [24.0, 25.7]          # x of an undeclared bottle on the hold floor (m)
const PLATES := ["p7", "p10", "p11"]     # the hold's roof plates a crack can run through


# the traps a ship type can carry: the Heron all ten; another type the ones
# its file has a slot for (market.slots), and the cargo ones when it has containers
static func allowed(d: Dictionary) -> Array:
	if not d.has("market"):
		return ALL
	var out: Array = []
	var slots: Dictionary = d.market.get("slots", {})
	for t in ALL + EXTRA:
		if slots.has(t):
			out.append(t)
	return out


static func _slot(d: Dictionary, trap: String):
	return d.get("market", {}).get("slots", {}).get(trap, null)


static func fittings(traps: Array) -> Dictionary:
	var out := {"pieces": {}, "ctrls": {}, "lines": {}, "reshaped": {}}
	for t in traps:
		var f: Dictionary = FITTINGS.get(t, {})
		for k in out:
			for id in f.get(k, []):
				out[k][id] = true
	return out


# what a careful operator finds the trap by: [kind, id] — controls to read or
# work, pieces to inspect, lines to trace. The contract validator makes sure
# each is aboard.
static func evidence(d: Dictionary, trap: String) -> Array:
	var tg: String = d.get("variant", {}).get("targets", {}).get(trap, "")
	var sl = _slot(d, trap)
	if sl != null:
		match trap:
			"second_source":
				return [["ctrl", sl.test], ["piece", "EG-01"], ["ctrl", "K-EG"]]
			"welded_hatch":
				var ev: Array = []
				for k in sl.evidence:
					ev.append(["piece", k])
				return ev
			"live_cargo":
				return [["piece", tg], ["ctrl", "K-RF"], ["line", "cr"]]
			"bio_breach":
				return [["ctrl", "S-" + tg], ["ctrl", "P-" + tg]]
			"gate_jam":
				return [["piece", tg], ["ctrl", tg]]
			"psv_stuck":
				var n: String = tg.trim_prefix("T-")
				return [["ctrl", "TT-" + n], ["ctrl", "VP-" + n], ["piece", "PSV-" + n]]
			"heater_live":
				return [["ctrl", sl.switch], ["ctrl", "E-HT"], ["piece", "HEATER"]]
			"jacket_loss":
				var n2: String = tg.trim_prefix("T-")
				return [["ctrl", "JP-" + n2], ["ctrl", "TT-" + n2]]
	match trap:
		"wrong_valve":
			return [["ctrl", "P-C01"], ["ctrl", "V-C01"]]
		"fake_stop":
			return [["ctrl", "E-D01"], ["ctrl", "G-LOCAL"]]
		"hidden_tank":
			return [["piece", "TK-X1"], ["ctrl", "TK-X1"]]
		"live_cargo":
			return [["piece", tg], ["ctrl", "K-RF"], ["line", "cr"]]
		"welded_hatch":
			return [["piece", "HATCH-1"], ["piece", "HATCH-2"]]
		"rerouted_line":
			return [["line", "q2"], ["piece", "p12"]]
		"second_source":
			return [["ctrl", "E-D01"], ["piece", "EG-01"], ["ctrl", "K-EG"]]
		"hidden_damage":
			return [["piece", tg], ["piece", tg + "~"]]
		"explosive_cargo":
			return [["piece", tg]]
		"fire_system":
			return [["piece", "FX-01"], ["ctrl", "FX-P"]]
	return []


# A survey report (the intel consumable): the true state behind one trap, as
# a reading — [Txt key, arguments]. Read from the contract's own ship.
static func intel(d: Dictionary, trap: String) -> Array:
	var tg: String = d.get("variant", {}).get("targets", {}).get(trap, "")
	var gas: Dictionary = d.get("gas", {})
	match trap:
		"wrong_valve":
			return ["in_wrong_valve", [int(float(gas.rooms.get("C", 0.0)))]]
		"hidden_tank":
			return ["in_hidden_tank", [int(float(gas.vessels.get("TX", {}).get("kpa", 0.0)))]]
		"fire_system":
			return ["in_fire_system", [int(float(gas.vessels.get("FX", {}).get("kpa", 0.0)))]]
		"bio_breach":
			return ["in_bio_breach", [tg, int(float(gas.rooms.get(tg, 0.0)))]]
		"gate_jam":
			return ["in_gate_jam", [tg]]
		"psv_stuck":
			return ["in_psv_stuck", [tg, int(float(gas.vessels.get("TV" + tg.trim_prefix("T-"), {}).get("kpa", 0.0)))]]
		"heater_live":
			return ["in_heater_live", [tg]]
		"jacket_loss":
			return ["in_jacket_loss", [tg, int(float(gas.rooms.get("J" + tg.trim_prefix("T-"), 0.0)))]]
		"live_cargo", "explosive_cargo":
			return ["in_" + trap, [tg]]
		"hidden_damage":
			# a roof plate has no name a player knows: say where it is
			var pd = Variant.piece(d, tg)
			return ["in_hidden_damage", [int(round(Variant._bbox(pd.poly).get_center().x)) if pd != null else 0]]
	return ["in_" + trap, []]


# did the trap bite on this contract? (an incident of its kind, where it was)
static func bit(trap: String, incidents: Array) -> bool:
	for x in incidents:
		var k: String = x[1]
		var det: String = str(x[2]) if x.size() > 2 else ""
		match trap:
			"wrong_valve":
				if k == "blowout" and det == "C":
					return true
			"fake_stop":
				if k == "arc" and det.find("G-01") >= 0:
					return true
			"hidden_tank":
				if k == "burst" and det == "TK-X1":
					return true
			"fire_system":
				if k == "burst" and det == "FX-01":
					return true
			"live_cargo", "second_source":
				if k == "arc" or (k == "drone_hit" and det == "live_unplug"):
					return true
			"welded_hatch":
				if k == "motor":
					return true
			"rerouted_line":
				if k == "leak" and det in ["cool", "cool_broken"]:
					return true
			"hidden_damage":
				if k == "snap":
					return true
			"explosive_cargo":
				if k in ["blast", "furnace"]:
					return true
	return false


static func _reject(notes: Array, why: String) -> void:
	notes.append("reject:" + why)


static func _carries_equipment(d: Dictionary, key: String) -> bool:
	var eq := {}
	for pd in d.pieces:
		if pd.get("cls", "") == "equip":
			eq[pd.key] = true
	for j in d.joints:
		if (j.a == key and eq.has(j.get("b", ""))) or (j.get("b", "") == key and eq.has(j.a)):
			return true
	return false


static func _target(d: Dictionary, trap: String, tg: String) -> void:
	var v: Dictionary = d.get("variant_targets", {})
	v[trap] = tg
	d.variant_targets = v


# changes the ship file for one trap (wrong_valve and fake_stop also shape
# the hazard settings, Variant._hazards)
static func apply(d: Dictionary, trap: String, rng: RandomNumberGenerator, notes: Array) -> void:
	notes.append(trap)
	var sl = _slot(d, trap)
	if sl != null:
		_apply_slot(d, trap, sl, rng, notes)
		return
	match trap:
		"hidden_tank":
			var x: float = TANK_SLOTS[rng.randi_range(0, TANK_SLOTS.size() - 1)]
			_add_bottle(d, "TK-X1", "TX", "C", x, 1.05, 2.95, rng.randf_range(1500.0, 2000.0), 0.6, "p_gastank", 2500.0, ["K3", 2.95])
			d.ctrls.append({"at": [x + 0.4, 1.12], "id": "TK-X1", "kind": "port", "medium": "gas", "piece": "TK-X1", "target": "TX", "hidden_room": "C"})
			d.ctrls_cfg["TK-X1"] = {"rate": 0.2}
			d.blueprint.hide.append("TK-X1")
		"fire_system":
			_add_bottle(d, "FX-01", "FX", "F", 33.3, -2.85, -1.25, rng.randf_range(1800.0, 2600.0), 0.4, "p_fx", 1800.0, ["BEAM-T", -2.88])
			d.ctrls.append({"at": [33.7, -1.32], "id": "FX-P", "kind": "port", "medium": "gas", "piece": "FX-01", "target": "FX"})
			d.ctrls_cfg["FX-P"] = {"rate": 0.2}
			d.labels["FX-01"] = "FX"
		"live_cargo":
			var c: String = Variant.CONTAINERS[rng.randi_range(0, 2)]
			_target(d, trap, c)
			var pd = Variant.piece(d, c)
			if pd == null:
				_reject(notes, "no_target live_cargo: %s is not aboard" % c)
				return
			if d.lines.any(func(l): return l.a == c or l.b == c):
				_reject(notes, "wired live_cargo: %s is already on the ship's own lines" % c)
				return
			var bb := Variant._bbox(pd.poly)
			var x0 := bb.position.x
			d.power.isolated.append({"piece": c, "volts": 230.0, "charge": 1.0, "switch": "K-RF"})
			d.ctrls.append({"at": [snappedf(x0 + 0.3, 0.01), snappedf(bb.position.y + 0.12, 0.01)], "id": "K-RF", "kind": "switch", "piece": c, "state": true, "target": "K-RF", "hidden_room": "C"})
			var kx := "K2" if x0 - 0.1 < 18.6 else "K3"
			d.lines.append({"id": "cr", "kind": "cable", "net": "power", "a": c, "b": kx, "pa": [x0 + 0.15, 2.75], "pb": [x0 - 0.1, 2.95],
				"path": [[x0 + 0.15, 2.75], [x0 - 0.1, 2.75], [x0 - 0.1, 2.95]]})
		"welded_hatch":
			d.joints.append({"a": "HATCH-1", "b": "p7", "type": "seam", "at": [15.33, -3.78]})
			d.joints.append({"a": "HATCH-2", "b": "p10", "type": "seam", "at": [21.28, -3.78]})
			d.joints.append({"a": "HATCH-1", "b": "HATCH-2", "type": "seam", "at": [18.31, -3.78]})
		"rerouted_line":
			for l in d.lines:
				if l.id == "q2":
					var bp: Dictionary = d.blueprint
					var lines: Dictionary = bp.get("lines", {})
					lines["q2"] = l.path.duplicate(true)
					bp.lines = lines
					l.path = [[29.7, -0.5], [29.8, -0.5], [29.8, -2.3], [27.9, -2.3], [27.9, -3.45], [32.4, -3.45], [32.4, -1.1], [34.2, -1.1]]
			# the safe way to G-01 drains the loop before the roof comes off
			_patch_proc(d, "G-01", func(steps: Array) -> Array:
				var out: Array = []
				for st in steps:
					if st.do == "hose" and st.get("ctrl", "") == "COOL-E":
						continue
					if st.do == "cut" and not out.any(func(s): return s.get("ctrl", "") == "COOL-E"):
						out.append({"ctrl": "COOL-E", "do": "hose"})
						out.append({"do": "wait", "max": 120.0, "until": {"fluid": ["cool", "<", 0.02]}})
					out.append(st)
				return out)
		"second_source":
			d.pieces.append({"key": "EG-01", "tag": "EG-01", "kind": "equip", "cls": "equip", "name_key": "p_egen", "room": "F", "art": "gen",
				"art_size": [1.4, 1.6], "art_xf": [1.0, 0.0, 0.0, 1.0, 33.2, 1.25], "poly": [[33.2, 1.25], [34.6, 1.25], [34.6, 2.85], [33.2, 2.85]],
				"mass": 1.6, "value": 5000.0, "fragile": 0.35, "hazard": "gen", "dest": "equip", "cut_speed": 140.0, "density": 1.0})
			d.joints.append({"a": "EG-01", "b": "BEAM-B", "type": "bolt", "at": [33.5, 2.88]})
			d.joints.append({"a": "EG-01", "b": "BEAM-B", "type": "bolt", "at": [34.3, 2.88]})
			d.ctrls.append({"at": [33.45, 1.33], "id": "K-EG", "kind": "switch", "piece": "EG-01", "state": true, "target": "K-EG"})
			d.lines.append({"id": "ce", "kind": "cable", "net": "power", "a": "EG-01", "b": "SWB", "pa": [33.25, 1.5], "pb": [32.45, -1.3],
				"path": [[33.25, 1.5], [32.75, 1.5], [32.75, -1.3], [32.45, -1.3]]})
			d.power.sources.append({"cable": "ce", "kind": "gen", "piece": "EG-01", "running": true, "switch": "K-EG", "volts": 230.0})
			d.labels["EG-01"] = "EG"
			d.blueprint.hide.append("EG-01")
			# the safe way to G-01 isolates the second supply before bleeding the capacitor
			_patch_proc(d, "G-01", func(steps: Array) -> Array:
				var out: Array = []
				for st in steps:
					if st.get("ctrl", "") == "E-D02" and st.do == "operate":
						out.append({"ctrl": "K-EG", "do": "operate"})
					out.append(st)
				return out)
		"hidden_damage":
			var plate: String = PLATES[rng.randi_range(0, PLATES.size() - 1)]
			_target(d, trap, plate)
			_crack(d, plate, rng.randf_range(0.3, 0.7))
		"explosive_cargo":
			var c: String = Variant.CONTAINERS[rng.randi_range(0, 2)]
			_target(d, trap, c)
			var pd = Variant.piece(d, c)
			if pd == null:
				_reject(notes, "no_target explosive_cargo: %s is not aboard" % c)
				return
			pd.hazard = "explosive"


# a cryogenic tank started dT warmer than it is kept: its vapour that much higher (scripts/cryo.gd)
static func _warm(d: Dictionary, tank: String, dT: float) -> void:
	var e: Dictionary = d.cryo.tanks[tank]
	e.T = snappedf(float(e.T0) + dT, 0.01)
	d.gas.vessels[e.vessel].kpa = snappedf(float(e.kpa0) * pow(2.0, dT / Cryo.DOUBLE), 0.1)


# The same trap on another ship type, placed where its file's slot says
# (market.slots[trap]). Same names and the same evidence as on the Heron;
# what it does depends on where it sits on that ship.
static func _apply_slot(d: Dictionary, trap: String, sl: Dictionary, rng: RandomNumberGenerator, notes: Array) -> void:
	match trap:
		"gate_jam":
			var gate: String = sl.gates[rng.randi_range(0, sl.gates.size() - 1)]
			_target(d, trap, gate)
			var cc: Dictionary = d.ctrls_cfg.get(gate, {})
			cc.stuck = true
			d.ctrls_cfg[gate] = cc
		"psv_stuck":
			# frozen shut, and the cargo already warm enough to be over the valve's set pressure
			var tk: String = sl.tanks[rng.randi_range(0, sl.tanks.size() - 1)]
			_target(d, trap, tk)
			var e: Dictionary = d.cryo.tanks[tk]
			e.stuck = true
			_warm(d, tk, rng.randf_range(9.6, 11.6))
		"heater_live":
			# someone left the heater on: it has been warming its tank a while
			var sw: String = sl.switch
			_target(d, trap, d.cryo.heater.tank)
			for c in d.ctrls:
				if c.id == sw:
					c.state = true
			_warm(d, d.cryo.heater.tank, rng.randf_range(2.0, 4.0))
		"jacket_loss":
			# air has got into the vacuum jacket: it no longer insulates, the cargo is warmer
			var tk2: String = sl.tanks[rng.randi_range(0, sl.tanks.size() - 1)]
			_target(d, trap, tk2)
			d.gas.rooms[d.cryo.tanks[tk2].jacket] = snappedf(rng.randf_range(18.0, 40.0), 0.1)
			_warm(d, tk2, rng.randf_range(3.5, 6.0))
		"bio_breach":
			# the pod's air is dirtier than the patient left it, and above the corridor
			var room: String = sl.rooms[rng.randi_range(0, sl.rooms.size() - 1)]
			_target(d, trap, room)
			d.gas.rooms[room] = snappedf(rng.randf_range(108.0, 118.0), 0.1)
			var b: Dictionary = d.get("bio", {})
			var br: Dictionary = b.get("rooms", {})
			br[room] = snappedf(rng.randf_range(3.2, 4.2), 0.01)
			b.rooms = br
			d.bio = b
		"hidden_tank":
			# each place it may stand: [x, the piece it is bolted to]
			var spot: Array = sl.x[rng.randi_range(0, sl.x.size() - 1)]
			var x: float = spot[0]
			_add_bottle(d, "TK-X1", "TX", sl.room, x, sl.y0, sl.y1, rng.randf_range(1500.0, 2000.0), 0.6, "p_gastank", 2500.0, [_key(d, spot[1]), sl.base_y])
			var c := {"at": [x + 0.4, float(sl.y0) + 0.07], "id": "TK-X1", "kind": "port", "medium": "gas", "piece": "TK-X1", "target": "TX"}
			if sl.room != "":
				c.hidden_room = sl.room
			d.ctrls.append(c)
			d.ctrls_cfg["TK-X1"] = {"rate": 0.2}
			d.blueprint.get("hide", []).append("TK-X1")
		"fire_system":
			_add_bottle(d, "FX-01", "FX", sl.room, sl.x, sl.y0, sl.y1, rng.randf_range(1800.0, 2600.0), 0.4, "p_fx", 1800.0, [_key(d, sl.base[0]), sl.base[1]])
			var fc := {"at": sl.port, "id": "FX-P", "kind": "port", "medium": "gas", "piece": "FX-01", "target": "FX"}
			if sl.room != "":
				fc.hidden_room = sl.room
			d.ctrls.append(fc)
			d.ctrls_cfg["FX-P"] = {"rate": 0.2}
			d.labels["FX-01"] = "FX"
		"second_source":
			var x0: float = sl.at[0]
			var y0: float = sl.at[1]
			var w: float = sl.size[0]
			var h: float = sl.size[1]
			var pd := {"key": "EG-01", "tag": "EG-01", "kind": "equip", "cls": "equip", "name_key": "p_egen", "art": "gen",
				"art_size": [w, h], "art_xf": [1.0, 0.0, 0.0, 1.0, x0, y0], "poly": [[x0, y0], [x0 + w, y0], [x0 + w, y0 + h], [x0, y0 + h]],
				"mass": 1.2, "value": 4500.0, "fragile": 0.35, "hazard": "gen", "dest": "equip", "cut_speed": 140.0, "density": 1.0}
			if sl.get("room", "") != "":
				pd.room = sl.room
			d.pieces.append(pd)
			for b in sl.base:
				d.joints.append({"a": "EG-01", "b": _key(d, b[0]), "type": "bolt", "at": [b[1], b[2]]})
			var kc := {"at": sl.switch_at, "id": "K-EG", "kind": "switch", "piece": "EG-01", "state": true, "target": "K-EG"}
			if sl.get("room", "") != "":
				kc.hidden_room = sl.room
			d.ctrls.append(kc)
			d.lines.append({"id": "ce", "kind": "cable", "net": "power", "a": "EG-01", "b": sl.bus, "pa": sl.path[0], "pb": sl.path[-1], "path": sl.path})
			d.power.sources.append({"cable": "ce", "kind": "gen", "piece": "EG-01", "running": true, "switch": "K-EG", "volts": float(sl.get("volts", 120.0))})
			d.labels["EG-01"] = "EG"
			d.blueprint.get("hide", []).append("EG-01")
			# the safe way to the named item isolates the second supply first
			_patch_proc(d, sl.proc, func(steps: Array) -> Array:
				var out: Array = []
				var done := false
				for st in steps:
					if not done and st.do == "operate":
						out.append({"ctrl": "K-EG", "do": "operate"})
						done = true
					out.append(st)
				return out)
		"hidden_damage":
			# a plate with nothing of value hung from it (else what drops with it is wrecked before anyone could know)
			var free: Array = []
			for pl in sl.plates:
				if not _carries_equipment(d, _key(d, pl)):
					free.append(pl)
			if free.is_empty():
				free = sl.plates
			var plate: String = _key(d, free[rng.randi_range(0, free.size() - 1)])
			_target(d, trap, plate)
			_crack(d, plate, rng.randf_range(0.3, 0.7))
		"welded_hatch":
			for s in sl.seams:
				d.joints.append({"a": _key(d, s[0]), "b": _key(d, s[1]), "type": "seam", "at": [s[2], s[3]]})
		"explosive_cargo", "live_cargo":
			# a plain container: aboard, no dangerous goods, not on a supply of its own already
			var pool: Array = Variant.containers(d).filter(func(c): return Variant.piece(d, c) != null and Variant.piece(d, c).get("hazard", "") == "" \
				and not d.power.get("isolated", []).any(func(s): return s.piece == c))
			if pool.is_empty():
				_reject(notes, "no_target %s: no plain container aboard" % trap)
				return
			var c: String = pool[rng.randi_range(0, pool.size() - 1)]
			_target(d, trap, c)
			var pd = Variant.piece(d, c)
			if trap == "explosive_cargo":
				pd.hazard = "explosive"
				return
			var bb := Variant._bbox(pd.poly)
			var x0 := bb.position.x
			var yb := bb.end.y
			d.power.isolated.append({"piece": c, "volts": 230.0, "charge": 1.0, "switch": "K-RF"})
			var kc := {"at": [snappedf(x0 + 0.3, 0.01), snappedf(bb.position.y + 0.12, 0.01)], "id": "K-RF", "kind": "switch", "piece": c, "state": true, "target": "K-RF"}
			if sl.get("room", "") != "":
				kc.hidden_room = sl.room
			d.ctrls.append(kc)
			var host: String = _key(d, sl.hosts.get(c, ""))
			# a cracked rail: the half under the container
			var hh = Variant.piece(d, host + "~")
			if hh != null and Variant._bbox(hh.poly).has_point(Vector2(x0 - 0.1, float(sl.host_y))):
				host = host + "~"
			if host == "":
				_reject(notes, "no_host live_cargo: nothing to plug %s into" % c)
				return
			d.lines.append({"id": "cr", "kind": "cable", "net": "power", "a": c, "b": host, "pa": [x0 + 0.15, yb - 0.2], "pb": [x0 - 0.1, float(sl.host_y)],
				"path": [[x0 + 0.15, yb - 0.2], [x0 - 0.1, yb - 0.2], [x0 - 0.1, float(sl.host_y)]]})


# a slot names a piece by its tag (or its key): the key the file uses
static func _key(d: Dictionary, name: String) -> String:
	if name == "":
		return ""
	for pd in d.pieces:
		if pd.get("tag", "") == name:
			return pd.key
	return name


# a pressure bottle standing on (or hanging from) a structural piece
static func _add_bottle(d: Dictionary, tag: String, vol: String, room: String, x: float, y0: float, y1: float, kpa: float, v: float, name_key: String, value: float, base: Array) -> void:
	d.pieces.append({"key": tag, "tag": tag, "kind": "equip", "cls": "equip", "name_key": name_key, "room": room, "art": "gastank",
		"art_size": [0.8, y1 - y0], "art_xf": [1.0, 0.0, 0.0, 1.0, x, y0], "poly": [[x, y0], [x + 0.8, y0], [x + 0.8, y1], [x, y1]],
		"mass": 0.35, "value": value, "hazard": "gas_tank", "dest": "equip", "cut_speed": 140.0, "density": 1.0})
	if room == "":
		d.pieces[-1].erase("room")
	for dx in [0.2, 0.6]:
		d.joints.append({"a": tag, "b": base[0], "type": "bolt", "at": [x + dx, base[1]]})
	d.gas.vessels[vol] = {"V": v, "burst": 200.0, "kpa": snappedf(kpa, 1.0), "piece": tag}


# a plate cracked straight across at fraction f of its width: two pieces held
# only by the crack (fixings, controls and line ends go with the side they are on)
static func _crack(d: Dictionary, key: String, f: float) -> void:
	var pd = Variant.piece(d, key)
	if pd == null:
		return
	var bb := Variant._bbox(pd.poly)
	var xc := snappedf(bb.position.x + bb.size.x * f, 0.01)
	var left := Geometry2D.clip_polygons(_pv(pd.poly), PackedVector2Array([Vector2(xc, -99), Vector2(99, -99), Vector2(99, 99), Vector2(xc, 99)]))
	var right := Geometry2D.clip_polygons(_pv(pd.poly), PackedVector2Array([Vector2(-99, -99), Vector2(xc, -99), Vector2(xc, 99), Vector2(-99, 99)]))
	if left.is_empty() or right.is_empty():
		return
	var other: Dictionary = pd.duplicate(true)
	other.key = key + "~"
	other.erase("tag")
	pd.poly = _arr(left[0])
	other.poly = _arr(right[0])
	var m: float = float(pd.get("mass", 0.0))
	var k := Geom.area(left[0]) / (Geom.area(left[0]) + Geom.area(right[0]))
	pd.mass = snappedf(m * k, 0.001)
	other.mass = snappedf(m - pd.mass, 0.001)
	d.pieces.insert(d.pieces.find(pd) + 1, other)
	for j in d.joints:
		for side in ["a", "b"]:
			if j[side] == key and float(j.at[0]) > xc:
				j[side] = other.key
	for c in d.ctrls:
		if c.piece == key and float(c.at[0]) > xc:
			c.piece = other.key
	for l in d.lines:
		if l.a == key and float(l.pa[0]) > xc:
			l.a = other.key
		if l.b == key and float(l.pb[0]) > xc:
			l.b = other.key
	var ys: Array = []
	for q in d.pieces[d.pieces.find(pd)].poly:
		if absf(float(q[0]) - xc) < 0.02:
			ys.append(float(q[1]))
	var yc: float = (ys.min() + ys.max()) * 0.5 if ys.size() >= 2 else bb.get_center().y
	d.joints.append({"a": key, "b": other.key, "type": "crack", "at": [xc, snappedf(yc, 0.01)]})


static func _pv(a: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in a:
		out.append(Vector2(q[0], q[1]))
	return out


static func _arr(p: PackedVector2Array) -> Array:
	var out: Array = []
	for q in p:
		out.append([snappedf(q.x, 0.0001), snappedf(q.y, 0.0001)])
	return out


static func _patch_proc(d: Dictionary, key: String, fn: Callable) -> void:
	var procs: Dictionary = d.get("procedures", {})
	if procs.has(key):
		procs[key] = fn.call(procs[key])
