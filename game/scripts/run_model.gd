extends RefCounted
## Deterministic run rules. Rendering, UI and device input live outside this model.

const NanaCombat := preload("res://scripts/nana_combat.gd")
const NanaEncounters := preload("res://scripts/nana_encounters.gd")
const NanaExperiment := preload("res://scripts/nana_experiment.gd")

const DURATION: float = 180.0
const WORLD := Vector2(2600, 1900)
const PLAYER_RADIUS: float = 20.0
const CHARACTERS := {
	"nana": {"name": "奈奈", "style": "連抓與重咬", "hint": "連抓累積重咬，夜影解放突破包圍"},
	"hedgehog": {"name": "小刺蝟", "style": "遠距尖刺", "hint": "保持距離，讓尖刺穿過敵群"},
	"bear": {"name": "小熊", "style": "近距揮擊", "hint": "抓好距離，用熊掌掃開前方敵人"},
}
const UPGRADE_IDS := ["scatter", "pierce", "bounce", "damage", "haste", "speed"]
const BEAR_UPGRADE_IDS := ["wide", "reach", "push", "damage", "haste", "speed"]
const UPGRADE_DATA := {
	"scatter": {"name": "花束散射", "desc": "多 2 根側向尖刺，每根威力略降。\n把狹窄射線變成一片扇形。", "cap": 2},
	"pierce": {"name": "一線穿透", "desc": "每根尖刺多穿過 1 個敵人。\n把追兵引成一線，清出通道。", "cap": 3},
	"bounce": {"name": "跳跳尖刺", "desc": "多 1 次轉向附近敵人的機會。\n穿透用完後才開始反彈。", "cap": 3},
	"damage": {"name": "堅韌尖刺", "desc": "基礎傷害加成 +20%。\n更快擊退眼前的麻煩。", "cap": 0},
	"haste": {"name": "輕快節奏", "desc": "基礎發射頻率加成 +15%。\n讓尖刺接連飛出去。", "cap": 0},
	"speed": {"name": "小腳快跑", "desc": "基礎移速加成 +10%。\n最高 490，繞路和拾取更輕鬆。", "cap": 0},
}
const BEAR_UPGRADE_DATA := {
	"wide": {"name": "展開熊掌", "desc": "揮擊角度 +24°，單次傷害略降。\n更容易掃到兩側的敵人。", "cap": 2},
	"reach": {"name": "伸展熊掌", "desc": "揮擊距離 +18。\n提早接敵，保持一點安全空間。", "cap": 3},
	"push": {"name": "強力推掌", "desc": "擊退距離 +28。\n在包圍中推開一條退路。", "cap": 3},
	"damage": {"name": "厚實熊掌", "desc": "基礎傷害加成 +20%。\n讓每次近身揮擊更有份量。", "cap": 0},
	"haste": {"name": "連拍節奏", "desc": "基礎揮擊頻率加成 +15%。\n縮短下一次出掌的空檔。", "cap": 0},
	"speed": {"name": "小腳快跑", "desc": "基礎移速加成 +10%。\n最高 490，方便進退與拾取。", "cap": 0},
}
const NANA_UPGRADE_DATA := {
	"wide": {"name": "展爪", "desc": "爪擊角度增加 15°。", "cap": 2},
	"reach": {"name": "長爪", "desc": "爪擊距離增加 10%。", "cap": 2},
	"bite": {"name": "狠咬", "desc": "追加咬擊傷害增加 25%。", "cap": 3},
	"damage": {"name": "強健", "desc": "直接攻擊傷害增加 15%。", "cap": 3},
	"haste": {"name": "輕快", "desc": "攻擊頻率增加 10%。", "cap": 3},
	"speed": {"name": "貓步", "desc": "移動速度增加 8%。", "cap": 2},
	"vitality": {"name": "結實", "desc": "最大生命增加 15，並恢復 15。", "cap": 2},
	"heal": {"name": "喘口氣", "desc": "恢復 20 生命。", "cap": 0},
	"sweep": {"name": "掃群・環掃", "desc": "寬爪擊；每第三次出手環掃周圍。", "cap": 1},
	"hunt": {"name": "狩獵・點殺", "desc": "遠距單體爪擊；重咬留下破綻。", "cap": 1},
	"micro_damage": {"name": "持續磨練", "desc": "所有直接攻擊傷害增加 3%。", "cap": 0},
	"micro_bite": {"name": "磨利牙齒", "desc": "咬擊傷害增加 3%。", "cap": 0},
	"micro_health": {"name": "堅韌體魄", "desc": "最大生命增加 5，並恢復 5。", "cap": 0},
}
const COMPARISON_SEED: int = 30301
const RUN_MODES := {
	"standard": {"name": "自由遊玩", "hint": "從基礎攻擊開始，升級三選一", "starter": {}},
	"bloom": {"name": "A 廣域清群", "hint": "散射 1 · 反彈 2 · 傷害 1", "starter": {"scatter": 1, "bounce": 2, "damage": 1}},
	"focus": {"name": "B 集中突破", "hint": "穿透 2 · 攻速 1 · 傷害 1", "starter": {"pierce": 2, "haste": 1, "damage": 1}},
}
const SCENARIOS := {
	"normal": {"name": "原本生存", "duration": DURATION, "hint": "3 分鐘 · 自由升級"},
	"surround": {"name": "四面包圍", "duration": 45.0, "hint": "45 秒 · 固定構築"},
	"queue": {"name": "單向隊列", "duration": 45.0, "hint": "45 秒 · 固定構築"},
	"nana_chasers": {"name": "追逐者", "duration": 180.0, "hint": "清除敵群"},
	"nana_charger": {"name": "衝撞者", "duration": 180.0, "hint": "閃避與反擊"},
	"nana_thrower": {"name": "投擲者", "duration": 180.0, "hint": "接近遠距敵人"},
	"nana_guard": {"name": "守衛者", "duration": 180.0, "hint": "誘招與繞側"},
	"nana_mixed": {"name": "混合敵人", "duration": 180.0, "hint": "選擇攻擊目標"},
	"nana_pressure_standard": {"name": "原本密度", "duration": 90.0, "hint": "固定能力 · 90 秒"},
	"nana_pressure_dense": {"name": "新版怪潮", "duration": 90.0, "hint": "固定能力 · 90 秒"},
	"nana_growth": {"name": "成長挑戰", "duration": 240.0, "hint": "升級 · 專精 · 精英"},
	"nana_build_e1": {"name": "清路", "duration": 60.0, "hint": "追逐者群 · 60 秒"},
	"nana_build_e2": {"name": "混合威脅", "duration": 60.0, "hint": "混合敵人 · 60 秒"},
	"nana_build_e3": {"name": "強敵帶支援", "duration": 60.0, "hint": "精英與追兵 · 60 秒"},
	"nana_build_s1": {"name": "林間開路", "duration": 75.0, "hint": "追逐者 · 75 秒"},
	"nana_build_s2": {"name": "混合威脅", "duration": 75.0, "hint": "投擲者與衝撞者 · 75 秒"},
	"nana_build_s3": {"name": "厚血追兵", "duration": 75.0, "hint": "較耐打的追逐者 · 75 秒"},
	"nana_build_s4": {"name": "精英終戰", "duration": 90.0, "hint": "精英與追兵 · 90 秒"},
	"nana_compare_group": {"name": "追逐者群", "duration": 180.0, "hint": "環掃與包圍"},
	"nana_compare_thrower": {"name": "投擲者混合", "duration": 180.0, "hint": "接近遠距威脅"},
	"nana_compare_guard": {"name": "守衛者", "duration": 180.0, "hint": "收招與反擊"},
	"nana_compare_elite": {"name": "精英守衛", "duration": 180.0, "hint": "雙段攻擊"},
}
const WAVE_INTERVAL: float = 6.0
const WAVE_WARNING: float = 1.0

