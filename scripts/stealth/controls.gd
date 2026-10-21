extends CanvasLayer

var movement_vector := Vector2.ZERO
var run_pressed := false
var joystick_touch := -1
var run_touch := -1
var joystick_center := Vector2.ZERO
var joystick_knob := Vector2.ZERO
var run_center := Vector2.ZERO
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
var ui_scale := 1.0

func _ready() -> void:
	layer = 30
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	hud.draw.connect(_draw_controls)
	status_label = _label(28, Color("#8af4c7"))
	stats_label = _label(21, Color("#d4e1e4"))
	hint_label = _label(18, Color("#a9bac0"))
	hint_label.text = "Collect 3 intel cases and return to extraction. Stay outside the guards' vision."
	summary = PanelContainer.new()
	summary.custom_minimum_size = Vector2(520, 300)
	summary.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 28)
	summary.add_child(margin)
	margin.add_child(box)
	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 32)
	box.add_child(result_label)
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 21)
	box.add_child(score_label)
	restart_button = Button.new()
	restart_button.custom_minimum_size.y = 64
	restart_button.pressed.connect(mission.restart)
	box.add_child(restart_button)
	hud.add_child(summary)
	summary.hide()
	get_viewport().size_changed.connect(_reflow)
	_reflow()

func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	hud.add_child(label)
	return label

func _reflow() -> void:
	var size := get_viewport().get_visible_rect().size
	ui_scale = clampf(minf(size.x / 1280.0, size.y / 650.0), 0.85, 1.35)
	var edge := 34.0 * ui_scale
	var radius := 102.0 * ui_scale
	joystick_center = Vector2(edge + radius, size.y - edge - radius)
	joystick_knob = joystick_center
	run_center = Vector2(size.x - edge - radius, size.y - edge - radius)
	status_label.position = Vector2(28, 20) * ui_scale
	stats_label.position = Vector2(28, 61) * ui_scale
	hint_label.position = Vector2(28, 96) * ui_scale
	summary.scale = Vector2.ONE * ui_scale
	summary.position = (size - summary.custom_minimum_size * ui_scale) * 0.5
	hud.queue_redraw()

func reset_for_sector() -> void:
	movement_vector = Vector2.ZERO
	run_pressed = false
	joystick_knob = joystick_center
	last_status = ""
	last_stats = ""
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
	var status := "DOODLE / COVERT   ·   " + ("CHASE — BREAK SIGHT!" if chased else ("SUSPICIOUS" if alert > 0.15 else "UNDETECTED"))
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
	var touch_radius := 112.0 * ui_scale
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.distance_to(run_center) < touch_radius and run_touch < 0:
				run_touch = event.index
				run_pressed = true
				hud.queue_redraw()
			elif event.position.x < get_viewport().get_visible_rect().size.x * 0.48 and joystick_touch < 0:
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
			hud.queue_redraw()
	elif event is InputEventScreenDrag and event.index == joystick_touch:
		_update_stick(event.position)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reset_for_sector()
		joystick_touch = -1
		run_touch = -1

func _update_stick(pos: Vector2) -> void:
	var travel := 92.0 * ui_scale
	movement_vector = ((pos - joystick_center) / travel).limit_length(1.0)
	joystick_knob = joystick_center + movement_vector * travel
	hud.queue_redraw()

func _draw_controls() -> void:
	if mission.finished: return
	var outer := 104.0 * ui_scale
	hud.draw_circle(joystick_center, outer, Color(0.04, 0.10, 0.14, 0.78))
	hud.draw_arc(joystick_center, outer, 0, TAU, 40, Color(0.55, 0.9, 0.8, 0.70), 4.0 * ui_scale, true)
	hud.draw_circle(joystick_knob, 42.0 * ui_scale, Color(0.55, 0.9, 0.8, 0.78))
	hud.draw_circle(run_center, 82.0 * ui_scale, Color("#377b66") if run_pressed else Color(0.06, 0.18, 0.20, 0.90))
	hud.draw_arc(run_center, 82.0 * ui_scale, 0, TAU, 36, Color("#81d9b8"), 4.0 * ui_scale, true)
	hud.draw_string(ThemeDB.fallback_font, run_center + Vector2(-30, 9) * ui_scale, "RUN", HORIZONTAL_ALIGNMENT_LEFT, -1, int(27 * ui_scale), Color.WHITE)

func show_result(won: bool) -> void:
	reset_for_sector()
	result_label.text = "SECTOR CLEARED" if won else "CAUGHT"
	score_label.text = "Score: %d  ·  Session best: %d\nDetections: %d  ·  Time: %ds\nTelegram ranking: not connected yet" % [mission.score, mission.best, mission.detections, int(mission.elapsed)]
	restart_button.text = "NEXT SECTOR" if won else "RETRY SECTOR"
	summary.show()
	restart_button.grab_focus()
