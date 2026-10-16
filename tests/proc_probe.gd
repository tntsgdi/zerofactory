extends Node
# Runs last in every idle frame: marks when all _process calls are done, so a
# perf test can split a frame into physics / process / render+present.

var end_us := 0


func _init() -> void:
	process_priority = 100000
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_dt: float) -> void:
	end_us = Time.get_ticks_usec()
