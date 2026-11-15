extends SceneTree
## Fixed stationary target and exact attacks; not a survival or player-feel test.
const Run := preload("res://scripts/run_model.gd")

func _initialize() -> void:
	for settings in [
		{"name": "old", "timed_mark": true, "charged_mark_bonus": false},
		{"name": "persistent_only", "timed_mark": false, "charged_mark_bonus": false},
		{"name": "charged_bonus_only", "timed_mark": true, "charged_mark_bonus": true},
		{"name": "both", "timed_mark": false, "charged_mark_bonus": true}]:
		for delay in [0.5, 6.0]: probe(settings, delay)
	quit()

func probe(settings: Dictionary, delay: float) -> void:
	var run = Run.new(99, "nana", "standard", "nana_build_e3")
	run.experiment.configure(run, ["b", "c"], settings)
	run.encounters.add_enemy(run, "guard", run.player + Vector2(100, 0))
	var target: Dictionary = run.enemies[0]
	target.hp = 1000.0
	target.max_hp = 1000.0
	for i in 4:
		run.nana.attack(run)
		run.nana.advance(run, 0.11)
		run.elapsed += 0.42
	run.nana.advance(run, delay)
	run.elapsed += delay
	var has_mark: bool = run.nana.has_prey()
	run.nana.movement_charge = 260.0 # Controlled fixture: B's movement requirement is tested separately.
	run.nana.attack(run)
	var charge_after: int = run.nana.bite_charge
	run.nana.advance(run, 0.11)
	run.nana.attack(run)
	run.nana.advance(run, 0.11)
	print("%s wait=%.1fs mark=%s charged_claw_bite_charge=%d cash_after_next=%d target_hp=%.1f" % [settings.name, delay, has_mark, charge_after, run.experiment.counts.cash, target.hp])
