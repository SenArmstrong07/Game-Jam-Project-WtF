extends CharacterBody2D
@export var max_speed := 300.0
@export var acceleration := 900.0
@export var friction := 1000.0

var last_direction := Vector2.DOWN
var controls_locked: bool = false
var frontlayer: TileMapLayer

func _ready() -> void:
	add_to_group("player")
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

	var desired_velocity := Vector2.ZERO
	if input_dir != Vector2.ZERO:
		last_direction = input_dir.normalized()
		desired_velocity = input_dir.normalized() * max_speed
	else:
		desired_velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	var next_position := position + desired_velocity * delta
	var next_tile := frontlayer.local_to_map(next_position)
	if frontlayer and frontlayer.is_tile_walkable(next_tile):
		velocity = desired_velocity
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	
	# Enforce world bounds immediately
	if frontlayer and frontlayer.is_world_ready:
		var original_pos = position
		var clamped_x = clamp(position.x, frontlayer.world_min_x, frontlayer.world_max_x)
		var clamped_y = clamp(position.y, frontlayer.world_min_y, frontlayer.world_max_y)
		position.x = clamped_x
		position.y = clamped_y
	
	_update_facing()


func _get_next_walkable_tile(input_dir: Vector2) -> Vector2i:
	if not frontlayer:
		return Vector2i(-1, -1)

	var current_tile := frontlayer.local_to_map(position)
	var axis_dir := Vector2i.ZERO
	if abs(input_dir.x) > abs(input_dir.y):
		axis_dir = Vector2i(signi(input_dir.x), 0)
	elif input_dir.y != 0:
		axis_dir = Vector2i(0, signi(input_dir.y))

	if axis_dir == Vector2i.ZERO:
		return Vector2i(-1, -1)

	var next_tile := current_tile + axis_dir
	if frontlayer.is_tile_walkable(next_tile):
		return next_tile

	return Vector2i(-1, -1)


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
