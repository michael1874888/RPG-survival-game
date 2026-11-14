extends SceneTree
## Controlled v0.9 diagnostic, not a player balance test.
## Stationary targets in the forward cone, perfect aim, reset knockback each step.
## No movement, enemy attacks, spawning, upgrades, ultimate, or XP collection.
const Run = preload("res://scripts/run_model.gd")

func _initialize() -> void:
	for kind: String in ["chaser", "guard", "elite"]:
		var count: int = 8 if kind == "chaser" else 1
		for variant: String in ["sweep", "current", "fast", "heavy"]:
			var model = Run.new(30301, "nana")
			model.player = Vector2(500, 500)
			model.aim = Vector2.RIGHT
			model.upgrades["sweep" if variant == "sweep" else "hunt"] = 1
			model.hunt_variant = variant
			for i in count:
				model.encounters.add_enemy(model, kind, model.player + Vector2(100, 0))
			var timer: float = 0.0
			while model.kills < count and model.elapsed < 30.0:
				model.elapsed += 0.01
				for target: Dictionary in model.enemies:
					target.pos = model.player + Vector2(100, 0)
					target.vulnerable = maxf(0.0, float(target.get("vulnerable", 0.0)) - 0.01)
				model.nana.advance(model, 0.01)
				timer -= 0.01
				if timer <= 0.000001 and model.kills < count:
					timer += model.nana.attack(model)
			print(JSON.stringify({"target": kind, "count": count, "variant": variant, "clear_seconds": snappedf(model.elapsed, 0.01), "kills": model.kills, "attacks": model.combat_metrics.attacks.size()}))
	quit()
