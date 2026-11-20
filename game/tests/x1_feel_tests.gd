extends SceneTree
## Feedback layer: event -> cue mapping by weight, hit-stop/slow-motion caps, haptic throttling,
## same-frame sound de-duplication, combo counting, damage-number modes and accessibility settings.

const Data := preload("res://scripts/x1/core/data.gd")
const WorldView := preload("res://scripts/x1/present/world_view.gd")
const Hud := preload("res://scripts/x1/present/hud.gd")
const AudioDirector := preload("res://scripts/x1/present/audio_director.gd")
const MusicDirector := preload("res://scripts/x1/present/music_director.gd")
const TimeController := preload("res://scripts/x1/present/time_controller.gd")
const CameraRig := preload("res://scripts/x1/present/camera_rig.gd")
const Haptics := preload("res://scripts/x1/present/haptics.gd")
const Director := preload("res://scripts/x1/present/feedback_director.gd")
const H := preload("res://tests/x1_helpers.gd")

var checks := 0
var failures := 0
var parts := {}


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func _initialize() -> void:
	call_deferred("exercise")


func make() -> Director:
	var data = Data.shared()
	for key in parts:
		if parts[key] is Node: parts[key].queue_free()
	var world = WorldView.new()
	root.add_child(world)
	var hud = Hud.new()
	root.add_child(hud)
	var audio = AudioDirector.new()
	root.add_child(audio)
	audio.setup(data.feel)
	var music = MusicDirector.new()
	root.add_child(music)
	music.setup(data.feel, audio)
	var time = TimeController.new()
	time.hitstop_cap = float(data.feel.limits.hitstop_cap)
	var camera = CameraRig.new()
	camera.setup(data.feel.camera)
	var haptics = Haptics.new()
	haptics.setup(data.feel, "medium")
	parts = {"world": world, "hud": hud, "audio": audio, "music": music, "time": time, "camera": camera, "haptics": haptics}
	var director = Director.new()
	director.setup(data.feel, parts)
	director.apply_settings({"damage_numbers": "heavy", "haptics": "medium", "shake_level": 1.0, "effects": "high"})
	var b = H.battle()
	world.set_battle(b)
	hud.reset_battle(b, null)
	return director


func defeat(role: String, prey := false) -> Dictionary:
	return {"kind": "defeat", "pos": Vector2(1200, 800), "role": role, "prey": prey, "color": "ac9acc", "radius": 15.0, "id": 1, "enemy": "E01"}


