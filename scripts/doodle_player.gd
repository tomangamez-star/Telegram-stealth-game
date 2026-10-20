extends CharacterBody2D

const WALK_SPEED := 205.0
const RUN_SPEED := 345.0
const ACCELERATION := 1150.0
const DECELERATION := 1450.0
const TURN_RESPONSE := 11.0
const PART_HEAD := 0
const PART_BODY := 1
const PART_LEFT_ARM := 2
const PART_RIGHT_ARM := 3
const PART_LEFT_LEG := 4
const PART_RIGHT_LEG := 5

const VisualScript = preload("res://scripts/doodle_visual.gd")
const PersonalityScript = preload("res://scripts/doodle_personality.gd")
var personality
var appearance_id := 0
var player_visual_style := 0

var controls
var facing := Vector2(0, 1)
var display_facing := Vector2(0, 1)
var stride_phase := 0.0
var moved_distance := 0.0
var speed_ratio := 0.0
var is_running := false
var input_strength := 0.0
var visual
var was_running := false
var run_stop_amount := 0.0
var run_stop_forward := Vector2(0, 1)

var ragdoll_active := false
var ragdoll_recovering := false
var ragdoll_time := 0.0
var ragdoll_blend := 0.0
var rag_spin_rate := 0.0
var rag_positions: Array[Vector2] = []
var rag_velocities: Array[Vector2] = []
var is_npc := false
var home_position := Vector2.ZERO
var ai_direction := Vector2.ZERO
var ai_change_timer := 0.0
var route_points := PackedVector2Array()
var route_index := 0
var route_speed_scale := 0.58
var route_pause_time := 0.0
var route_pause_min := 0.0
var route_pause_max := 0.0
var world_activity_enabled := true
var npc_redraw_time := 0.0
var sidestep_time := 0.0
var sidestep_direction := 1.0
var player_blocked_last_frame := false
var behavior_state := "walk"
var behavior_timer := 0.0
var behavior_cooldown := 4.0
var behavior_destination := Vector2.ZERO
var behavior_look_direction := Vector2.DOWN
var sit_spots := PackedVector2Array()
var gather_spots := PackedVector2Array()
var behavior_rng := RandomNumberGenerator.new()
var behavior_last_position := Vector2.ZERO
var behavior_stuck_time := 0.0
var is_sitting := false
var push_target
var show_connectors := true
var clothing_color := Color("#16a9bd")
var clothing_dark := Color("#10242b")
var hair_color := Color("#15171b")
var hair_highlight := Color("#292b31")
var skin_color := Color("#e9ab7b")
var push_animation_time := 0.0
var push_pose := 0.0
var push_impact_done := false
var push_pending_target

func _ready() -> void:
	visual = VisualScript.new()
	visual.name = "ProceduralDoodle"
	visual.player = self
	add_child(visual)
	personality = PersonalityScript.new()
	personality.name = "Personality"
	add_child(personality)

	var collider := CollisionShape2D.new()
	collider.name = "CollisionShape2D"
	var shape := CircleShape2D.new()
	# Matches the visible head/limb footprint so normal doodles never overlap.
	shape.radius = 33.0
	collider.shape = shape
	add_child(collider)
	z_index = 10
	if is_npc:
		add_to_group("world_activity")

func _physics_process(delta: float) -> void:
	if not is_npc and Input.is_action_just_pressed("ui_focus_next"):
		cycle_player_visual_style()
	if not is_npc and is_instance_valid(controls) and controls.consume_style_request():
		cycle_player_visual_style()
	if not is_npc and ((is_instance_valid(controls) and controls.consume_ragdoll_request()) or Input.is_action_just_pressed("ragdoll")):
		trigger_ragdoll(display_facing * 390.0)

	if ragdoll_active:
		_update_ragdoll(delta)
		visual.queue_redraw()
		return

	if push_animation_time > 0.0:
		_update_push_animation(delta)
		visual.queue_redraw()
		return

	if is_npc:
		_update_npc(delta)
		return

	var keyboard := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var touch := Vector2.ZERO
	var touch_run := false
	if is_instance_valid(controls):
		touch = controls.movement_vector
		touch_run = controls.run_pressed

	var movement_input := touch if touch.length() > 0.04 else keyboard
	if is_sitting and movement_input.length() < 0.08:
		velocity = Vector2.ZERO
		visual.queue_redraw()
		return
	if is_sitting:
		is_sitting = false
		behavior_state = "walk"
	input_strength = clampf(movement_input.length(), 0.0, 1.0)
	is_running = input_strength > 0.12 and (touch_run or Input.is_action_pressed("run"))
	if was_running and input_strength < 0.08 and velocity.length() > 235.0:
		run_stop_amount = 1.0
		run_stop_forward = display_facing
	if run_stop_amount > 0.0:
		run_stop_amount = move_toward(run_stop_amount, 0.0, delta * 2.85)
	var target_speed := (RUN_SPEED if is_running else WALK_SPEED) * input_strength
	var target_velocity := movement_input.normalized() * target_speed if input_strength > 0.02 else Vector2.ZERO
	var rate := ACCELERATION if target_velocity.length() > velocity.length() else DECELERATION
	velocity = velocity.move_toward(target_velocity, rate * delta)

	if movement_input.length() > 0.08:
		facing = movement_input.normalized()
	var turn_blend := 1.0 - exp(-TURN_RESPONSE * delta)
	display_facing = display_facing.lerp(facing, turn_blend).normalized()

	var before := global_position
	move_and_slide()
	var travelled := global_position.distance_to(before)
	moved_distance += travelled
	if travelled > 0.001:
		stride_phase += travelled * (0.060 if is_running else 0.047)

	speed_ratio = clampf(velocity.length() / RUN_SPEED, 0.0, 1.0)
	was_running = is_running
	_apply_crate_pushes()
	_update_push_interaction()
	visual.queue_redraw()

