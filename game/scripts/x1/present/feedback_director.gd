extends RefCounted
## Turns battle events into feedback: picks the cue for each event from feel.json and sends it to
## time (hit-stop / slow motion), camera, effects, sound, haptics, music and the HUD.
## Also keeps the combo (連獵) count, music intensity and the low-health heartbeat.

const Data := preload("res://scripts/x1/core/data.gd")
const LADDER := [0, 2, 4, 7, 9, 12, 9, 7, 4, 2]

var feel: Dictionary = {}
var time = null
var camera = null
var world = null
var hud = null
var audio = null
var music = null
var haptics = null
var settings: Dictionary = {}
var view_size := Vector2(1280, 720)
var combo := 0
var combo_timer := 0.0
var combo_tier := -1
var best_combo := 0
var pickup_streak := 0
var pickup_timer := 0.0
var slash_index := 0
var heartbeat := 0.0
var last_pending := 0
var applied: Array = []      # cue names applied, for tests


func setup(feel_data: Dictionary, parts: Dictionary) -> void:
	feel = feel_data
	time = parts.get("time")
	camera = parts.get("camera")
	world = parts.get("world")
	hud = parts.get("hud")
	audio = parts.get("audio")
	music = parts.get("music")
	haptics = parts.get("haptics")


func apply_settings(values: Dictionary) -> void:
	settings = values
	var reduce: bool = values.get("reduce_motion", false)
	if time != null: time.enabled = not reduce
	if camera != null:
		camera.shake_scale = clampf(float(values.get("shake_level", 1.0)), 0.0, 1.0) * (0.5 if reduce else 1.0)
		camera.motion = not reduce
	if world != null:
		world.fx.quality = str(values.get("effects", "high"))
		world.fx.low_flash = values.get("low_flash", false)
		world.settings = values
	if hud != null: hud.settings = values
	if haptics != null: haptics.set_level(str(values.get("haptics", "medium")))


func reset_battle(run) -> void:
	combo = 0
	combo_timer = 0.0
	combo_tier = -1
	best_combo = 0
	pickup_streak = 0
	slash_index = 0
	heartbeat = 0.0
	last_pending = run.pending_levels if run != null else 0
	if time != null: time.reset()


func _color(name: String) -> Color:
	return world.fx.color(name) if world != null else Color.WHITE


func _screen(pos: Vector2) -> Vector2:
	return camera.world_to_screen(view_size, world.battle.world, pos) if camera != null and world != null and world.battle != null else pos


## Apply one named cue at a world position. opts: dir, tint, ladder (semitones), radius.
func cue(name: String, pos: Vector2, opts: Dictionary = {}) -> void:
	var entry: Dictionary = feel.get("cues", {}).get(name, {})
	if entry.is_empty(): return
	applied.append(name)
	if applied.size() > 400: applied.pop_front()
	if time != null:
		if entry.has("hitstop"): time.add_hitstop(float(entry.hitstop))
		if entry.has("slowmo"): time.slow_motion(float(entry.slowmo.scale), float(entry.slowmo.time))
	if camera != null:
		if entry.has("shake"):
			var dir: Vector2 = opts.get("dir", Vector2.ZERO) if entry.get("directional", false) else Vector2.ZERO
			camera.add_trauma(float(entry.shake), dir)
		if entry.has("kick"): camera.add_kick(opts.get("dir", Vector2.ZERO), float(entry.kick))
		if entry.has("zoom"): camera.punch(float(entry.zoom))
	if world != null:
		var fx = world.fx
		if entry.has("particles"):
			fx.burst(str(entry.particles.preset), pos, int(entry.particles.get("count", 4)), opts.get("tint", Color.WHITE), opts.get("dir", Vector2.ZERO))
		if entry.has("ring"): fx.ring(str(entry.ring), pos, float(opts.get("radius", 0.0)))
		if entry.get("pillar", false): fx.pillar(pos)
		if entry.get("puff", false): fx.burst("puff", pos, 3, opts.get("tint", Color.WHITE))
		if entry.has("fx"): fx.special(str(entry.fx), pos, opts.get("dir", Vector2.RIGHT), opts)
		if entry.has("text"): fx.text(str(entry.text), pos + Vector2(0, -50), _color(str(entry.get("text_color", "cream"))), 30)
	if hud != null:
		if entry.has("flash"): hud.screen_flash(str(entry.flash), 1.0)
		if entry.get("fish_fly", false): hud.fly_fish(_screen(pos))
	if audio != null and entry.has("sound"):
		var semis: float = float(entry.get("pitch", 0.0))
		if entry.get("ladder", false): semis += float(opts.get("ladder", 0.0))
		audio.play(str(entry.sound), semis, float(entry.get("pitch_var", 0.04)))
	if haptics != null and entry.has("haptic"): haptics.play(str(entry.haptic))
	if music != null and entry.has("music"): music.stinger(str(entry.music))


