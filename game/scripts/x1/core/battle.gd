extends RefCounted
## One X1 fight: auto claw, pounce, night shadow, enemies, spawning and card effects.
## Pure rules: no rendering or device input. step() advances a fixed simulation tick.

const Data := preload("res://scripts/x1/core/data.gd")
const Geometry := preload("res://scripts/combat_geometry.gd")
const Stats := preload("res://scripts/x1/core/stats.gd")
const Effects := preload("res://scripts/x1/core/effects.gd")
const Obstacles := preload("res://scripts/x1/core/obstacles.gd")
const Grid := preload("res://scripts/x1/core/spatial_grid.gd")
const Spawner := preload("res://scripts/x1/core/spawner.gd")
const AI := {
	"chaser": preload("res://scripts/x1/ai/chaser.gd"),
	"charger": preload("res://scripts/x1/ai/charger.gd"),
	"thrower": preload("res://scripts/x1/ai/thrower.gd"),
	"guard": preload("res://scripts/x1/ai/guard.gd"),
	"trapper": preload("res://scripts/x1/ai/trapper.gd"),
	"caller": preload("res://scripts/x1/ai/caller.gd"),
	"lantern": preload("res://scripts/x1/ai/lantern.gd"),
	"warden": preload("res://scripts/x1/ai/warden.gd"),
	"stalker": preload("res://scripts/x1/ai/stalker.gd"),
	"boss_tree": preload("res://scripts/x1/ai/boss_tree.gd"),
	"boss_vine": preload("res://scripts/x1/ai/boss_vine.gd"),
	"boss_crow": preload("res://scripts/x1/ai/boss_crow.gd"),
}

var data
var t: Dictionary = {}
var region_id := "courtyard"
var region: Dictionary = {}
var kind := "hunt"
var layer := 1
var night := 0
var mods: Dictionary = {}
var next_mods: Dictionary = {}
var assist := false
var spawning := true   # tests turn this off for controlled scenarios
var owner = null
var rng_spawn: RandomNumberGenerator
var rng_combat: RandomNumberGenerator
var stats = Stats.new()
var effects = Effects.new()
var obstacles = Obstacles.new()
var grid = Grid.new()
var spawner = Spawner.new()
var world := Vector2(2400, 1600)
var view_size := Vector2(1280, 720)
var max_depth := 2
var base_max_hp := 100.0

var state := "playing"   # playing, net, won, lost
var elapsed := 0.0
var net_timer := 0.0
var next_id := 1
var player: Dictionary = {}
var claw_timer := 0.0
var pounce: Dictionary = {}
var ult: Dictionary = {}
var enemies: Array = []
var by_id: Dictionary = {}
var busy_total := 0
var shots: Array = []
var hazards: Array = []
var balls: Array = []
var lines: Array = []
var pickups: Array = []
var marked_id := -1
var metrics: Dictionary = {}
var events: Array = []


## ctx: region, kind, layer, night, assist, hp, max_hp_base, entries, next_mods, view_size
## fresh = false is used when restoring a snapshot: nothing may consume random numbers.
func setup(ctx: Dictionary, rngs, owner_ref = null, fresh := true) -> void:
	data = Data.shared()
	t = data.tuning
	owner = owner_ref
	region_id = str(ctx.get("region", "courtyard"))
	region = data.regions[region_id]
	kind = str(ctx.get("kind", "hunt"))
	layer = int(ctx.get("layer", 1))
	night = int(ctx.get("night", 0))
	mods = data.night_mods(night)
	next_mods = ctx.get("next_mods", {}).duplicate(true)
	assist = bool(ctx.get("assist", false))
	view_size = ctx.get("view_size", Vector2(1280, 720))
	rng_spawn = rngs.get_rng("spawn")
	rng_combat = rngs.get_rng("combat")
	max_depth = int(t.effects.max_depth)
	world = Data.vec(region.get("world", [2400, 1600]))
	obstacles.setup(region, world, float(t.world.edge))
	base_max_hp = float(ctx.get("max_hp_base", t.player.hp))
	state = "playing"
	elapsed = 0.0
	net_timer = 0.0
	next_id = 1
	enemies.clear()
	by_id.clear()
	shots.clear()
	hazards.clear()
	balls.clear()
	lines.clear()
	pickups.clear()
	events.clear()
	marked_id = -1
	busy_total = 0
	metrics = {"kills": 0, "claw_kills": 0, "pounce_kills": 0, "shadow_kills": 0, "prey_kills": 0, "elites": 0, "bosses": 0,
		"bites": 0, "marks": 0, "pounces": 0, "escape_pounces": 0, "ult_uses": 0, "roam_charges": 0, "xp": 0,
		"damage_taken": 0.0, "hits_taken": 0, "taken_by": {}, "last_hurt": "", "damage_dealt": 0.0}
	refresh_build(ctx.get("entries", []))
	var start: Vector2 = Data.vec(region.get("start", [world.x * 0.5, world.y * 0.5]))
	player = {"pos": obstacles.resolve(start, float(t.player.radius)), "hp": 0.0, "max_hp": 0.0, "invuln": 0.0,
		"facing": Vector2.RIGHT, "move_dir": Vector2.RIGHT, "roam": 0.0, "block_used": false,
		"pending": 0.0, "pending_source": "", "pending_from": Vector2.INF, "slow": 0.0}
	player.max_hp = base_max_hp + stats.value("max_hp")
	player.hp = clampf(float(ctx.get("hp", player.max_hp)), 1.0, player.max_hp)
	claw_timer = 0.0
	pounce = {"charges": max_charges(), "recharge": 0.0, "dash": {}}
	var start_meter: float = stats.value("start_meter") + (float(t.ult.meter_max) if next_mods.get("full_meter", 0) else 0.0)
	ult = {"meter": minf(float(t.ult.meter_max), start_meter), "active": 0.0}
	effects.reset_battle()
	spawner.setup(self, int(next_mods.get("extra_target", 0)))
	if fresh: effects.fire(self, "battle_start", {"source": "start", "depth": 0, "pos": player.pos})


## entries: effect bundles from habit, items and cards. Keeps current health ratio sensible.
func refresh_build(entries: Array) -> void:
	stats.rebuild(entries)
	effects.rebuild(entries)
	if not player.is_empty():
		var old_max: float = player.max_hp
		player.max_hp = base_max_hp + stats.value("max_hp")
		if player.max_hp > old_max: player.hp += player.max_hp - old_max
		player.hp = minf(player.hp, player.max_hp)