var rng := RandomNumberGenerator.new()
var upgrade_rng := RandomNumberGenerator.new()
var character_id: String = "hedgehog"
var mode_id: String = "standard"
var scenario_id: String = "normal"
var warning_positions: Array[Vector2] = []
var warning_remaining: float = 0.0
var wave_count: int = 0
var starting_upgrades: Dictionary = {}
var chosen_upgrades: Array[String] = []
var state: String = "playing"
var player := WORLD * 0.5
var aim := Vector2.RIGHT
var hp: float = 100.0
var max_hp: float = 100.0
var elapsed: float = 0.0
var invulnerability: float = 0.0
var shot_timer: float = 0.0
var spawn_timer: float = 0.8
var level: int = 1
var xp: int = 0
var kills: int = 0
var next_enemy_id: int = 1
var upgrades: Dictionary = {}
var offers: Array[String] = []
var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var events: Array[Dictionary] = []
var combat_metrics: Dictionary = {}
var view_size := Vector2(1280, 720)
var nana = NanaCombat.new()
var encounters = NanaEncounters.new()
var experiment = NanaExperiment.new()
var fixed_abilities: bool = false
var drop_xp: bool = true
var enemy_profile: String = "legacy"
var hunt_variant: String = "fast"


func _init(seed_value: int = 0, animal: String = "hedgehog", mode: String = "standard", scenario: String = "normal") -> void:
	reset(seed_value, animal, mode, scenario)


