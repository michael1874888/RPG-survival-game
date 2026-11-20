extends RefCounted
## Streams fodder from off screen, schedules prey, specials and hounds, and decides when to net.
## Warned spawns appear only after a full warning and at a safe distance from the player.

const Data := preload("res://scripts/x1/core/data.gd")

var cfg: Dictionary = {}
var time := 0.0
var credit := 0.0
var next_special := 0.0
var next_hound := 0.0
var target_times: Array = []
var targets_total := 0
var targets_killed := 0
var elite_done := false
var boss_done := false
var pending: Array = []   # {kind, pos, timer, opts}


func setup(b, extra_targets: int) -> void:
	cfg = b.data.spawns[b.kind]
	time = 0.0
	credit = 0.0
	pending.clear()
	target_times.clear()
	targets_killed = 0
	elite_done = false
	boss_done = false
	next_special = float(cfg.get("specials", {}).get("first", 9999))
	var hounds: Dictionary = cfg.get("hounds", {})
	next_hound = maxf(15.0, float(hounds.get("from", 9999)) - 15.0 * float(b.mods.get("extra_hounds", 0.0)))
	targets_total = 0
	match b.kind:
		"hunt", "practice":
			var targets: Dictionary = cfg.get("targets", {})
			var count: int = int(targets.get("count", 0)) + extra_targets
			for i in count: target_times.append(float(targets.get("first", 8)) + float(targets.get("gap", 14)) * i)
			if b.kind == "hunt": targets_total = count
		"den":
			var targets: Dictionary = cfg.get("targets", {})
			var count: int = int(targets.get("count", 0)) + extra_targets
			for i in count: target_times.append(float(targets.get("first", 15)) + float(targets.get("gap", 15)) * i)
			targets_total = 1 + count
		"boss":
			targets_total = 1


func remaining_targets(_b) -> int:
	return maxi(0, targets_total - targets_killed)


func _alive(b, predicate: Callable) -> int:
	var count := 0
	for e: Dictionary in b.enemies:
		if float(e.hp) > 0.0 and predicate.call(e): count += 1
	for entry: Dictionary in pending:
		var spec: Dictionary = b.data.enemies[entry.kind]
		if predicate.call({"role": spec.role, "kind": entry.kind, "target": entry.opts.get("target", false),
				"summoned": entry.opts.get("summoned", false), "prey": entry.opts.get("prey", false)}):
			count += 1
	return count


func update(b, dt: float) -> void:
	time += dt
	_update_pending(b, dt)
	var rng: RandomNumberGenerator = b.rng_spawn
	var total: int = b.enemies.size() + pending.size()
	var cap: int = int(cfg.get("cap", 120))
	var fodder: Dictionary = cfg.fodder
	var rate: float = minf(float(fodder.max_rate), float(fodder.rate) + floorf(time / float(fodder.step_every)) * float(fodder.rate_step))
	credit = minf(credit + rate * dt, float(fodder.pack_max) * 2.0)
	if credit >= float(fodder.pack_min) and total < cap:
		var size: int = mini(mini(rng.randi_range(int(fodder.pack_min), int(fodder.pack_max)), cap - total), int(credit))
		if size > 0:
			_spawn_pack(b, str(fodder.kind), size)
			credit -= size
	while not target_times.is_empty() and time >= float(target_times[0]):
		target_times.pop_front()
		var kind_id: String = _pick(rng, b.region.get("targets", ["E03"]))
		var pos := warned_pos(b)
		queue(b, kind_id, pos, {"prey": true, "target": b.kind != "practice"})
		if float(b.mods.get("target_escort", 0.0)) > 0.0 and b.kind == "hunt":
			queue(b, "E02", b.obstacles.resolve(pos + Vector2(60, 0).rotated(rng.randf() * TAU), 18.0), {})
	var specials: Dictionary = cfg.get("specials", {})
	if time >= next_special:
		next_special += maxf(1.0, float(specials.get("every", 13)))
		var alive := _alive(b, func(e): return e.role == "special" and not e.get("target", false) and not e.get("summoned", false))
		if alive < int(specials.get("max_alive", 0)) and not b.region.get("specials", []).is_empty():
			queue(b, _pick(rng, b.region.specials), warned_pos(b), {})
	var hounds: Dictionary = cfg.get("hounds", {})
	if time >= next_hound:
		next_hound += maxf(1.0, float(hounds.get("every", 10)))
		var limit: int = int(hounds.get("max_alive", 0)) + int(b.mods.get("extra_hounds", 0.0))
		var hound_kind: String = str(hounds.get("kind", "E02"))
		var alive := _alive(b, func(e): return e.kind == hound_kind and not e.get("summoned", false) and not e.get("target", false))
		if alive < limit:
			b.spawn_enemy(hound_kind, offscreen_pos(b), {})
	if b.kind == "den" and not elite_done and time >= float(cfg.get("elite_at", 3)):
		elite_done = true
		queue(b, _pick(rng, b.region.get("elites", ["EL01"])), warned_pos(b), {"target": true})
	if b.kind == "boss" and not boss_done and time >= float(cfg.get("boss_at", 1.5)):
		boss_done = true
		var pos: Vector2 = b.player.pos + Vector2(0, -360)
		if pos.y < 160.0: pos = b.player.pos + Vector2(0, 360)
		queue(b, str(b.region.boss), b.obstacles.resolve(pos.clamp(Vector2(120, 120), b.world - Vector2(120, 120)), 40.0), {"target": true})


