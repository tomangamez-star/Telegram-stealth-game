extends CanvasLayer

const MENU_MAP = preload("res://assets/stealth/menu_background.png")

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
	if mission.api.player_name != "Guest Agent": telegram_user.name = mission.api.player_name
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = MENU_MAP
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color(0.32, 0.42, 0.46, 0.72)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.035, 0.05, 0.64)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	add_child(root)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 610)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.075, 0.095, 0.94)
	panel_style.border_color = Color("#65c9ad")
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 22
	panel_style.corner_radius_top_right = 22
	panel_style.corner_radius_bottom_left = 22
	panel_style.corner_radius_bottom_right = 22
	panel_style.shadow_color = Color(0, 0, 0, 0.65)
	panel_style.shadow_size = 18
	panel.add_theme_stylebox_override("panel", panel_style)
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
	button.add_theme_color_override("font_color", Color("#e8fffa"))
	button.add_theme_stylebox_override("normal", _button_style(Color("#102a32"), Color("#3e766e")))
	button.add_theme_stylebox_override("hover", _button_style(Color("#174039"), Color("#78dfbd")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#246651"), Color("#9affdc")))
	button.pressed.connect(callback)
	content.add_child(button)
	return button

func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	return style

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
	info.text = "Loading global rankings..."
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 20)
	content.add_child(info)
	mission.api.leaderboard_received.connect(func(entries):
		if not is_instance_valid(info): return
		if entries.is_empty():
			info.text = "No global scores yet.\nYour session best: %d" % mission.best
			return
		var lines: Array[String] = []
		for i in entries.size(): lines.append("%d. %s    %d" % [i + 1, entries[i].get("display_name", "Agent"), entries[i].get("best_score", 0)])
		info.text = "\n\n".join(lines), CONNECT_ONE_SHOT)
	mission.api.fetch_leaderboard()
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
	mission.api.submit_feedback(message)
	feedback_box.text = ""
	feedback_box.placeholder_text = "Feedback sent." if mission.api.connected() else "Open the game from the bot to send feedback."

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
