extends Node2D

const Agent = preload("res://scripts/stealth/agent.gd")
const Controls = preload("res://scripts/stealth/controls.gd")
const Overlay = preload("res://scripts/stealth/overlay.gd")
const MAP_TEXTURE = preload("res://assets/stealth/room_map.png")
const COVER_TEXTURE = preload("res://assets/stealth/room_cover.png")

# A real eight-room office plan. Every break in these walls is a visible door.
const WALLS := [
	Rect2(0, 0, 1800, 40), Rect2(0, 1160, 1800, 40),
	Rect2(0, 0, 40, 1200), Rect2(1760, 0, 40, 1200),
	Rect2(430, 40, 40, 320), Rect2(430, 500, 40, 660),
	Rect2(880, 40, 40, 220), Rect2(880, 400, 40, 420), Rect2(880, 960, 40, 200),
	Rect2(1330, 40, 40, 420), Rect2(1330, 600, 40, 560),
	Rect2(40, 580, 180, 40), Rect2(350, 580, 80, 40),
	Rect2(470, 580, 170, 40), Rect2(770, 580, 110, 40),
	Rect2(920, 580, 160, 40), Rect2(1210, 580, 120, 40),
	Rect2(1370, 580, 140, 40), Rect2(1640, 580, 120, 40),
]
const FURNITURE := [
	Rect2(120, 120, 180, 75), Rect2(560, 150, 190, 78),
	Rect2(1010, 690, 190, 80), Rect2(1460, 130, 180, 78),
	Rect2(130, 780, 175, 75), Rect2(560, 930, 190, 78),
	Rect2(1460, 760, 170, 78),
]
const LOCKERS := [Vector2(355, 255), Vector2(790, 1040), Vector2(1240, 185), Vector2(1680, 940)]
const INTEL := [Vector2(250, 320), Vector2(1090, 900), Vector2(1550, 320)]
const EXIT := Vector2(1650, 1080)
const CELL := 25

var player
var controls
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
var interaction_time := 0.0

func _ready() -> void:
	if OS.has_feature("web"): Engine.max_fps = 45
	RenderingServer.set_default_clear_color(Color("#0b1117"))
	Input.emulate_touch_from_mouse = true
	_add_map_sprite(MAP_TEXTURE, -20)
	_build_navigation_and_collision()
	controls = Controls.new()
	controls.mission = self
	add_child(controls)
	_start_sector()
	var overlay = Overlay.new()
	overlay.mission = self
	overlay.z_index = 5
	add_child(overlay)
	_add_map_sprite(COVER_TEXTURE, 30)

func _add_map_sprite(texture: Texture2D, layer: int) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.z_index = layer
	add_child(sprite)

func _build_navigation_and_collision() -> void:
	grid.region = Rect2i(0, 0, 72, 48)
	grid.cell_size = Vector2(CELL, CELL)
	grid.offset = Vector2(CELL * 0.5, CELL * 0.5)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for solid in WALLS + FURNITURE:
		_add_collider(solid)
	for y in 48:
		for x in 72:
			var point := Vector2(x * CELL + CELL * 0.5, y * CELL + CELL * 0.5)
			for solid in WALLS + FURNITURE:
				if solid.grow(34).has_point(point):
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
	player.position = Vector2(250, 1080)
	player.collision_layer = 2
	player.collision_mask = 1
	player.add_to_group("player_doodle")
	actors.add_child(player)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.zoom = Vector2(0.90, 0.90)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 1800
	camera.limit_bottom = 1200
	player.add_child(camera)
	camera.make_current()
	_add_guard([Vector2(220, 420), Vector2(370, 420), Vector2(370, 250), Vector2(220, 250)])
	_add_guard([Vector2(610, 420), Vector2(810, 420), Vector2(810, 300), Vector2(610, 300)])
	_add_guard([Vector2(1500, 430), Vector2(1690, 430), Vector2(1690, 260), Vector2(1500, 260)])
	for i in mini(level - 1, 3):
		_add_guard([Vector2(1010, 1040), Vector2(1260, 1040), Vector2(1260, 720), Vector2(1010, 720)], i)

func _add_guard(route: Array, start_index: int = 0) -> void:
	var guard = Agent.new()
	guard.mission = self
	guard.guard = true
	guard.is_npc = true
	guard.appearance_id = 0
	guard.clothing_color = Color("#bf6571")
	guard.clothing_dark = Color("#442e40")
	guard.patrol = PackedVector2Array(route)
	guard.patrol_index = start_index % route.size()
	guard.position = route[guard.patrol_index]
	guard.facing = (route[(guard.patrol_index + 1) % route.size()] - guard.position).normalized()
	guard.display_facing = guard.facing
	guard.collision_layer = 4
	guard.collision_mask = 1
	actors.add_child(guard)
	guards.append(guard)

func _physics_process(delta: float) -> void:
	if finished: return
	elapsed += delta
	for i in range(remaining.size() - 1, -1, -1):
		if player.position.distance_to(remaining[i]) < 58.0:
			remaining.remove_at(i)
			collected += 1
			score += 100
	if collected == 3 and player.position.distance_to(EXIT) < 78.0: finish(true)
	interaction_time -= delta
	if interaction_time <= 0.0:
		interaction_time = 0.10
		controls.set_hide_state(player.in_locker, nearest_locker() >= 0)
	if controls.consume_hide_request(): toggle_locker()

func nearest_locker() -> int:
	if not is_instance_valid(player): return -1
	if player.in_locker: return player.locker_index
	var nearest := -1
	var distance := 82.0
	for i in LOCKERS.size():
		var current: float = player.position.distance_to(LOCKERS[i])
		if current < distance:
			distance = current
			nearest = i
	return nearest

func toggle_locker() -> void:
	if player.in_locker:
		var exit_index: int = player.locker_index
		player.in_locker = false
		player.visible = true
		player.position = LOCKERS[exit_index] + Vector2(0, 82)
		player.locker_index = -1
		return
	var enter_index := nearest_locker()
	if enter_index < 0: return
	player.in_locker = true
	player.locker_index = enter_index
	player.position = LOCKERS[enter_index]
	player.visible = false

func clear_sight(from: Vector2, to: Vector2) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(from, to, 1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func sight_endpoint(from: Vector2, to: Vector2) -> Vector2:
	var ray := PhysicsRayQueryParameters2D.create(from, to, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	return to if hit.is_empty() else Vector2(hit.position)

func player_hidden() -> bool:
	return is_instance_valid(player) and player.in_locker

func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start := Vector2i(clampi(int(from.x / CELL), 0, 71), clampi(int(from.y / CELL), 0, 47))
	var end := Vector2i(clampi(int(to.x / CELL), 0, 71), clampi(int(to.y / CELL), 0, 47))
	start = _nearest_walkable(start)
	end = _nearest_walkable(end)
	return grid.get_point_path(start, end)

func _nearest_walkable(cell: Vector2i) -> Vector2i:
	if not grid.is_point_solid(cell): return cell
	for radius in range(1, 6):
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
