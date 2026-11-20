extends Node
## Adaptive music: four same-length loops per region (ambient, drums, lead, boss) play in sync;
## layers fade in and out with battle intensity. Stingers play on top and duck the loops.

const DIR := "res://assets/audio/x1/music/"
const LAYERS := ["ambient", "drums", "lead", "boss"]

var feel: Dictionary = {}
var region := ""
var players: Dictionary = {}     # layer -> AudioStreamPlayer
var targets: Dictionary = {}     # layer -> linear 0..1
var levels: Dictionary = {}      # layer -> linear 0..1 (current)
var stinger_player: AudioStreamPlayer
var audio = null
var mode := "off"                # off, menu, battle
var last_stinger := ""


func setup(feel_data: Dictionary, audio_director) -> void:
	feel = feel_data
	audio = audio_director
	if players.is_empty():
		for layer: String in LAYERS:
			var player := AudioStreamPlayer.new()
			player.bus = "Music"
			add_child(player)
			players[layer] = player
			levels[layer] = 0.0
			targets[layer] = 0.0
		stinger_player = AudioStreamPlayer.new()
		stinger_player.bus = "Music"
		add_child(stinger_player)


func play_region(region_id: String, new_mode: String) -> void:
	mode = new_mode
	if region_id != region:
		region = region_id
		for layer: String in LAYERS:
			var path := "%s%s_%s.wav" % [DIR, region, layer]
			var player: AudioStreamPlayer = players[layer]
			player.stop()
			player.stream = load(path) if ResourceLoader.exists(path) else null
			levels[layer] = 0.0
			player.volume_db = -80.0
		for layer: String in LAYERS:
			if players[layer].stream != null: players[layer].play()
	elif not players.ambient.playing:
		for layer: String in LAYERS:
			if players[layer].stream != null: players[layer].play()
	set_state(0.0, false, false)


func stop() -> void:
	mode = "off"
	for layer: String in LAYERS: targets[layer] = 0.0


## intensity 0..1; boss and night shadow add their own layers.
func set_state(intensity: float, boss: bool, ult: bool) -> void:
	var gates: Dictionary = feel.get("music", {}).get("layers", {})
	if mode == "menu":
		targets = {"ambient": 0.55, "drums": 0.0, "lead": 0.0, "boss": 0.0}
		return
	targets.ambient = 1.0
	targets.drums = clampf((intensity - float(gates.get("drums", 0.3)) + 0.15) / 0.3, 0.0, 1.0)
	targets.lead = 1.0 if ult else clampf((intensity - float(gates.get("lead", 0.6)) + 0.15) / 0.3, 0.0, 1.0)
	targets.boss = 1.0 if boss else 0.0
	if boss: targets.drums = maxf(targets.drums, 0.7)


func stinger(name: String) -> void:
	var path := "%sstinger_%s.wav" % [DIR, name]
	last_stinger = name
	if not ResourceLoader.exists(path) or stinger_player == null: return
	stinger_player.stream = load(path)
	stinger_player.volume_db = -2.0
	stinger_player.play()
	if audio != null: audio.duck(stinger_player.stream.get_length() * 0.8)


func _process(delta: float) -> void:
	var fade: float = maxf(0.05, float(feel.get("music", {}).get("fade", 1.2)))
	for layer: String in LAYERS:
		var player: AudioStreamPlayer = players.get(layer)
		if player == null: continue
		levels[layer] = move_toward(float(levels[layer]), float(targets.get(layer, 0.0)), delta / fade)
		player.volume_db = linear_to_db(maxf(0.0001, float(levels[layer])))
