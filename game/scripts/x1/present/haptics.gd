extends RefCounted
## Haptic vocabulary on top of Input.vibrate_handheld: named patterns, priorities,
## a minimum gap between buzzes and a strength setting. Every call is logged for tests.

var feel: Dictionary = {}
var strength := 1.0
var gap := 0.07
var clock := 0.0
var last_at := -99.0
var last_priority := -1
var queue: Array = []        # [{at, ms, amp}] pulses of the current pattern
var history: Array = []          # [{name, at}] for tests
var device := false


func setup(feel_data: Dictionary, level: String) -> void:
	feel = feel_data.get("haptics", {})
	gap = float(feel_data.get("limits", {}).get("haptic_gap", 0.07))
	set_level(level)
	device = OS.has_feature("mobile")


func set_level(level: String) -> void:
	strength = float(feel.get("strength", {}).get(level, 1.0))


## Returns true when the pattern was accepted.
func play(name: String) -> bool:
	if strength <= 0.0 or name.is_empty(): return false
	var patterns: Dictionary = feel.get("patterns", {})
	if not patterns.has(name): return false
	var priority: int = int(feel.get("priority", {}).get(name, 0))
	var busy: bool = clock - last_at < gap or not queue.is_empty()
	if busy and priority <= last_priority: return false
	queue.clear()
	var at := clock
	for pulse: Array in patterns[name]:
		var ms: float = float(pulse[0])
		var amp: float = float(pulse[1])
		if amp > 0.0: queue.append({"at": at, "ms": ms, "amp": amp})
		at += ms / 1000.0
	last_at = clock
	last_priority = priority
	history.append({"name": name, "at": clock})
	if history.size() > 200: history.pop_front()
	return true


func process(dt: float) -> void:
	clock += dt
	while not queue.is_empty() and float(queue[0].at) <= clock:
		var pulse: Dictionary = queue.pop_front()
		_buzz(float(pulse.ms), float(pulse.amp))
	if queue.is_empty() and clock - last_at >= gap: last_priority = -1


func _buzz(ms: float, amp: float) -> void:
	if not device: return
	var duration := int(clampf(ms * lerpf(0.8, 1.2, clampf(strength - 0.5, 0.0, 1.0)), 5.0, 120.0))
	Input.vibrate_handheld(duration, clampf(amp * strength, 0.05, 1.0))
