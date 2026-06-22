extends CharacterBody2D 

#temporary overworld enemy object lang toh

signal died

var speed = 70
var player_chase : bool = false
var player = null

# Idle/patrol behavior
var is_idle : bool = true
var patrol_center : Vector2
var patrol_radius : float = 200.0  # How far they can wander from spawn
var patrol_target : Vector2
var patrol_speed : float = 50.0  # Slower than chase speed
var patrol_timer : float = 0.0
var patrol_change_interval : float = 3.0  # Change target every 3 seconds

func _ready() -> void:
	# Set patrol center to spawn position
	patrol_center = position
	pick_new_patrol_target()

func _physics_process(delta: float) -> void:
	if player_chase:
		# Chase mode - follow player
		is_idle = false
		position += (player.position - position) / speed
		
		$sprite.play("s_walk")
		update_sprite_direction(player.position)
	else:
		# Idle mode - patrol
		if not is_idle:
			is_idle = true
			pick_new_patrol_target()
		
		patrol_timer += delta
		
		# Periodically pick a new patrol target
		if patrol_timer >= patrol_change_interval:
			pick_new_patrol_target()
			patrol_timer = 0.0
		
		# Move towards patrol target
		var distance_to_target = position.distance_to(patrol_target)
		if distance_to_target > 5.0:  # Only move if not at target
			var direction = (patrol_target - position).normalized()
			position += direction * patrol_speed * delta
			
			$sprite.play("s_walk")
			update_sprite_direction(patrol_target)
		else:
			$sprite.stop()


func _on_detection_area_body_entered(body: Node2D) -> void:
	player = body
	player_chase = true


func _on_detection_area_body_exited(body: Node2D) -> void:
	player = null
	player_chase = false


func _on_battle_trigger_body_entered(body: Node2D) -> void:
	# Check if the body is the player
	if body == player:
		trigger_battle() # (COLLISION) NOTE TO SELF: DAPAT PAREHAS YUNG LAYER AND MASK INDEX WITH THE LAYER AND MASK INDEX NG PLAYER TO TRIGGER A BATTLE SEQUENCE


func trigger_battle() -> void:
	print("TRANSITION TO BATTLE")
	# TODO: Implement actual battle scene transition here


func pick_new_patrol_target() -> void:
	# Pick a random point within patrol radius
	var random_angle = randf() * TAU
	var random_distance = randf() * patrol_radius
	
	patrol_target = patrol_center + Vector2(cos(random_angle), sin(random_angle)) * random_distance


func update_sprite_direction(target_pos: Vector2) -> void:
	# Flip sprite based on target direction
	if (target_pos.x - position.x) < 0:
		$sprite.flip_h = false
	else:
		$sprite.flip_h = true