func queue(b, kind_id: String, pos: Vector2, opts: Dictionary) -> void:
	pending.append({"kind": kind_id, "pos": pos, "timer": float(b.t.world.spawn_warning), "opts": opts})
	b.event("warn", {"pos": pos, "kind": kind_id})


func _update_pending(b, dt: float) -> void:
	var safe: float = float(b.t.world.spawn_safe_distance)
	for i in range(pending.size() - 1, -1, -1):
		var entry: Dictionary = pending[i]
		entry.timer = float(entry.timer) - dt
		if float(entry.timer) > 0.0: continue
		if Vector2(entry.pos).distance_to(b.player.pos) < safe * 0.75 and not entry.opts.get("near_owner", false):
			# Too close at birth: move it and give a complete new warning.
			entry.pos = warned_pos(b)
			entry.timer = float(b.t.world.spawn_warning)
			b.event("warn", {"pos": entry.pos, "kind": entry.kind})
			continue
		pending.remove_at(i)
		b.spawn_enemy(str(entry.kind), Vector2(entry.pos), entry.opts)


func on_kill(b, e: Dictionary) -> void:
	if not e.get("target", false): return
	targets_killed += 1
	if targets_total > 0 and targets_killed >= targets_total: b.event("last_target", {"pos": e.pos, "role": e.role})
	if e.role == "boss":
		b.begin_net(1.0)
	elif targets_total > 0 and targets_killed >= targets_total:
		b.begin_net()


static func _pick(rng: RandomNumberGenerator, options: Array) -> String:
	if options.is_empty(): return ""
	return str(options[rng.randi_range(0, options.size() - 1)])


## A visible spot at a safe distance, for warned spawns.
func warned_pos(b) -> Vector2:
	var rng: RandomNumberGenerator = b.rng_spawn
	var safe: float = float(b.t.world.spawn_safe_distance)
	var margin := 80.0
	for attempt in 14:
		var distance := rng.randf_range(safe + 30.0, safe + 200.0)
		var candidate: Vector2 = b.player.pos + Vector2.RIGHT.rotated(rng.randf() * TAU) * distance
		candidate = candidate.clamp(Vector2.ONE * margin, b.world - Vector2.ONE * margin)
		candidate = b.obstacles.resolve(candidate, 30.0)
		if candidate.distance_to(b.player.pos) >= safe: return candidate
	var corners := [Vector2(margin, margin), Vector2(b.world.x - margin, margin), Vector2(margin, b.world.y - margin), b.world - Vector2.ONE * margin]
	var best: Vector2 = corners[0]
	for corner: Vector2 in corners:
		if corner.distance_to(b.player.pos) > best.distance_to(b.player.pos): best = corner
	return b.obstacles.resolve(best, 30.0)


## Just outside the camera, for unwarned fodder and hounds.
func offscreen_pos(b) -> Vector2:
	var rng: RandomNumberGenerator = b.rng_spawn
	var safe: float = float(b.t.world.spawn_safe_distance)
	var cam: Rect2 = b.camera_rect().grow(float(b.t.world.view_margin))
	var low := Vector2.ONE * (float(b.t.world.edge) + 20.0)
	var high: Vector2 = b.world - low
	for attempt in 10:
		var point: Vector2
		match rng.randi_range(0, 3):
			0: point = Vector2(rng.randf_range(cam.position.x, cam.end.x), cam.position.y)
			1: point = Vector2(rng.randf_range(cam.position.x, cam.end.x), cam.end.y)
			2: point = Vector2(cam.position.x, rng.randf_range(cam.position.y, cam.end.y))
			_: point = Vector2(cam.end.x, rng.randf_range(cam.position.y, cam.end.y))
		point = point.clamp(low, high)
		point = b.obstacles.resolve(point, 18.0)
		if not b.camera_rect().has_point(point) and point.distance_to(b.player.pos) >= safe: return point
	return warned_pos(b)


func _spawn_pack(b, kind_id: String, size: int) -> void:
	var center := offscreen_pos(b)
	var rng: RandomNumberGenerator = b.rng_spawn
	for i in size:
		var offset := Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(0.0, 46.0)
		b.spawn_enemy(kind_id, center + offset, {})


const SAVED := ["time", "credit", "next_special", "next_hound", "target_times", "targets_total", "targets_killed", "elite_done", "boss_done", "pending"]


func to_dict() -> Dictionary:
	var result := {}
	for key: String in SAVED: result[key] = get(key).duplicate(true) if get(key) is Array else get(key)
	return result


func from_dict(saved: Dictionary) -> void:
	for key: String in SAVED:
		if saved.has(key): set(key, saved[key].duplicate(true) if saved[key] is Array else saved[key])
