extends CanvasLayer

var mission
var root: Control
var panel: PanelContainer
var title: Label
var identity_label: Label
var content: VBoxContainer
var sound_button: Button
var feedback_box: TextEdit
var telegram_user := {"id": "guest", "name": "Guest Agent"}

func _ready() -> void:
	layer = 60
	telegram_user = _read_telegram_user()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#071017")
	root.add_child(background)
	add_child(root)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 610)
	root.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 34)
	panel.add_child(margin)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)
	title = Label.new()
	title.text = "DOODLE / COVERT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color("#8ff1d1"))
	content.add_child(title)
	identity_label = Label.new()
	identity_label.text = "AGENT: %s" % telegram_user.name
	identity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	identity_label.add_theme_font_size_override("font_size", 17)
	identity_label.add_theme_color_override("font_color", Color("#8da5ae"))
	content.add_child(identity_label)
	_add_button("PLAY", _play)
	_add_button("LEADERBOARD", _leaderboard)
	_add_button("HOW TO PLAY", _how_to_play)
	sound_button = _add_button("SOUND: ON", _toggle_sound)
	_add_button("FEEDBACK", _feedback)
	_add_button("EXIT", _exit_game)
	get_viewport().size_changed.connect(_reflow)
	_reflow()

func _add_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(450, 58)
	button.add_theme_font_size_override("font_size", 21)
	button.pressed.connect(callback)
	content.add_child(button)
	return button

func _reflow() -> void:
	var size := get_viewport().get_visible_rect().size
	var scale_value: float = clampf(minf(size.x / 1280.0, size.y / 720.0), 0.72, 1.15)
	panel.scale = Vector2.ONE * scale_value
	panel.position = (size - panel.custom_minimum_size * scale_value) * 0.5

func _play() -> void:
	mission.audio.unlock_web_audio()
	mission.start_game()
	root.hide()

func _toggle_sound() -> void:
	var enabled: bool = mission.audio.toggle_enabled()
	sound_button.text = "SOUND: ON" if enabled else "SOUND: OFF"

func _clear_content() -> void:
	for child in content.get_children(): child.queue_free()

func _screen_heading(text: String) -> void:
	_clear_content()
	var heading := Label.new()
	heading.text = text
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 34)
	heading.add_theme_color_override("font_color", Color("#8ff1d1"))
	content.add_child(heading)

func _leaderboard() -> void:
	_screen_heading("LEADERBOARD")
	var info := Label.new()
	info.text = "1. %s    %d\n\nGlobal Telegram rankings activate\nwhen the bot backend is connected." % [telegram_user.name, mission.best]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 20)
	content.add_child(info)
	_add_button("BACK", _restore_main)

func _how_to_play() -> void:
	_screen_heading("HOW TO PLAY")
	var info := Label.new()
	info.text = "• Move quietly with the left joystick.\n• Hold RUN only when you must escape.\n• Stay outside every vision cone.\n• Collect all 3 intel cases.\n• Extract through the door at the top of the hall.\n• Guards investigate noise, then return to their posts."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 19)
	info.custom_minimum_size.y = 300
	content.add_child(info)
	_add_button("BACK", _restore_main)

func _feedback() -> void:
	_screen_heading("FEEDBACK")
	feedback_box = TextEdit.new()
	feedback_box.placeholder_text = "Tell us what should improve..."
	feedback_box.custom_minimum_size = Vector2(450, 240)
	feedback_box.add_theme_font_size_override("font_size", 18)
	content.add_child(feedback_box)
	_add_button("SEND TO BOT", _send_feedback)
	_add_button("BACK", _restore_main)

func _send_feedback() -> void:
	var message := feedback_box.text.strip_edges()
	if message.is_empty():
		feedback_box.placeholder_text = "Write feedback first."
		return
	var payload := JSON.stringify({"action": "feedback", "telegram_user_id": telegram_user.id, "message": message})
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(function(){if(window.Telegram&&Telegram.WebApp&&Telegram.WebApp.sendData){Telegram.WebApp.sendData(%s);return true;}return false;})()" % JSON.stringify(payload), true)
	feedback_box.text = ""
	feedback_box.placeholder_text = "Feedback prepared for the bot."

func _restore_main() -> void:
	_clear_content()
	title = Label.new()
	title.text = "DOODLE / COVERT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color("#8ff1d1"))
	content.add_child(title)
	identity_label = Label.new()
	identity_label.text = "AGENT: %s" % telegram_user.name
	identity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	identity_label.add_theme_font_size_override("font_size", 17)
	content.add_child(identity_label)
	_add_button("PLAY", _play)
	_add_button("LEADERBOARD", _leaderboard)
	_add_button("HOW TO PLAY", _how_to_play)
	sound_button = _add_button("SOUND: ON" if mission.audio.enabled else "SOUND: OFF", _toggle_sound)
	_add_button("FEEDBACK", _feedback)
	_add_button("EXIT", _exit_game)

func _exit_game() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(function(){if(window.Telegram&&Telegram.WebApp){Telegram.WebApp.close();}else{window.close();}})()")

func _read_telegram_user() -> Dictionary:
	if not OS.has_feature("web"): return telegram_user
	var raw = JavaScriptBridge.eval("(function(){var u=window.Telegram&&Telegram.WebApp&&Telegram.WebApp.initDataUnsafe?Telegram.WebApp.initDataUnsafe.user:null;if(!u)return JSON.stringify({id:'guest',name:'Guest Agent'});return JSON.stringify({id:String(u.id),name:[u.first_name,u.last_name].filter(Boolean).join(' ')||u.username||'Telegram Agent'});})()", true)
	if typeof(raw) == TYPE_STRING:
		var parsed = JSON.parse_string(raw)
		if typeof(parsed) == TYPE_DICTIONARY: return parsed
	return telegram_user
