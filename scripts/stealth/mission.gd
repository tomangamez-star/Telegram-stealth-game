extends Node2D

const Agent = preload("res://scripts/stealth/agent.gd")
const Controls = preload("res://scripts/stealth/controls.gd")
const Overlay = preload("res://scripts/stealth/overlay.gd")
const AudioDirector = preload("res://scripts/stealth/audio_director.gd")
const MAP_TEXTURE = preload("res://assets/stealth/room_map.png")

const MAP_SIZE := Vector2(1600, 1200)
const CELL := 25
const WALLS := [
	Rect2(0, 0, 1600, 40), Rect2(0, 1160, 1600, 40),
	Rect2(0, 0, 40, 1200), Rect2(1560, 0, 40, 1200),
	Rect2(620, 40, 40, 80), Rect2(620, 220, 40, 200),
	Rect2(620, 520, 40, 200), Rect2(620, 820, 40, 200), Rect2(620, 1120, 40, 40),
	Rect2(940, 40, 40, 80), Rect2(940, 220, 40, 200),
	Rect2(940, 520, 40, 200), Rect2(940, 820, 40, 200), Rect2(940, 1120, 40, 40),
	Rect2(40, 290, 580, 30), Rect2(980, 290, 580, 30),
	Rect2(40, 590, 580, 30), Rect2(980, 590, 580, 30),
	Rect2(40, 890, 580, 30), Rect2(980, 890, 580, 30),
]
const FURNITURE := [
	Rect2(75, 75, 175, 52), Rect2(1350, 75, 175, 52),
	Rect2(75, 1050, 175, 52), Rect2(1350, 1050, 175, 52),
]
const INTEL := [Vector2(340, 170), Vector2(1260, 470), Vector2(340, 770)]
const EXIT := Vector2(800, 1090)

var player
var controls
var audio
var guards: Array = []
var remaining: Array[Vector2] = []
var collected := 0
var detections := 0
var elapsed := 0.0
var score := 0
var best := 0
var level := 1
var finished := false
var won := false
var grid := AStarGrid2D.new()
var actors: Node2D
var camera: Camera2D

func _ready() -> void:
	if OS.has_feature("web"): Engine.max_fps = 45
	RenderingServer.set_default_clear_color(Color("#081015"))
	Input.emulate_touch_from_mouse = true
	_add_map_sprite(MAP_TEXTURE, -20)
	_build_navigation_and_collision()
	audio = AudioDirector.new()
	audio.mission = self
	add_child(audio)
	controls = Controls.new()
	controls.mission = self
	add_child(controls)
	_start_sector()
	var overlay = Overlay.new()
	overlay.mission = self
	overlay.z_index = 5
	add_child(overlay)

func _add_map_sprite(texture: Texture2D, layer: int) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.z_index = layer
	add_child(sprite)

func _build_navigation_and_collision() -> void:
	grid.region = Rect2i(0, 0, 64, 48)
	grid.cell_size = Vector2(CELL, CELL)
	grid.offset = Vector2(CELL * 0.5, CELL * 0.5)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for solid in WALLS + FURNITURE: _add_collider(solid)
	for y in 48:
		for x in 64:
			var point := Vector2(x * CELL + CELL * 0.5, y * CELL + CELL * 0.5)
			for solid in WALLS + FURNITURE:
				if solid.grow(30).has_point(point):
					grid.set_point_solid(Vector2i(x, y))
					break

func _add_collider(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	body.collision_layer = 1
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
	body.add_child(collider)
	add_child(body)

func _start_sector() -> void:
	finished = false
	won = false
	collected = 0
	detections = 0
	elapsed = 0.0
	remaining.assign(INTEL)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	actors.z_index = 10
	add_child(actors)
	player = Agent.new()
	player.mission = self
	player.controls = controls
	player.name = "OriginalDoodle"
	player.position = Vector2(800, 1060)
	player.collision_layer = 2
	player.collision_mask = 1
	player.add_to_group("player_doodle")
	actors.add_child(player)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.zoom = Vector2(1.12, 1.12)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(MAP_SIZE.x)
	camera.limit_bottom = int(MAP_SIZE.y)
	player.add_child(camera)
	camera.make_current()
	_add_guard([Vector2(735, 170), Vector2(735, 1010)])
	_add_guard([Vector2(1120, 170), Vector2(1450, 170)])
	_add_sentry(Vector2(860, 605), [Vector2.LEFT, Vector2.RIGHT], 2.7)
	controls.reset_for_sector()

func _add_guard(route: Array) -> void:
	var guard = _guard_base()
	guard.patrol = PackedVector2Array(route)
	guard.position = route[0]
	guard.facing = (route[1] - route[0]).normalized()
	guard.display_facing = guard.facing
	actors.add_child(guard)
	guards.append(guard)

func _add_sentry(at: Vector2, directions: Array, interval: float) -> void:
	var guard = _guard_base()
	guard.guard_mode = "SENTRY"
	guard.position = at
	guard.look_directions = PackedVector2Array(directions)
	guard.look_interval = interval
	guard.facing = directions[0]
	guard.display_facing = directions[0]
	actors.add_child(guard)
	guards.append(guard)

func _guard_base():
	var guard = Agent.new()
	guard.mission = self
	guard.guard = true
	guard.is_npc = true
	guard.appearance_id = 0
	guard.clothing_color = Color("#bf6571")
	guard.clothing_dark = Color("#442e40")
	guard.collision_layer = 4
	guard.collision_mask = 1
	return guard

func _physics_process(delta: float) -> void:
	if finished: return
	elapsed += delta
	for i in range(remaining.size() - 1, -1, -1):
		if player.position.distance_to(remaining[i]) < 58.0:
			remaining.remove_at(i)
			collected += 1
			score += 100
			audio.play_event("intel_collect")
	if collected == 3 and player.position.distance_to(EXIT) < 78.0: finish(true)

func clear_sight(from: Vector2, to: Vector2) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(from, to, 1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func sight_endpoint(from: Vector2, to: Vector2) -> Vector2:
	var ray := PhysicsRayQueryParameters2D.create(from, to, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	return to if hit.is_empty() else Vector2(hit.position)

func player_hidden() -> bool:
	return false

func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start := Vector2i(clampi(int(from.x / CELL), 0, 63), clampi(int(from.y / CELL), 0, 47))
	var end := Vector2i(clampi(int(to.x / CELL), 0, 63), clampi(int(to.y / CELL), 0, 47))
	start = _nearest_walkable(start)
	end = _nearest_walkable(end)
	return grid.get_point_path(start, end)

func _nearest_walkable(cell: Vector2i) -> Vector2i:
	if not grid.is_point_solid(cell): return cell
	for radius in range(1, 7):
		for y in range(cell.y - radius, cell.y + radius + 1):
			for x in range(cell.x - radius, cell.x + radius + 1):
				var candidate := Vector2i(x, y)
				if grid.is_in_boundsv(candidate) and not grid.is_point_solid(candidate): return candidate
	return cell

func finish(success: bool) -> void:
	if finished: return
	finished = true
	won = success
	if won: score += 500 + maxi(0, 300 - int(elapsed)) + (250 if detections == 0 else 0)
	best = maxi(best, score)
	audio.play_event("mission_complete" if won else "mission_failed")
	controls.show_result(won)

func restart() -> void:
	if not finished: return
	if won: level += 1
	else: score = 0
	guards.clear()
	remove_child(actors)
	actors.queue_free()
	controls.summary.hide()
	_start_sector()
