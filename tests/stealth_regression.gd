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
	mission.start_game()
	check(mission.player.player_visual_style == 0, "Original doodle selected")
	mission.player.cycle_player_visual_style()
	check(mission.player.player_visual_style == 0, "Style stays locked")
	check(not mission.clear_sight(Vector2(300, 250), Vector2(300, 350)), "Room divider blocks sight")
	check(mission.clear_sight(Vector2(700, 450), Vector2(900, 450)), "Central hallway allows sight")
	check(mission.find_path(Vector2(340, 170), Vector2(1260, 470)).size() > 1, "Hallway connects left and right rooms")
	for intel in mission.INTEL:
		check(mission.find_path(Vector2(800, 1060), intel).size() > 1, "Intel is reachable")
	check(mission.find_path(Vector2(340, 170), mission.EXIT).size() > 1, "Extraction is reachable")
	check(mission.guards.size() == 3, "Exactly three deliberately placed guards")
	check(mission.guards[2].guard_mode == "SENTRY", "Third guard is a stationary lookout")
	check(mission.EXIT.y < 100.0, "Extraction is at the far end of the hallway")
	check(mission.audio.streams.has("player_run_steps"), "Hyphenated player run sound is loaded")
	check(not mission.audio.streams.has("player_stealth_steps"), "Stealth remains silent when its sound is absent")
	var sentry = mission.guards[2]
	var first_facing: Vector2 = sentry.display_facing
	sentry._physics_process(2.8)
	check(sentry.position == Vector2(860, 605) and sentry.display_facing != first_facing, "Sentry waits then rotates without walking")
	var guard = mission.guards[0]
	guard.position = Vector2(700, 420)
	guard.display_facing = Vector2.RIGHT
	mission.player.position = Vector2(820, 420)
	check(guard.can_see(mission.player.position), "Guard sees player in cone")
	check(not guard.can_see(Vector2(580, 420)), "Guard cannot see behind itself")
	guard._physics_process(0.9)
	check(guard.state == "CHASE" and mission.detections == 1, "Sustained detection triggers chase")
	check(not mission.player_hidden(), "Hiding is disabled in this level")
	guard.state = "PATROL"
	guard.suspicion = 0.0
	guard.display_facing = Vector2.UP
	guard.position = Vector2(700, 680)
	guard.cached_sees = false
	guard.sight_time = 0.0
	mission.player.position = Vector2(820, 680)
	mission.player.is_running = true
	mission.player.velocity = Vector2(200, 0)
	guard._physics_process(0.01)
	check(guard.state == "SEARCH", "Running noise makes guard investigate")
	check(not mission.player_hidden(), "Running reveals player")
	guard.state = "SEARCH"
	guard.search_time = 0.0
	guard.position = Vector2(820, 680)
	guard.post_position = Vector2(735, 170)
	guard.cached_sees = false
	guard.sight_time = 1.0
	guard._physics_process(0.01)
	check(guard.state == "RETURN", "Failed search sends guard back to original post")
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
	check(mission.level == 2 and mission.guards.size() == 3 and not mission.finished, "Next sector keeps the deliberate three-guard layout")
	mission.finish(false)
	mission.restart()
	check(mission.score == 0 and mission.collected == 0 and mission.level == 2, "Retry resets failed run without advancing sector")
	for i in 240: await physics_frame
	print("Stealth regression: %d failures" % errors)
	mission.queue_free()
	await process_frame
	quit(1 if errors else 0)
