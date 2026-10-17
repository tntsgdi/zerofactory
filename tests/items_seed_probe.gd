extends "res://tests/items_check.gd"
# Reproduce the consumable regression on the same contract in both revisions.
func _initialize() -> void:
	seed(20261017)
	super._initialize()