func reset(seed_value: int = 0, animal: String = "hedgehog", mode: String = "standard", scenario: String = "normal") -> void:
	hunt_variant = "fast"
	character_id = animal if CHARACTERS.has(animal) else "hedgehog"
	mode_id = mode if character_id == "hedgehog" and RUN_MODES.has(mode) else "standard"
	scenario_id = scenario if SCENARIOS.has(scenario) and ((character_id == "nana" and (scenario == "normal" or scenario == "nana_growth" or scenario.begins_with("nana_pressure_") or scenario.begins_with("nana_build_") or NanaEncounters.ENCOUNTERS.has(scenario))) or (mode_id != "standard" and scenario in ["normal", "surround", "queue"])) else "normal"
	experiment = NanaExperiment.new()
	fixed_abilities = (character_id == "nana" and scenario_id != "nana_growth") or (character_id != "nana" and scenario_id != "normal")
	drop_xp = not fixed_abilities
	enemy_profile = "practice" if character_id == "nana" else "legacy"
	warning_positions.clear()
	warning_remaining = 0.0
	wave_count = 0
	if seed_value == 0 and mode_id != "standard":
		rng.seed = COMPARISON_SEED
	elif seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	# Upgrade draws must not consume the enemy generation random stream.
	upgrade_rng.seed = rng.seed + 137
	state = "playing"
	player = WORLD * 0.5
	aim = Vector2.RIGHT
	hp = 100.0
	max_hp = 100.0
	elapsed = 0.0
	invulnerability = 0.0
	shot_timer = 0.0
	spawn_timer = 0.8
	level = 1
	xp = 0
	kills = 0
	next_enemy_id = 1
	upgrades.clear()
	for id: String in UPGRADE_IDS:
		upgrades[id] = 0
	for id: String in BEAR_UPGRADE_IDS:
		upgrades[id] = 0
	for id: String in NANA_UPGRADE_DATA:
		upgrades[id] = 0
	starting_upgrades = RUN_MODES[mode_id]["starter"].duplicate()
	chosen_upgrades.clear()
	for id: String in starting_upgrades:
		upgrades[id] = int(starting_upgrades[id])
	offers.clear()
	enemies.clear()
	projectiles.clear()
	pickups.clear()
	events.clear()
	combat_metrics = {"attacks": [], "damage": {}, "damage_taken": {}, "defeats": []}
	nana.reset()
	encounters.reset(self, scenario_id)