# ---- derived values ------------------------------------------------------------------

func player_radius() -> float:
	return float(t.player.radius)


func move_speed() -> float:
	var bonus: float = stats.value("move_speed_pct") + float(next_mods.get("speed_pct", 0))
	var speed: float = float(t.player.speed) * (1.0 + minf(float(t.player.speed_cap_pct), bonus) / 100.0)
	return speed * (1.0 - float(player.get("slow", 0.0)) / 100.0)


func max_charges() -> int:
	return int(t.pounce.charges) + int(stats.value("pounce_charges"))


func recharge_time() -> float:
	var base: float = float(t.pounce.recharge) + float(mods.get("pounce_recharge_add", 0.0))
	return maxf(0.4, base * (1.0 - minf(70.0, stats.value("pounce_recharge_pct")) / 100.0))


func roam_step() -> float:
	var step: float = float(stats.base.get("roam_step_set", t.roam.step))
	return maxf(60.0, step * (1.0 - minf(80.0, stats.value("roam_step_pct")) / 100.0))


func claw_interval() -> float:
	return maxf(float(t.claw.min_interval), float(t.claw.interval) / (1.0 + stats.value("claw_rate_pct") / 100.0))


func claw_reach() -> float:
	return float(t.claw.reach) * (1.0 + stats.value("claw_reach_pct") / 100.0) * (float(t.ult.reach_mult) if ult_active() else 1.0)


func claw_half_angle() -> float:
	return deg_to_rad(minf(340.0, float(t.claw.angle) + stats.value("claw_angle")) * 0.5)


func bite_radius() -> float:
	return float(t.pounce.bite_radius) + stats.value("bite_radius")


func ult_active() -> bool:
	return float(ult.get("active", 0.0)) > 0.0


func ult_ready() -> bool:
	return float(ult.meter) >= float(t.ult.meter_max) and not ult_active()


func is_prey(e: Dictionary) -> bool:
	return bool(e.get("prey", false)) or e.get("role", "") in ["elite", "boss"]


func dashing() -> bool:
	return not pounce.dash.is_empty()


func camera_rect() -> Rect2:
	var origin: Vector2 = (player.pos - view_size * 0.5).clamp(Vector2.ZERO, (world - view_size).max(Vector2.ZERO))
	return Rect2(origin, view_size)


func event(kind_name: String, info: Dictionary = {}) -> void:
	var entry := info.duplicate()
	entry["kind"] = kind_name
	events.append(entry)
	if events.size() > 600: events = events.slice(events.size() - 400)


func take_events() -> Array:
	var result := events
	events = []
	return result


# ---- main tick ---------------------------------------------------------------------------

## input: {"move": Vector2, "pounce": Vector2 (zero when none), "ult": bool}
func step(dt: float, input: Dictionary = {}) -> void:
	if state == "won" or state == "lost": return
	if owner != null and owner.wants_choice(): return
	elapsed += dt
	stats.tick(dt)
	_rebuild_index()
	_update_player(dt, input)
	_update_pounce(dt, input)
	if state == "playing" or state == "net":
		_update_claw(dt)
		_update_ult(dt, input)
		effects.tick(self, dt)
	_update_lines(dt)
	_update_balls(dt)
	if state == "playing" and spawning: spawner.update(self, dt)
	_update_enemies(dt)
	_update_shots(dt)
	_update_hazards(dt)
	_update_status(dt)
	_resolve_player_damage()
	_remove_dead()
	_rebuild_index()
	_update_pickups(dt)
	_update_end(dt)


func _rebuild_index() -> void:
	grid.rebuild(enemies)
	by_id.clear()
	busy_total = 0
	for e: Dictionary in enemies:
		if float(e.hp) <= 0.0: continue
		by_id[int(e.id)] = e
		if e.get("busy", false): busy_total += int(e.get("busy_cost", 1))


func _update_player(dt: float, input: Dictionary) -> void:
	player.invuln = maxf(0.0, float(player.invuln) - dt)
	player.slow = 0.0
	for hazard: Dictionary in hazards:
		if float(hazard.windup) <= 0.0 and player.pos.distance_to(hazard.pos) <= float(hazard.radius) + player_radius():
			player.slow = maxf(float(player.slow), float(hazard.slow))
	if dashing(): return
	var move: Vector2 = input.get("move", Vector2.ZERO)
	move = move.limit_length(1.0)
	if move.length_squared() < 0.0001: return
	var before: Vector2 = player.pos
	player.pos = obstacles.resolve(player.pos + move * move_speed() * dt, player_radius())
	player.move_dir = move.normalized()
	var moved: float = before.distance_to(player.pos)
	if moved <= 0.0: return
	_roam(moved)
	effects.moved(self, moved)


func _roam(moved: float) -> void:
	var step_length := roam_step()
	var cap: int = max_charges() + int(stats.value("roam_overcap"))
	player.roam = float(player.roam) + moved
	if float(player.roam) < step_length: return
	if int(pounce.charges) < cap:
		player.roam = float(player.roam) - step_length
		pounce.charges = int(pounce.charges) + 1
		metrics.roam_charges += 1
		event("roam_charge", {"pos": player.pos})
		effects.fire(self, "roam_charge", {"source": "roam", "depth": 0, "pos": player.pos})
	else:
		player.roam = step_length


func _update_pounce(dt: float, input: Dictionary) -> void:
	if dashing():
		_advance_dash(dt)
		return
	if int(pounce.charges) < max_charges():
		pounce.recharge = float(pounce.recharge) + dt * (float(t.ult.recharge_mult) if ult_active() else 1.0)
		if float(pounce.recharge) >= recharge_time():
			pounce.recharge = 0.0
			pounce.charges = int(pounce.charges) + 1
	else:
		pounce.recharge = 0.0
	var request: Vector2 = input.get("pounce", Vector2.ZERO)
	if request.length_squared() > 0.0001 and int(pounce.charges) >= 1 and state in ["playing", "net"]:
		start_pounce(request.normalized())


