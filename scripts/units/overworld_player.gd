extends CharacterBody2D
#temp player representation on overworld. Should use player_character instead
@export var max_speed := 140.0
@export var acceleration := 900.0
@export var friction := 1000.0

var last_direction := Vector2.DOWN
var frontlayer: TileMapLayer

func _ready() -> void:
	# Get reference to frontlayer to check if world is ready
	frontlayer = get_parent().get_node("TileNode/front")

func _physics_process(delta: float) -> void:
	# Don't allow movement until world generation is complete
	if frontlayer and not frontlayer.is_world_ready:
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