func cycle_player_visual_style() -> int:
	if is_npc:
		return 0
	player_visual_style = (player_visual_style + 1) % 3
	if is_instance_valid(visual):
		visual.queue_redraw()
	return player_visual_style

func _update_npc(delta: float) -> void:
	behavior_cooldown = maxf(0.0, behavior_cooldown - delta)
	if behavior_state != "walk":
		_update_npc_behavior(delta)
		return
	if route_points.size() > 1:
		_update_route_npc(delta)
		return
	ai_change_timer -= delta
	if ai_change_timer <= 0.0:
		ai_change_timer = 1.35 + randf() * 1.65
		if global_position.distance_to(home_position) > 220.0:
			ai_direction = global_position.direction_to(home_position)
		elif randf() < 0.22:
			ai_direction = Vector2.ZERO
		else:
			ai_direction = Vector2.RIGHT.rotated(randf() * TAU)
	_apply_controlled_motion(ai_direction * 0.58, false, delta)
	_apply_crate_pushes()
	visual.queue_redraw()

func configure_route(points: PackedVector2Array, start_index: int, speed_scale: float, reverse: bool = false) -> void:
	route_points = points.duplicate()
	if reverse:
		route_points.reverse()
	route_index = posmod(start_index, route_points.size()) if not route_points.is_empty() else 0
	route_speed_scale = clampf(speed_scale, 0.38, 0.82)
	if not route_points.is_empty():
		global_position = route_points[route_index]
		route_index = (route_index + 1) % route_points.size()

func configure_behavior_spots(seats: PackedVector2Array, gatherings: PackedVector2Array, seed_offset: int) -> void:
	sit_spots = seats.duplicate()
	gather_spots = gatherings.duplicate()
	behavior_rng.seed = 401500 + seed_offset * 97

func start_behavior_at(kind: String, destination: Vector2, look_direction: Vector2) -> void:
	global_position = destination
	behavior_state = kind
	behavior_timer = 5.5 + behavior_rng.randf_range(0.0, 2.5)
	behavior_look_direction = look_direction.normalized() if look_direction.length_squared() > 0.01 else Vector2.DOWN
	display_facing = behavior_look_direction
	facing = behavior_look_direction
	is_sitting = kind == "sit"
	velocity = Vector2.ZERO
	if is_instance_valid(visual):
		visual.queue_redraw()

func _begin_approach(kind: String, destination: Vector2) -> void:
	behavior_state = "approach_" + kind
	behavior_destination = destination
	behavior_last_position = global_position
	behavior_stuck_time = 0.0
	is_sitting = false

func _update_npc_behavior(delta: float) -> void:
	if behavior_state.begins_with("approach_"):
		var distance := global_position.distance_to(behavior_destination)
		if distance > 15.0:
			var direction := global_position.direction_to(behavior_destination)
			_apply_controlled_motion(direction * 0.44, false, delta)
			if global_position.distance_to(behavior_last_position) < 0.35:
				behavior_stuck_time += delta
			else:
				behavior_stuck_time = 0.0
				behavior_last_position = global_position
			if behavior_stuck_time >= 1.05:
				resume_nearest_route()
			_queue_npc_redraw()
			return
		behavior_state = behavior_state.trim_prefix("approach_")
		behavior_timer = behavior_rng.randf_range(3.8, 7.0)
		behavior_look_direction = Vector2.UP if behavior_state == "sit" else Vector2.RIGHT.rotated(behavior_rng.randf_range(-0.55, 0.55))
		is_sitting = behavior_state == "sit"
	behavior_timer -= delta
	velocity = velocity.move_toward(Vector2.ZERO, DECELERATION * delta)
	display_facing = display_facing.lerp(behavior_look_direction, 1.0 - exp(-7.0 * delta)).normalized()
	facing = display_facing
	_queue_npc_redraw()
	if behavior_timer <= 0.0:
		behavior_state = "walk"
		is_sitting = false
		behavior_cooldown = behavior_rng.randf_range(5.0, 9.0)