func start_pounce(dir: Vector2) -> void:
	pounce.charges = int(pounce.charges) - 1
	var distance: float = float(t.pounce.distance) * (1.0 + stats.value("pounce_distance_pct") / 100.0)
	var crowd := 0
	for index in grid.query(player.pos, float(t.pounce.escape_radius)):
		var e: Dictionary = enemies[index]
		if float(e.hp) > 0.0 and e.pos.distance_to(player.pos) <= float(t.pounce.escape_radius) + float(e.radius): crowd += 1
	var escape: bool = crowd >= int(t.pounce.escape_count)
	pounce.dash = {"from": player.pos, "dir": dir, "dist": distance, "travel": 0.0, "hit": {}, "escape": escape}
	player.facing = dir
	metrics.pounces += 1
	if escape: metrics.escape_pounces += 1
	event("pounce", {"pos": player.pos, "dir": dir, "dist": distance})
	effects.fire(self, "pounce_start", {"source": "pounce", "depth": 0, "pos": player.pos, "dir": dir, "length": distance})


func _advance_dash(dt: float) -> void:
	var dash: Dictionary = pounce.dash
	var speed: float = float(dash.dist) / float(t.pounce.duration)
	var step_length: float = minf(speed * dt, float(dash.dist) - float(dash.travel))
	var from: Vector2 = player.pos
	var wanted: Vector2 = from + Vector2(dash.dir) * step_length
	var resolved: Vector2 = obstacles.resolve(wanted, player_radius())
	var blocked: bool = resolved.distance_to(wanted) > 1.0
	player.pos = resolved
	dash.travel = float(dash.travel) + step_length
	_pounce_hits(from, player.pos, dash)
	if blocked or float(dash.travel) >= float(dash.dist) - 0.01:
		_land(dash)


func _pounce_hits(from: Vector2, to: Vector2, dash: Dictionary) -> void:
	var width: float = float(t.pounce.width) + stats.value("pounce_width")
	var middle := (from + to) * 0.5
	var knock: float = stats.value("pounce_knock")
	for index in grid.query(middle, from.distance_to(to) * 0.5 + width + 50.0):
		var e: Dictionary = enemies[index]
		if float(e.hp) <= 0.0 or dash.hit.has(int(e.id)): continue
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(e.pos, from, to)
		if closest.distance_to(e.pos) > width * 0.5 + float(e.radius): continue
		dash.hit[int(e.id)] = true
		damage_enemy(e, float(t.pounce.path_damage) + stats.value("pounce_path_damage"), "pounce", 0)
		if knock > 0.0 and float(e.hp) > 0.0:
			var side: Vector2 = e.pos - closest
			if side.length_squared() < 0.01: side = Vector2(dash.dir).orthogonal()
			knockback(e, side.normalized(), knock)
		event("pounce_hit", {"pos": e.pos, "index": dash.hit.size(), "dir": dash.dir})
		effects.fire(self, "pounce_hit", {"source": "pounce", "depth": 0, "target": e, "pos": e.pos})


func _land(dash: Dictionary) -> void:
	pounce.dash = {}
	player.invuln = maxf(float(player.invuln), float(t.pounce.after_invuln) + stats.value("pounce_after_invuln"))
	var kills_before: int = metrics.kills
	var target := bite_target(player.pos, bite_radius(), [])
	if not target.is_empty():
		var bitten: Array = [int(target.id)]
		bite(target, true)
		for i in int(stats.value("bite_extra_targets")):
			var other := bite_target(player.pos, bite_radius(), bitten)
			if other.is_empty(): break
			bitten.append(int(other.id))
			bite(other, false)
	event("land", {"pos": player.pos, "dir": dash.dir, "escape": dash.get("escape", false), "hits": dash.hit.size()})
	effects.fire(self, "pounce_land", {"source": "pounce", "depth": 0, "pos": player.pos, "dir": dash.dir, "kills": metrics.kills - kills_before})