## Pentatonic up-and-down so rapid pops and pickups sound like a melody, never runaway pitch.
func _ladder(step: int) -> float:
	return float(LADDER[posmod(step, LADDER.size())])


func _heavy(ev: Dictionary) -> bool:
	var spec: Dictionary = feel.get("damage_numbers", {})
	if str(ev.get("source", "")) in spec.get("heavy_sources", []): return true
	if ev.get("prey", false) and spec.get("heavy_prey", true): return true
	return str(ev.get("role", "")) in spec.get("heavy_roles", [])


## Process the events of one simulation step (or a whole frame).
func process(events: Array, b, run) -> void:
	var claw_sound := false
	for ev: Dictionary in events:
		var kind: String = ev.kind
		if world != null: world.on_event(kind, ev)
		var pos: Vector2 = ev.get("pos", Vector2.ZERO)
		match kind:
			"swipe":
				if int(ev.get("depth", 0)) == 0: cue("swipe", pos)
			"hit":
				var source: String = str(ev.get("source", ""))
				var heavy := _heavy(ev)
				if not ev.get("kill", false) and source in ["claw", "burst"] and not claw_sound:
					claw_sound = true
					cue("claw_hit", pos, {"dir": ev.get("dir", Vector2.ZERO)})
				if heavy and not ev.get("kill", false): cue("hit_heavy", pos, {"dir": ev.get("dir", Vector2.ZERO)})
				_damage_number(ev, heavy)
			"defeat":
				_on_defeat(ev)
			"last_target":
				cue("last_target", pos)
			"pounce":
				slash_index = 0
				cue("pounce", pos, {"dir": -Vector2(ev.dir)})
			"pounce_hit":
				slash_index += 1
				cue("pounce_hit", pos, {"dir": ev.get("dir", Vector2.RIGHT), "ladder": _ladder(slash_index)})
			"land":
				cue("land", pos, {"dir": ev.get("dir", Vector2.ZERO)})
				if int(ev.get("hits", 0)) >= 3: cue("pierce", pos)
				if ev.get("escape", false): cue("escape", pos)
			"bite":
				var prey: bool = ev.get("prey", false) or str(ev.get("role", "")) in ["elite", "boss"]
				cue("bite_prey" if prey else "bite", pos, {"prey": prey})
			"mark": cue("mark", pos)
			"cash": cue("cash", pos)
			"execute": cue("execute", pos)
			"hurt":
				var from: Vector2 = ev.get("from", Vector2.INF)
				var dir := Vector2.ZERO
				if from != Vector2.INF and from.distance_squared_to(pos) > 1.0: dir = (pos - from).normalized()
				cue("hurt", pos, {"dir": dir})
				if hud != null: hud.hurt(_screen(pos))
				if feel.get("combo", {}).get("break_on_hurt", true): _break_combo(pos)
			"ult_ready": cue("ult_ready", pos)
			"ult": cue("ult", pos, {"radius": float(ev.get("radius", 220.0))})
			"ult_end": cue("ult_end", pos)
			"wave":
				if str(ev.get("source", "")) != "ult": cue("wave", pos, {"radius": float(ev.get("radius", 100.0))})
			"burst": cue("burst", pos, {"radius": float(ev.get("radius", 100.0))})
			"line": cue("line", Vector2(ev.get("origin", pos)))
			"heal": cue("heal", pos)
			"refund": cue("refund", pos)
			"roam_charge": cue("roam_charge", pos)
			"pickup":
				pickup_streak += 1
				pickup_timer = 0.6
				cue("pickup", pos, {"ladder": float(mini(pickup_streak, 12))})
			"telegraph":
				var role: String = str(ev.get("role", ""))
				cue("telegraph_boss" if role == "boss" else ("telegraph_elite" if role == "elite" else "telegraph"), pos)
			"enemy_strike": cue("enemy_strike", pos)
			"spawn":
				if str(ev.get("role", "")) in ["special", "elite", "boss"] or ev.get("prey", false): cue("spawn_special", pos)
				if str(ev.get("role", "")) == "boss" and hud != null:
					hud.banner(str(Data.shared().enemies.get(str(ev.get("kind", "")), {}).get("name", "")), "守關現身", "danger", 1.8)
			"boss_phase": cue("boss_phase", pos)
			"net":
				cue("net", pos)
				if hud != null: hud.banner("收網！", "目標獵物全部打倒", "prey", 1.5)
			"lost": cue("lost", pos)


