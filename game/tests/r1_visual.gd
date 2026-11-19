extends SceneTree
## Manual desktop visual inspection using isolated test-only saves.


func _initialize() -> void:
	call_deferred("launch")


func launch() -> void:
	var test_base := "user://r1-visual-test"
	var scene = load("res://r1_main.tscn").instantiate()
	scene.profile = load("res://scripts/r1_profile.gd").new(test_base + ".save", test_base + ".old")
	scene.treasure = load("res://scripts/treasure_collection.gd").new(test_base + ".old")
	root.add_child(scene)
