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
#   hidden_damage   a cracked rib in the hold that snaps when hauled
#   explosive_cargo a container of dangerous goods under an ordinary stencil
#   fire_system     the fire suppression bottle never discharged

const ALL := ["wrong_valve", "fake_stop", "hidden_tank", "live_cargo", "welded_hatch",
	"rerouted_line", "second_source", "hidden_damage", "explosive_cargo", "fire_system"]
const TIER := {
	"wrong_valve": 0, "fake_stop": 0, "hidden_tank": 0, "live_cargo": 0, "welded_hatch": 0,
	"explosive_cargo": 0, "fire_system": 0, "rerouted_line": 1, "second_source": 1, "hidden_damage": 1,
}
# the names a trap may add to the factory ship (and the structure it may reshape)
const FITTINGS := {
	"hidden_tank": {"pieces": ["TK-X1"], "ctrls": ["TK-X1"]},
	"live_cargo": {"ctrls": ["K-RF"], "lines": ["cr"]},
	"second_source": {"pieces": ["EG-01"], "ctrls": ["K-EG"], "lines": ["ce"]},
	"hidden_damage": {"pieces": ["p47~", "p48~", "p49~"], "reshaped": ["p47", "p48", "p49"]},
	"fire_system": {"pieces": ["FX-01"], "ctrls": ["FX-P"]},
}
const TANK_SLOTS := [24.0, 25.7]          # x of an undeclared bottle on the hold floor (m)
const RIBS := ["p47", "p48", "p49"]


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


static func _target(d: Dictionary, trap: String, tg: String) -> void:
	var v: Dictionary = d.get("variant_targets", {})
	v[trap] = tg
	d.variant_targets = v


# changes the ship file for one trap (wrong_valve and fake_stop also shape
# the hazard settings, Variant._hazards)
static func apply(d: Dictionary, trap: String, rng: RandomNumberGenerator, notes: Array) -> void:
	notes.append(trap)
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
			var rib: String = RIBS[rng.randi_range(0, RIBS.size() - 1)]
			_target(d, trap, rib)
			var yc := snappedf(rng.randf_range(-1.6, 1.2), 0.01)
			_crack(d, rib, yc)
		"explosive_cargo":
			var c: String = Variant.CONTAINERS[rng.randi_range(0, 2)]
			_target(d, trap, c)
			var pd = Variant.piece(d, c)
			if pd == null:
				_reject(notes, "no_target explosive_cargo: %s is not aboard" % c)
				return
			pd.hazard = "explosive"


# a pressure bottle standing on (or hanging from) a structural piece
static func _add_bottle(d: Dictionary, tag: String, vol: String, room: String, x: float, y0: float, y1: float, kpa: float, v: float, name_key: String, value: float, base: Array) -> void:
	d.pieces.append({"key": tag, "tag": tag, "kind": "equip", "cls": "equip", "name_key": name_key, "room": room, "art": "gastank",
		"art_size": [0.8, y1 - y0], "art_xf": [1.0, 0.0, 0.0, 1.0, x, y0], "poly": [[x, y0], [x + 0.8, y0], [x + 0.8, y1], [x, y1]],
		"mass": 0.35, "value": value, "hazard": "gas_tank", "dest": "equip", "cut_speed": 140.0, "density": 1.0})
	for dx in [0.2, 0.6]:
		d.joints.append({"a": tag, "b": base[0], "type": "bolt", "at": [x + dx, base[1]]})
	d.gas.vessels[vol] = {"V": v, "burst": 200.0, "kpa": snappedf(kpa, 1.0), "piece": tag}


# a rib cracked across at height yc: two pieces held only by the crack
static func _crack(d: Dictionary, rib: String, yc: float) -> void:
	var pd = Variant.piece(d, rib)
	if pd == null:
		return
	var bb := Variant._bbox(pd.poly)
	var low: Dictionary = pd.duplicate(true)
	low.key = rib + "~"
	pd.poly = [[bb.position.x, bb.position.y], [bb.end.x, bb.position.y], [bb.end.x, yc], [bb.position.x, yc]]
	low.poly = [[bb.position.x, yc], [bb.end.x, yc], [bb.end.x, bb.end.y], [bb.position.x, bb.end.y]]
	var m: float = float(pd.get("mass", 0.0))
	var k := (yc - bb.position.y) / bb.size.y
	pd.mass = snappedf(m * k, 0.001)
	low.mass = snappedf(m - pd.mass, 0.001)
	d.pieces.insert(d.pieces.find(pd) + 1, low)
	for j in d.joints:
		for side in ["a", "b"]:
			if j[side] == rib and float(j.at[1]) > yc:
				j[side] = low.key
	d.joints.append({"a": rib, "b": low.key, "type": "crack", "at": [snappedf(bb.get_center().x, 0.01), yc]})


static func _patch_proc(d: Dictionary, key: String, fn: Callable) -> void:
	var procs: Dictionary = d.get("procedures", {})
	if procs.has(key):
		procs[key] = fn.call(procs[key])
