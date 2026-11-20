extends SceneTree
## Generated audio: every sound variant and music file exists and loads, loops share one length
## and loop forward, stingers do not loop.

const Data := preload("res://scripts/x1/core/data.gd")

var checks := 0
var failures := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func _initialize() -> void:
	var feel: Dictionary = Data.shared().feel
	for name: String in feel.sounds:
		for k in int(feel.sounds[name].get("variants", 1)):
			var path := "res://assets/audio/x1/sfx/%s_%d.wav" % [name, k + 1]
			var stream = load(path) if ResourceLoader.exists(path) else null
			check(stream is AudioStreamWAV, "sound %s_%d loads" % [name, k + 1])
			if stream is AudioStreamWAV: check(stream.get_length() > 0.01 and stream.get_length() < 3.0, "sound %s_%d has a sensible length" % [name, k + 1])
	var length := -1.0
	for region: String in Data.shared().regions:
		for layer: String in ["ambient", "drums", "lead", "boss"]:
			var path := "res://assets/audio/x1/music/%s_%s.wav" % [region, layer]
			var stream = load(path) if ResourceLoader.exists(path) else null
			check(stream is AudioStreamWAV, "music %s %s loads" % [region, layer])
			if not stream is AudioStreamWAV: continue
			check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "music %s %s loops" % [region, layer])
			if length < 0.0: length = stream.get_length()
			check(absf(stream.get_length() - length) < 0.01, "music %s %s matches the shared loop length" % [region, layer])
	for name in feel.get("stingers", []):
		var path := "res://assets/audio/x1/music/stinger_%s.wav" % name
		var stream = load(path) if ResourceLoader.exists(path) else null
		check(stream is AudioStreamWAV and stream.loop_mode != AudioStreamWAV.LOOP_FORWARD, "stinger %s loads and plays once" % name)
	print("X1 AUDIO: %d checks, %d failures" % [checks, failures])
	Data.release()
	quit(1 if failures > 0 else 0)
