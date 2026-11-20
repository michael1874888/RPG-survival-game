extends RefCounted
## Fixed 1/60 s simulation steps driven by an accumulator. Hit-stop and slow motion only change
## how often a step runs, never its length, so rules stay deterministic and snapshots reproducible.

const STEP := 1.0 / 60.0
const MAX_STEPS := 4

var accumulator := 0.0
var hitstop := 0.0
var slow_scale := 1.0
var slow_left := 0.0
var hitstop_cap := 0.15
var min_scale := 0.2
var enabled := true          # false: reduce motion (no hit-stop, no slow motion)
var steps_total := 0


## Real (unscaled) frame time in; returns how many fixed steps to simulate now.
func advance(real_dt: float) -> int:
	real_dt = clampf(real_dt, 0.0, 0.25)
	if hitstop > 0.0:
		var frozen := minf(real_dt, hitstop)
		hitstop -= frozen
		real_dt -= frozen
	var scale := 1.0
	if slow_left > 0.0:
		scale = slow_scale
		slow_left = maxf(0.0, slow_left - real_dt)
	accumulator += real_dt * scale
	var steps := 0
	while accumulator >= STEP and steps < MAX_STEPS:
		accumulator -= STEP
		steps += 1
	if steps == MAX_STEPS: accumulator = minf(accumulator, STEP)
	steps_total += steps
	return steps


func add_hitstop(seconds: float) -> void:
	if not enabled or seconds <= 0.0: return
	hitstop = minf(hitstop_cap, hitstop + seconds)


func slow_motion(scale: float, seconds: float) -> void:
	if not enabled or seconds <= 0.0: return
	var clamped := clampf(scale, min_scale, 1.0)
	if slow_left > 0.0 and clamped > slow_scale:
		slow_left = maxf(slow_left, seconds)
		return
	slow_scale = clamped
	slow_left = maxf(slow_left, seconds)


## 0..1 interpolation between the last and next simulation step, for smooth drawing.
func alpha() -> float:
	return clampf(accumulator / STEP, 0.0, 1.0)


func current_scale() -> float:
	if hitstop > 0.0: return 0.0
	return slow_scale if slow_left > 0.0 else 1.0


func reset() -> void:
	accumulator = 0.0
	hitstop = 0.0
	slow_left = 0.0
	slow_scale = 1.0
