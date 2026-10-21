extends Node2D

var mission
var refresh_time := 0.0

func _process(delta: float) -> void:
	refresh_time -= delta
	if refresh_time > 0.0: return
	refresh_time = 1.0 / (15.0 if OS.has_feature("web") else 24.0)
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(mission): return
	for guard in mission.guards:
		if not is_instance_valid(guard): continue
		var polygon := PackedVector2Array([guard.position])
		for i in 10:
			var direction: Vector2 = guard.display_facing.rotated(deg_to_rad(-38.0 + float(i) * 76.0 / 9.0))
			polygon.append(mission.sight_endpoint(guard.position, guard.position + direction * 350.0))
		draw_colored_polygon(polygon, Color(1.0, 0.25, 0.23, 0.22) if guard.state == "CHASE" else Color(1.0, 0.83, 0.36, 0.12))
		var bar: Vector2 = guard.position + Vector2(-27, -49)
		draw_rect(Rect2(bar, Vector2(54, 6)), Color("#10232c"))
		draw_rect(Rect2(bar, Vector2(54 * guard.suspicion, 6)), Color("#ff8877"))
	for intel in mission.remaining:
		draw_circle(intel, 29 + sin(mission.elapsed * 3.0) * 2.0, Color(0.35, 0.9, 0.85, 0.16))
		draw_rect(Rect2(intel - Vector2(18, 13), Vector2(36, 26)), Color("#8ff1df"))
		draw_string(ThemeDB.fallback_font, intel + Vector2(-20, -35), "INTEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#aefff1"))
	var exit_color := Color("#78e9ae") if mission.collected == 3 else Color("#72838e")
	draw_circle(mission.EXIT, 72, Color(exit_color, 0.12))
	draw_arc(mission.EXIT, 68, 0, TAU, 32, exit_color, 3, true)
	draw_string(ThemeDB.fallback_font, mission.EXIT + Vector2(-45, 7), "EXTRACT" if mission.collected == 3 else "LOCKED", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, exit_color)