func exercise() -> void:
	var data = Data.shared()
	var d := make()
	await process_frame
	# Every cue the director can name exists in feel.json.
	for name: String in ["swipe", "claw_hit", "hit_heavy", "kill_fodder", "kill_hound", "kill_special", "kill_prey", "kill_elite", "kill_boss",
			"last_target", "pounce", "pounce_hit", "pierce", "land", "escape", "bite", "bite_prey", "mark", "cash", "execute", "hurt",
			"ult_ready", "ult", "ult_end", "wave", "line", "burst", "heal", "refund", "roam_charge", "pickup", "level_up", "telegraph",
			"telegraph_elite", "telegraph_boss", "enemy_strike", "spawn_special", "boss_phase", "net", "combo_tier", "combo_break", "lost", "button"]:
		check(data.feel.cues.has(name), "feel.json has cue %s" % name)
	# Weight ladder: kills map to the right cue.
	var cases := [[defeat("fodder"), "kill_fodder"], [defeat("hound"), "kill_hound"], [defeat("special"), "kill_special"],
		[defeat("special", true), "kill_prey"], [defeat("elite"), "kill_elite"], [defeat("boss"), "kill_boss"]]
	for entry: Array in cases:
		d.applied.clear()
		d.process([entry[0]], d.world.battle, null)
		check(entry[1] in d.applied, "%s defeat -> %s" % [entry[0].role, entry[1]])
	# T0/T1 are light: no hit-stop, no shake, no haptic for fodder.
	d = make()
	await process_frame
	d.process([defeat("fodder")], d.world.battle, null)
	check(d.time.hitstop == 0.0 and d.camera.trauma == 0.0 and d.haptics.history.is_empty(), "killing fodder has no stop, shake or buzz")
	check(d.world.fx.particles.size() > 0, "killing fodder bursts into shards")
	# T3 bite: hit-stop + medium haptic; prey bite is heavier.
	d.process([{"kind": "bite", "pos": Vector2(1200, 800), "prey": false, "id": 1}], d.world.battle, null)
	check(absf(d.time.hitstop - 0.045) < 0.001, "bite adds a 45 ms hit-stop")
	check(not d.haptics.history.is_empty() and d.haptics.history[-1].name == "medium", "bite buzzes medium")
	for i in 10: d.process([{"kind": "bite", "pos": Vector2(1200, 800), "prey": true, "id": 1}], d.world.battle, null)
	check(d.time.hitstop <= float(data.feel.limits.hitstop_cap) + 0.0001, "hit-stop is capped")
	# T4/T5: slow motion and zoom.
	d = make()
	await process_frame
	d.process([defeat("elite")], d.world.battle, null)
	check(d.time.slow_left > 0.0 and absf(d.time.slow_scale - 0.35) < 0.01, "elite kill slows time")
	d.process([{"kind": "ult", "pos": Vector2(1200, 800), "radius": 220.0}], d.world.battle, null)
	check(d.camera.zoom_punch > 0.0 and d.camera.trauma > 0.3, "night shadow punches the camera")
	# Directional hurt shake.
	d = make()
	await process_frame
	d.process([{"kind": "hurt", "pos": Vector2(1200, 800), "from": Vector2(1100, 800), "amount": 8.0, "source": "E01"}], d.world.battle, null)
	check(d.camera.trauma > 0.0 and d.camera.shake_dir.x > 0.9, "hurt shakes away from where the hit came from")
	check(d.hud.hurt_t > 0.0, "hurt flashes the HUD")
	# Haptic throttle and priority.
	var h = Haptics.new()
	h.setup(data.feel, "medium")
	check(h.play("light"), "first buzz plays")
	check(not h.play("light"), "a second light buzz within 70 ms is dropped")
	check(h.play("heavy"), "a higher-priority buzz still gets through")
	h.process(0.2)
	check(h.play("light"), "after the gap the next buzz plays")
	h.set_level("off")
	check(not h.play("heavy"), "haptics off means no buzz")
	# Same-frame sound de-duplication.
	var audio = d.audio
	await process_frame
	check(audio.play("pop"), "a sound plays")
	check(not audio.play("pop"), "the same sound twice in one frame plays once")
	await process_frame
	check(audio.play("pop"), "next frame it plays again")
	# Combo: counts, tiers, breaks on hurt, times out.
	d = make()
	await process_frame
	for i in 12: d.process([defeat("fodder")], d.world.battle, null)
	check(d.combo == 12 and d.combo_tier == 0 and d.hud.combo == 12, "12 quick kills reach the first combo tier")
	check("combo_tier" in d.applied, "reaching a tier plays its cue")
	d.process([{"kind": "hurt", "pos": Vector2(1200, 800), "amount": 5.0, "source": "E01"}], d.world.battle, null)
	check(d.combo == 0 and "combo_break" in d.applied, "getting hit breaks the combo")
	for i in 3: d.process([defeat("fodder")], d.world.battle, null)
	d.frame(2.0, d.world.battle, null)
	check(d.combo == 0, "the combo times out after the window")
	check(d.best_combo == 12, "the best combo is remembered for the result screen")
	check(d.hud.banners.is_empty() and d.hud.combo_rank > 0.0, "a combo tier pops the HUD counter instead of a screen banner")
	# Damage numbers.
	var claw := {"kind": "hit", "pos": Vector2(1200, 800), "amount": 10.0, "source": "claw", "role": "fodder", "prey": false, "kill": false, "id": 2}
	var bite := {"kind": "hit", "pos": Vector2(1200, 800), "amount": 30.0, "source": "bite", "role": "fodder", "prey": false, "kill": false, "id": 2}
	d = make()
	await process_frame
	d.process([claw], d.world.battle, null)
	check(d.world.fx.numbers.is_empty(), "heavy-only mode hides ordinary claw numbers")
	d.process([bite], d.world.battle, null)
	check(d.world.fx.numbers.size() == 1, "heavy-only mode shows bite numbers")
	d.apply_settings({"damage_numbers": "all"})
	d.process([claw], d.world.battle, null)
	check(d.world.fx.numbers.size() == 2, "all mode shows every hit")
	d.apply_settings({"damage_numbers": "off"})
	d.process([bite], d.world.battle, null)
	check(d.world.fx.numbers.size() == 2, "off mode shows none")
	d.apply_settings({"damage_numbers": "heavy"})
	d.process([{"kind": "hit", "pos": Vector2(1200, 800), "amount": 999999.0, "shown": 120.0, "source": "bite", "role": "boss", "prey": false, "kill": true, "id": 3}], d.world.battle, null)
	check(int(d.world.fx.numbers[-1].value) == 120, "an overkill hit shows only the health it took")
	# Floating words do not pile up on one spot; the boss entrance banner names the boss.
	d.world.fx.text("獵物！", Vector2(1200, 800), Color.WHITE, 30)
	d.world.fx.text("精英擊破！", Vector2(1200, 800), Color.WHITE, 30)
	var words: Array = d.world.fx.texts
	check(absf(float(words[-1].pos.y) - float(words[-2].pos.y)) >= 30.0, "a second word at the same spot moves out of the way")
	var boss_id := ""
	for id: String in data.enemies:
		if str(data.enemies[id].get("role", "")) == "boss": boss_id = id
	d.process([{"kind": "spawn", "pos": Vector2(1200, 800), "enemy": boss_id, "role": "boss", "id": 9, "prey": false, "summoned": false}], d.world.battle, null)
	check(not d.hud.banners.is_empty() and str(d.hud.banners[-1].text) == str(data.enemies[boss_id].name), "the boss entrance banner shows the boss name")
	# Accessibility.
	d = make()
	await process_frame
	d.apply_settings({"reduce_motion": true, "low_flash": true, "shake_level": 0.0})
	d.process([{"kind": "bite", "pos": Vector2(1200, 800), "prey": true, "id": 1}, defeat("elite")], d.world.battle, null)
	check(d.time.hitstop == 0.0 and d.time.slow_left == 0.0, "reduce motion removes hit-stop and slow motion")
	check(d.camera.trauma == 0.0, "shake 0% removes screen shake")
	d.process([{"kind": "boss_phase", "pos": Vector2(1200, 800)}], d.world.battle, null)
	check(not d.hud.flash.is_empty() and float(d.hud.flash.alpha) <= 0.36, "low flash dims full-screen flashes")
	# Particles respect the quality cap.
	d.apply_settings({"effects": "low"})
	for i in 200: d.world.fx.burst("gold", Vector2(1200, 800), 40)
	check(d.world.fx.particles.size() <= int(data.feel.limits.particles.low), "low effects cap particles")
	# Music follows the fight.
	d.music.mode = "battle"
	d.music.set_state(0.0, true, false)
	check(float(d.music.targets.boss) == 1.0 and float(d.music.targets.lead) == 0.0, "boss fights bring in the boss layer")
	d.music.set_state(0.9, false, true)
	check(float(d.music.targets.lead) == 1.0 and float(d.music.targets.drums) > 0.9, "intensity and night shadow bring in drums and lead")
	print("X1 FEEL: %d checks, %d failures" % [checks, failures])
	for key in parts:
		if parts[key] is Node: parts[key].queue_free()
	await process_frame
	Data.release()
	quit(1 if failures > 0 else 0)
