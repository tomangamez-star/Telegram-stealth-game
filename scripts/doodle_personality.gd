extends Node

# All head offsets are relative to the torso, bounded to a 150-degree sweep.
# No lerp_angle here: interpolating the bounded scalar prevents a wraparound spin.
const MAX_HEAD_ANGLE := deg_to_rad(75.0)
var actor
var style := 0
var head_angle := 0.0
var head_target := 0.0
var glance_timer := 1.0
var clock := 0.0
var gesture := ""
var gesture_time := 0.0
var mood := "calm"
var mood_time := 0.0
var friendship := 0
var acquaintances: Dictionary = {}
var attention_target: Node2D
var attention_time := 0.0
var rng := RandomNumberGenerator.new()
var redraw_time := 0.0
var was_ragdoll := false

func _ready() -> void:
	actor = get_parent()
	style = actor.appearance_id % 3
	rng.seed = 2817 + actor.appearance_id * 113
	clock = rng.randf_range(0.0, 20.0)
	glance_timer = rng.randf_range(0.8, 2.0)

func _physics_process(delta: float) -> void:
	if not actor.visible or (actor.is_npc and not actor.world_activity_enabled): return
	clock += delta
	attention_time = maxf(0.0, attention_time - delta)
	if attention_time == 0.0: attention_target = null
	gesture_time = maxf(0.0, gesture_time - delta)
	mood_time = maxf(0.0, mood_time - delta)
	if mood_time == 0.0: mood = "calm"
	if gesture_time == 0.0: gesture = ""
	if actor.ragdoll_active:
		was_ragdoll = true
		head_target = 0.0
	elif was_ragdoll:
		was_ragdoll = false
		mood = "upset"
		mood_time = 8.0
		emote("surprise", 2.0)
	glance_timer -= delta
	if glance_timer <= 0.0:
		glance_timer = rng.randf_range(1.8, 4.2)
		head_target = rng.randf_range(-MAX_HEAD_ANGLE, MAX_HEAD_ANGLE) if actor.velocity.length() < 15.0 else 0.0
		if actor.velocity.length() < 15.0 and gesture == "" and rng.randf() < 0.32:
			emote("stretch" if style == 1 else "phone", 2.6)
		if not is_instance_valid(attention_target):
			for candidate in get_tree().get_nodes_in_group("doodles"):
				if candidate != actor and candidate.visible and actor.global_position.distance_to(candidate.global_position) < 160.0:
					attention_target = candidate
					attention_time = 2.2
					if candidate.ragdoll_active: emote("surprise", 1.5)
					break
		if gesture == "":
			for vehicle in get_tree().get_nodes_in_group("traffic"):
				if not vehicle.visible: continue
				var to_actor: Vector2 = actor.global_position - vehicle.global_position
				if to_actor.length() < 200.0 and vehicle.velocity.length() > 65.0 and vehicle.velocity.normalized().dot(to_actor.normalized()) > 0.75:
					attention_target = vehicle
					attention_time = 1.2
					emote("surprise", 1.2)
					break
	if is_instance_valid(attention_target):
		if not attention_target.visible or actor.global_position.distance_to(attention_target.global_position) > 230.0:
			attention_target = null
		else:
			var direction: Vector2 = actor.global_position.direction_to(attention_target.global_position)
			head_target = clampf(actor.display_facing.angle_to(direction), -MAX_HEAD_ANGLE, MAX_HEAD_ANGLE)
	var limit := MAX_HEAD_ANGLE if actor.velocity.length() < 15.0 else deg_to_rad(28.0)
	if actor.ragdoll_active: head_target = 0.0
	head_angle = lerpf(head_angle, clampf(head_target, -limit, limit), 1.0 - exp(-3.2 * delta))
	redraw_time -= delta
	if redraw_time <= 0.0:
		redraw_time = 1.0 / (20.0 if OS.has_feature("web") and actor.is_npc else 30.0)
		actor.visual.queue_redraw()

func emote(kind: String, duration: float = 2.0) -> void:
	gesture = kind
	gesture_time = duration

func greet(source: Node2D) -> String:
	attention_target = source
	attention_time = 3.5
	if mood == "upset":
		emote("surprise")
		return "Give me a moment!"
	var identity := source.get_instance_id()
	friendship = mini(int(acquaintances.get(identity, 0)) + 1, 3)
	acquaintances[identity] = friendship
	emote("wave")
	return "Good to see you again!" if friendship > 1 else "Hey! Nice to meet you."
