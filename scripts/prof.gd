class_name Prof
# Per-frame timing buckets for the perf tests (tools/prof_wrap.py adds the calls).

static var sum := {}
static var peak := {}
static var frame := {}


static func add(key: String, t0: int) -> void:
	frame[key] = frame.get(key, 0) + Time.get_ticks_usec() - t0


# call once per frame: folds this frame's buckets into the totals
static func roll() -> void:
	for k in frame:
		sum[k] = sum.get(k, 0) + frame[k]
		peak[k] = maxi(peak.get(k, 0), frame[k])
	frame = {}


static func reset() -> void:
	sum = {}
	peak = {}
	frame = {}
