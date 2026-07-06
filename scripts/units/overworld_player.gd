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

func set_controls_locked(locked: bool) -> void:
	controls_locked = locked
	if not locked:
		velocity = Vector2.ZERO

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
		# Stop immediately when no input (no sliding)
		desired_velocity = Vector2.ZERO

	var next_global_position: Vector2 = global_position + desired_velocity * delta
	var next_tile: Vector2i = frontlayer.local_to_map(frontlayer.to_local(next_global_position))
	if frontlayer and frontlayer.is_tile_walkable(next_tile):
		velocity = desired_velocity
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	
	_update_facing()


func _get_next_walkable_tile(input_dir: Vector2) -> Vector2i:
	if not frontlayer:
		return Vector2i(-1, -1)

	var current_tile : Vector2i = frontlayer.local_to_map(frontlayer.to_local(global_position))
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
