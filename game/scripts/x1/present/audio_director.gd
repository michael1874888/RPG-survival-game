extends Node
## Sound effects: pre-generated WAV variants, a player pool, per-sound voice limits,
## same-frame de-duplication, pitch ladders, buses (Music / SFX / UI) with a limiter,
## music ducking and a low-pass for low health.

const DIR := "res://assets/audio/x1/sfx/"
const POOL := 20

var feel: Dictionary = {}
var streams: Dictionary = {}     # name -> [AudioStreamWAV]
var players: Array = []          # [{player, name, started}]
var frame := 0
var frame_played: Dictionary = {}
var played: Array = []           # [{name, pitch}] recent, for tests
var rng := RandomNumberGenerator.new()
var duck_left := 0.0
var duck_db := 0.0
var music_db := 0.0
var sfx_db := 0.0


func setup(feel_data: Dictionary) -> void:
	feel = feel_data
	rng.seed = 99
	_ensure_buses()
	for name: String in feel.get("sounds", {}):
		var variants: Array = []
		for k in int(feel.sounds[name].get("variants", 1)):
			var path := "%s%s_%d.wav" % [DIR, name, k + 1]
			if ResourceLoader.exists(path): variants.append(load(path))
		streams[name] = variants
	if players.is_empty():
		for i in POOL:
			var player := AudioStreamPlayer.new()
			add_child(player)
			players.append({"player": player, "name": "", "started": 0})


static func _bus(name: String) -> int:
	return AudioServer.get_bus_index(name)


func _ensure_buses() -> void:
	for name: String in ["Music", "SFX", "UI"]:
		if _bus(name) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, name)
			AudioServer.set_bus_send(index, "Master")
	var master := _bus("Master")
	var has_limiter := false
	for i in AudioServer.get_bus_effect_count(master):
		if AudioServer.get_bus_effect(master, i) is AudioEffectHardLimiter: has_limiter = true
	if not has_limiter:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -0.5
		AudioServer.add_bus_effect(master, limiter)
	var music := _bus("Music")
	if AudioServer.get_bus_effect_count(music) == 0:
		var low := AudioEffectLowPassFilter.new()
		low.cutoff_hz = 900.0
		AudioServer.add_bus_effect(music, low)
		AudioServer.set_bus_effect_enabled(music, 0, false)


func set_volumes(music_linear: float, sfx_linear: float) -> void:
	music_db = linear_to_db(maxf(0.0001, music_linear))
	sfx_db = linear_to_db(maxf(0.0001, sfx_linear))
	AudioServer.set_bus_mute(_bus("Music"), music_linear <= 0.0)
	AudioServer.set_bus_mute(_bus("SFX"), sfx_linear <= 0.0)
	AudioServer.set_bus_mute(_bus("UI"), sfx_linear <= 0.0)
	AudioServer.set_bus_volume_db(_bus("SFX"), sfx_db)
	AudioServer.set_bus_volume_db(_bus("UI"), sfx_db)
	_apply_music_volume()


func _apply_music_volume() -> void:
	AudioServer.set_bus_volume_db(_bus("Music"), music_db + float(feel.get("music", {}).get("volume_db", -6.0)) + (duck_db if duck_left > 0.0 else 0.0))


func duck(seconds: float) -> void:
	duck_db = float(feel.get("music", {}).get("duck_db", -6.0))
	duck_left = maxf(duck_left, seconds)
	_apply_music_volume()


func low_pass(on: bool) -> void:
	var music := _bus("Music")
	if AudioServer.get_bus_effect_count(music) > 0 and AudioServer.is_bus_effect_enabled(music, 0) != on:
		AudioServer.set_bus_effect_enabled(music, 0, on)


## semitones: pitch offset (ladders); variance: random +- fraction of pitch.
func play(name: String, semitones := 0.0, variance := 0.0, volume_add := 0.0) -> bool:
	var spec: Dictionary = feel.get("sounds", {}).get(name, {})
	if spec.is_empty(): return false
	if frame_played.has(name): return false
	var active := 0
	for slot: Dictionary in players:
		if slot.name == name and slot.player.playing: active += 1
	if active >= int(spec.get("max", 2)): return false
	frame_played[name] = true
	played.append({"name": name, "pitch": semitones})
	if played.size() > 300: played.pop_front()
	var variants: Array = streams.get(name, [])
	if variants.is_empty(): return true
	var slot := _free_slot()
	var player: AudioStreamPlayer = slot.player
	player.stream = variants[rng.randi_range(0, variants.size() - 1)]
	player.bus = str(spec.get("bus", "SFX"))
	player.volume_db = float(spec.get("volume", -8.0)) + volume_add
	player.pitch_scale = clampf(pow(2.0, semitones / 12.0) * (1.0 + rng.randf_range(-variance, variance)), 0.25, 4.0)
	player.play()
	slot.name = name
	slot.started = Time.get_ticks_msec()
	return true


func _free_slot() -> Dictionary:
	var oldest: Dictionary = players[0]
	for slot: Dictionary in players:
		if not slot.player.playing: return slot
		if int(slot.started) < int(oldest.started): oldest = slot
	oldest.player.stop()
	return oldest


func _process(delta: float) -> void:
	frame += 1
	frame_played.clear()
	if duck_left > 0.0:
		duck_left -= delta
		if duck_left <= 0.0: _apply_music_volume()
