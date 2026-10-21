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
var player_step_time := 0.0
var guard_step_times := {}
var cough_time := 8.0
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
			if FileAccess.file_exists(path): return load(path)
	return null

func play_event(event_name: String) -> void:
	if not enabled or not players.has(event_name): return
	var player: AudioStreamPlayer = players[event_name]
	if player.playing and event_name in ["guard_steps", "player_run_steps"]: return
	player.play()

func update_player_steps(speed: float, running: bool, delta: float) -> void:
	player_step_time -= delta
	# Stealth walking intentionally stays silent until it receives its own sound.
	if not running or speed < 25.0 or player_step_time > 0.0: return
	play_event("player_run_steps")
	player_step_time = 0.26

func toggle_enabled() -> bool:
	enabled = not enabled
	for player in players.values():
		player.volume_db = 0.0 if enabled else -80.0
	return enabled

func unlock_web_audio() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(function(){var c=window.godotAudioContext||window.audioContext;if(c&&c.state==='suspended')c.resume();if(window.Telegram&&Telegram.WebApp)Telegram.WebApp.expand();})()")

func update_guard_steps(guard, speed: float, delta: float) -> void:
	var key: int = guard.get_instance_id()
	guard_step_times[key] = float(guard_step_times.get(key, 0.0)) - delta
	if speed > 20.0 and guard_step_times[key] <= 0.0:
		play_event("guard_steps")
		guard_step_times[key] = 0.48
	cough_time -= delta
	if cough_time <= 0.0 and guard.guard_mode == "SENTRY":
		play_event("guard_cough")
		cough_time = randf_range(9.0, 16.0)
