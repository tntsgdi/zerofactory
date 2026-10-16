class_name Variant
# A random contract's ship: the factory ship file of its type, changed the
# way a ship that has lived a different life would be. Built again from the
# contract's seed every time it is needed, so a save only has to name it.

# the ship file a contract plays: its type with this contract's history on top
static func make(base: Dictionary, job: Dictionary) -> Dictionary:
	var d: Dictionary = base.duplicate(true)
	# the hand-made first contract's story stays with the first contract
	d.erase("story")
	d.contract = job.get("id", d.get("contract", ""))
	d.variant = {"seed": int(job.get("variant", 0)), "traps": job.get("traps", [])}
	return d
