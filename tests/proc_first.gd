extends Node
# Runs first in every idle frame (see proc_probe.gd).

var start_us := 0


func _init() -> void:
	process_priority = -100000
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_dt: float) -> void:
	start_us = Time.get_ticks_usec()
