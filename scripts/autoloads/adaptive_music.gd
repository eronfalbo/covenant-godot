extends Node
## AdaptiveMusicManager — 5-layer adaptive music system.
## Each layer responds independently to game state. The MIX is the music.
##
## Layer 1: EARTH (Outer Hostility responsive — always present)
## Layer 2: SKY (time-of-day + OH responsive)
## Layer 3: FAMILY (social state responsive)
## Layer 4: FIRE (covenant-integrity / pillar responsive)
## Layer 5: SILENCE (OH responsive — absence of sound)

# ── Audio buses ──
# Set up in project: Master > Earth, Sky, Family, Fire, Silence
const BUS_EARTH := "Earth"
const BUS_SKY := "Sky"
const BUS_FAMILY := "Family"
const BUS_FIRE := "Fire"
const BUS_SILENCE := "Silence"

# ── Crossfade ──
const FADE_TIME := 3.0
const FAST_FADE := 0.5

# ── Players (two per layer for crossfading) ──
var _earth: Array[AudioStreamPlayer] = []
var _sky: Array[AudioStreamPlayer] = []
var _family: Array[AudioStreamPlayer] = []
var _fire: Array[AudioStreamPlayer] = []
var _silence: Array[AudioStreamPlayer] = []

# Active player index (0 or 1) per layer
var _earth_idx := 0
var _sky_idx := 0
var _family_idx := 0
var _fire_idx := 0
var _silence_idx := 0

# Currently playing track name per layer (to avoid redundant crossfades)
var _earth_current := ""
var _sky_current := ""
var _family_current := ""
var _fire_current := ""
var _silence_current := ""

# ── Scene overrides ──
var scene_override := ""  # "tent_before", "tent_breach", "tent_after", "sabbath", "festival", ""
var _scene_player: AudioStreamPlayer  # For one-shot scene scores

# ── The 0.1% tone — enters after tent scene, never leaves ──
var _crack_player: AudioStreamPlayer
var _crack_active := false

# ── Audio root path ──
const AUDIO_ROOT := "res://assets/audio/music/"


func _ready() -> void:
	# Create dual players per layer for crossfading
	_earth = _create_player_pair(BUS_EARTH)
	_sky = _create_player_pair(BUS_SKY)
	_family = _create_player_pair(BUS_FAMILY)
	_fire = _create_player_pair(BUS_FIRE)
	_silence = _create_player_pair(BUS_SILENCE)

	# Scene score player
	_scene_player = AudioStreamPlayer.new()
	_scene_player.bus = &"Master"
	add_child(_scene_player)

	# The 0.1% crack tone
	_crack_player = AudioStreamPlayer.new()
	_crack_player.bus = &"Master"
	_crack_player.volume_db = -24.0
	add_child(_crack_player)

	# Listen for game state changes
	GameState.state_changed.connect(_on_state_changed)
	GameState.flag_set.connect(_on_flag_set)

	# Initial update
	_update_all_layers()


func _create_player_pair(bus_name: String) -> Array[AudioStreamPlayer]:
	var pair: Array[AudioStreamPlayer] = []
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = &"Master"  # Use Master until buses are configured
		p.volume_db = -80.0 if i == 1 else 0.0
		add_child(p)
		pair.append(p)
	return pair


# ── Public API ──

func set_scene_override(scene: String) -> void:
	scene_override = scene
	_update_all_layers()

	if scene == "tent_before":
		_play_scene_score("scenes/tent_build")
	elif scene == "tent_breach":
		_cut_all_layers()
		# The white screen moment — absolute silence
	elif scene == "tent_after":
		_start_crack_tone()
		_play_scene_score("scenes/tent_aftermath")
	elif scene == "sabbath":
		_play_scene_score("scenes/sabbath")
	elif scene == "":
		_update_all_layers()


func trigger_shofar() -> void:
	_play_sfx("scenes/shofar")


func trigger_festival(festival_type: String) -> void:
	scene_override = "festival"
	_play_scene_score("scenes/festival_" + festival_type)
	_update_all_layers()


# ── State listeners ──

func _on_state_changed() -> void:
	_update_all_layers()


func _on_flag_set(flag_name: String, _value: Variant) -> void:
	if flag_name == "ham_incident":
		# The tent scene — activate the 0.1% crack
		_start_crack_tone()


# ── Layer updates ──

func _update_all_layers() -> void:
	_update_earth()
	_update_sky()
	_update_family()
	_update_fire()
	_update_silence()


func _update_earth() -> void:
	if scene_override == "tent_breach":
		_fade_out_layer(_earth, _earth_idx)
		return

	var bracket := _get_oh_bracket()
	var target := "earth/earth_" + bracket
	if target != _earth_current:
		_earth_current = target
		_earth_idx = _crossfade_layer(_earth, _earth_idx, target)

	# Volume: always present, louder as OH rises
	var vol := lerpf(-6.0, 0.0, clampf(GameState.outer_hostility / 30.0, 0.0, 1.0))
	_earth[_earth_idx].volume_db = vol


func _update_sky() -> void:
	if scene_override in ["tent_breach", "tent_after"]:
		_fade_out_layer(_sky, _sky_idx)
		return

	var tod := _get_time_of_day()
	var bracket := _get_oh_bracket()
	var target := "sky/sky_" + tod + "_" + bracket
	if target != _sky_current:
		_sky_current = target
		_sky_idx = _crossfade_layer(_sky, _sky_idx, target)

	# Volume drops as OH rises
	var vol := lerpf(0.0, -20.0, clampf(GameState.outer_hostility / 30.0, 0.0, 1.0))
	_sky[_sky_idx].volume_db = vol


