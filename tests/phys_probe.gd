extends Node
# Notes when the first physics step of each frame starts, so a perf test can
# tell how much of the frame went to physics (engine step + scripts).

var start_us := 0
var steps := 0
var _frame := -1


func _init() -> void:
	process_physics_priority = -100000
	process_mode = Node.PROCESS_MODE_ALWAYS


func _physics_process(_dt: float) -> void:
	var f := Engine.get_process_frames()
	if f != _frame:
		_frame = f
		start_us = Time.get_ticks_usec()
		steps = 0
	steps += 1
