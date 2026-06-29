extends CharacterBody2D
#temp player representation on overworld. Should use player_character instead
@export var max_speed := 200.0
@export var acceleration := 900.0
@export var friction := 1000.0

var last_direction := Vector2.DOWN
var controls_locked: bool = false
var frontlayer: TileMapLayer

func _ready() -> void:
	# Get reference to frontlayer to check if world is ready
	frontlayer = get_parent().get_node("TileNode/front")

func _physics_process(delta: float) -> void:
	# Don't allow movement until world generation is complete
	if frontlayer and not frontlayer.is_world_ready:
		return
	if controls_locked:
		#locks player movement when Scenes load some stuff
		velocity = Vector2.ZERO
		return
	
	var input_dir := Input.get_vector(
		"left",
		"right",
		"up",
		"down"
	)

	# Track last direction for facing/animations
	if input_dir != Vector2.ZERO:
		last_direction = input_dir.normalized()
		velocity = velocity.move_toward(input_dir * max_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
	
	# Enforce world bounds immediately
	if frontlayer and frontlayer.is_world_ready:
		var original_pos = position
		var clamped_x = clamp(position.x, frontlayer.world_min_x, frontlayer.world_max_x)
		var clamped_y = clamp(position.y, frontlayer.world_min_y, frontlayer.world_max_y)
		position.x = clamped_x
		position.y = clamped_y
		
		# Debug: Show if player was clamped
		if original_pos.x != clamped_x:
			print("[PLAYER] X CLAMPED: ", original_pos.x, " -> ", clamped_x, " (Bounds: ", frontlayer.world_min_x, " to ", frontlayer.world_max_x, ")")
		if original_pos.y != clamped_y:
			print("[PLAYER] Y CLAMPED: ", original_pos.y, " -> ", clamped_y, " (Bounds: ", frontlayer.world_min_y, " to ", frontlayer.world_max_y, ")")
		
		# Show proximity to boundaries
		var dist_to_min_x = position.x - frontlayer.world_min_x
		var dist_to_max_x = frontlayer.world_max_x - position.x
		var dist_to_min_y = position.y - frontlayer.world_min_y
		var dist_to_max_y = frontlayer.world_max_y - position.y
		
		# Alert if very close to boundary (within 500 pixels)
		if dist_to_min_x < 500:
			print("[WARNING] Close to X MIN boundary: ", dist_to_min_x, " pixels away")
		if dist_to_max_x < 500:
			print("[WARNING] Close to X MAX boundary: ", dist_to_max_x, " pixels away")
		if dist_to_min_y < 500:
			print("[WARNING] Close to Y MIN boundary: ", dist_to_min_y, " pixels away")
		if dist_to_max_y < 500:
			print("[WARNING] Close to Y MAX boundary: ", dist_to_max_y, " pixels away")
	
	_update_facing()


func _update_facing() -> void:
	if last_direction == Vector2.ZERO:
		return

	# This is where you'd hook up animations
	# Example logic for directional states:

	if abs(last_direction.x) > abs(last_direction.y):
		if last_direction.x > 0:
			# Facing right
			pass
		else:
			# Facing left
			pass
	else:
		if last_direction.y > 0:
			# Facing down
			pass
		else:
			# Facing up
			pass