func _on_defeat(ev: Dictionary) -> void:
	var pos: Vector2 = ev.pos
	var role: String = str(ev.get("role", "fodder"))
	var tint := Color(str(ev.get("color", "ffffff")))
	combo += 1
	combo_timer = float(feel.get("combo", {}).get("window", 1.4))
	best_combo = maxi(best_combo, combo)
	var ladder: float = _ladder(combo - 1)
	var name := "kill_fodder"
	if role == "boss": name = "kill_boss"
	elif role == "elite": name = "kill_elite"
	elif ev.get("prey", false): name = "kill_prey"
	elif role == "special": name = "kill_special"
	elif role == "hound": name = "kill_hound"
	cue(name, pos, {"tint": tint, "ladder": ladder, "radius": float(ev.get("radius", 20.0)) * 2.5})
	var tiers: Array = feel.get("combo", {}).get("tiers", [])
	var tier_index := -1
	for i in tiers.size():
		if combo >= int(tiers[i].at): tier_index = i
	if tier_index > combo_tier:
		combo_tier = tier_index
		cue("combo_tier", pos)
		if hud != null: hud.banner("%s ×%d" % [tiers[tier_index].name, combo], "", "prey", 0.9, false)
	if hud != null: hud.set_combo(combo, tiers[maxi(0, combo_tier)] if not tiers.is_empty() and combo_tier >= 0 else {"name": "連獵", "color": "fff2d4"})


func _break_combo(pos: Vector2) -> void:
	if combo >= 5: cue("combo_break", pos)
	combo = 0
	combo_tier = -1
	combo_timer = 0.0
	if hud != null: hud.break_combo()


func _damage_number(ev: Dictionary, heavy: bool) -> void:
	if world == null: return
	var mode: String = str(settings.get("damage_numbers", "heavy"))
	if mode == "off" or (mode == "heavy" and not heavy): return
	var source: String = str(ev.get("source", ""))
	var big: bool = source in ["cash", "execute"] or (heavy and float(ev.get("amount", 0.0)) >= 40.0)
	var col_name := "cream"
	match source:
		"bite": col_name = "white"
		"cash": col_name = "shadow"
		"execute": col_name = "danger"
		"shadow", "wind": col_name = "shadow"
	if ev.get("prey", false) and source in ["bite", "claw"]: col_name = "prey"
	world.fx.number(float(ev.get("amount", 0.0)), Vector2(ev.pos), _color(col_name), big)


## Per frame: combo timeout, pickup streak, level-up detection, heartbeat, music intensity.
func frame(dt: float, b, run) -> void:
	if combo_timer > 0.0:
		combo_timer -= dt
		if combo_timer <= 0.0: combo = 0
	if pickup_timer > 0.0:
		pickup_timer -= dt
		if pickup_timer <= 0.0: pickup_streak = 0
	if run != null:
		if run.pending_levels > last_pending and b != null: cue("level_up", b.player.pos)
		if b != null and run.pending_levels > last_pending and hud != null: hud.banner("升級！", "", "prey", 1.0)
		last_pending = run.pending_levels
	if b == null: return
	var ratio: float = float(b.player.hp) / maxf(1.0, float(b.player.max_hp))
	var low: bool = ratio < float(feel.get("low_hp", {}).get("ratio", 0.3)) and b.state == "playing"
	if audio != null: audio.low_pass(low)
	if low:
		heartbeat -= dt
		if heartbeat <= 0.0:
			heartbeat = float(feel.get("low_hp", {}).get("beat", 0.9))
			if audio != null: audio.play("heartbeat")
			if haptics != null: haptics.play("heart")
	if music != null:
		var cfg: Dictionary = feel.get("music", {}).get("intensity", {})
		var near := 0
		var radius: float = float(cfg.get("near_radius", 320))
		for e: Dictionary in b.enemies:
			if e.pos.distance_squared_to(b.player.pos) < radius * radius: near += 1
		var intensity: float = clampf(float(near) / float(cfg.get("near_full", 30)), 0.0, 1.0) * 0.6
		intensity += clampf(float(combo) / float(cfg.get("combo_full", 40)), 0.0, 1.0) * 0.4
		if b.ult_active(): intensity += float(cfg.get("ult_bonus", 0.4))
		var boss: bool = not b.boss().is_empty()
		if boss: intensity += float(cfg.get("boss_bonus", 0.5))
		music.set_state(clampf(intensity, 0.0, 1.0), boss, b.ult_active())