func bite_target(origin: Vector2, radius: float, excluded: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_score := INF
	for index in grid.query(origin, radius + 60.0):
		var e: Dictionary = enemies[index]
		if float(e.hp) <= 0.0 or int(e.id) in excluded: continue
		var distance: float = origin.distance_to(e.pos) - float(e.radius)
		if distance > radius: continue
		var score: float = distance - (70.0 if is_prey(e) else 0.0) - (40.0 if e.get("marked", false) else 0.0)
		if score < best_score or (score == best_score and int(e.id) < int(best.get("id", 0))):
			best_score = score
			best = e
	return best


func bite(e: Dictionary, primary: bool) -> void:
	var was_prey := is_prey(e)
	metrics.bites += 1
	damage_enemy(e, float(t.pounce.bite_damage), "bite", 0)
	event("bite", {"pos": e.pos, "prey": was_prey, "id": int(e.id), "role": e.role, "kill": float(e.hp) <= 0.0})
	effects.fire(self, "bite_hit", {"source": "bite", "depth": 0, "target": e, "pos": e.pos})
	# Only marked prey refunds, on a cooldown, so elites and bosses cannot be pounce-chained.
	if primary and bool(e.get("prey", false)) and elapsed - float(pounce.get("last_refund", -99.0)) >= float(t.pounce.prey_refund_icd):
		pounce.last_refund = elapsed
		refund_pounce(int(t.pounce.prey_refund))


func refund_pounce(amount: int) -> void:
	var cap: int = max_charges() + int(stats.value("roam_overcap"))
	pounce.charges = mini(cap, int(pounce.charges) + amount)
	event("refund", {"pos": player.pos})


func _update_claw(dt: float) -> void:
	claw_timer -= dt
	if claw_timer > 0.0 or dashing(): return
	var reach := claw_reach()
	var target := _claw_target(maxf(float(t.claw.seek), reach + 30.0))
	if target.is_empty():
		claw_timer = 0.0
		return
	claw_timer = claw_interval()
	var dir: Vector2 = (target.pos - player.pos).normalized() if target.pos.distance_to(player.pos) > 0.01 else player.facing
	player.facing = dir
	swing(dir, 100.0, 0, "claw")


func _claw_target(seek: float) -> Dictionary:
	var best: Dictionary = {}
	var best_score := INF
	for index in grid.query(player.pos, seek + 40.0):
		var e: Dictionary = enemies[index]
		if float(e.hp) <= 0.0: continue
		var distance: float = player.pos.distance_to(e.pos) - float(e.radius)
		if distance > seek: continue
		var score: float = distance - (60.0 if is_prey(e) else 0.0) - (40.0 if e.get("marked", false) else 0.0)
		if score < best_score or (score == best_score and int(e.id) < int(best.get("id", 0))):
			best_score = score
			best = e
	return best


## One claw arc. Extra claws from cards come in with depth > 0.
func swing(dir: Vector2, damage_pct: float, depth: int, source: String) -> int:
	var reach := claw_reach()
	var half := claw_half_angle()
	var hits: Array = []
	for index in grid.query(player.pos, reach + 50.0):
		var e: Dictionary = enemies[index]
		if float(e.hp) <= 0.0: continue
		if Geometry.sector_circle(player.pos, dir, e.pos, float(e.radius), reach, half): hits.append(e)
	event("swipe", {"pos": player.pos, "dir": dir, "reach": reach, "half": half, "depth": depth, "hits": hits.size()})
	effects.fire(self, "claw_swing", {"source": source, "depth": depth, "pos": player.pos, "dir": dir, "hits": hits.size()})
	var base: float = (float(t.claw.damage) + stats.value("claw_damage_flat")) * damage_pct / 100.0
	for e: Dictionary in hits:
		damage_enemy(e, base, source, depth)
		effects.fire(self, "claw_hit", {"source": source, "depth": depth, "target": e, "pos": e.pos})
	return hits.size()


func extra_claw(mode: String, damage_pct: float, depth: int) -> void:
	var dir: Vector2 = -player.facing
	if mode == "next":
		var best: Dictionary = {}
		var best_distance := INF
		for index in grid.query(player.pos, claw_reach() + 60.0):
			var e: Dictionary = enemies[index]
			if float(e.hp) <= 0.0: continue
			var offset: Vector2 = e.pos - player.pos
			if offset.length_squared() < 1.0 or absf(player.facing.angle_to(offset)) < deg_to_rad(50.0): continue
			if offset.length() < best_distance:
				best_distance = offset.length()
				best = e
		if not best.is_empty(): dir = (best.pos - player.pos).normalized()
	swing(dir, damage_pct, depth, "claw")


func claw_burst(radius: float, damage_pct: float, depth: int) -> void:
	var amount: float = (float(t.claw.damage) + stats.value("claw_damage_flat")) * damage_pct / 100.0
	event("burst", {"pos": player.pos, "radius": radius})
	for index in grid.query(player.pos, radius + 40.0):
		var e: Dictionary = enemies[index]
		if float(e.hp) > 0.0 and player.pos.distance_to(e.pos) <= radius + float(e.radius):
			damage_enemy(e, amount, "burst", depth)


func _update_ult(dt: float, input: Dictionary) -> void:
	if ult_active():
		ult.active = maxf(0.0, float(ult.active) - dt)
		if float(ult.active) <= 0.0: event("ult_end", {"pos": player.pos})
	if input.get("ult", false): activate_ult()


func activate_ult() -> bool:
	if not ult_ready() or state != "playing": return false
	ult.meter = 0.0
	ult.active = float(t.ult.duration) + stats.value("ult_duration")
	player.invuln = maxf(float(player.invuln), float(t.ult.protect))
	pounce.charges = maxi(int(pounce.charges), max_charges())
	metrics.ult_uses += 1
	event("ult", {"pos": player.pos, "radius": float(t.ult.radius)})
	shockwave(player.pos, float(t.ult.radius), float(t.ult.damage), float(t.ult.knockback), "ult", 0)
	effects.fire(self, "ult_start", {"source": "ult", "depth": 0, "pos": player.pos})
	return true


func add_meter(amount: float) -> void:
	if ult_active(): return
	var was_ready := ult_ready()
	ult.meter = minf(float(t.ult.meter_max), float(ult.meter) + amount)
	if not was_ready and ult_ready(): event("ult_ready", {"pos": player.pos})


# ---- damage to enemies ---------------------------------------------------------------------

func damage_multiplier(source: String, e: Dictionary) -> float:
	var pct: float = stats.value("all_damage_pct")
	match source:
		"claw", "burst": pct += stats.value("claw_damage_pct")
		"bite", "cash", "execute": pct += stats.value("bite_damage_pct")
		"shadow": pct += stats.value("shadow_damage_pct")
	var mult: float = 1.0 + pct / 100.0
	if is_prey(e): mult *= 1.0 + stats.value("prey_damage_pct") / 100.0
	if e.get("marked", false): mult *= 1.0 + stats.value("marked_damage_pct") / 100.0
	if ult_active() and source in ["claw", "bite", "pounce", "burst", "cash"]: mult *= float(t.ult.damage_mult)
	var shield: int = int(e.get("shield_by", -1))
	if shield >= 0 and by_id.has(shield):
		var lantern: Dictionary = by_id[shield]
		var spec: Dictionary = data.enemies[lantern.kind]
		if lantern.pos.distance_to(e.pos) <= float(spec.get("link_range", 200)):
			mult *= 1.0 - float(spec.get("reduction", 20)) / 100.0
	return maxf(0.0, mult)


## Returns true when this hit killed the enemy.
func damage_enemy(e: Dictionary, amount: float, source: String, depth: int) -> bool:
	if float(e.hp) <= 0.0 or amount <= 0.0: return false
	var dealt: float = amount * damage_multiplier(source, e)
	var hp_before: float = float(e.hp)
	e.hp = hp_before - dealt
	e.flash = 0.1
	metrics.damage_dealt = float(metrics.damage_dealt) + dealt
	if source != "bleed":
		var away: Vector2 = e.pos - player.pos
		event("hit", {"pos": e.pos, "amount": dealt, "shown": minf(dealt, hp_before), "source": source, "id": int(e.id), "role": e.role, "prey": is_prey(e),
			"kill": float(e.hp) <= 0.0, "dir": away.normalized() if away.length_squared() > 0.01 else Vector2.RIGHT, "radius": e.radius})
	if source != "bleed" and depth < max_depth:
		effects.fire(self, "hit", {"source": source, "depth": depth, "target": e, "pos": e.pos})
	if float(e.hp) <= 0.0:
		_kill(e, source, depth)
		return true
	return false


func _kill(e: Dictionary, source: String, depth: int) -> void:
	e.hp = 0.0
	e.busy = false
	e.tele = {}
	metrics.kills += 1
	if source in ["claw", "burst"]: metrics.claw_kills += 1
	elif source in ["pounce", "bite", "cash", "execute"]: metrics.pounce_kills += 1
	elif source == "shadow": metrics.shadow_kills += 1
	var drop_key: String = "prey" if e.get("prey", false) else ("summon" if e.get("summoned", false) else str(e.role))
	if not e.get("no_xp", false):
		var value: int = int(t.xp.drop.get(drop_key, 1))
		if value > 0: pickups.append({"pos": e.pos, "value": value})
	var fish := 0
	if e.get("prey", false): fish = int(t.fish.prey)
	elif e.role == "elite": fish = int(t.fish.elite)
	if fish > 0 and owner != null: owner.gain_fish(fish)
	add_meter(float(t.ult.gain.get(drop_key, 0)) * (1.0 + stats.value("ult_gain_pct") / 100.0))
	event("defeat", {"pos": e.pos, "role": e.role, "color": data.enemies[e.kind].get("color", "ffffff"), "radius": e.radius,
		"source": source, "id": int(e.id), "enemy": e.kind, "prey": bool(e.get("prey", false)), "target": bool(e.get("target", false)),
		"summoned": bool(e.get("summoned", false))})
	if is_prey(e):
		if e.get("prey", false) or e.role == "elite": metrics.prey_kills += 1
		if e.role == "elite": metrics.elites += 1
		if e.role == "boss": metrics.bosses += 1
		effects.fire(self, "prey_kill", {"source": source, "depth": depth, "target": e, "pos": e.pos})
	if e.get("marked", false):
		e.marked = false
		marked_id = -1
		var transfer: float = stats.value("mark_transfer")
		if transfer > 0.0:
			var next := nearest_enemy(e.pos, transfer, [int(e.id)])
			if not next.is_empty():
				next.marked = true
				marked_id = int(next.id)
				event("mark", {"pos": next.pos})
	effects.fire(self, "kill", {"source": source, "depth": depth, "target": e, "pos": e.pos})
	spawner.on_kill(self, e)


func nearest_enemy(origin: Vector2, radius: float, excluded: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	for index in grid.query(origin, radius + 40.0):
		var e: Dictionary = enemies[index]
		if float(e.hp) <= 0.0 or int(e.id) in excluded: continue
		var distance: float = origin.distance_to(e.pos)
		if distance <= radius and (distance < best_distance or (distance == best_distance and int(e.id) < int(best.get("id", 0)))):
			best_distance = distance
			best = e
	return best


func shockwave(origin: Vector2, radius: float, amount: float, knock: float, source: String, depth: int) -> int:
	var kills := 0
	event("wave", {"pos": origin, "radius": radius, "source": source})
	for index in grid.query(origin, radius + 40.0):
		var e: Dictionary = enemies[index]
		if float(e.hp) <= 0.0 or origin.distance_to(e.pos) > radius + float(e.radius): continue
		if damage_enemy(e, amount, source, depth): kills += 1
		elif knock > 0.0:
			var away: Vector2 = e.pos - origin
			knockback(e, away.normalized() if away.length_squared() > 0.01 else Vector2.RIGHT, knock)
	return kills


func knockback(e: Dictionary, dir: Vector2, distance: float) -> void:
	var mult := 1.0
	if e.role == "elite": mult = float(t.knockback.elite_mult)
	elif e.role == "boss": mult = float(t.knockback.boss_mult)
	e.knock = dir * distance * mult
	e.knock_t = float(t.knockback.time)


func apply_bleed(e: Dictionary, dps: float, duration: float) -> void:
	if float(e.hp) <= 0.0: return
	e.bleed = maxf(float(e.get("bleed", 0.0)), dps)
	e.bleed_t = maxf(float(e.get("bleed_t", 0.0)), duration)


func apply_slow(e: Dictionary, pct: float, duration: float) -> void:
	if float(e.hp) <= 0.0: return
	var cap: float = float(t.slow.boss_cap) if e.role == "boss" else float(t.slow.cap)
	e.slow = minf(cap, maxf(float(e.get("slow", 0.0)) if float(e.get("slow_t", 0.0)) > 0.0 else 0.0, pct))
	e.slow_t = maxf(float(e.get("slow_t", 0.0)), duration)


func slow_area(origin: Vector2, radius: float, pct: float, duration: float) -> void:
	event("slow", {"pos": origin, "radius": radius})
	for index in grid.query(origin, radius + 40.0):
		var e: Dictionary = enemies[index]
		if float(e.hp) > 0.0 and origin.distance_to(e.pos) <= radius + float(e.radius): apply_slow(e, pct, duration)


func heal(amount: float) -> void:
	if amount <= 0.0 or float(player.hp) <= 0.0: return
	player.hp = minf(float(player.max_hp), float(player.hp) + amount)
	event("heal", {"pos": player.pos, "amount": amount})


func mark_or_cash(e: Dictionary, depth: int) -> void:
	if float(e.hp) <= 0.0: return
	if e.get("marked", false):
		event("cash", {"pos": e.pos})
		if stats.value("mark_keep") <= 0.0:
			e.marked = false
			marked_id = -1
		damage_enemy(e, float(t.mark.cash_damage), "cash", depth)
		return
	if marked_id >= 0 and by_id.has(marked_id): by_id[marked_id].marked = false
	e.marked = true
	marked_id = int(e.id)
	metrics.marks += 1
	event("mark", {"pos": e.pos})


func execute(e: Dictionary, threshold_pct: float, boss_mult: float, depth: int) -> void:
	if float(e.hp) <= 0.0: return
	if e.role == "boss":
		damage_enemy(e, float(t.pounce.bite_damage) * maxf(0.0, boss_mult - 1.0), "execute", depth)
		return
	if float(e.hp) / maxf(1.0, float(e.max_hp)) <= threshold_pct / 100.0:
		event("execute", {"pos": e.pos})
		damage_enemy(e, float(e.hp) / maxf(0.01, damage_multiplier("execute", e)) + 1.0, "execute", depth)


# ---- player projectiles ----------------------------------------------------------------------

func spawn_ball(from: Vector2, amount: float, bounces: int, speed: float, search: float, depth: int, skip_id: int, params: Dictionary) -> void:
	if balls.size() >= int(t.effects.max_balls): return
	var target := nearest_enemy(from, search, [skip_id])
	if target.is_empty(): return
	balls.append({"pos": from, "vel": (target.pos - from).normalized() * speed, "damage": amount, "bounces": bounces,
		"speed": speed, "range": search, "last": skip_id, "life": 2.5, "depth": depth,
		"line_length": float(params.get("line_length", 0)), "line_width": float(params.get("line_width", 0)),
		"line_damage": float(params.get("line_damage", 0))})


func add_line(origin: Vector2, dir: Vector2, length: float, width: float, amount: float, delay: float, source: String, depth: int) -> void:
	if lines.size() >= int(t.effects.max_lines): return
	if source == "shadow": width *= 1.0 + stats.value("shadow_width_pct") / 100.0
	lines.append({"origin": origin, "dir": dir, "length": length, "width": width, "damage": amount, "delay": delay,
		"source": source, "depth": depth, "echo": stats.value("shadow_echo") if source == "shadow" else 0.0})
	event("line_warn", {"origin": origin, "dir": dir, "length": length, "width": width, "delay": delay, "source": source})


func _update_lines(dt: float) -> void:
	for i in range(lines.size() - 1, -1, -1):
		var line: Dictionary = lines[i]
		line.delay = float(line.delay) - dt
		if float(line.delay) > 0.0: continue
		lines.remove_at(i)
		var origin: Vector2 = line.origin
		var dir: Vector2 = line.dir
		var length: float = line.length
		event("line", {"origin": origin, "dir": dir, "length": length, "width": line.width, "source": line.source})
		for index in grid.query(origin + dir * length * 0.5, length * 0.5 + float(line.width) + 40.0):
			var e: Dictionary = enemies[index]
			if float(e.hp) <= 0.0: continue
			if Geometry.rectangle_circle(origin, dir, e.pos, float(e.radius), length, float(line.width)):
				damage_enemy(e, float(line.damage), str(line.source), int(line.depth))
		if float(line.echo) > 0.0:
			lines.append({"origin": origin, "dir": dir, "length": length, "width": line.width,
				"damage": float(line.damage) * float(line.echo) / 100.0, "delay": float(t.effects.echo_delay),
				"source": line.source, "depth": line.depth, "echo": 0.0})


func _update_balls(dt: float) -> void:
	for i in range(balls.size() - 1, -1, -1):
		var ball: Dictionary = balls[i]
		ball.life = float(ball.life) - dt
		ball.pos = Vector2(ball.pos) + Vector2(ball.vel) * dt
		if float(ball.life) <= 0.0 or obstacles.blocked(ball.pos, 6.0):
			balls.remove_at(i)
			continue
		var hit: Dictionary = {}
		for index in grid.query(ball.pos, 50.0):
			var e: Dictionary = enemies[index]
			if float(e.hp) > 0.0 and int(e.id) != int(ball.last) and Vector2(ball.pos).distance_to(e.pos) <= float(e.radius) + 9.0:
				hit = e
				break
		if hit.is_empty(): continue
		var hit_pos: Vector2 = hit.pos
		damage_enemy(hit, float(ball.damage), "ball", int(ball.depth))
		if float(ball.line_length) > 0.0:
			add_line(hit_pos, Vector2(ball.vel).normalized(), float(ball.line_length), float(ball.line_width), float(ball.line_damage), 0.1, "shadow", int(ball.depth))
		ball.bounces = int(ball.bounces) - 1
		ball.last = int(hit.id)
		var next := nearest_enemy(hit_pos, float(ball.range), [int(hit.id)])
		if int(ball.bounces) < 0 or next.is_empty():
			balls.remove_at(i)
			continue
		ball.vel = (next.pos - hit_pos).normalized() * float(ball.speed)
		ball.life = 2.5


# ---- enemies -----------------------------------------------------------------------------------

## opts: prey, target, no_xp, summoned, summoner, support, escort
func spawn_enemy(kind_id: String, pos: Vector2, opts: Dictionary = {}) -> Dictionary:
	var spec: Dictionary = data.enemies[kind_id]
	var role: String = spec.role
	var hp_mult := 1.0
	var damage_mult := 1.0
	if role != "boss":
		var layers: Array = data.spawns.get("layer_hp_mult", [1.0])
		var damage_layers: Array = data.spawns.get("layer_damage_mult", [1.0])
		hp_mult = float(region.get("hp_mult", 1.0)) * float(layers[clampi(layer, 0, layers.size() - 1)])
		damage_mult = float(region.get("damage_mult", 1.0)) * float(damage_layers[clampi(layer, 0, damage_layers.size() - 1)])
	if role == "fodder": hp_mult *= 1.0 + float(mods.get("fodder_hp_pct", 0.0)) / 100.0
	if role in ["elite", "boss"]: hp_mult *= 1.0 + float(mods.get("elite_hp_pct", 0.0)) / 100.0
	var speed: float = float(spec.speed)
	if role == "fodder": speed *= 1.0 + float(mods.get("fodder_speed_pct", 0.0)) / 100.0
	var hp: float = float(spec.hp) * hp_mult
	var e := {"id": next_id, "kind": kind_id, "ai": spec.ai, "role": role, "pos": obstacles.resolve(pos, float(spec.radius)),
		"hp": hp, "max_hp": hp, "speed": speed, "radius": float(spec.radius),
		"damage": float(spec.get("damage", 0)) * damage_mult, "contact": float(spec.get("contact", 0)) * damage_mult,
		"phase": "chase", "timer": 0.0, "dir": Vector2.RIGHT, "flash": 0.0, "tele": {},
		"prey": bool(opts.get("prey", false)), "target": bool(opts.get("target", false)), "marked": false,
		"no_xp": bool(opts.get("no_xp", false)), "summoned": bool(opts.get("summoned", false)),
		"summoner": int(opts.get("summoner", -1)), "support": bool(opts.get("support", false)),
		"visible_time": 0.0, "slow": 0.0, "slow_t": 0.0, "bleed": 0.0, "bleed_t": 0.0,
		"knock": Vector2.ZERO, "knock_t": 0.0, "busy": false, "busy_cost": 2 if role == "boss" else 1,
		"fleeing": false, "stuck_t": 0.0, "slide_t": 0.0, "born": elapsed, "shield_by": -1, "cycle": 0, "count": 0}
	next_id += 1
	var script = AI.get(str(spec.ai))
	if script != null and script.has_method("init"): script.init(self, e)
	enemies.append(e)
	by_id[int(e.id)] = e
	event("spawn", {"pos": e.pos, "enemy": kind_id, "role": role, "id": int(e.id), "prey": bool(e.prey), "summoned": bool(e.summoned)})
	return e


func spec(e: Dictionary) -> Dictionary:
	return data.enemies[e.kind]


func dist_to_player(e: Dictionary) -> float:
	return e.pos.distance_to(player.pos)


func dir_to_player(e: Dictionary) -> Vector2:
	var offset: Vector2 = player.pos - e.pos
	return offset.normalized() if offset.length_squared() > 0.0001 else Vector2.RIGHT


func visible(pos: Vector2) -> bool:
	return camera_rect().grow(-10.0).has_point(pos)


## Special attacks wait until the enemy has been on screen and a concurrency slot is free.
func can_attack(e: Dictionary, cost: int = 1) -> bool:
	if state != "playing" or e.get("fleeing", false): return false
	if float(e.visible_time) < float(t.fairness.visible_before_attack): return false
	var limit: int = int(t.fairness.max_special_attacks)
	if e.role == "boss": return busy_total == 0 or busy_total + cost <= limit
	return busy_total + cost <= limit


func begin_attack(e: Dictionary) -> void:
	if not e.get("busy", false):
		e.busy = true
		busy_total += int(e.get("busy_cost", 1))


func end_attack(e: Dictionary) -> void:
	if e.get("busy", false):
		e.busy = false
		busy_total = maxi(0, busy_total - int(e.get("busy_cost", 1)))
	e.tele = {}


## Moves with slow, obstacle sliding and a small sideways nudge when stuck.
func move_enemy(e: Dictionary, velocity: Vector2, dt: float) -> bool:
	var slow: float = float(e.slow) if float(e.get("slow_t", 0.0)) > 0.0 else 0.0
	var v: Vector2 = velocity * (1.0 - slow / 100.0)
	e.slide_memory = maxf(0.0, float(e.get("slide_memory", 0.0)) - dt)
	if float(e.get("slide_t", 0.0)) > 0.0 and v.length_squared() > 0.01:
		e.slide_t = float(e.slide_t) - dt
		v = (Vector2(e.slide_dir) * 0.85 + v.normalized() * 0.15).normalized() * v.length()
		if float(e.slide_t) <= 0.0: e.slide_memory = 1.5
	var wanted: Vector2 = e.pos + v * dt
	var resolved: Vector2 = obstacles.resolve(wanted, float(e.radius))
	var push: Vector2 = resolved - wanted
	var blocked: bool = push.length() > 0.5
	var intended: float = v.length() * dt
	var actual: float = e.pos.distance_to(resolved)
	e.pos = resolved
	if not obstacles.is_empty() and intended > 0.3 and actual < intended * 0.35:
		e.stuck_t = float(e.get("stuck_t", 0.0)) + dt
		if float(e.stuck_t) > 0.2:
			e.stuck_t = 0.0
			# Slide along the obstacle face; keep the same side if we were just sliding.
			if float(e.get("slide_memory", 0.0)) <= 0.0 or not e.has("slide_dir"):
				var normal: Vector2 = push.normalized() if push.length() > 0.01 else -v.normalized()
				var tangent: Vector2 = normal.orthogonal()
				var toward: Vector2 = player.pos - e.pos
				var side: float = signf(tangent.dot(toward))
				if absf(tangent.dot(toward.normalized())) < 0.15 or side == 0.0: side = 1.0 if int(e.id) % 2 == 0 else -1.0
				e.slide_dir = tangent * side
			e.slide_t = 1.0
	else:
		e.stuck_t = maxf(0.0, float(e.get("stuck_t", 0.0)) - dt)
	return blocked


func flee(e: Dictionary, dt: float) -> void:
	var away: Vector2 = e.pos - player.pos
	if away.length_squared() < 0.01: away = Vector2.RIGHT
	move_enemy(e, away.normalized() * maxf(120.0, float(e.speed)) * float(t.flee.speed_mult), dt)


## from: where the hit came from (for directional feedback); Vector2.INF when unknown.
func hurt_player(amount: float, source: String, from: Vector2 = Vector2.INF) -> void:
	if amount <= 0.0 or float(player.invuln) > 0.0 or dashing() or state != "playing": return
	var dealt := amount * (float(t.assist.enemy_damage_mult) if assist else 1.0)
	if dealt > float(player.pending):
		player.pending = dealt
		player.pending_source = source
		player.pending_from = from


func sector_attack(origin: Vector2, dir: Vector2, reach: float, angle_deg: float, amount: float, source: String) -> void:
	event("enemy_strike", {"pos": origin, "dir": dir, "reach": reach, "half": deg_to_rad(angle_deg * 0.5), "shape": "sector"})
	if Geometry.sector_circle(origin, dir, player.pos, player_radius(), reach, deg_to_rad(angle_deg * 0.5)):
		hurt_player(amount, source, origin)


func line_attack(origin: Vector2, dir: Vector2, length: float, width: float, amount: float, source: String) -> void:
	event("enemy_strike", {"pos": origin, "dir": dir, "length": length, "width": width, "shape": "line"})
	if Geometry.rectangle_circle(origin, dir, player.pos, player_radius(), length, width):
		hurt_player(amount, source, origin)


func fire_shot(origin: Vector2, dir: Vector2, speed: float, life: float, amount: float, source: String) -> void:
	shots.append({"pos": origin, "dir": dir, "speed": speed, "life": life, "damage": amount, "source": source})


## Hazards hit once when they appear, then linger as a slowing area.
func add_hazard(origin: Vector2, radius: float, amount: float, linger: float, slow: float, source: String) -> void:
	hazards.append({"pos": origin, "radius": radius, "windup": 0.0, "linger": linger, "slow": slow, "source": source})
	event("hazard", {"pos": origin, "radius": radius})
	if player.pos.distance_to(origin) <= radius + player_radius(): hurt_player(amount, source, origin)


func support_count(owner_id: int) -> int:
	var count := 0
	for e: Dictionary in enemies:
		if float(e.hp) > 0.0 and int(e.get("summoner", -1)) == owner_id: count += 1
	for entry: Dictionary in spawner.pending:
		if int(entry.opts.get("summoner", -1)) == owner_id: count += 1
	return count


func _update_enemies(dt: float) -> void:
	var cam := camera_rect()
	for e: Dictionary in enemies:
		if float(e.hp) <= 0.0: continue
		e.flash = maxf(0.0, float(e.flash) - dt)
		e.visible_time = float(e.visible_time) + dt if cam.grow(-10.0).has_point(e.pos) else 0.0
		if float(e.knock_t) > 0.0:
			var share: float = minf(dt, float(e.knock_t)) / float(t.knockback.time)
			e.pos = obstacles.resolve(e.pos + Vector2(e.knock) * share, float(e.radius))
			e.knock_t = float(e.knock_t) - dt
		if e.fleeing:
			flee(e, dt)
			continue
		var script = AI.get(str(e.ai))
		if script != null: script.update(self, e, dt)


func _update_shots(dt: float) -> void:
	for i in range(shots.size() - 1, -1, -1):
		var shot: Dictionary = shots[i]
		var from: Vector2 = shot.pos
		var to: Vector2 = from + Vector2(shot.dir) * float(shot.speed) * dt
		shot.pos = to
		shot.life = float(shot.life) - dt
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(player.pos, from, to)
		if closest.distance_to(player.pos) <= player_radius() + 8.0 and not dashing() and float(player.invuln) <= 0.0:
			hurt_player(float(shot.damage), str(shot.source), from - Vector2(shot.dir) * 40.0)
			shots.remove_at(i)
		elif float(shot.life) <= 0.0 or obstacles.blocked(to, 4.0):
			shots.remove_at(i)


func _update_hazards(dt: float) -> void:
	for i in range(hazards.size() - 1, -1, -1):
		hazards[i].linger = float(hazards[i].linger) - dt
		if float(hazards[i].linger) <= 0.0: hazards.remove_at(i)


func _update_status(dt: float) -> void:
	for e: Dictionary in enemies:
		if float(e.hp) <= 0.0: continue
		if float(e.get("slow_t", 0.0)) > 0.0:
			e.slow_t = float(e.slow_t) - dt
			if float(e.slow_t) <= 0.0: e.slow = 0.0
		if float(e.get("bleed_t", 0.0)) > 0.0:
			e.bleed_t = float(e.bleed_t) - dt
			damage_enemy(e, float(e.bleed) * dt, "bleed", max_depth - 1)


func _resolve_player_damage() -> void:
	if float(player.pending) <= 0.0: return
	var amount: float = player.pending
	var source: String = player.pending_source
	var from: Vector2 = player.get("pending_from", Vector2.INF)
	player.pending = 0.0
	player.pending_source = ""
	if float(player.invuln) > 0.0 or dashing() or state != "playing": return
	var block: float = stats.value("first_hit_block")
	if block > 0.0 and not player.block_used:
		amount = maxf(1.0, amount - block)
		player.block_used = true
	player.hp = float(player.hp) - amount
	player.invuln = float(t.player.hurt_invuln) + stats.value("hurt_invuln_bonus")
	metrics.damage_taken = float(metrics.damage_taken) + amount
	metrics.hits_taken += 1
	metrics.taken_by[source] = float(metrics.taken_by.get(source, 0.0)) + amount
	metrics.last_hurt = source
	event("hurt", {"pos": player.pos, "amount": amount, "source": source, "from": from, "ratio": float(player.hp) / float(player.max_hp)})
	effects.fire(self, "hurt", {"source": source, "depth": 0, "pos": player.pos})
	if float(player.hp) <= 0.0:
		player.hp = 0.0
		state = "lost"
		event("lost", {"pos": player.pos})


func _remove_dead() -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var e: Dictionary = enemies[i]
		if float(e.hp) <= 0.0:
			if e.get("busy", false): busy_total = maxi(0, busy_total - int(e.get("busy_cost", 1)))
			enemies.remove_at(i)
			by_id.erase(int(e.id))
		elif e.get("fleeing", false) and float(net_timer) <= 0.6 and not camera_rect().grow(80.0).has_point(e.pos):
			enemies.remove_at(i)
			by_id.erase(int(e.id))


func _update_pickups(dt: float) -> void:
	var radius: float = float(t.xp.pickup_radius) + stats.value("pickup_radius")
	var collect: float = float(t.xp.collect_radius)
	for i in range(pickups.size() - 1, -1, -1):
		var pickup: Dictionary = pickups[i]
		var offset: Vector2 = player.pos - Vector2(pickup.pos)
		var distance := offset.length()
		if distance <= collect:
			_collect(pickup)
			pickups.remove_at(i)
		elif distance <= radius or pickup.get("pulled", false):
			pickup.pulled = true
			pickup.pos = Vector2(pickup.pos) + offset / maxf(distance, 0.01) * minf(distance, float(t.xp.magnet_speed) * dt)


func _collect(pickup: Dictionary) -> void:
	metrics.xp = int(metrics.xp) + int(pickup.value)
	event("pickup", {"pos": pickup.pos})
	if owner != null: owner.gain_xp(int(pickup.value))


func begin_net(delay: float = -1.0) -> void:
	if state != "playing": return
	state = "net"
	net_timer = float(t.flee.duration) if delay < 0.0 else delay
	for e: Dictionary in enemies:
		if float(e.hp) <= 0.0: continue
		end_attack(e)
		e.fleeing = true
	shots.clear()
	hazards.clear()
	busy_total = 0
	player.pending = 0.0
	event("net", {"pos": player.pos})


func _update_end(dt: float) -> void:
	if state == "playing" and kind == "practice" and elapsed >= float(data.spawns.practice.get("duration", 180)):
		begin_net()
	if state != "net": return
	net_timer = float(net_timer) - dt
	if net_timer > 0.0: return
	for pickup: Dictionary in pickups: _collect(pickup)
	pickups.clear()
	enemies.clear()
	_rebuild_index()
	balls.clear()
	lines.clear()
	state = "won"
	event("won", {"pos": player.pos})


func remaining_targets() -> int:
	return spawner.remaining_targets(self)


func boss() -> Dictionary:
	for e: Dictionary in enemies:
		if e.role == "boss" and float(e.hp) > 0.0: return e
	return {}


# ---- snapshot -------------------------------------------------------------------------------

const SAVED := ["region_id", "kind", "layer", "night", "next_mods", "assist", "base_max_hp", "state",
	"elapsed", "net_timer", "next_id", "player", "claw_timer", "pounce", "ult", "enemies", "shots", "hazards",
	"balls", "lines", "pickups", "marked_id", "metrics"]


func to_dict() -> Dictionary:
	var result := {}
	for key: String in SAVED: result[key] = get(key).duplicate(true) if get(key) is Dictionary or get(key) is Array else get(key)
	result["stats"] = stats.to_dict()
	result["effects"] = effects.to_dict()
	result["spawner"] = spawner.to_dict()
	result["view_size"] = view_size
	return result


func from_dict(saved: Dictionary, rngs, entries: Array, owner_ref = null) -> void:
	setup({"region": saved.region_id, "kind": saved.kind, "layer": saved.layer, "night": saved.night, "next_mods": saved.next_mods,
		"assist": saved.assist, "max_hp_base": saved.base_max_hp, "entries": entries,
		"view_size": saved.get("view_size", Vector2(1280, 720))}, rngs, owner_ref, false)
	for key: String in SAVED:
		var value = saved[key]
		set(key, value.duplicate(true) if value is Dictionary or value is Array else value)
	stats.from_dict(saved.get("stats", {}))
	effects.from_dict(saved.get("effects", {}))
	spawner.from_dict(saved.get("spawner", {}))
	events.clear()
	_rebuild_index()