func _update_family() -> void:
	if scene_override in ["tent_breach", "tent_after"]:
		_fade_out_layer(_family, _family_idx)
		return

	var state := _get_family_state()
	var target := "family/family_" + state
	if target != _family_current:
		_family_current = target
		_family_idx = _crossfade_layer(_family, _family_idx, target)

	# Volume drops as OH rises
	var vol := lerpf(0.0, -15.0, clampf(GameState.outer_hostility / 20.0, 0.0, 1.0))
	_family[_family_idx].volume_db = vol


func _update_fire() -> void:
	if scene_override == "tent_breach":
		_fade_out_layer(_fire, _fire_idx)
		return

	var state := _get_fire_state()
	var target := "fire/fire_" + state
	if target != _fire_current:
		_fire_current = target
		_fire_idx = _crossfade_layer(_fire, _fire_idx, target)

	if scene_override == "tent_after":
		_fire[_fire_idx].volume_db = -18.0  # Embers
	elif scene_override == "tent_before":
		_fire[_fire_idx].volume_db = 3.0  # Roaring
	else:
		_fire[_fire_idx].volume_db = 0.0


func _update_silence() -> void:
	# Silence layer grows as OH rises — it's the ABSENCE of the other layers
	# Implemented as room tone / wind that fills gaps left by fading layers
	var bracket := _get_oh_bracket()
	var target := "silence/silence_" + bracket
	if target != _silence_current:
		_silence_current = target
		_silence_idx = _crossfade_layer(_silence, _silence_idx, target)

	# Louder as OH rises
	var vol := lerpf(-30.0, -3.0, clampf(GameState.outer_hostility / 30.0, 0.0, 1.0))
	_silence[_silence_idx].volume_db = vol


# ── Bracket / state helpers ──

func _get_oh_bracket() -> String:
	var oh: float = GameState.outer_hostility
	if oh <= 1.0: return "warm"
	if oh <= 5.0: return "neutral"
	if oh <= 15.0: return "uneasy"
	if oh <= 30.0: return "threatening"
	return "hostile"


func _get_time_of_day() -> String:
	# Map season to time-of-day feel
	match GameState.season_idx:
		0: return "dusk"    # Autumn
		1: return "night"   # Winter
		2: return "dawn"    # Spring
		3: return "day"     # Summer
	return "day"


func _get_family_state() -> String:
	var hr: int = GameState.ham_relation
	if hr >= 70: return "united"
	if hr >= 50: return "strained"
	if hr >= 30: return "fractured"
	return "fractured"


func _get_fire_state() -> String:
	var ci: float = GameState.living_fire
	if ci >= 80: return "strong"
	if ci >= 50: return "steady"
	if ci >= 25: return "flickering"
	return "embers"


# ── Audio crossfade system ──

func _crossfade_layer(players: Array[AudioStreamPlayer], current_idx: int, track_name: String) -> int:
	var path := AUDIO_ROOT + track_name + ".ogg"
	if not ResourceLoader.exists(path):
		# Gracefully handle missing audio
		return current_idx

	var next_idx := 1 - current_idx
	var old_player := players[current_idx]
	var new_player := players[next_idx]

	# Load and start new track
	new_player.stream = load(path)
	new_player.volume_db = -80.0
	new_player.play()

	# Crossfade
	var tween := create_tween().set_parallel(true)
	tween.tween_property(old_player, "volume_db", -80.0, FADE_TIME)
	tween.tween_property(new_player, "volume_db", 0.0, FADE_TIME)

	# Stop old player when fade completes
	tween.chain().tween_callback(old_player.stop)

	return next_idx


func _fade_out_layer(players: Array[AudioStreamPlayer], current_idx: int) -> void:
	var player := players[current_idx]
	if player.playing:
		var tween := create_tween()
		tween.tween_property(player, "volume_db", -80.0, FAST_FADE)
		tween.tween_callback(player.stop)


func _cut_all_layers() -> void:
	# Instant silence — used for tent breach
	for layer in [_earth, _sky, _family, _fire, _silence]:
		for p in layer:
			p.volume_db = -80.0
			p.stop()
	if _scene_player.playing:
		_scene_player.stop()


func _start_crack_tone() -> void:
	if _crack_active:
		return
	var path := AUDIO_ROOT + "scenes/crack_tone.ogg"
	if not ResourceLoader.exists(path):
		return
	_crack_active = true
	_crack_player.stream = load(path)
	_crack_player.volume_db = -24.0
	_crack_player.play()


func _play_scene_score(track_name: String) -> void:
	var path := AUDIO_ROOT + track_name + ".ogg"
	if not ResourceLoader.exists(path):
		return
	_scene_player.stream = load(path)
	_scene_player.play()


func _play_sfx(track_name: String) -> void:
	var path := AUDIO_ROOT + track_name + ".ogg"
	if not ResourceLoader.exists(path):
		return
	# Use scene player for one-shots
	var sfx := AudioStreamPlayer.new()
	sfx.stream = load(path)
	sfx.bus = &"Master"
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)