func camera_origin() -> Vector2:
	return (player - view_size * 0.5).clamp(Vector2.ZERO, WORLD - view_size)


func required_xp() -> int:
	return 5 + (level - 1) * 3


func move_speed() -> float:
	if character_id == "nana":
		return 260.0 * (1.0 + 0.08 * int(upgrades["speed"]))
	return minf(490.0, 245.0 * (1.0 + 0.10 * int(upgrades["speed"])))


func shot_interval() -> float:
	var base_interval: float = 0.70 if character_id == "bear" else 0.42
	return maxf(0.065, base_interval / (1.0 + 0.15 * int(upgrades["haste"])))


func duration() -> float:
	return float(SCENARIOS[scenario_id]["duration"])


func upgrade_ids() -> Array:
	if character_id == "nana":
		return ["wide", "reach", "bite", "damage", "haste", "speed", "vitality", "heal"]
	return BEAR_UPGRADE_IDS if character_id == "bear" else UPGRADE_IDS


func upgrade_info(id: String) -> Dictionary:
	if character_id == "nana":
		if id == "wide" and int(upgrades.get("hunt", 0)) > 0:
			return {"name": "穩準", "desc": "選敵角度增加 15°，仍只命中一隻。", "cap": 2}
		return NANA_UPGRADE_DATA[id]
	return BEAR_UPGRADE_DATA[id] if character_id == "bear" else UPGRADE_DATA[id]


func melee_reach() -> float:
	return 118.0 + 18.0 * int(upgrades["reach"])


func melee_half_angle() -> float:
	return deg_to_rad(60.0 + 12.0 * int(upgrades["wide"]))


func tick(delta: float, movement: Vector2, direction: Vector2, firing: bool) -> void:
	if state != "playing":
		return
	if experiment.active and experiment.hitstop > 0.0:
		var frozen: float = minf(delta, experiment.hitstop)
		experiment.hitstop -= frozen
		experiment.hitstop_seconds += frozen
		delta -= frozen
		if delta <= 0.000001:
			return
	elapsed += delta
	invulnerability = maxf(0.0, invulnerability - delta)
	var previous_position: Vector2 = player
	player = (player + movement.limit_length() * move_speed() * delta).clamp(
		Vector2.ONE * 30.0, WORLD - Vector2.ONE * 30.0)
	var displacement: float = previous_position.distance_to(player)
	if experiment.active and "b" in experiment.abilities and not firing and movement.length_squared() > 0.0:
		var was_ready: bool = nana.movement_charge >= 260.0
		nana.movement_charge = minf(260.0, nana.movement_charge + displacement)
		if not was_ready and nana.movement_charge >= 260.0:
			experiment.note(self, "charge_ready", {"engaged": experiment.engaged(self)})
			events.append({"kind": "nana_ready", "pos": player})
	if character_id == "nana":
		nana.advance(self, delta)
	if direction.length_squared() > 0.01:
		aim = direction.normalized()
	if experiment.active:
		nana.update_bite_target(self, nana.BITE_REACH * (1.4 if nana.ultimate_remaining > 0.0 else 1.0), nana.BITE_HALF_ANGLE)
	shot_timer -= delta
	if firing and shot_timer <= 0.0:
		if character_id == "nana":
			shot_timer = nana.attack(self)
		else:
			fire()
			shot_timer = shot_interval()
	if experiment.active:
		experiment.update_schedule(self, delta)
	elif scenario_id == "normal":
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			var breathing: bool = fmod(elapsed, 40.0) > 32.0
			spawn_timer = maxf(0.18, 0.85 - elapsed * 0.0035) * (2.5 if breathing else 1.0)
			if enemies.size() < (60 if fixed_abilities else 110):
				spawn_enemy()
	elif scenario_id == "nana_growth" or scenario_id == "nana_pressure_dense":
		encounters.update_growth(self, delta)
	elif scenario_id == "nana_pressure_standard":
		encounters.update_legacy_growth(self, delta)
	elif not NanaEncounters.ENCOUNTERS.has(scenario_id):
		_update_scenario(delta)
	if experiment.active or NanaEncounters.ENCOUNTERS.has(scenario_id) or scenario_id == "nana_growth" or scenario_id.begins_with("nana_pressure_"):
		encounters.update(self, delta)
	else:
		update_enemies(delta)
	update_projectiles(delta)
	collect_pickups(delta)
	if experiment.active:
		experiment.observe(self, delta, movement, firing, displacement)
	if hp <= 0.0:
		state = "lost"
		offers.clear()
	elif experiment.active and experiment.all_finished() and enemies.is_empty():
		state = "won"
	elif NanaEncounters.ENCOUNTERS.has(scenario_id) and enemies.is_empty():
		state = "won"
		offers.clear()
	elif elapsed >= duration():
		elapsed = duration()
		state = "unfinished" if experiment.active else ("lost" if NanaEncounters.ENCOUNTERS.has(scenario_id) or (scenario_id == "nana_growth" and not encounters.elite_defeated) else "won")
		offers.clear()
	if experiment.active and state in ["won", "lost", "unfinished"]:
		nana.pending_shadows.clear()
		nana.pending_bite.clear()
		experiment.hitstop = 0.0


