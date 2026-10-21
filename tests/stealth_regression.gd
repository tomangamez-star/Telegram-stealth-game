extends SceneTree
var errors := 0
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		errors += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var mission = load("res://scenes/stealth.tscn").instantiate()
	root.add_child(mission)
	await physics_frame
	await physics_frame
	check(mission.player.player_visual_style == 0, "Original doodle selected")
	mission.player.cycle_player_visual_style()
	check(mission.player.player_visual_style == 0, "Style stays locked")
	check(not mission.clear_sight(Vector2(300, 250), Vector2(550, 250)), "Wall blocks sight")
	check(mission.clear_sight(Vector2(500, 450), Vector2(700, 450)), "Open corridor allows sight")
	check(mission.find_path(Vector2(570, 450), Vector2(1090, 900)).size() > 1, "Guards can route through room doors")
	for intel in mission.INTEL:
		check(mission.find_path(Vector2(250, 1080), intel).size() > 1, "Intel is reachable")
	check(mission.find_path(Vector2(250, 1080), mission.EXIT).size() > 1, "Extraction is reachable")
	var guard = mission.guards[0]
	guard.position = Vector2(220, 420)
	guard.display_facing = Vector2.RIGHT
	mission.player.position = Vector2(340, 420)
	check(guard.can_see(mission.player.position), "Guard sees player in cone")
	check(not guard.can_see(Vector2(100, 420)), "Guard cannot see behind itself")
	guard._physics_process(0.9)
	check(guard.state == "CHASE" and mission.detections == 1, "Sustained detection triggers chase")
	mission.player.position = Vector2(600, 800)
	check(not mission.player_hidden(), "Bare floor never hides player")
	mission.player.position = mission.LOCKERS[0]
	mission.toggle_locker()
	check(mission.player_hidden() and not mission.player.visible, "Player deliberately enters a nearby locker")
	mission.toggle_locker()
	check(not mission.player_hidden() and mission.player.visible, "Player deliberately exits locker")
	guard.state = "PATROL"
	guard.suspicion = 0.0
	guard.display_facing = Vector2.UP
	guard.position = Vector2(160, 680)
	guard.cached_sees = false
	guard.sight_time = 0.0
	mission.player.position = Vector2(300, 680)
	mission.player.is_running = true
	mission.player.velocity = Vector2(200, 0)
	guard._physics_process(0.01)
	check(guard.state == "SEARCH", "Running noise makes guard investigate")
	check(not mission.player_hidden(), "Running reveals player")
	mission.player.position = mission.INTEL[0]
	mission._physics_process(0.0)
	check(mission.collected == 1 and mission.score == 100, "Intel scores once")
	mission._physics_process(0.0)
	check(mission.collected == 1, "Intel cannot be collected twice")
	mission.player.position = mission.EXIT
	mission._physics_process(0.0)
	check(not mission.finished, "Exit is locked until all intel collected")
	mission.player.position = mission.INTEL[1]
	mission._physics_process(0.0)
	mission.player.position = mission.INTEL[2]
	mission._physics_process(0.0)
	mission.player.position = mission.EXIT
	mission._physics_process(0.0)
	check(mission.finished and mission.won, "Full objective unlocks extraction")
	var previous: int = mission.score
	mission.finish(true)
	check(previous == mission.score, "Finish cannot score twice")
	mission.restart()
	check(mission.level == 2 and mission.guards.size() == 4 and not mission.finished, "Next sector adds guard and resets objectives")
	mission.finish(false)
	mission.restart()
	check(mission.score == 0 and mission.collected == 0 and mission.level == 2, "Retry resets failed run without advancing sector")
	for i in 240: await physics_frame
	print("Stealth regression: %d failures" % errors)
	quit(1 if errors else 0)