func _nearest_behavior_spot(spots: PackedVector2Array, maximum_distance: float) -> Vector2:
	var nearest := Vector2(INF, INF)
	var best_distance := maximum_distance
	for spot in spots:
		var distance := global_position.distance_to(spot)
		if distance < best_distance:
			best_distance = distance
			nearest = spot
	return nearest

func _try_start_route_behavior() -> bool:
	if behavior_cooldown > 0.0 or behavior_rng.randf() > 0.12:
		return false
	if behavior_rng.randf() < 0.25:
		behavior_state = "idle"
		behavior_timer = 3.0
		behavior_look_direction = display_facing
		personality.emote("phone" if appearance_id % 2 == 0 else "stretch", 2.8)
		return true
	if behavior_rng.randf() < 0.46 and not sit_spots.is_empty():
		var seat := _nearest_behavior_spot(sit_spots, 390.0)
		if not is_inf(seat.x):
			_begin_approach("sit", seat)
			return true
	if not gather_spots.is_empty():
		var gathering := _nearest_behavior_spot(gather_spots, 420.0)
		if not is_inf(gathering.x):
			var side := -1.0 if get_instance_id() % 2 == 0 else 1.0
			_begin_approach("talk", gathering + Vector2(side * 36.0, 0))
			return true
	return false

func _update_route_npc(delta: float) -> void:
	npc_redraw_time -= delta
	sidestep_time = maxf(0.0, sidestep_time - delta)
	if route_pause_time > 0.0:
		route_pause_time -= delta
		_apply_controlled_motion(Vector2.ZERO, false, delta)
		_queue_npc_redraw()
		return
	var target := route_points[route_index]
	var distance := global_position.distance_to(target)
	if distance <= 18.0:
		route_index = (route_index + 1) % route_points.size()
		if _try_start_route_behavior():
			_apply_controlled_motion(Vector2.ZERO, false, delta)
			_queue_npc_redraw()
			return
		# Route nodes guide corners; they are not automatic stop signs.
		target = route_points[route_index]
		distance = global_position.distance_to(target)
	var desired := global_position.direction_to(target)
	var avoidance := Vector2.ZERO
	var blocked_ahead := false
	var player_ahead_distance := INF
	# Look ahead for poles, benches, shelters and vehicles before body contact.
	# Pick a stable side early so NPCs flow around props instead of walking into
	# them, stopping, and then sliding along the collider.
	var ray := PhysicsRayQueryParameters2D.create(global_position, global_position + desired * 132.0)
	ray.exclude = [get_rid()]
	var obstacle := get_world_2d().direct_space_state.intersect_ray(ray)
	if not obstacle.is_empty():
		blocked_ahead = true
		if sidestep_time <= 0.0:
			sidestep_time = 0.95
			var obstacle_position: Vector2 = obstacle.position
			var right := Vector2(-desired.y, desired.x)
			sidestep_direction = -1.0 if right.dot(obstacle_position - global_position) > 0.0 else 1.0
	for candidate in get_tree().get_nodes_in_group("doodles"):
		if candidate == self or not candidate.visible:
			continue
		var separation: Vector2 = global_position - candidate.global_position
		var separation_length: float = separation.length()
		var awareness := 154.0 if not candidate.is_npc else 126.0
		if separation_length > 0.01 and separation_length < awareness:
			var separation_direction := separation.normalized()
			var strength := 1.0 - separation_length / awareness
			avoidance += separation_direction * strength * (1.85 if not candidate.is_npc else 1.25)
			if desired.dot(-separation_direction) > 0.45 and separation_length < 112.0:
				blocked_ahead = true
				if not candidate.is_npc:
					player_ahead_distance = minf(player_ahead_distance, separation_length)
	player_blocked_last_frame = player_ahead_distance < INF
	if blocked_ahead and sidestep_time <= 0.0:
		sidestep_time = 0.85
		sidestep_direction = -1.0 if get_instance_id() % 2 == 0 else 1.0
	# At body-contact distance pedestrians wait instead of bulldozing the player.
	# Farther away they use the same soft side-step used for another pedestrian.
	if player_ahead_distance < 50.0:
		_apply_controlled_motion(Vector2.ZERO, false, delta)
		_queue_npc_redraw()
		return
	var side := Vector2(-desired.y, desired.x) * sidestep_direction
	var sidestep := side * 0.92 if sidestep_time > 0.0 else Vector2.ZERO
	desired = (desired + avoidance * 1.15 + sidestep).normalized()
	_apply_controlled_motion(desired * route_speed_scale, false, delta)
	_apply_crate_pushes()
	_queue_npc_redraw()