func fire() -> void:
	if character_id == "nana":
		nana.attack(self)
		return
	if character_id == "bear":
		swing()
		return
	var spread: int = int(upgrades["scatter"])
	var count: int = 1 + spread * 2
	var damage: float = 13.0 * (1.0 + 0.20 * int(upgrades["damage"])) / (1.0 + 0.45 * spread)
	for i in count:
		var angle: float = (float(i) - float(count - 1) * 0.5) * 0.19
		var direction: Vector2 = aim.rotated(angle)
		projectiles.append({"pos": player + direction * 25.0, "dir": direction,
			"damage": damage, "pierce": int(upgrades["pierce"]),
			"bounce": int(upgrades["bounce"]), "hit": [], "life": 1.65})
	events.append({"kind": "shot", "pos": player})


func swing() -> void:
	var reach: float = melee_reach()
	var half_angle: float = melee_half_angle()
	var damage: float = 30.0 * (1.0 + 0.20 * int(upgrades["damage"])) / (1.0 + 0.12 * int(upgrades["wide"]))
	var push: float = 75.0 + 28.0 * int(upgrades["push"])
	for enemy: Dictionary in enemies:
		if float(enemy["hp"]) <= 0.0:
			continue
		var offset: Vector2 = Vector2(enemy["pos"]) - player
		var distance: float = offset.length()
		var radius: float = enemy["radius"]
		if distance > reach + radius:
			continue
		# Include the enemy's radius at the cone edge, not only its center point.
		var angle_margin: float = asin(clampf(radius / maxf(distance, 1.0), 0.0, 1.0))
		if distance > radius and aim.dot(offset.normalized()) < cos(half_angle + angle_margin):
			continue
		damage_enemy(enemy, damage)
		if float(enemy["hp"]) > 0.0:
			var push_direction: Vector2 = offset.normalized() if distance > 0.1 else aim
			enemy["pos"] = (Vector2(enemy["pos"]) + push_direction * push).clamp(Vector2.ONE * 20.0, WORLD - Vector2.ONE * 20.0)
			enemy["stagger"] = 0.16
	events.append({"kind": "swipe", "pos": player, "dir": aim, "reach": reach, "half_angle": half_angle})


