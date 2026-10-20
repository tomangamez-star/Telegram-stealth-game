extends Node2D
const Atlas = preload("res://scripts/doodle_atlas.gd")
const DirectionalAtlas = preload("res://scripts/directional_rig_atlas.gd")

var player
var light_manager

func _ready() -> void:
	var lights := get_tree().get_nodes_in_group("world_light")
	if not lights.is_empty():
		light_manager = lights[0]

func _draw() -> void:
	if not is_instance_valid(player):
		return

	var moving: float = clampf(player.velocity.length() / 45.0, 0.0, 1.0)
	var personality = player.personality
	var gait_style: int = player.appearance_id % 3
	var visual_mode: int = 0 if player.is_npc else player.player_visual_style
	var idle_breath: float = sin(personality.clock * 2.1) * (1.0 - moving)
	var run_blend: float = clampf((player.velocity.length() - 180.0) / 140.0, 0.0, 1.0)
	var phase: float = player.stride_phase
	var forward: Vector2 = player.display_facing
	var right: Vector2 = Vector2(-forward.y, forward.x)
	var step_wave: float = sin(phase)
	if gait_style == 1: step_wave = sin(phase) * 0.75
	elif gait_style == 2: step_wave = sin(phase) * 1.15
	var opposite: float = sin(phase + PI)
	var cadence: float = absf(sin(phase * 2.0))
	var stop_tug: float = 4.0 * player.run_stop_amount * (1.0 - player.run_stop_amount)
	if stop_tug > 0.001:
		forward = forward.lerp(player.run_stop_forward, 0.72).normalized()
		right = Vector2(-forward.y, forward.x)
	if visual_mode == 2:
		forward = _snap_direction(forward)
		right = Vector2(-forward.y, forward.x)

	var body_center: Vector2 = -forward * (5.0 + 4.0 * run_blend)
	var head_center: Vector2 = forward * (8.0 + 9.0 * run_blend)
	body_center += right * idle_breath * 0.85
	head_center += forward * idle_breath * 0.7
	body_center += forward * stop_tug * 3.5
	head_center += forward * stop_tug * 8.5
	head_center += right * step_wave * 1.8 * moving
	var bounce: float = cadence * (1.4 + 1.8 * run_blend) * moving
	bounce *= [1.0, 0.55, 1.65][gait_style]
	body_center -= forward * bounce * 0.25
	head_center -= forward * bounce * 0.12

	# Soft shadow is grounded independently from the bouncing body.
	var shadow_offset := Vector2(2, 10)
	if is_instance_valid(light_manager):
		shadow_offset = light_manager.get_shadow_offset(8.5)
	draw_set_transform(shadow_offset, 0.0, Vector2(1, 1))
	draw_circle(Vector2.ZERO, 30.0, Color(0.10, 0.055, 0.025, 0.26))
	draw_circle(Vector2.ZERO, 23.0, Color(0.06, 0.035, 0.02, 0.19))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var stride: float = (8.0 + 11.0 * run_blend) * moving
	stride *= [1.0, 0.72, 1.18][gait_style]
	var leg_side: float = 10.0
	var left_leg: Vector2 = body_center - forward * 15.0 - right * leg_side + forward * step_wave * stride
	var right_leg: Vector2 = body_center - forward * 15.0 + right * leg_side + forward * opposite * stride
	var left_arm: Vector2 = body_center - right * 27.0 - forward * (step_wave * (5.0 + 6.0 * run_blend) * moving)
	var right_arm: Vector2 = body_center + right * 27.0 + forward * (step_wave * (5.0 + 6.0 * run_blend) * moving)
	if personality.gesture == "wave":
		right_arm += forward * 17.0 + right * sin(personality.clock * 10.0) * 7.0
	elif personality.gesture == "stretch":
		left_arm -= right * 8.0
		right_arm += right * 8.0
	elif personality.gesture == "phone":
		right_arm = body_center + forward * 29.0 + right * 13.0

	if player.is_sitting:
		# Compressed torso and forward feet make the bench pose readable overhead.
		body_center -= forward * 4.0
		head_center -= forward * 2.0
		left_leg = body_center - forward * 23.0 - right * 14.0
		right_leg = body_center - forward * 23.0 + right * 14.0
		left_arm = body_center - right * 24.0
		right_arm = body_center + right * 24.0

	if player.ragdoll_blend > 0.0 and player.rag_positions.size() == 6:
		var blend: float = player.ragdoll_blend
		head_center = head_center.lerp(player.rag_positions[player.PART_HEAD], blend)
		body_center = body_center.lerp(player.rag_positions[player.PART_BODY], blend)
		left_arm = left_arm.lerp(player.rag_positions[player.PART_LEFT_ARM], blend)
		right_arm = right_arm.lerp(player.rag_positions[player.PART_RIGHT_ARM], blend)
		left_leg = left_leg.lerp(player.rag_positions[player.PART_LEFT_LEG], blend)
		right_leg = right_leg.lerp(player.rag_positions[player.PART_RIGHT_LEG], blend)
		var loose_forward: Vector2 = (head_center - body_center).normalized()
		if loose_forward.length_squared() > 0.1:
			forward = forward.lerp(loose_forward, blend).normalized()
			right = Vector2(-forward.y, forward.x)

	if player.push_pose > 0.001:
		var push_target_left := body_center + forward * 32.0 - right * 8.5
		var push_target_right := body_center + forward * 32.0 + right * 8.5
		left_arm = left_arm.lerp(push_target_left, player.push_pose)
		right_arm = right_arm.lerp(push_target_right, player.push_pose)
		body_center += forward * player.push_pose * 3.5
		head_center += forward * player.push_pose * 2.0

	# Optional rounded doodle connectors remain behind the endpoint circles.
	if player.show_connectors:
		draw_line(body_center, left_leg, Color("#303844"), 8.0, true)
		draw_line(body_center, right_leg, Color("#303844"), 8.0, true)
		draw_line(body_center, left_arm, player.skin_color.darkened(0.12), 7.0, true)
		draw_line(body_center, right_arm, player.skin_color.darkened(0.12), 7.0, true)

	if visual_mode != 2:
		_draw_shoe(left_leg, forward, false)
		_draw_shoe(right_leg, forward, true)

	# Classic retains the original abstract rotating doodle. Detailed and Rig use
	# a smaller head so the shoulders and clothing read clearly at phone scale.
	if visual_mode == 0:
		draw_circle(body_center, 22.0, player.clothing_dark)
		draw_circle(body_center + forward * 2.0, 19.0, player.clothing_color)
	elif visual_mode == 1:
		_draw_part(3 + gait_style, body_center - forward * 3.0, forward, Vector2(62, 50) * (1.0 + idle_breath * 0.012))
		if player.appearance_id % 2 == 1:
			_draw_part(7, body_center - forward * 16.0, forward, Vector2(30, 31))
	else:
		_draw_directional_part(8 + _direction_index(forward), body_center - forward * 2.0, Vector2(65, 74))

	if visual_mode != 2:
		_draw_arm(left_arm, right * -1.0, player.skin_color.darkened(0.11))
		_draw_arm(right_arm, right, player.skin_color.darkened(0.11))
		if personality.gesture == "phone": _draw_part(8, right_arm + forward * 4.0, forward, Vector2(11, 19))

	# Head, skin rim and directional forehead highlight.
	var head_forward: Vector2 = forward.rotated(personality.head_angle * (1.0 - player.ragdoll_blend))
	if visual_mode == 2:
		head_forward = _snap_direction(head_forward)
	var head_right := Vector2(-head_forward.y, head_forward.x)
	if visual_mode == 0:
		draw_circle(head_center, 29.5, player.skin_color.darkened(0.55))
		draw_circle(head_center, 27.0, player.skin_color)
		draw_circle(head_center + head_right * 25.0, 4.0, player.skin_color)
		draw_circle(head_center - head_right * 25.0, 4.0, player.skin_color)
		_draw_hair(head_center, head_forward, head_right, run_blend, step_wave * moving)
	elif visual_mode == 1:
		# Hair overlaps the head edge; no exposed skin halo around the raster hair.
		draw_circle(head_center, 20.0, player.skin_color.darkened(0.50))
		draw_circle(head_center, 18.5, player.skin_color)
		draw_circle(head_center + head_right * 18.0, 3.5, player.skin_color)
		draw_circle(head_center - head_right * 18.0, 3.5, player.skin_color)
		_draw_part(gait_style, head_center - head_forward * 2.0, head_forward, Vector2(48, 50))
	else:
		_draw_directional_part(_direction_index(head_forward), head_center, Vector2(52, 54))

	# Tiny direction cue: barely visible while idle, clearer with forward run posture.
	var cue_alpha: float = 0.12 + 0.12 * run_blend
	draw_arc(head_center + forward * 10.0, 7.0, forward.angle() - 0.35, forward.angle() + 0.35, 8, Color(0.20, 0.09, 0.05, cue_alpha), 1.6)

	if player.behavior_state == "talk":
		var bubble := head_center + right * 30.0 + forward * 25.0
		draw_circle(bubble, 10.0, Color(0.96, 0.93, 0.82, 0.86))
		draw_circle(bubble + Vector2(-11, 9), 4.0, Color(0.96, 0.93, 0.82, 0.72))
		var dot_count := get_talk_dot_count(Time.get_ticks_msec())
		var first_x := -float(dot_count - 1) * 2.2
		for dot in dot_count:
			draw_circle(bubble + Vector2(first_x + float(dot) * 4.4, 0), 1.4, Color(0.28, 0.24, 0.20, 0.75))
	if personality.gesture == "surprise":
		var marker := head_center + Vector2(36, -35)
		draw_line(marker, marker + Vector2(0, 10), Color("#ffd36d"), 4.0, true)
		draw_circle(marker + Vector2(0, 16), 2.5, Color("#ffd36d"))

