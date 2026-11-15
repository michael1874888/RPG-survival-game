extends SceneTree
const Run := preload("res://scripts/run_model.gd")
const Series := preload("res://scripts/nana_series.gd")
var checks := 0
var failures := 0
var paths: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func finish_fixture(run, state := "won") -> void:
	# Synthetic terminal fixture; full combat completion is checked by the series probe.
	run.state = state
	run.enemies.clear()
	for entry in run.experiment.schedule:
		entry.state = "born"

func record(series, run) -> void:
	series.collect(run)
	if not run.experiment.saved_path.is_empty(): paths.append(run.experiment.saved_path)

func _initialize() -> void:
	var run = Run.new()
	var series = Series.new()
	check(not series.begin(run, "bad"), "Unknown opening abilities cannot start a series")
	check(series.begin(run, "b") and run.experiment.abilities == ["b"] and run.experiment.levels == {"b": 1} and run.scenario_id == "nana_build_e1", "A series starts with exactly one ability in E1")
	check(not series.advance(run, {"kind": "add", "id": "a"}), "A playing stage cannot be skipped")
	run.hp = 52.0
	run.elapsed = 20.0
	run.nana.cooldown = 26.0
	run.nana.ultimate_remaining = 2.0
	run.nana.movement_charge = 200.0
	run.nana.bite_charge = 2
	run.shot_timer = 0.2
	finish_fixture(run)
	record(series, run)
	check(series.between and not series.finished and series.snapshot.hp == 77.0, "A won stage offers a single capped 25 HP recovery")
	check(not series.collect(run) and series.results.size() == 1 and series.snapshot.hp == 77.0, "Repeated screen sync cannot duplicate healing or results")
	var time_before: float = run.elapsed
	run.tick(20.0, Vector2.RIGHT, Vector2.RIGHT, true)
	check(run.elapsed == time_before and run.nana.cooldown == 26.0, "Intermission cannot advance combat or cooldown")
	check(not series.advance(run, {"kind": "replace", "id": "c", "remove": "b"}), "The first choice retains the opening ability")
	check(not series.advance(run, {"kind": "add", "id": "b"}) and not series.advance(run, {"kind": "upgrade", "id": "c"}), "Duplicate adds and upgrading unavailable abilities are rejected")
	check(series.advance(run, {"kind": "add", "id": "a"}), "The first choice adds a second ability")
	check(run.scenario_id == "nana_build_e2" and run.hp == 77.0 and run.nana.cooldown == 26.0 and run.nana.ultimate_remaining == 2.0, "HP, cooldown and remaining ultimate buff carry to E2")
	check(run.nana.movement_charge == 200.0 and run.nana.bite_charge == 2 and is_equal_approx(run.shot_timer, 0.2), "Retained B, shared bite charge and attack timer carry")
	check(run.nana.shadow_count == 0 and run.nana.pending_bite.is_empty() and run.nana.prey_id == -1, "New abilities and target-bound state start clean")
	run.hp = 90.0
	run.elapsed = 18.0
	run.nana.shadow_count = 2
	run.nana.shadow_last_hit = 17.5
	run.nana.movement_charge = 260.0
	finish_fixture(run)
	record(series, run)
	check(series.choices().size() == 4 and series.snapshot.hp == 100.0, "Two abilities permit two upgrades or two replacements and healing is capped")
	check(series.advance(run, {"kind": "replace", "id": "c", "remove": "b"}) and run.nana.movement_charge == 0.0, "Replacing B discards its stored charge")
	check(run.nana.shadow_count == 2 and is_equal_approx(run.nana.shadow_last_hit, -0.5), "Retained A's time window is rebased to the new stage clock")
	check(run.experiment.context.stage == 3 and run.experiment.context.previous_results.size() == 2, "Stage records share series identity and preceding results")
	finish_fixture(run)
	record(series, run)
	check(series.finished and not series.between and series.results.size() == 3 and is_equal_approx(series.total_seconds(), 38.0), "Three wins finish exactly once and sum combat time")
	check(not series.advance(run, {"kind": "add", "id": "a"}), "A completed series cannot enter another stage")
	var data = JSON.parse_string(FileAccess.get_file_as_string(run.experiment.saved_path))
	check(data.context.results.size() == 3 and data.context.series_id == series.series_id, "Final saved JSON contains all stage summaries and common identity")
	check(data.context.decisions.size() == 2 and data.context.decisions[1].kind == "replace" and data.context.decisions[1].offered.size() == 4, "Saved JSON records offered and selected choices")
	for state in ["lost", "unfinished"]:
		series.begin(run, "c")
		finish_fixture(run, state)
		record(series, run)
		check(series.finished and not series.between and not series.advance(run, {"kind": "replace", "id": "c", "remove": "b"}), "Failure and timeout end the series: " + state)
	series.begin(run, "a")
	finish_fixture(run)
	record(series, run)
	check(series.choices().size() == 3 and series.advance(run, {"kind": "upgrade", "id": "a"}), "The first intermission can develop the opening ability")
	check(run.experiment.abilities == ["a"] and run.experiment.levels == {"a": 2}, "Developing keeps one slot and applies level 2")
	finish_fixture(run)
	record(series, run)
	check(series.choices().size() == 2 and not series.advance(run, {"kind": "upgrade", "id": "a"}), "A developed single ability cannot exceed level 2")
	check(series.advance(run, {"kind": "add", "id": "c"}) and run.experiment.levels == {"a": 2, "c": 1}, "A later add preserves the developed ability")
	series.begin(run, "a")
	check(series.results.is_empty() and run.hp == 100.0 and run.nana.cooldown == 0.0 and run.nana.bite_charge == 0, "Restart clears carryover and returns to the first stage")
	for path in paths: DirAccess.remove_absolute(path)
	print("SERIES RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
