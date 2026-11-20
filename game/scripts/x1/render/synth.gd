extends Node
## Tiny synthesised sound effects: a few voices of sine/square/noise with pitch slides.

const RATE := 22050.0
const SOUNDS := {
	"swipe": {"freq": 260.0, "to": 200.0, "time": 0.05, "wave": "noise", "gain": 0.22},
	"pounce": {"freq": 420.0, "to": 900.0, "time": 0.12, "wave": "noise", "gain": 0.35},
	"land": {"freq": 150.0, "to": 90.0, "time": 0.1, "wave": "sine", "gain": 0.5},
	"bite": {"freq": 330.0, "to": 220.0, "time": 0.08, "wave": "square", "gain": 0.3},
	"hurt": {"freq": 180.0, "to": 110.0, "time": 0.16, "wave": "square", "gain": 0.45},
	"defeat": {"freq": 520.0, "to": 640.0, "time": 0.04, "wave": "sine", "gain": 0.18},
	"prey": {"freq": 660.0, "to": 990.0, "time": 0.16, "wave": "sine", "gain": 0.45},
	"ult": {"freq": 120.0, "to": 300.0, "time": 0.35, "wave": "square", "gain": 0.5},
	"ready": {"freq": 880.0, "to": 1180.0, "time": 0.12, "wave": "sine", "gain": 0.35},
	"pickup": {"freq": 1100.0, "to": 1300.0, "time": 0.03, "wave": "sine", "gain": 0.12},
	"level": {"freq": 700.0, "to": 1050.0, "time": 0.2, "wave": "sine", "gain": 0.4},
	"warn": {"freq": 560.0, "to": 560.0, "time": 0.05, "wave": "square", "gain": 0.12},
	"boss": {"freq": 200.0, "to": 140.0, "time": 0.3, "wave": "square", "gain": 0.45},
	"net": {"freq": 520.0, "to": 1040.0, "time": 0.3, "wave": "sine", "gain": 0.45},
	"click": {"freq": 900.0, "to": 700.0, "time": 0.03, "wave": "sine", "gain": 0.2},
}

var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var voices: Array = []
var volume := 0.7
var noise := RandomNumberGenerator.new()
var cooldowns: Dictionary = {}


func _ready() -> void:
	if DisplayServer.get_name() == "headless": return
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = RATE
	stream.buffer_length = 0.08
	player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -14.0
	add_child(player)
	player.play()
	playback = player.get_stream_playback() as AudioStreamGeneratorPlayback


func _exit_tree() -> void:
	if is_instance_valid(player):
		player.stop()
		player.stream = null
	playback = null


func play(name: String) -> void:
	if not SOUNDS.has(name) or volume <= 0.0: return
	var now := Time.get_ticks_msec()
	if now - int(cooldowns.get(name, 0)) < 35: return
	cooldowns[name] = now
	var sound: Dictionary = SOUNDS[name]
	if voices.size() >= 6: voices.pop_front()
	voices.append({"freq": float(sound.freq), "to": float(sound.to), "time": float(sound.time), "left": float(sound.time),
		"wave": sound.wave, "gain": float(sound.gain), "phase": 0.0})


func _process(_delta: float) -> void:
	if playback == null: return
	var frames := playback.get_frames_available()
	for i in frames:
		var sample := 0.0
		for v: Dictionary in voices:
			if float(v.left) <= 0.0: continue
			var progress: float = 1.0 - float(v.left) / float(v.time)
			var freq: float = lerpf(float(v.freq), float(v.to), progress)
			v.phase = fmod(float(v.phase) + freq / RATE, 1.0)
			var value: float
			match str(v.wave):
				"square": value = 1.0 if float(v.phase) < 0.5 else -1.0
				"noise": value = noise.randf_range(-1.0, 1.0)
				_: value = sin(float(v.phase) * TAU)
			var envelope: float = minf(1.0, float(v.left) * 40.0) * minf(1.0, progress * 60.0 + 0.2)
			sample += value * envelope * float(v.gain)
			v.left = float(v.left) - 1.0 / RATE
		playback.push_frame(Vector2.ONE * clampf(sample * volume * 0.5, -1.0, 1.0))
	for i in range(voices.size() - 1, -1, -1):
		if float(voices[i].left) <= 0.0: voices.remove_at(i)
