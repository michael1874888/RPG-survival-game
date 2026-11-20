extends SceneTree
## X1 enemies and spawning: warned attacks keep their windups, fairness limits, safe spawns,
## obstacle movement, the net (收網) and boss phases.

const H := preload("res://tests/x1_helpers.gd")
const Data := preload("res://scripts/x1/core/data.gd")

var checks := 0
var failures := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func _initialize() -> void:
	windup_tests()
	fairness_tests()
	spawn_tests()
	obstacle_tests()
	net_tests()
	boss_tests()
	print("X1 ENEMY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


## Measures how long an enemy stays in its first warned phase.
func _first_windup(kind: String, night: int, distance: float) -> Dictionary:
	var b = H.battle("roam", {}, "courtyard", Vector2(1200, 800), "hunt", night)
	b.claw_timer = 9999.0
	var e: Dictionary = H.enemy(b, kind, b.player.pos + Vector2(distance, 0), 99999.0)
	var windup_phase := ""
	var frames := 0
	var struck := false
	for i in 900:
		b.claw_timer = 9999.0
		b.player.invuln = 0.0
		b.player.hp = 100.0
		b.step(1.0 / 60.0, {})
		for ev: Dictionary in b.take_events():
			if ev.kind == "enemy_strike" or ev.kind == "hazard": struck = true
		if windup_phase.is_empty() and not e.tele.is_empty(): windup_phase = str(e.phase)
		if not windup_phase.is_empty():
			if str(e.phase) == windup_phase: frames += 1
			else: break
	return {"seconds": frames / 60.0, "phase": windup_phase, "struck": struck or b.shots.size() > 0 or float(b.metrics.damage_taken) > 0.0 or b.enemies.size() > 1}


func windup_tests() -> void:
	var data = Data.shared()
	var cases := {"E03": ["windup", 0.85, 200.0], "E04": ["windup", 0.9, 300.0], "E05": ["windup", 0.9, 150.0],
		"E06": ["windup", 1.1, 300.0], "E07": ["windup", 1.2, 320.0], "EL01": ["windup1", 0.9, 160.0], "EL02": ["windup", 0.8, 240.0]}
	for kind: String in cases:
		var expected: Array = cases[kind]
		var result := _first_windup(kind, 0, float(expected[2]))
		check(result.phase == expected[0], "%s warns with phase %s (got %s)" % [kind, expected[0], result.phase])
		check(absf(float(result.seconds) - float(expected[1])) <= 0.05, "%s warning lasts %.2f s (got %.2f)" % [kind, expected[1], result.seconds])
		var deep := _first_windup(kind, 8, float(expected[2]))
		check(absf(float(deep.seconds) - float(expected[1])) <= 0.05, "%s warning is not shortened at night 8" % kind)
	check(_first_windup("E05", 0, 150.0).struck, "guard swing resolves after its warning")
	var lantern = H.battle()
	var guard: Dictionary = H.enemy(lantern, "E05", lantern.player.pos + Vector2(500, 0), 999.0)
	H.enemy(lantern, "E08", lantern.player.pos + Vector2(560, 0), 999.0)
	lantern.claw_timer = 9999.0
	H.run_for(lantern, 1.5)
	check(int(guard.get("shield_by", -1)) >= 0, "lantern links to a nearby ally")
	var before: float = guard.hp
	lantern.damage_enemy(guard, 10.0, "claw", 0)
	check(absf(before - float(guard.hp) - 8.0) < 0.01, "linked ally takes 20% less damage")


func fairness_tests() -> void:
	var b = H.battle()
	b.claw_timer = 9999.0
	for i in 5: H.enemy(b, "E05", b.player.pos + Vector2(140, 0).rotated(TAU * i / 5.0), 999.0)
	var most := 0
	for i in 240:
		b.claw_timer = 9999.0
		b.player.invuln = 0.0
		b.player.hp = 100.0
		b.step(1.0 / 60.0, {})
		b.take_events()
		var busy := 0
		for e: Dictionary in b.enemies:
			if e.get("busy", false): busy += 1
		most = maxi(most, busy)
	check(most <= 2 and most >= 1, "at most 2 special attacks at once (saw %d)" % most)
	var hidden = H.battle()
	hidden.claw_timer = 9999.0
	var far: Dictionary = hidden.spawn_enemy("E04", hidden.player.pos + Vector2(900, 0), {})
	for i in 120:
		hidden.step(1.0 / 60.0, {})
		hidden.take_events()
		if not hidden.visible(far.pos):
			check(far.tele.is_empty(), "no ranged windup from off screen")
			break


func spawn_tests() -> void:
	var b = H.battle()
	b.spawning = true
	var min_distance := INF
	var most := 0
	var warned := 0
	for i in 60 * 70:
		b.player.invuln = 1.0
		var move := Vector2.RIGHT.rotated(b.elapsed * 0.5)
		b.step(1.0 / 60.0, {"move": move})
		for ev: Dictionary in b.take_events():
			if ev.kind == "spawn": min_distance = minf(min_distance, Vector2(ev.pos).distance_to(b.player.pos))
			if ev.kind == "warn": warned += 1
		most = maxi(most, b.enemies.size())
	check(min_distance >= 240.0, "every spawn appears at least 240 from Nana (closest %.0f)" % min_distance)
	check(most <= 125, "enemy count stays near the 120 cap (max %d)" % most)
	check(warned >= 3, "prey and specials get a warning first")
	var rate = H.battle()
	rate.spawning = true
	var early := 0
	var late := 0
	for i in 60 * 50:
		rate.player.invuln = 1.0
		rate.claw_timer = 9999.0
		rate.step(1.0 / 60.0, {})
		for ev: Dictionary in rate.take_events():
			if ev.kind == "spawn" and ev.get("role", "") == "fodder":
				if rate.elapsed < 15.0: early += 1
				elif rate.elapsed >= 30.0 and rate.elapsed < 45.0: late += 1
	check(late > early, "fodder streams faster later in the fight (%d → %d)" % [early, late])
	var hounds = H.battle()
	hounds.spawning = true
	var first_hound := -1.0
	for i in 60 * 60:
		hounds.player.invuln = 1.0
		hounds.step(1.0 / 60.0, {})
		hounds.take_events()
		for e: Dictionary in hounds.enemies:
			if e.kind == "E02" and not e.get("target", false) and first_hound < 0.0: first_hound = hounds.elapsed
	check(first_hound >= 44.0, "hounds join only after 45 s (first at %.1f)" % first_hound)


func obstacle_tests() -> void:
	var b = H.battle("roam", {}, "greenhouse", Vector2(1200, 600))
	b.claw_timer = 9999.0
	var spots := [Vector2(680, 1300), Vector2(1720, 1300), Vector2(1200, 1100), Vector2(300, 950), Vector2(2100, 950), Vector2(680, 200)]
	var chasers: Array = []
	for spot: Vector2 in spots:
		for k in 3: chasers.append(H.enemy(b, "E01", spot + Vector2(k * 30, 0), 9999.0))
	for i in 60 * 25:
		b.player.invuln = 1.0
		b.claw_timer = 9999.0
		b.step(1.0 / 60.0, {})
		b.take_events()
	var arrived := 0
	for e: Dictionary in chasers:
		if e.pos.distance_to(b.player.pos) < 160.0: arrived += 1
		check(not b.obstacles.blocked(e.pos, float(e.radius) - 1.0), "chaser is never inside a flower bed")
	check(arrived >= int(chasers.size() * 0.9), "chasers find their way around beds (%d/%d)" % [arrived, chasers.size()])


func net_tests() -> void:
	var b = H.battle()
	var t1: Dictionary = H.enemy(b, "E03", b.player.pos + Vector2(140, 0), 5.0, {"prey": true, "target": true})
	var fodder: Dictionary = H.enemy(b, "E01", b.player.pos + Vector2(-300, 0), 999.0)
	b.spawner.targets_total = 1
	H.run_for(b, 0.5)
	check(float(t1.hp) <= 0.0 and b.state == "net", "killing the last target starts the net")
	check(fodder.fleeing, "remaining enemies flee during the net")
	H.run_for(b, 2.2)
	check(b.state == "won" and b.pickups.is_empty(), "net finishes as a win and collects the drops")
	var practice = H.battle("roam", {}, "courtyard", Vector2(1200, 800), "practice")
	practice.elapsed = 179.9
	H.run_for(practice, 2.5)
	check(practice.state == "won", "practice ends after its duration")


func boss_tests() -> void:
	var data = Data.shared()
	for region: String in ["courtyard", "greenhouse", "belltower"]:
		var b = H.battle("roam", {}, region, Data.vec(data.regions[region].start), "boss")
		b.spawning = true
		var boss: Dictionary = {}
		var strikes := 0
		for i in 60 * 30:
			b.player.invuln = 0.0
			b.player.hp = 100.0
			b.claw_timer = 9999.0
			b.step(1.0 / 60.0, {"move": Vector2.RIGHT.rotated(b.elapsed * 0.8)})
			for ev: Dictionary in b.take_events():
				if ev.kind == "telegraph" and ev.role == "boss": strikes += 1
			if boss.is_empty(): boss = b.boss()
		check(not boss.is_empty(), "%s boss appears" % region)
		check(strikes >= 4, "%s boss uses its attacks (%d strikes)" % [region, strikes])
		boss.hp = float(boss.max_hp) * 0.25
		var phases := 0
		for i in 60 * 25:
			b.player.invuln = 1.0
			b.claw_timer = 9999.0
			b.step(1.0 / 60.0, {})
			for ev: Dictionary in b.take_events():
				if ev.kind == "boss_phase": phases += 1
		check(phases >= 1 and int(boss.phase_level) == 2, "%s boss reaches its last phase" % region)
		check(b.support_count(int(boss.id)) <= 2, "%s boss support stays within 2" % region)
		b.damage_enemy(boss, 999999.0, "claw", 0)
		check(b.state == "net", "%s boss death ends the fight at once" % region)
		H.run_for(b, 1.2)
		check(b.state == "won", "%s boss win completes" % region)
	var deep = H.battle("roam", {}, "courtyard", Vector2(1200, 800), "boss", 7)
	var tree: Dictionary = deep.spawn_enemy("B01", deep.player.pos + Vector2(0, -300), {"target": true})
	tree.hp = float(tree.max_hp) * 0.44
	deep.step(1.0 / 60.0, {})
	check(int(tree.phase_level) == 2, "night 7 moves the boss's last phase to 45%")