func _queue_npc_redraw() -> void:
	# Procedural doodles are expensive on Web; 30 visual updates per second still
	# reads as smooth while physics and routing continue at the full tick rate.
	if npc_redraw_time > 0.0:
		return
	npc_redraw_time = 1.0 / (20.0 if OS.has_feature("web") else 30.0)
	visual.queue_redraw()

func set_world_activity(active: bool) -> void:
	if not is_npc or world_activity_enabled == active:
		return
	world_activity_enabled = active
	visible = active
	set_physics_process(active)
	if not active:
		velocity = Vector2.ZERO

func _apply_controlled_motion(movement_input: Vector2, wants_run: bool, delta: float) -> void:
	input_strength = clampf(movement_input.length(), 0.0, 1.0)
	is_running = input_strength > 0.12 and wants_run
	var target_speed := (RUN_SPEED if is_running else WALK_SPEED) * input_strength
	var target_velocity := movement_input.normalized() * target_speed if input_strength > 0.02 else Vector2.ZERO
	var rate := ACCELERATION if target_velocity.length() > velocity.length() else DECELERATION
	velocity = velocity.move_toward(target_velocity, rate * delta)
	if movement_input.length() > 0.08:
		facing = movement_input.normalized()
	var turn_blend := 1.0 - exp(-TURN_RESPONSE * delta)
	display_facing = display_facing.lerp(facing, turn_blend).normalized()
	var before := global_position
	move_and_slide()
	var travelled := global_position.distance_to(before)
	moved_distance += travelled
	if travelled > 0.001:
		stride_phase += travelled * (0.060 if is_running else 0.047)
	speed_ratio = clampf(velocity.length() / RUN_SPEED, 0.0, 1.0)
	was_running = is_running

func _update_push_interaction() -> void:
	push_target = null
	var closest := 112.0
	for candidate in get_tree().get_nodes_in_group("npc"):
		if candidate == self or candidate.ragdoll_active:
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance < closest:
			closest = distance
			push_target = candidate
	if is_instance_valid(controls):
		controls.set_push_visible(push_target != null)
		if controls.consume_push_request() or Input.is_action_just_pressed("push"):
			push_nearby_npc()

func push_nearby_npc() -> bool:
	if push_animation_time > 0.0 or not is_instance_valid(push_target) or push_target.ragdoll_active:
		return false
	var direction := global_position.direction_to(push_target.global_position)
	if direction.length_squared() < 0.1:
		direction = display_facing
	facing = direction
	display_facing = direction
	push_pending_target = push_target
	push_animation_time = 0.001
	push_pose = 0.0
	push_impact_done = false
	velocity = Vector2.ZERO
	z_index = 12
	if is_instance_valid(controls):
		controls.set_push_visible(false)
	return true

func _update_push_animation(delta: float) -> void:
	push_animation_time += delta
	velocity = Vector2.ZERO
	# Extend quickly, hold contact briefly, then retract cleanly.
	if push_animation_time < 0.15:
		push_pose = clampf(push_animation_time / 0.15, 0.0, 1.0)
	elif push_animation_time < 0.23:
		push_pose = 1.0
	else:
		push_pose = clampf(1.0 - (push_animation_time - 0.23) / 0.16, 0.0, 1.0)
	if not push_impact_done and push_animation_time >= 0.16:
		push_impact_done = true
		if is_instance_valid(push_pending_target) and not push_pending_target.ragdoll_active:
			var direction := global_position.direction_to(push_pending_target.global_position)
			push_pending_target.trigger_ragdoll(direction * 390.0)
	if push_animation_time >= 0.40:
		push_animation_time = 0.0
		push_pose = 0.0
		push_impact_done = false
		push_pending_target = null
		z_index = 10

func set_connectors_enabled(enabled: bool) -> void:
	show_connectors = enabled
	if is_instance_valid(visual):
		visual.queue_redraw()

func _apply_crate_pushes() -> void:
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var body := collision.get_collider()
		if body is RigidBody2D and body.is_in_group("pushable_crate"):
			var strength := 4.8 if is_running else 1.7
			body.apply_central_impulse(-collision.get_normal() * velocity.length() * strength * 0.01)

