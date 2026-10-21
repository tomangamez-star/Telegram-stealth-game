extends CanvasLayer

var movement_vector := Vector2.ZERO
var run_pressed := false
var hide_requested := false
var hide_active := false
var hide_available := false
var joystick_touch := -1
var run_touch := -1
var hide_touch := -1
var joystick_center := Vector2.ZERO
var joystick_knob := Vector2.ZERO
var run_center := Vector2.ZERO
var hide_center := Vector2.ZERO
var mission
var hud: Control
var summary: PanelContainer
var status_label: Label
var stats_label: Label
var result_label: Label
var score_label: Label
var hint_label: Label
var restart_button: Button
var ui_time := 0.0
var last_status := ""
var last_stats := ""

func _ready() -> void:
	layer = 30
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	hud.draw.connect(_draw_controls)
	status_label = _label(Vector2(26, 20), 25, Color("#8af4c7"))
	stats_label = _label(Vector2(26, 56), 18, Color("#d4e1e4"))
	hint_label = _label(Vector2(26, 87), 16, Color("#92a6ae"))
	hint_label.text = "Sneak through rooms, collect 3 intel cases, then extract. Lockers are the only hiding places."
	summary = PanelContainer.new()
	summary.custom_minimum_size = Vector2(470, 270)
	summary.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 24)
	summary.add_child(margin)
	margin.add_child(box)
	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 28)
	box.add_child(result_label)
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 19)
	box.add_child(score_label)
	restart_button = Button.new()
	restart_button.text = "TRY AGAIN"
	restart_button.custom_minimum_size.y = 54
	restart_button.pressed.connect(mission.restart)
	box.add_child(restart_button)
	hud.add_child(summary)
	summary.hide()
	get_viewport().size_changed.connect(_reflow)
	_reflow()

func _label(pos: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	hud.add_child(label)
	return label

func _reflow() -> void:
	var size := get_viewport().get_visible_rect().size
	joystick_center = Vector2(125, size.y - 125)
	joystick_knob = joystick_center
	run_center = Vector2(size.x - 120, size.y - 125)
	hide_center = Vector2(size.x - 255, size.y - 125)
	summary.position = (size - summary.custom_minimum_size) * 0.5
	hud.queue_redraw()

func _process(delta: float) -> void:
	ui_time -= delta
	if ui_time > 0.0 or not is_instance_valid(mission.player): return
	ui_time = 0.12
	var alert := 0.0
	var chased := false
	for guard in mission.guards:
		alert = maxf(alert, guard.suspicion)
		chased = chased or guard.state == "CHASE"
	var status := "DOODLE / COVERT   ·   " + ("CHASE — BREAK SIGHT!" if chased else ("INSIDE LOCKER" if mission.player_hidden() else ("SUSPICIOUS" if alert > 0.15 else "UNDETECTED")))
	var stats := "SECTOR %02d    INTEL %d / 3    SCORE %d    %ds" % [mission.level, mission.collected, mission.score, int(mission.elapsed)]
	if status != last_status:
		last_status = status
		status_label.text = status
		status_label.modulate = Color("#ff877a") if chased else Color.WHITE
	if stats != last_stats:
		last_stats = stats
		stats_label.text = stats

func _input(event: InputEvent) -> void:
	if mission.finished: return
	if event is InputEventScreenTouch:
		if event.pressed:
			if (hide_available or hide_active) and event.position.distance_to(hide_center) < 70.0 and hide_touch < 0:
				hide_touch = event.index
				hide_requested = true
			elif event.position.distance_to(run_center) < 75.0 and run_touch < 0 and not hide_active:
				run_touch = event.index
				run_pressed = true
			elif event.position.x < get_viewport().get_visible_rect().size.x * 0.48 and joystick_touch < 0 and not hide_active:
				joystick_touch = event.index
				_update_stick(event.position)
		else:
			if event.index == joystick_touch:
				joystick_touch = -1
				movement_vector = Vector2.ZERO
				joystick_knob = joystick_center
			if event.index == run_touch:
				run_touch = -1
				run_pressed = false
			if event.index == hide_touch: hide_touch = -1
	elif event is InputEventScreenDrag and event.index == joystick_touch:
		_update_stick(event.position)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		movement_vector = Vector2.ZERO
		run_pressed = false
		joystick_touch = -1
		run_touch = -1
		hide_touch = -1

func _update_stick(pos: Vector2) -> void:
	movement_vector = ((pos - joystick_center) / 75.0).limit_length(1.0)
	joystick_knob = joystick_center + movement_vector * 75.0
	hud.queue_redraw()

func set_hide_state(active: bool, available: bool) -> void:
	if hide_active == active and hide_available == available: return
	hide_active = active
	hide_available = available
	if active:
		movement_vector = Vector2.ZERO
		run_pressed = false
	hud.queue_redraw()

func consume_hide_request() -> bool:
	if not hide_requested: return false
	hide_requested = false
	return true

func _draw_controls() -> void:
	if mission.finished: return
	hud.draw_circle(joystick_center, 80, Color(0.06, 0.12, 0.16, 0.70))
	hud.draw_arc(joystick_center, 80, 0, TAU, 32, Color(0.55, 0.9, 0.8, 0.5), 2, true)
	hud.draw_circle(joystick_knob, 30, Color(0.55, 0.9, 0.8, 0.65))
	hud.draw_circle(run_center, 57, Color(0.08, 0.22, 0.24, 0.85) if not run_pressed else Color("#377b66"))
	hud.draw_arc(run_center, 57, 0, TAU, 28, Color("#81d9b8"), 2, true)
	hud.draw_string(ThemeDB.fallback_font, run_center + Vector2(-22, 7), "RUN", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	if hide_available or hide_active:
		hud.draw_circle(hide_center, 57, Color("#50406d") if not hide_active else Color("#7a5998"))
		hud.draw_arc(hide_center, 57, 0, TAU, 28, Color("#c6a7e3"), 2, true)
		var text := "EXIT" if hide_active else "HIDE"
		hud.draw_string(ThemeDB.fallback_font, hide_center + Vector2(-22, 7), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)

func show_result(won: bool) -> void:
	movement_vector = Vector2.ZERO
	run_pressed = false
	result_label.text = "SECTOR CLEARED" if won else "CAUGHT"
	score_label.text = "Score: %d  ·  Session best: %d\nDetections: %d  ·  Time: %ds\nTelegram ranking: not connected yet" % [mission.score, mission.best, mission.detections, int(mission.elapsed)]
	restart_button.text = "NEXT SECTOR" if won else "RETRY SECTOR"
	summary.show()
	restart_button.grab_focus()
