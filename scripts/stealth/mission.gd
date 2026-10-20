extends Node2D

const Agent = preload("res://scripts/stealth/agent.gd")
const Controls = preload("res://scripts/stealth/controls.gd")
const WALLS := [Rect2(0, 0, 1800, 48), Rect2(0, 1152, 1800, 48), Rect2(0, 0, 48, 1200), Rect2(1752, 0, 48, 1200), Rect2(400, 48, 48, 360), Rect2(400, 600, 48, 360), Rect2(800, 260, 48, 400), Rect2(800, 850, 48, 302), Rect2(1200, 48, 48, 400), Rect2(1200, 650, 48, 300), Rect2(1450, 750, 180, 110), Rect2(150, 500, 130, 150), Rect2(570, 670, 120, 140), Rect2(950, 140, 120, 130)]
const HIDES := [Rect2(85, 790, 220, 160), Rect2(480, 90, 190, 140), Rect2(900, 710, 200, 120), Rect2(1390, 330, 250, 150)]
const INTEL := [Vector2(570, 230), Vector2(1000, 1000), Vector2(1560, 170)]
const EXIT := Vector2(1630, 1040)
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

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#101c25"))
	Input.emulate_touch_from_mouse = true
	grid.region = Rect2i(0, 0, 72, 48)
	grid.cell_size = Vector2(25, 25)
	grid.offset = Vector2(12.5, 12.5)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for y in 48:
		for x in 72:
			var point := Vector2(x * 25 + 12.5, y * 25 + 12.5)
			for wall in WALLS:
				if wall.grow(34).has_point(point): grid.set_point_solid(Vector2i(x, y))
	for wall in WALLS:
		var body := StaticBody2D.new()
		body.position = wall.get_center()
		body.collision_layer = 1
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = wall.size
		collider.shape = shape
		body.add_child(collider)
		add_child(body)
	controls = Controls.new()
	controls.mission = self
	add_child(controls)
	_start_sector()

func _start_sector() -> void:
	finished = false
	won = false
	collected = 0
	detections = 0
	elapsed = 0.0
	remaining.assign(INTEL)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	add_child(actors)
	player = Agent.new()
	player.mission = self
	player.controls = controls
	player.name = "OriginalDoodle"
	player.position = Vector2(170, 1040)
	player.collision_layer = 2
	player.collision_mask = 1
	player.add_to_group("player_doodle")
	actors.add_child(player)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.zoom = Vector2(0.86, 0.86)
	camera.limit_left = -40
	camera.limit_top = -150
	camera.limit_right = 1840
	camera.limit_bottom = 1350
	player.add_child(camera)
	camera.make_current()
	_add_guard([Vector2(570, 450), Vector2(570, 550), Vector2(200, 350), Vector2(200, 130)])
	_add_guard([Vector2(1020, 420), Vector2(1020, 600), Vector2(680, 1000), Vector2(680, 550)])
	_add_guard([Vector2(1550, 550), Vector2(1370, 550), Vector2(1370, 160), Vector2(1640, 160)])
	for i in mini(level - 1, 3):
		_add_guard([Vector2(1380, 1030), Vector2(1060, 1030), Vector2(1050, 550), Vector2(1660, 550)], i)
	queue_redraw()

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
		if player.position.distance_to(remaining[i]) < 65.0:
			remaining.remove_at(i)
			collected += 1
			score += 100
	if collected == 3 and player.position.distance_to(EXIT) < 85.0: finish(true)
	queue_redraw()

func clear_sight(from: Vector2, to: Vector2) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(from, to, 1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func player_hidden() -> bool:
	if not is_instance_valid(player) or player.is_running: return false
	for hide in HIDES:
		if hide.has_point(player.position): return true
	return false

func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start := Vector2i(clampi(int(from.x / 25), 0, 71), clampi(int(from.y / 25), 0, 47))
	var end := Vector2i(clampi(int(to.x / 25), 0, 71), clampi(int(to.y / 25), 0, 47))
	start = _nearest_walkable(start)
	end = _nearest_walkable(end)
	return grid.get_point_path(start, end)

func _nearest_walkable(cell: Vector2i) -> Vector2i:
	if not grid.is_point_solid(cell): return cell
	for radius in range(1, 5):
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

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1800, 1200), Color("#263744"))
	for x in range(0, 1801, 100): draw_line(Vector2(x, 0), Vector2(x, 1200), Color("#2d414d"), 1)
	for y in range(0, 1201, 100): draw_line(Vector2(0, y), Vector2(1800, y), Color("#2d414d"), 1)
	for hide in HIDES:
		draw_rect(hide, Color("#214c44"))
		draw_rect(hide, Color("#468b70"), false, 2)
		for x in range(int(hide.position.x) + 16, int(hide.end.x), 27):
			for y in range(int(hide.position.y) + 16, int(hide.end.y), 27): draw_circle(Vector2(x, y), 12, Color("#306451"))
		draw_string(ThemeDB.fallback_font, hide.position + Vector2(14, 25), "HIDE / WALK", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#a1e3bd"))
	for guard in guards:
		var polygon := PackedVector2Array([guard.position])
		for i in 25:
			var direction: Vector2 = guard.display_facing.rotated(deg_to_rad(-38.0 + float(i) * 76.0 / 24.0))
			var endpoint: Vector2 = guard.position + direction * 350.0
			# Clip vision against the same solid cover used by detection.
			for wall in WALLS:
				var points := [wall.position, Vector2(wall.end.x, wall.position.y), wall.end, Vector2(wall.position.x, wall.end.y)]
				for edge in 4:
					var hit = Geometry2D.segment_intersects_segment(guard.position, endpoint, points[edge], points[(edge + 1) % 4])
					if hit != null: endpoint = hit
			polygon.append(endpoint)
		draw_colored_polygon(polygon, Color(1.0, 0.25, 0.23, 0.23) if guard.state == "CHASE" else Color(1.0, 0.83, 0.36, 0.13))
		var bar: Vector2 = guard.position + Vector2(-27, -49)
		draw_rect(Rect2(bar, Vector2(54, 6)), Color("#10232c"))
		draw_rect(Rect2(bar, Vector2(54 * guard.suspicion, 6)), Color("#ff8877"))
	for wall in WALLS:
		draw_rect(Rect2(wall.position + Vector2(8, 10), wall.size), Color(0.02, 0.04, 0.06, 0.4))
		draw_rect(wall, Color("#526673"))
		draw_rect(wall.grow(-5), Color("#627b88"))
		draw_line(wall.position + Vector2(5, 5), Vector2(wall.end.x - 5, wall.position.y + 5), Color("#95a9b0"), 3)
	for intel in remaining:
		draw_circle(intel, 31 + sin(elapsed * 3) * 3, Color(0.35, 0.9, 0.85, 0.15))
		draw_rect(Rect2(intel - Vector2(19, 14), Vector2(38, 28)), Color("#8ff1df"))
		draw_rect(Rect2(intel - Vector2(8, 21), Vector2(16, 8)), Color("#8ff1df"), false, 3)
		draw_string(ThemeDB.fallback_font, intel + Vector2(-21, -38), "INTEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#aefff1"))
	var exit_color := Color("#78e9ae") if collected == 3 else Color("#72838e")
	draw_circle(EXIT, 82, Color(exit_color, 0.12))
	draw_arc(EXIT, 78, 0, TAU, 48, exit_color, 3, true)
	draw_string(ThemeDB.fallback_font, EXIT + Vector2(-48, 7), "EXTRACT" if collected == 3 else "LOCKED", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, exit_color)
