class_name Traps
# The signature traps a contract can carry (design/DECISIONS.md, contract
# loop v2): what each does to the ship file. Every one can be found by
# measuring or looking before it bites. Tier 0 traps are plain to read and
# come from the first contract on; tier 1 ones only once the berth has a
# name (reputation "certified" and up).

const ALL := ["wrong_valve", "fake_stop"]
const TIER := {
	"wrong_valve": 0, "fake_stop": 0, "hidden_tank": 0, "live_cargo": 0, "welded_hatch": 0,
	"explosive_cargo": 0, "fire_system": 0, "rerouted_line": 1, "second_source": 1, "hidden_damage": 1,
}


# changes the ship file for one trap; wrong_valve and fake_stop live in the
# hazard settings themselves (Variant._hazards)
static func apply(d: Dictionary, trap: String, rng: RandomNumberGenerator, notes: Array) -> void:
	match trap:
		"wrong_valve", "fake_stop":
			notes.append(trap)


# the names a contract's traps add to the factory ship: pieces, controls,
# lines, and factory structure they are allowed to reshape (a crack splits one)
static func fittings(traps: Array) -> Dictionary:
	var out := {"pieces": {}, "ctrls": {}, "lines": {}, "reshaped": {}}
	for t in traps:
		var f: Dictionary = FITTINGS.get(t, {})
		for k in out:
			for id in f.get(k, []):
				out[k][id] = true
	return out


const FITTINGS := {}


# what a careful operator finds the trap by: [kind, id] — controls to read or
# work, pieces to inspect, lines to trace. The contract validator makes sure
# each is aboard.
static func evidence(d: Dictionary, trap: String) -> Array:
	match trap:
		"wrong_valve":
			return [["ctrl", "P-C01"], ["ctrl", "V-C01"]]
		"fake_stop":
			return [["ctrl", "E-D01"], ["ctrl", "G-LOCAL"]]
	return []
