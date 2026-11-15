extends SceneTree

const Run := preload("res://scripts/run_model.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	_test_shadow()
	_test_charge()
	_test_mark()
	_test_pending_preview()
	_test_target_assistance()
	_test_shadow_rectangle()
	_test_combinations()
	_test_ability_upgrades()
	_test_encounters()
	_test_logging()
	print("BUILD EXPERIMENT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func setup(ids: Array, scenario := "nana_build_e1", options: Dictionary = {}):
	var run = Run.new(1, "nana", "standard", scenario)
	run.experiment.configure(run, ids, options)
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

func _test_pending_preview() -> void:
	var run = setup([])
	var first := enemy(run, "guard", Vector2(100, 0))
	var second := enemy(run, "guard", Vector2(0, 100))
	run.nana.bite_charge = 3
	run.nana.attack(run)
	run.aim = Vector2.DOWN
	var preview: Dictionary = run.nana.bite_target(run, 175.0, deg_to_rad(27.5))
	check(not preview.is_empty() and int(preview.id) == int(first.id), "During windup the displayed bite target must remain the locked target")
	run.nana.advance(run, 0.11)
	check(is_equal_approx(float(first.hp), 976.0) and is_equal_approx(float(second.hp), 1000.0), "The shown locked target receives the bite even if aim moves during windup")

func _test_target_assistance() -> void:
	var run = setup([])
	var chaser := enemy(run, "chaser", Vector2.RIGHT.rotated(deg_to_rad(0.0)) * 120.0)
	var special := enemy(run, "guard", Vector2.RIGHT.rotated(deg_to_rad(4.0)) * 120.0)
	run.nana.update_bite_target(run, 175.0, deg_to_rad(27.5))
	check(int(run.nana.bite_target(run, 175.0, deg_to_rad(27.5)).id) == int(special.id), "A nearby special enemy gets a modest angular preference")
	special.pos = run.player + Vector2.RIGHT.rotated(deg_to_rad(6.5)) * 120.0
	run.nana.update_bite_target(run, 175.0, deg_to_rad(27.5))
	check(int(run.nana.bite_target(run, 175.0, deg_to_rad(27.5)).id) == int(special.id), "Small changes retain the existing target")
	special.pos = run.player + Vector2.RIGHT.rotated(deg_to_rad(18.0)) * 120.0
	run.nana.update_bite_target(run, 175.0, deg_to_rad(27.5))
	check(int(run.nana.bite_target(run, 175.0, deg_to_rad(27.5)).id) == int(chaser.id), "A clear aim preference can override the special enemy")
	chaser.hp = 0.0
	run.nana.update_bite_target(run, 175.0, deg_to_rad(27.5))
	check(int(run.nana.bite_target(run, 175.0, deg_to_rad(27.5)).id) == int(special.id), "Dead targets immediately release assistance")

func _test_shadow_rectangle() -> void:
	var run = setup(["a"])
	var inside := enemy(run, "chaser", Vector2(80, 60))
	var outside := enemy(run, "chaser", Vector2(80, 70))
	var far := enemy(run, "chaser", Vector2(345, 0))
	var beyond := enemy(run, "chaser", Vector2(360, 0))
	run.nana.pending_shadows.append({"remaining": 0.01, "pos": run.player, "dir": Vector2.RIGHT})
	run.nana.advance(run, 0.02)
	check(is_equal_approx(float(inside.hp), 992.0) and is_equal_approx(float(far.hp), 992.0), "The rectangle includes circles touching its side and end")
	check(is_equal_approx(float(outside.hp), 1000.0) and is_equal_approx(float(beyond.hp), 1000.0), "The rectangle excludes circles outside its side and end")
	check(run.experiment.counts.shadow_hits == 2, "Each enemy in the rectangle receives one eight-point hit")

func _test_mark() -> void:
	var run = setup(["c"])
	var target := enemy(run, "guard", Vector2(120, 15))
	for i in 4: attack(run)
	check(run.nana.prey_id == int(target.id) and run.nana.prey_remaining == -1.0, "First bite creates a persistent mark on a living target")
	run.nana.advance(run, 6.0)
	check(run.nana.prey_id == int(target.id) and run.nana.has_prey(), "The new mark survives six seconds without attacking")
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
	var transfer = setup(["c"])
	var old_prey := enemy(transfer, "guard", Vector2(0, 100))
	var new_prey := enemy(transfer, "guard", Vector2(100, 0))
	transfer.nana.prey_id = int(old_prey.id)
	transfer.nana.prey_remaining = -1.0
	transfer.nana.bite_charge = 3
	transfer.nana.attack(transfer)
	transfer.nana.advance(transfer, 0.11)
	check(transfer.nana.prey_id == int(new_prey.id) and transfer.nana.prey_remaining == -1.0, "Biting a different legal target transfers a persistent mark")
	var expiry_run = setup(["c"], "nana_build_e1", {"legacy_c": true})
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
	check(e1.experiment.schedule.size() == 60 and e2.experiment.schedule.size() == 29 and run.experiment.schedule.size() == 34, "Fixed event tables contain the specified counts")
	for i in 45: run.tick(0.05, Vector2.ZERO, Vector2.RIGHT, false)
	check(run.experiment.elite_born, "Elite spawns through a completed warning")
	check(run.enemies.any(func(e): return e.kind == "elite" and e.hp == 320.0 and e.max_hp == 320.0), "E3 gives its single elite a longer health window")
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
	check(cancelled == 27 and retained == 3, "Elite defeat cancels unannounced support but preserves warned events")
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
	check(is_equal_approx(float(marked.hp), 978.0) and bc.nana.bite_charge == 3 and bc.nana.movement_charge == 0.0, "B+C consumes one charge and fills the next bite when the marked target survives")
	bc.nana.attack(bc)
	bc.nana.advance(bc, 0.11)
	check(bc.experiment.counts.cash == 1 and is_equal_approx(float(marked.hp), 932.0), "The next claw cashes out the marked target exactly once")
	var already_ready = setup(["b", "c"])
	var ready_target := enemy(already_ready, "guard", Vector2(100, 0))
	already_ready.nana.prey_id = int(ready_target.id)
	already_ready.nana.prey_remaining = -1.0
	already_ready.nana.bite_charge = 3
	already_ready.nana.movement_charge = 260.0
	already_ready.nana.attack(already_ready)
	check(already_ready.nana.bite_charge == 0 and not already_ready.nana.pending_bite.is_empty(), "A charged claw that already triggers a bite does not refill it")
	var lethal = setup(["b", "c"])
	var lethal_target := enemy(lethal, "guard", Vector2(100, 0), 20.0)
	lethal.nana.prey_id = int(lethal_target.id)
	lethal.nana.prey_remaining = -1.0
	lethal.nana.movement_charge = 260.0
	lethal.nana.attack(lethal)
	check(lethal.nana.prey_id == -1 and lethal.nana.bite_charge == 2, "A killed mark cannot grant an extra full charge")
	var legacy_bc = setup(["b", "c"], "nana_build_e1", {"legacy_c": true})
	var legacy_target := enemy(legacy_bc, "guard", Vector2(100, 0))
	legacy_bc.nana.prey_id = int(legacy_target.id)
	legacy_bc.nana.prey_remaining = 4.0
	legacy_bc.nana.movement_charge = 260.0
	legacy_bc.nana.attack(legacy_bc)
	check(legacy_bc.nana.bite_charge == 2, "The development comparison preserves the old B+C interaction")
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
	check(not path.is_empty() and parsed is Dictionary and parsed.samples.size() > 0 and parsed.schedule.size() == 60, "Completed experiment observations can be read back as JSON")
	check(parsed.abilities == ["a", "c"] and parsed.result == "abandoned", "Observation preserves ability selection and outcome")
	if not path.is_empty():
		DirAccess.remove_absolute(path)

func _test_ability_upgrades() -> void:
	var a = setup(["a"], "nana_build_e1", {"levels": {"a": 2}})
	var front := enemy(a, "guard", Vector2(100, 0))
	var rear := enemy(a, "guard", Vector2(-100, 0))
	var overlap := enemy(a, "guard", Vector2(0, 0))
	a.nana.pending_shadows.append({"remaining": 0.01, "pos": a.player, "dir": Vector2.RIGHT})
	a.nana.advance(a, 0.02)
	check(front.hp == 992.0 and rear.hp == 992.0 and overlap.hp == 992.0, "A level 2 hits front and rear without double-hitting overlap")
	check(a.experiment.counts.shadow_hits == 3, "A level 2 records one hit per enemy, not per direction")
	var b = setup(["b", "c"], "nana_build_e1", {"levels": {"b": 2, "c": 1}})
	var prey := enemy(b, "guard", Vector2(100, 0))
	var support := enemy(b, "guard", Vector2(100, 30))
	b.nana.prey_id = int(prey.id)
	b.nana.prey_remaining = -1.0
	b.nana.movement_charge = 260.0
	b.nana.attack(b)
	check(Vector2(prey.pos).distance_to(b.player) == 100.0 and Vector2(support.pos).distance_to(b.player) > 160.0, "B level 2 pushes other survivors while keeping the marked prey in place")
	check(b.nana.bite_charge == 3, "B level 2 still prepares the C follow-up on a marked hit")
	var c = setup(["c"], "nana_build_e1", {"levels": {"c": 2}})
	var primary := enemy(c, "guard", Vector2(100, 0))
	var nearby := enemy(c, "guard", Vector2(100, 80))
	var distant := enemy(c, "guard", Vector2(320, 0))
	c.nana.prey_id = int(primary.id)
	c.nana.prey_remaining = -1.0
	c.nana.bite_charge = 3
	c.nana.attack(c)
	c.nana.advance(c, 0.11)
	check(primary.hp == 954.0 and nearby.hp == 982.0 and distant.hp == 1000.0, "C level 2 cashout splashes nearby enemies without re-hitting prey or distant targets")
	check(c.experiment.counts.cash == 1 and c.nana.bite_charge == 0, "C splash cannot recursively create a bite or cashout")
