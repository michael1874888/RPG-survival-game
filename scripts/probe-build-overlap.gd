extends SceneTree
## Controlled v0.3 volley probe; stationary, durable targets, not a win-rate test.

const Run := preload("res://scripts/run_model.gd")


func _initialize() -> void:
	print("v0.3 controlled volley probe: no movement, no upgrades after start, aim right")
	for formation: String in ["line", "surround"]:
		for mode: String in ["bloom", "focus"]:
			probe(formation, mode)
	quit()


func probe(formation: String, mode: String) -> void:
	var model = Run.new(30301, "hedgehog", mode)
	model.player = Vector2(1000, 900)
	var positions: Array[Vector2] = []
	if formation == "line":
		for i in 7:
			positions.append(model.player + Vector2(140 + 80 * i, 0))
	else:
		for i in 36:
			positions.append(model.player + Vector2.RIGHT.rotated(i * TAU / 36.0) * 200.0)
	for i in positions.size():
		model.enemies.append({"id": i + 1, "pos": positions[i], "hp": 10000.0,
			"max_hp": 10000.0, "radius": 14.0})
	model.fire()
	for frame in 240:
		model.update_projectiles(1.0 / 120.0)
	var damage: float = 0.0
	var targets: int = 0
	var contacts: int = 0
	for target: Dictionary in model.enemies:
		var dealt: float = float(target["max_hp"]) - float(target["hp"])
		damage += dealt
		if dealt > 0.0:
			targets += 1
	for event: Dictionary in model.events:
		if event["kind"] == "hit":
			contacts += 1
	print("%s / %s: contacts=%d distinct_targets=%d damage=%.3f interval=%.4f" % [formation, mode, contacts, targets, damage, model.shot_interval()])