func damage_enemy(enemy: Dictionary, amount: float, source: String = "other") -> void:
	if float(enemy["hp"]) <= 0.0:
		return
	var previous_hp: float = float(enemy["hp"])
	enemy["hp"] = float(enemy["hp"]) - amount * (1.2 if float(enemy.get("vulnerable", 0.0)) > 0.0 else 1.0)
	if experiment.active:
		experiment.note(self, "damage", {"target": int(enemy.id), "enemy_kind": enemy.kind, "source": source, "amount": minf(previous_hp, previous_hp - float(enemy.hp)), "hp_before": previous_hp, "hp_after": maxf(0.0, float(enemy.hp))})
	if character_id == "nana":
		var damage: Dictionary = combat_metrics["damage"]
		damage[source] = float(damage.get(source, 0.0)) + minf(previous_hp, previous_hp - float(enemy["hp"]))
	enemy["flash"] = 0.10
	events.append({"kind": "hit", "pos": enemy["pos"]})
	if float(enemy["hp"]) <= 0.0:
		if experiment.active and int(enemy.id) == nana.prey_id:
			experiment.note(self, "mark_target_died", {"target": nana.prey_id})
			nana.prey_id = -1
			nana.prey_remaining = 0.0
		kills += 1
		if character_id == "nana":
			combat_metrics["defeats"].append({"kind": enemy["kind"], "time": elapsed, "id": enemy.id, "born_at": enemy.get("born_at", 0.0)})
		if enemy["kind"] == "elite":
			encounters.elite_defeated = true
			hp = minf(max_hp, hp + 20.0)
		if drop_xp:
			var value: int = (8 if enemy["kind"] == "elite" else (2 if enemy["kind"] in ["charger", "thrower", "guard"] else 1)) if scenario_id == "nana_growth" else (2 if enemy["kind"] == "charger" else 1)
			pickups.append({"pos": enemy["pos"], "value": value})
		events.append({"kind": "defeat", "pos": enemy["pos"]})


func spawn_enemy() -> void:
	var visible := Rect2(camera_origin() - Vector2.ONE * 45.0, view_size + Vector2.ONE * 90.0)
	var spawn_pos := Vector2.ZERO
	var found: bool = false
	for attempt in 60:
		spawn_pos = Vector2(rng.randf_range(30, WORLD.x - 30), rng.randf_range(30, WORLD.y - 30))
		if not visible.has_point(spawn_pos) and spawn_pos.distance_to(player) > 380.0:
			found = true
			break
	if not found:
		return
	if enemy_profile == "practice":
		encounters.add_enemy(self, "chaser", spawn_pos)
		return
	var charger: bool = elapsed > 45.0 and rng.randf() < 0.22
	var health: float = (31.0 if charger else 19.0) * (1.0 + elapsed / 240.0)
	_add_enemy(spawn_pos, charger, health, rng.randf_range(62.0, 86.0) + elapsed * 0.18)


func _add_enemy(pos: Vector2, charger: bool, health: float, speed: float) -> void:
	enemies.append({"id": next_enemy_id, "pos": pos, "hp": health, "max_hp": health,
		"kind": "charger" if charger else "chaser", "phase": "chase", "timer": 0.0,
		"dir": Vector2.ZERO, "radius": 22.0 if charger else 17.0,
		"speed": speed, "flash": 0.0, "damage": 16.0 if charger else 10.0})
	next_enemy_id += 1


func _update_scenario(delta: float) -> void:
	if not warning_positions.is_empty():
		warning_remaining = maxf(0.0, warning_remaining - delta)
		if warning_remaining <= 0.0:
			for pos: Vector2 in warning_positions:
				if enemies.size() < 110:
					_add_enemy(pos, false, 19.0, 72.0)
			warning_positions.clear()
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer += WAVE_INTERVAL
		wave_count += 1
		warning_positions = scenario_positions()
		warning_remaining = WAVE_WARNING


func scenario_positions() -> Array[Vector2]:
	# Fixed arena coordinates preserve the schedule independently of player motion.
	# Queue depth is part of the formation, not an equal-travel-time experiment.
	var positions: Array[Vector2] = []
	var center: Vector2 = WORLD * 0.5
	for i in 8:
		var offset: Vector2 = Vector2(260.0 + 36.0 * i, 0.0) if scenario_id == "queue" else Vector2.RIGHT.rotated(i * TAU / 8.0) * 300.0
		positions.append(center + offset)
	return positions


