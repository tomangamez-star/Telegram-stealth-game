extends "res://scripts/doodle_player.gd"

# Expensive sight and route work is timer-driven. Movement stays on the
# physics tick so touch controls remain responsive.
var mission
var guard := false
var patrol := PackedVector2Array()
var patrol_index := 0
var suspicion := 0.0
var state := "PATROL"
var last_seen := Vector2.ZERO
var search_time := 0.0
var repath_time := 0.0
var sight_time := 0.0
var visual_time := 0.0
var cached_sees := false
var path := PackedVector2Array()
var path_index := 0
var stealth_pose := true
var guard_mode := "PATROL"
var look_directions := PackedVector2Array()
var look_index := 0
var look_interval := 2.7
var look_time := 2.7
var notice_announced := false

func cycle_player_visual_style() -> int:
	player_visual_style = 0
	return 0

func _physics_process(delta: float) -> void:
	if mission.finished:
		velocity = Vector2.ZERO
		return
	if not guard:
		_update_player(delta)
		return
	_update_guard(delta)

func _update_player(delta: float) -> void:
	var keyboard := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var movement: Vector2 = controls.movement_vector if controls.movement_vector.length() > 0.04 else keyboard
	var wants_run: bool = controls.run_pressed or Input.is_action_pressed("run")
	# Default motion is a quiet, cautious walk. RUN is for breaking contact.
	var speed_scale := 0.72 if not wants_run else 0.88
	stealth_pose = not wants_run
	_apply_controlled_motion(movement * speed_scale, wants_run, delta)
	mission.audio.update_player_steps(velocity.length(), is_running, delta)
	_queue_visual(delta, 30.0)

func _update_guard(delta: float) -> void:
	var target: Vector2 = mission.player.global_position
	sight_time -= delta
	if sight_time <= 0.0:
		sight_time = 0.10
		cached_sees = can_see(target) and not mission.player_hidden()
	var sees := cached_sees
	if sees:
		last_seen = target
		suspicion = minf(1.0, suspicion + delta * 1.25)
		if suspicion >= 1.0:
			if state != "CHASE":
				mission.detections += 1
				mission.audio.play_event("guard_notice_shout")
			state = "CHASE"
		search_time = 3.5
	elif state == "CHASE":
		search_time -= delta
		if search_time <= 0.0:
			state = "SEARCH"
			search_time = 4.0
	elif state == "SEARCH":
		search_time -= delta
		if search_time <= 0.0:
			state = "PATROL"
			suspicion = 0.0
	else:
		suspicion = maxf(0.0, suspicion - delta * 0.45)
		if mission.player.is_running and mission.player.velocity.length() > 100.0 and global_position.distance_to(target) < 260.0:
			last_seen = target
			state = "SEARCH"
			search_time = 3.0
			mission.audio.play_event("guard_suspicious")
	if guard_mode == "SENTRY" and state == "PATROL":
		_update_sentry(delta)
		mission.audio.update_guard_steps(self, 0.0, delta)
		_queue_visual(delta, 20.0 if OS.has_feature("web") else 30.0)
		return
	var destination: Vector2 = patrol[patrol_index] if state == "PATROL" and not patrol.is_empty() else last_seen
	if state == "PATROL" and not patrol.is_empty() and global_position.distance_to(destination) < 36.0:
		patrol_index = (patrol_index + 1) % patrol.size()
		destination = patrol[patrol_index]
	repath_time -= delta
	if repath_time <= 0.0:
		repath_time = 0.48 if OS.has_feature("web") else 0.34
		path = mission.find_path(global_position, destination)
		path_index = 0
	while path_index < path.size() and global_position.distance_to(path[path_index]) < 30.0:
		path_index += 1
	var movement := Vector2.ZERO
	if path_index < path.size(): movement = global_position.direction_to(path[path_index])
	stealth_pose = false
	_apply_controlled_motion(movement * (0.72 if state == "CHASE" else 0.40), false, delta)
	mission.audio.update_guard_steps(self, velocity.length(), delta)
	if state == "SEARCH" and global_position.distance_to(last_seen) < 45.0:
		facing = facing.rotated(delta * 1.4)
		display_facing = facing
	if state == "CHASE" and global_position.distance_to(target) < 65.0:
		mission.finish(false)
	_queue_visual(delta, 20.0 if OS.has_feature("web") else 30.0)

func _update_sentry(delta: float) -> void:
	velocity = Vector2.ZERO
	look_time -= delta
	if look_time > 0.0 or look_directions.is_empty(): return
	look_time = look_interval
	look_index = (look_index + 1) % look_directions.size()
	facing = look_directions[look_index]
	display_facing = facing

func _queue_visual(delta: float, fps: float) -> void:
	visual_time -= delta
	if visual_time > 0.0: return
	visual_time = 1.0 / fps
	visual.queue_redraw()

func can_see(target: Vector2) -> bool:
	var offset := target - global_position
	if offset.length() > 350.0: return false
	if offset.length() > 55.0 and display_facing.dot(offset.normalized()) < cos(deg_to_rad(38.0)): return false
	return mission.clear_sight(global_position, target)
