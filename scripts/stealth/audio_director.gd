extends Node

const AUDIO_ROOT := "res://assets/audio/"
const EVENT_NAMES := [
	"player_stealth_steps", "player_run_steps", "guard_steps", "guard_cough",
	"guard_notice_shout", "guard_suspicious", "intel_collect",
	"mission_complete", "mission_failed"
]

var mission
var streams := {}
var players := {}
var guard_step_players := {}
var cough_time := 35.0
var enabled := true

func _ready() -> void:
	for event_name in EVENT_NAMES:
		var stream = _load_optional(event_name)
		if stream == null: continue
		streams[event_name] = stream
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.bus = "Master"
		add_child(player)
		players[event_name] = player

func _load_optional(stem: String):
	for candidate in [stem, stem.replace("_", "-")]:
		for extension in [".wav", ".mp3"]:
			var path: String = AUDIO_ROOT + candidate + extension
			# Exported Web resources are remapped inside index.pck. FileAccess can
			# report false even though ResourceLoader can resolve the imported asset.
			if ResourceLoader.exists(path): return ResourceLoader.load(path)
	return null

func play_event(event_name: String) -> void:
	if not enabled or not players.has(event_name): return
	var player: AudioStreamPlayer = players[event_name]
	if player.playing and event_name in ["guard_steps", "player_run_steps"]: return
	player.play()

func update_player_steps(speed: float, running: bool, delta: float) -> void:
	# Movement tracks are treated as loops and stopped on the exact frame movement ends.
	# Stealth walking intentionally stays silent in this level.
	if not players.has("player_run_steps"): return
	var player: AudioStreamPlayer = players["player_run_steps"]
	if enabled and running and speed >= 25.0:
		if not player.playing: player.play()
	elif player.playing:
		player.stop()

func toggle_enabled() -> bool:
	enabled = not enabled
	for player in players.values():
		player.volume_db = 0.0 if enabled else -80.0
	for player in guard_step_players.values():
		player.volume_db = 0.0 if enabled else -80.0
	if not enabled: stop_movement()
	return enabled

func unlock_web_audio() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(function(){var c=window.godotAudioContext||window.audioContext;if(c&&c.state==='suspended')c.resume();if(window.Telegram&&Telegram.WebApp)Telegram.WebApp.expand();})()")

func update_guard_steps(guard, speed: float, delta: float) -> void:
	var key: int = guard.get_instance_id()
	if streams.has("guard_steps") and not guard_step_players.has(key):
		var step_player := AudioStreamPlayer.new()
		step_player.stream = streams["guard_steps"]
		step_player.bus = "Master"
		add_child(step_player)
		guard_step_players[key] = step_player
	if guard_step_players.has(key):
		var step_player: AudioStreamPlayer = guard_step_players[key]
		if enabled and speed > 20.0:
			if not step_player.playing: step_player.play()
		elif step_player.playing:
			step_player.stop()
	cough_time -= delta
	if cough_time <= 0.0 and guard.guard_mode == "SENTRY":
		play_event("guard_cough")
		cough_time = randf_range(30.0, 40.0)

func stop_movement() -> void:
	if players.has("player_run_steps"): players["player_run_steps"].stop()
	for player in guard_step_players.values(): player.stop()