func update_enemies(delta: float) -> void:
	for enemy: Dictionary in enemies:
		if float(enemy["hp"]) <= 0.0:
			continue
		enemy["flash"] = maxf(0.0, float(enemy["flash"]) - delta)
		var offset: Vector2 = player - Vector2(enemy["pos"])
		var velocity: Vector2 = offset.normalized() * float(enemy["speed"])
		if enemy["kind"] == "charger":
			enemy["timer"] = maxf(0.0, float(enemy["timer"]) - delta)
			if enemy["phase"] == "chase" and offset.length() < 390.0:
				enemy["phase"] = "windup"
				enemy["timer"] = 0.9
				enemy["dir"] = offset.normalized()
			if enemy["phase"] == "windup":
				velocity = Vector2.ZERO
				if float(enemy["timer"]) <= 0.0:
					enemy["phase"] = "dash"
					enemy["timer"] = 0.65
			elif enemy["phase"] == "dash":
				velocity = Vector2(enemy["dir"]) * 440.0
				if float(enemy["timer"]) <= 0.0:
					enemy["phase"] = "recover"
					enemy["timer"] = 1.2
			elif enemy["phase"] == "recover":
				velocity *= 0.35
				if float(enemy["timer"]) <= 0.0:
					enemy["phase"] = "chase"
		var stagger: float = float(enemy.get("stagger", 0.0))
		if stagger > 0.0:
			velocity = Vector2.ZERO
			enemy["stagger"] = maxf(0.0, stagger - delta)
		enemy["pos"] = (Vector2(enemy["pos"]) + velocity * delta).clamp(Vector2.ONE * 20.0, WORLD - Vector2.ONE * 20.0)
		if Vector2(enemy["pos"]).distance_to(player) < float(enemy["radius"]) + PLAYER_RADIUS:
			take_damage(float(enemy.get("damage", 10.0)))


func apply_heavy_hit(enemy: Dictionary) -> void:
	if experiment.active or NanaEncounters.ENCOUNTERS.has(scenario_id) or scenario_id == "nana_growth" or scenario_id.begins_with("nana_pressure_"):
		encounters.heavy_hit(enemy)


func take_damage(amount: float, source: String = "unknown") -> void:
	if state != "playing" or invulnerability > 0.0:
		return
	var previous_hp: float = hp
	hp = maxf(0.0, hp - amount)
	if character_id == "nana":
		var taken: Dictionary = combat_metrics["damage_taken"]
		taken[source] = float(taken.get(source, 0.0)) + previous_hp - hp
	invulnerability = 0.8 if character_id == "nana" else 0.9
	events.append({"kind": "hurt", "pos": player})


func update_projectiles(delta: float) -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = projectiles[index]
		projectile["life"] = float(projectile["life"]) - delta
		var old_pos: Vector2 = projectile["pos"]
		var new_pos: Vector2 = old_pos + Vector2(projectile["dir"]) * 760.0 * delta
		projectile["pos"] = new_pos
		var expired: bool = float(projectile["life"]) <= 0.0
		# Resolve intersected enemies in travel order, not array insertion order.
		var contacts: Array[Dictionary] = []
		for enemy: Dictionary in enemies:
			if float(enemy["hp"]) <= 0.0 or int(enemy["id"]) in projectile["hit"]:
				continue
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy["pos"], old_pos, new_pos)
			if closest.distance_to(enemy["pos"]) <= float(enemy["radius"]) + 4.0:
				contacts.append({"enemy": enemy, "distance": old_pos.distance_squared_to(closest)})
		contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["distance"]) < float(b["distance"]))
		for contact: Dictionary in contacts:
			if expired:
				break
			var enemy: Dictionary = contact["enemy"]
			projectile["hit"].append(int(enemy["id"]))
			damage_enemy(enemy, float(projectile["damage"]))
			if int(projectile["pierce"]) > 0:
				projectile["pierce"] = int(projectile["pierce"]) - 1
			elif int(projectile["bounce"]) > 0:
				var target: Dictionary = nearest_target(enemy["pos"], projectile["hit"])
				if target.is_empty():
					expired = true
				else:
					projectile["bounce"] = int(projectile["bounce"]) - 1
					projectile["pos"] = enemy["pos"]
					projectile["dir"] = (Vector2(target["pos"]) - Vector2(enemy["pos"])).normalized()
				break
			else:
				expired = true
		if expired or not Rect2(Vector2.ZERO, WORLD).grow(30.0).has_point(projectile["pos"]):
			projectiles.remove_at(index)
	for index in range(enemies.size() - 1, -1, -1):
		if float(enemies[index]["hp"]) <= 0.0:
			enemies.remove_at(index)