func trigger_ragdoll(impulse: Vector2) -> void:
	if ragdoll_active:
		return
	is_sitting = false
	if is_instance_valid(personality): personality.emote("surprise", 2.0)
	if not is_npc and is_instance_valid(controls):
		controls.set_push_visible(false)
	run_stop_amount = 0.0
	is_running = false
	was_running = false
	ragdoll_active = true
	ragdoll_recovering = false
	ragdoll_time = 0.0
	ragdoll_blend = 1.0
	rag_spin_rate = 7.5

	var forward: Vector2 = display_facing
	var right := Vector2(-forward.y, forward.x)
	var body := -forward * 5.0
	rag_positions = [
		forward * 10.0,
		body,
		body - right * 27.0,
		body + right * 27.0,
		body - forward * 17.0 - right * 10.0,
		body - forward * 17.0 + right * 10.0
	]
	rag_velocities = [
		forward * 74.0 + right * 24.0,
		-forward * 18.0,
		-right * 128.0 - forward * 30.0,
		right * 115.0 + forward * 18.0,
		-right * 52.0 - forward * 105.0,
		right * 67.0 - forward * 91.0
	]
	velocity = impulse

func _update_ragdoll(delta: float) -> void:
	ragdoll_time += delta
	velocity = velocity.move_toward(Vector2.ZERO, 245.0 * delta)
	move_and_slide()
	display_facing = display_facing.rotated(rag_spin_rate * delta).normalized()
	rag_spin_rate = move_toward(rag_spin_rate, 0.0, 4.2 * delta)

	if not ragdoll_recovering:
		for i in rag_positions.size():
			var swirl := Vector2(-rag_positions[i].y, rag_positions[i].x) * rag_spin_rate * 0.08
			rag_velocities[i] += swirl * delta
			rag_positions[i] += rag_velocities[i] * delta
			rag_velocities[i] *= exp(-3.0 * delta)
		_apply_spring(PART_BODY, PART_HEAD, 22.0, 31.0, delta)
		_apply_spring(PART_BODY, PART_LEFT_ARM, 28.0, 27.0, delta)
		_apply_spring(PART_BODY, PART_RIGHT_ARM, 28.0, 27.0, delta)
		_apply_spring(PART_BODY, PART_LEFT_LEG, 29.0, 25.0, delta)
		_apply_spring(PART_BODY, PART_RIGHT_LEG, 29.0, 25.0, delta)
		# Keeps the loose body centred on the moving collision body.
		rag_velocities[PART_BODY] += -rag_positions[PART_BODY] * 13.0 * delta
		if (ragdoll_time >= 1.55 and velocity.length() < 95.0) or ragdoll_time >= 2.10:
			ragdoll_recovering = true
	else:
		var targets := _standing_part_positions()
		for i in rag_positions.size():
			rag_positions[i] = rag_positions[i].lerp(targets[i], 1.0 - exp(-8.5 * delta))
			rag_velocities[i] = Vector2.ZERO
		ragdoll_blend = move_toward(ragdoll_blend, 0.0, delta * 1.65)
		if ragdoll_blend <= 0.001:
			ragdoll_active = false
			ragdoll_recovering = false
			ragdoll_blend = 0.0
			ragdoll_time = 0.0
			if is_npc:
				resume_nearest_route()

func resume_nearest_route() -> void:
	behavior_state = "walk"
	is_sitting = false
	behavior_stuck_time = 0.0
	route_pause_time = 0.0
	velocity = Vector2.ZERO
	if route_points.is_empty(): return
	var best_index := 0
	var best_distance := INF
	for index in route_points.size():
		var distance := global_position.distance_squared_to(route_points[index])
		if distance < best_distance:
			best_distance = distance
			best_index = index
	route_index = best_index

func _apply_spring(a: int, b: int, rest_length: float, strength: float, delta: float) -> void:
	var difference := rag_positions[b] - rag_positions[a]
	var distance := maxf(difference.length(), 0.001)
	var direction := difference / distance
	var force := direction * (distance - rest_length) * strength * delta
	rag_velocities[a] += force
	rag_velocities[b] -= force

func _standing_part_positions() -> Array[Vector2]:
	var forward: Vector2 = display_facing
	var right := Vector2(-forward.y, forward.x)
	var body := -forward * 5.0
	return [
		forward * 10.0,
		body,
		body - right * 27.0,
		body + right * 27.0,
		body - forward * 17.0 - right * 10.0,
		body - forward * 17.0 + right * 10.0
	]
