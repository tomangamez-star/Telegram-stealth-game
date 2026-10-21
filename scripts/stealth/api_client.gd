extends Node

signal leaderboard_received(entries: Array)
signal feedback_finished(ok: bool)

var api_base := ""
var session_token := ""
var player_name := "Guest Agent"

func _ready() -> void:
	if not OS.has_feature("web"): return
	var raw = JavaScriptBridge.eval("JSON.stringify(Object.fromEntries(new URLSearchParams(location.search)))", true)
	if typeof(raw) != TYPE_STRING: return
	var params = JSON.parse_string(raw)
	if typeof(params) != TYPE_DICTIONARY: return
	api_base = str(params.get("api", "")).trim_suffix("/")
	session_token = str(params.get("session", ""))
	player_name = str(params.get("player_name", "Guest Agent")).uri_decode()

func connected() -> bool:
	return not api_base.is_empty() and not session_token.is_empty()

func submit_score(score: int, won: bool, sector: int, intel: int, elapsed: float, detections: int) -> void:
	_post("/api/v1/scores", {"game_key":"doodle_covert", "score":score, "won":won, "sector":sector, "intel":intel, "time_seconds":elapsed, "detections":detections})

func submit_feedback(message: String) -> void:
	if not connected():
		feedback_finished.emit(false)
		return
	var request: HTTPRequest = _post("/api/v1/feedback", {"game_key":"doodle_covert", "message":message})
	if request: request.request_completed.connect(func(_r, code, _h, _b): feedback_finished.emit(code >= 200 and code < 300), CONNECT_ONE_SHOT)

func fetch_leaderboard() -> void:
	if api_base.is_empty():
		leaderboard_received.emit([])
		return
	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(func(_r, code, _h, body):
		var entries: Array = []
		if code == 200:
			var data = JSON.parse_string(body.get_string_from_utf8())
			if typeof(data) == TYPE_DICTIONARY: entries.assign(data.get("entries", []))
		leaderboard_received.emit(entries)
		request.queue_free(), CONNECT_ONE_SHOT)
	request.request(api_base + "/api/v1/leaderboard?game=doodle_covert&limit=5")

func _post(path: String, payload: Dictionary) -> HTTPRequest:
	if not connected(): return null
	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(func(_r, _c, _h, _b): request.queue_free(), CONNECT_ONE_SHOT)
	request.request(api_base + path, ["Content-Type: application/json", "Authorization: Bearer " + session_token], HTTPClient.METHOD_POST, JSON.stringify(payload))
	return request
