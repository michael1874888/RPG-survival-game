extends SceneTree
## Read-only diagnostic for the v0.5 review, not a player game mode.
## Damage probes keep targets alive and in range; the claws-only probe suppresses
## charge solely as a comparison baseline. No-attack routes use no invulnerability.
const Run = preload("res://scripts/run_model.gd")

func make_enemy(id: int, pos: Vector2, hp: float) -> Dictionary:
	return {"id":id,"pos":pos,"hp":hp,"max_hp":hp,"kind":"chaser","radius":17.0,"speed":0.0,"phase":"chase","timer":0.0,"dir":Vector2.ZERO,"flash":0.0}

func _initialize():
	var geometry = Run.new(1, "nana")
	geometry.player = Vector2(500,500)
	var target = make_enemy(1, geometry.player + Vector2.RIGHT.rotated(deg_to_rad(55.0)) * 160.0, 100.0)
	geometry.enemies.assign([target])
	var edge = geometry.player + Vector2.RIGHT.rotated(deg_to_rad(50.0)) * 145.0
	var closest_distance = edge.distance_to(target["pos"])
	geometry.nana.attack(geometry)
	print("GEOMETRY corner nearest_sector_distance=%.4f enemy_radius=17 actual_damage=%.1f" % [closest_distance,100.0-target["hp"]])
	for count in [1,3,6]:
		for suppress_bite in [false,true]:
			var m = Run.new(10,"nana")
			m.player = Vector2(500,500)
			m.spawn_timer = 10000.0
			var initial_hp: float = 0.0
			for i in count:
				m.enemies.append(make_enemy(i+1,m.player+Vector2.RIGHT.rotated((i-float(count-1)/2)*0.1)*100,100000.0))
				initial_hp += 100000.0
			for frame in 3600:
				for i in count:
					m.enemies[i]["pos"] = m.player+Vector2.RIGHT.rotated((i-float(count-1)/2)*0.1)*100
				if suppress_bite: m.nana.bite_charge = 0
				m.tick(1.0/60.0,Vector2.ZERO,Vector2.RIGHT,true)
				m.events.clear()
			var remaining: float = 0.0
			for enemy in m.enemies: remaining += float(enemy["hp"])
			print("DAMAGE targets=%d claws_only=%s damage_60s=%.1f" % [count,suppress_bite,initial_hp-remaining])
	for seed_value in [1,7,11,71,901]:
		var m = Run.new(seed_value,"nana")
		var route: Array[Vector2] = [Vector2(350,350),Vector2(2250,350),Vector2(2250,1550),Vector2(350,1550)]
		var waypoint: int = 0
		for frame in 10860:
			if m.state != "playing": break
			if m.player.distance_to(route[waypoint]) < 10.0: waypoint=(waypoint+1)%route.size()
			m.tick(1.0/60.0,(route[waypoint]-m.player).normalized(),Vector2.RIGHT,false)
			m.events.clear()
		print("NO_ATTACK seed=%d state=%s time=%.2f hp=%.1f kills=%d" % [seed_value,m.state,m.elapsed,m.hp,m.kills])
	quit()