func _draw_part(index: int, center: Vector2, forward: Vector2, size: Vector2) -> void:
	draw_set_transform(center, forward.angle() + PI * 0.5, Vector2.ONE)
	draw_texture_rect(Atlas.get_part(index), Rect2(-size * 0.5, size), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_directional_part(index: int, center: Vector2, size: Vector2) -> void:
	draw_texture_rect(DirectionalAtlas.get_part(index), Rect2(center - size * 0.5, size), false)

func _direction_index(direction: Vector2) -> int:
	# Atlas order: N, NE, E, SE, S, SW, W, NW.
	return posmod(int(roundf((direction.angle() + PI * 0.5) / (PI / 4.0))), 8)

func _snap_direction(direction: Vector2) -> Vector2:
	var step := PI / 4.0
	return Vector2.RIGHT.rotated(roundf(direction.angle() / step) * step)

func _draw_shoe(center: Vector2, forward: Vector2, right_shoe: bool) -> void:
	var pair := Atlas.get_part(6)
	var region := Rect2(Vector2(pair.get_width() * (0.5 if right_shoe else 0.0), 0), Vector2(pair.get_width() * 0.5, pair.get_height()))
	draw_set_transform(center, forward.angle() + PI * 0.5, Vector2.ONE)
	draw_texture_rect_region(pair, Rect2(-7, -11, 14, 22), region)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func get_talk_dot_count(milliseconds: int) -> int:
	# Classic (...) -> (..) -> (.) -> (..) -> (...) conversation rhythm.
	var sequence := [3, 2, 1, 2, 3]
	return sequence[(milliseconds / 340) % sequence.size()]

func _draw_limb(center: Vector2, forward: Vector2, radius: float, cloth: Color, shoe: Color) -> void:
	draw_circle(center, radius + 2.0, Color(0.12, 0.10, 0.10, 0.42))
	draw_circle(center, radius, cloth)
	draw_circle(center + forward * 4.0, radius * 0.58, shoe)

func _draw_arm(center: Vector2, outward: Vector2, skin: Color) -> void:
	draw_circle(center, 7.5, Color(0.14, 0.08, 0.05, 0.38))
	draw_circle(center, 6.4, skin)
	draw_circle(center + outward * 3.0, 2.0, Color(1.0, 0.77, 0.59, 0.36))

func _draw_hair(center: Vector2, forward: Vector2, right: Vector2, run_blend: float, wave: float) -> void:
	var hair: Color = player.hair_color
	var hair_light: Color = player.hair_highlight
	# Back mass and chunky anime tufts preserve a readable silhouette at phone scale.
	draw_circle(center - forward * 5.0, 27.2, hair)
	for i in 9:
		var side: float = (float(i) - 4.0) / 4.0
		var root: Vector2 = center + right * side * 23.0 - forward * (8.0 + absf(side) * 3.0)
		var sway: Vector2 = right * wave * (0.45 + run_blend * 0.8)
		var tip: Vector2 = root - forward * (10.0 + (1.0 - absf(side)) * 8.0) + sway
		var tangent: Vector2 = right * (5.0 - absf(side) * 1.5)
		var points: PackedVector2Array = PackedVector2Array([root - tangent, root + tangent, tip])
		draw_colored_polygon(points, hair)
	# Crown tufts.
	for side_value in [-1.0, 0.0, 1.0]:
		var side: float = float(side_value)
		var base: Vector2 = center - forward * 22.0 + right * side * 8.0
		var tip: Vector2 = base - forward * (9.0 + (1.0 - absf(side)) * 5.0) + right * side * 2.0
		draw_colored_polygon(PackedVector2Array([base - right * 5.0, base + right * 5.0, tip]), hair)
	draw_arc(center - forward * 5.0, 18.0, 0.0, TAU, 24, hair_light, 2.2)
