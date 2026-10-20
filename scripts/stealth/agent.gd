extends "res://scripts/doodle_player.gd"

# Reuse the original doodle rig and movement; no style switch or sandbox actions.
var mission
var guard := false
var patrol := PackedVector2Array()
var patrol_index := 0
var suspicion := 0.0
var state := "PATROL"
var last_seen := Vector2.ZERO
var search_time := 0.0
var repath_time := 0.0
var path := PackedVector2Array()
var path_index := 0

func cycle_player_visual_style() -> int:
	player_visual_style = 0
	return 0

func _physics_process(delta: float) -> void:
	if mission.finished:
		velocity = Vector2.ZERO
		return
	if not guard:
		var keyboard := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var movement: Vector2 = controls.movement_vector if controls.movement_vector.length() > 0.04 else keyboard
		_apply_controlled_motion(movement, controls.run_pressed or Input.is_action_pressed("run"), delta)
		visual.queue_redraw()
		return
	var target: Vector2 = mission.player.global_position
	var sees: bool = can_see(target) and not mission.player_hidden()
	if sees:
		last_seen = target
		suspicion = minf(1.0, suspicion + delta * 1.25)
		if suspicion >= 1.0:
			if state != "CHASE": mission.detections += 1
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
			# Sound travels around cover, but only reveals the last heard position.
			last_seen = target
			state = "SEARCH"
			search_time = 3.0
	var destination: Vector2 = patrol[patrol_index] if state == "PATROL" else last_seen
	if state == "PATROL" and global_position.distance_to(destination) < 36.0:
		patrol_index = (patrol_index + 1) % patrol.size()
		destination = patrol[patrol_index]
	repath_time -= delta
	if repath_time <= 0.0:
		repath_time = 0.35
		path = mission.find_path(global_position, destination)
		path_index = 0
	while path_index < path.size() and global_position.distance_to(path[path_index]) < 30.0:
		path_index += 1
	var movement := Vector2.ZERO
	if path_index < path.size(): movement = global_position.direction_to(path[path_index])
	_apply_controlled_motion(movement * (0.87 if state == "CHASE" else 0.48), false, delta)
	if state == "SEARCH" and global_position.distance_to(last_seen) < 45.0:
		facing = facing.rotated(delta * 1.4)
		display_facing = facing
	if state == "CHASE" and global_position.distance_to(target) < 65.0:
		mission.finish(false)
	visual.queue_redraw()

func can_see(target: Vector2) -> bool:
	var offset := target - global_position
	if offset.length() > 350.0: return false
	if offset.length() > 55.0 and display_facing.dot(offset.normalized()) < cos(deg_to_rad(38.0)): return false
	return mission.clear_sight(global_position, target)