func nearest_target(origin: Vector2, excluded: Array) -> Dictionary:
	var nearest: Dictionary = {}
	var best_distance: float = 340.0 * 340.0
	for enemy: Dictionary in enemies:
		if float(enemy["hp"]) <= 0.0 or int(enemy["id"]) in excluded:
			continue
		var distance: float = origin.distance_squared_to(enemy["pos"])
		if distance < best_distance:
			best_distance = distance
			nearest = enemy
	return nearest


func collect_pickups(delta: float) -> void:
	for index in range(pickups.size() - 1, -1, -1):
		var pickup: Dictionary = pickups[index]
		var distance: float = Vector2(pickup["pos"]).distance_to(player)
		if distance < 100.0:
			pickup["pos"] = Vector2(pickup["pos"]).move_toward(player, 420.0 * delta)
		if Vector2(pickup["pos"]).distance_to(player) < 24.0:
			xp += int(pickup["value"])
			pickups.remove_at(index)
			events.append({"kind": "pickup", "pos": player})
	maybe_level_up()


func maybe_level_up() -> void:
	if not fixed_abilities and state == "playing" and hp > 0.0 and xp >= required_xp():
		xp -= required_xp()
		level += 1
		state = "upgrade"
		make_offers()


func make_offers() -> void:
	if character_id == "nana" and level >= 4 and int(upgrades["sweep"]) == 0 and int(upgrades["hunt"]) == 0:
		offers.assign(["sweep", "hunt", "damage"])
		if int(upgrades["damage"]) >= int(NANA_UPGRADE_DATA["damage"]["cap"]):
			offers[2] = "heal" if hp < max_hp else "micro_damage"
		return
	var pool: Array[String] = []
	for id: String in upgrade_ids():
		if id == "heal" and hp >= max_hp:
			continue
		var cap: int = int(upgrade_info(id)["cap"])
		if cap == 0 or int(upgrades[id]) < cap:
			pool.append(id)
	offers.clear()
	while offers.size() < 3 and not pool.is_empty():
		var index: int = upgrade_rng.randi_range(0, pool.size() - 1)
		offers.append(pool[index])
		pool.remove_at(index)
	if character_id == "nana":
		for fallback: String in ["micro_damage", "micro_bite", "micro_health"]:
			if offers.size() >= 3:
				break
			if fallback not in offers:
				offers.append(fallback)


func choose_upgrade(id: String) -> bool:
	if state != "upgrade" or id not in offers:
		return false
	upgrades[id] = int(upgrades[id]) + 1
	if character_id == "nana" and id == "vitality":
		max_hp += 15.0
		hp += 15.0
	elif character_id == "nana" and id == "heal":
		hp = minf(max_hp, hp + 20.0)
	elif character_id == "nana" and id == "micro_health":
		max_hp += 5.0
		hp += 5.0
	chosen_upgrades.append(id)
	offers.clear()
	state = "playing"
	maybe_level_up()
	return true


func pause() -> void:
	if state == "playing":
		if experiment.active:
			experiment.pause_clock()
		state = "paused"


func resume() -> void:
	if state == "paused":
		if experiment.active:
			experiment.resume_clock()
		state = "playing"
