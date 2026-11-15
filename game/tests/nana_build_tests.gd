extends SceneTree

const Run := preload("res://scripts/run_model.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	_test_shadow()
	_test_charge()
	_test_mark()
	_test_combinations()
	_test_encounters()
	_test_logging()
	print("BUILD EXPERIMENT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func setup(ids: Array, scenario := "nana_build_e1"):
	var run = Run.new(1, "nana", "standard", scenario)
	run.experiment.configure(run, ids)
	return run

func enemy(run, kind: String, offset: Vector2, hp := 1000.0) -> Dictionary:
	run.encounters.add_enemy(run, kind, run.player + offset)
	var item: Dictionary = run.enemies[-1]
	item.hp = hp
	item.max_hp = hp
	item.speed = 0.0
	return item

func attack(run) -> void:
	run.nana.attack(run)
	run.nana.advance(run, 0.11)
	run.elapsed += 0.42

func _test_shadow() -> void:
	var run = setup(["a"])
	var front := enemy(run, "guard", Vector2(100, 0))
	var back := enemy(run, "guard", Vector2(300, 0))
	attack(run)
	attack(run)
	run.nana.bite_charge = 3
	attack(run)
	check(run.experiment.counts.shadow == 1 and run.nana.shadow_count == 0, "A counts the claw that also triggers a bite")
	run.nana.advance(run, 0.02)
	check(is_equal_approx(float(front.hp), 948.0) and is_equal_approx(float(back.hp), 992.0), "A damages the narrow front and back after its delay")
	check(run.nana.bite_charge == 0 and run.experiment.counts.shadow_hits == 2, "Shadow does not recharge the bite or recursively trigger")
	run.elapsed += 2.0
	attack(run)
	check(run.nana.shadow_count == 1, "A restarts counting after an expired streak")

func _test_charge() -> void:
	var run = setup(["b"])
	run.nana.movement_charge = 260.0
	run.nana.attack(run)
	check(run.nana.movement_charge == 260.0, "B retains its charge on a miss")
	var target := enemy(run, "chaser", Vector2(100, 0), 18.0)
	run.nana.attack(run)
	check(float(target.hp) <= 0.0 and run.nana.movement_charge == 0.0, "B deals enough damage to defeat a chaser and consumes only on hit")
	check(is_equal_approx(run.experiment.hitstop, 0.05), "B requests hitstop")
	var before: float = run.elapsed
	run.tick(0.03, Vector2.RIGHT, Vector2.RIGHT, true)
	check(is_equal_approx(run.elapsed, before) and is_equal_approx(run.experiment.hitstop, 0.02), "Hitstop freezes gameplay time")
	run.pause()
	run.tick(1.0, Vector2.RIGHT, Vector2.RIGHT, true)
	check(is_equal_approx(run.experiment.hitstop, 0.02), "Pause freezes hitstop countdown")
	run.resume()
	run.tick(0.03, Vector2.ZERO, Vector2.RIGHT, false)
	check(run.elapsed > before and run.elapsed < before + 0.02, "Remaining delta advances after hitstop")

func _test_mark() -> void:
	var run = setup(["c"])
	var target := enemy(run, "guard", Vector2(120, 15))
	for i in 4: attack(run)
	check(run.nana.prey_id == int(target.id) and is_equal_approx(run.nana.prey_remaining, 4.0), "First bite creates a mark on a living target")
	var closer := enemy(run, "guard", Vector2(110, 0))
	check(int(run.nana.bite_target(run, 175.0, deg_to_rad(27.5)).id) == int(target.id), "Marked target takes priority only inside the bite cone")
	for i in 3: attack(run)
	check(run.experiment.counts.cash == 1 and run.nana.prey_id == -1, "Second bite cashes and clears the mark")
	check(is_equal_approx(float(target.hp), 880.0), "C's seven claws plus two bites deal 120 damage")
	for i in 3: attack(run)
	check(run.nana.prey_id == -1 and run.nana.bite_charge == 3, "After cashout a new mark requires four ordinary attacks")
	attack(run)
	check(run.nana.prey_id == int(closer.id), "The next bite returns to the ordinary target rule")
	run.nana.prey_remaining = 0.05
	run.nana.advance(run, 0.06)
	check(run.nana.prey_id == -1, "An expired mark is removed")
	var kill_run = setup(["c"])
	var victim := enemy(kill_run, "guard", Vector2(100, 0), 10.0)
	kill_run.nana.prey_id = int(victim.id)
	kill_run.nana.prey_remaining = 4.0
	kill_run.nana.attack(kill_run)
	check(kill_run.nana.bite_charge == 2 and kill_run.nana.prey_id == -1, "A lethal marked claw retains its bonus charge and clears the dead mark")
	var miss_run = setup(["c"])
	var escaped := enemy(miss_run, "guard", Vector2(100, 0))
	miss_run.nana.prey_id = int(escaped.id)
	miss_run.nana.prey_remaining = 3.0
	miss_run.nana.bite_charge = 3
	miss_run.nana.attack(miss_run)
	escaped.pos = miss_run.player + Vector2(1000, 0)
	miss_run.nana.advance(miss_run, 0.11)
	check(miss_run.experiment.counts.cash == 0 and miss_run.nana.prey_id == int(escaped.id), "A missed bite cannot cash out or transfer the mark")
	var expiry_run = setup(["c"])
	var expiry_target := enemy(expiry_run, "guard", Vector2(100, 0))
	expiry_run.nana.prey_id = int(expiry_target.id)
	expiry_run.nana.prey_remaining = 0.05
	expiry_run.nana.bite_charge = 3
	expiry_run.nana.attack(expiry_run)
	expiry_run.nana.advance(expiry_run, 0.11)
	check(expiry_run.experiment.counts.cash == 0 and is_equal_approx(float(expiry_target.hp), 976.0), "A mark expiring during windup uses ordinary bite damage")

func _test_encounters() -> void:
	var e1 = setup([], "nana_build_e1")
	var e2 = setup([], "nana_build_e2")
	var run = setup([], "nana_build_e3")
	check(e1.experiment.schedule.size() == 40 and e2.experiment.schedule.size() == 20 and run.experiment.schedule.size() == 25, "Fixed event tables contain the specified counts")
	for i in 45: run.tick(0.05, Vector2.ZERO, Vector2.RIGHT, false)
	check(run.experiment.elite_born, "Elite spawns through a completed warning")
	var warned := 0
	for event in run.experiment.schedule:
		if event.conditional and event.warned_once:
			warned += 1
	check(warned == 3, "First E3 support warning begins at two seconds")
	for item in run.enemies:
		if item.kind == "elite":
			run.damage_enemy(item, 10000.0, "test")
	run.tick(0.05, Vector2.ZERO, Vector2.RIGHT, false)
	var cancelled := 0
	var retained := 0
	for event in run.experiment.schedule:
		if event.conditional and event.state == "cancelled": cancelled += 1
		if event.conditional and event.warned_once and event.state != "cancelled": retained += 1
	check(cancelled == 18 and retained == 3, "Elite defeat cancels unannounced support but preserves warned events")
	var timed = setup([], "nana_build_e1")
	timed.elapsed = 59.99
	timed.tick(0.02, Vector2.ZERO, Vector2.RIGHT, false)
	check(timed.state == "unfinished", "Unborn events cannot produce a successful result")
	var retry = setup([], "nana_build_e1")
	retry.tick(0.01, Vector2.ZERO, Vector2.RIGHT, false)
	var first: Dictionary = retry.experiment.schedule[0]
	var first_pos: Vector2 = first.pos
	retry.player = first_pos
	retry.tick(1.01, Vector2.ZERO, Vector2.RIGHT, false)
	check(first.state == "retry", "An unsafe completed warning remains a pending retry")
	retry.tick(0.01, Vector2.ZERO, Vector2.RIGHT, false)
	check(first.state == "warning" and Vector2(first.pos) != first_pos and is_equal_approx(float(first.timer), 1.0), "A safe alternate anchor receives a complete new warning")


func _test_combinations() -> void:
	var ab = setup(["a", "b"])
	var target := enemy(ab, "guard", Vector2(100, 0))
	ab.nana.shadow_count = 2
	ab.nana.shadow_last_hit = 0.0
	ab.nana.movement_charge = 260.0
	ab.nana.attack(ab)
	ab.nana.advance(ab, 0.13)
	check(is_equal_approx(float(target.hp), 970.0) and ab.experiment.counts.shadow == 1 and ab.experiment.counts.charged == 1, "A+B applies a 22-point claw and an independent 8-point shadow")
	var bc = setup(["b", "c"])
	var marked := enemy(bc, "guard", Vector2(100, 0))
	bc.nana.prey_id = int(marked.id)
	bc.nana.prey_remaining = 4.0
	bc.nana.movement_charge = 260.0
	bc.nana.attack(bc)
	check(is_equal_approx(float(marked.hp), 978.0) and bc.nana.bite_charge == 2 and bc.nana.movement_charge == 0.0, "B+C consumes one charge and gives one additional bite charge on the marked target")
	var ultimate_b = setup(["b"])
	var distant := enemy(ultimate_b, "guard", Vector2(250, 0))
	ultimate_b.nana.ultimate_remaining = 6.0
	ultimate_b.nana.movement_charge = 260.0
	ultimate_b.nana.attack(ultimate_b)
	check(is_equal_approx(float(distant.hp), 967.0), "Ultimate multiplies B's full 22 damage and expands its reach")
	var ultimate_c = setup(["c"])
	var prey := enemy(ultimate_c, "guard", Vector2(100, 0))
	ultimate_c.nana.ultimate_remaining = 6.0
	ultimate_c.nana.prey_id = int(prey.id)
	ultimate_c.nana.prey_remaining = 4.0
	ultimate_c.nana.bite_charge = 3
	ultimate_c.nana.attack(ultimate_c)
	ultimate_c.nana.advance(ultimate_c, 0.11)
	check(is_equal_approx(float(prey.hp), 931.0) and ultimate_c.experiment.counts.cash == 1, "Ultimate multiplies C's cashout once")

func _test_logging() -> void:
	var run = setup(["a", "c"])
	run.tick(0.1, Vector2.RIGHT, Vector2.RIGHT, false)
	var path: String = run.experiment.save(run, "abandoned")
	var contents := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(contents)
	check(not path.is_empty() and parsed is Dictionary and parsed.samples.size() > 0 and parsed.schedule.size() == 40, "Completed experiment observations can be read back as JSON")
	check(parsed.abilities == ["a", "c"] and parsed.result == "abandoned", "Observation preserves ability selection and outcome")
	if not path.is_empty():
		DirAccess.remove_absolute(path)
