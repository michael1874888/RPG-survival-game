extends SceneTree
## Time controller: fixed 1/60 s steps, hit-stop and slow motion only change how often steps run,
## so a battle stepped through hit-stops matches one stepped plainly, byte for byte.

const TimeController := preload("res://scripts/x1/present/time_controller.gd")
const Run := preload("res://scripts/x1/core/run.gd")
const Data := preload("res://scripts/x1/core/data.gd")

var checks := 0
var failures := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func _initialize() -> void:
	var time = TimeController.new()
	var total := 0
	for i in 60: total += time.advance(1.0 / 60.0)
	check(total == 60, "one second of frames is 60 steps (got %d)" % total)
	time.reset()
	time.add_hitstop(0.05)
	total = 0
	for i in 60: total += time.advance(1.0 / 60.0)
	check(total >= 56 and total <= 57, "a 50 ms hit-stop skips about 3 steps (got %d)" % total)
	time.reset()
	time.slow_motion(0.3, 0.5)
	total = 0
	for i in 30: total += time.advance(1.0 / 60.0)
	check(total >= 8 and total <= 10, "half a second at 30%% speed is about 9 steps (got %d)" % total)
	total = 0
	for i in 60: total += time.advance(1.0 / 60.0)
	check(total >= 59 and total <= 61, "speed returns to normal afterwards (got %d)" % total)
	time.reset()
	time.add_hitstop(1.0)
	check(time.hitstop <= time.hitstop_cap, "hit-stop is capped")
	time.reset()
	time.enabled = false
	time.add_hitstop(0.05)
	time.slow_motion(0.3, 1.0)
	check(time.hitstop == 0.0 and time.slow_left == 0.0, "reduce motion ignores hit-stop and slow motion")
	time.enabled = true
	time.reset()
	check(time.advance(0.5) == TimeController.MAX_STEPS, "a long hitch never runs more than 4 steps in one frame")
	# Determinism: hit-stops and slow motion do not change the simulation, only its pacing.
	var a = Run.new()
	var b = Run.new()
	for r in [a, b]:
		r.begin({"seed": 4242, "region": "greenhouse", "habit": "roam"})
		r.enter(r.available_nodes()[0])
	var paced = TimeController.new()
	var steps_a := 0
	var frame := 0
	while steps_a < 900:
		frame += 1
		if frame % 37 == 0: paced.add_hitstop(0.07)
		if frame % 211 == 0: paced.slow_motion(0.3, 0.4)
		var n: int = paced.advance(1.0 / 60.0)
		for i in n:
			if steps_a >= 900: break
			_step(a, steps_a)
			steps_a += 1
	for i in 900: _step(b, i)
	var da: Dictionary = a.to_dict()
	var db: Dictionary = b.to_dict()
	da.erase("run_id")
	db.erase("run_id")
	check(var_to_bytes(da) == var_to_bytes(db), "900 steps through hit-stops and slow motion equal 900 plain steps")
	print("X1 TIME: %d checks, %d failures" % [checks, failures])
	Data.release()
	quit(1 if failures > 0 else 0)


func _step(r, index: int) -> void:
	if r.phase != "battle": return
	if r.needs_level_choice():
		r.choose_card(r.build.offers[0])
		return
	r.battle.player.invuln = 1.0
	var input := {"move": Vector2.RIGHT.rotated(index * 0.013), "pounce": Vector2.UP.rotated(index * 0.1) if index % 90 == 45 else Vector2.ZERO}
	r.tick(1.0 / 60.0, input)
	if r.battle != null: r.battle.take_events()
