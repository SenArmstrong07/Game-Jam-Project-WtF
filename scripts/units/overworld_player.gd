extends CharacterBody2D
@export var max_speed := 300.0
@export var acceleration := 900.0
@export var friction := 1000.0
@export var after_image_scene: PackedScene

var last_direction := Vector2.DOWN
var controls_locked: bool = false
var frontlayer: TileMapLayer

#Dash stuff:
@export var dash_speed := 700.0
@export var dash_duration := 0.18
@export var dash_cooldown := 0.45

const AFTERIMG_INTERVAL := 0.03

var is_dashing := false
var dash_direction := Vector2.ZERO
var dash_timer := 0.0
var dash_duration_timer := 0.0
var dash_cooldown_timer := 0.0

func _ready() -> void:
	add_to_group("player")
	# Get reference to frontlayer to check if world is ready
	frontlayer = get_parent().get_node("TileNode/front")

	# Ensure player renders above corruption overlays
	if self is CanvasItem:
		self.z_index = 7

func set_controls_locked(locked: bool) -> void:
	controls_locked = locked
	print("Controls locked:", locked)
	if locked:
		velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	# Don't allow movement until world generation is complete
	if frontlayer and not frontlayer.is_world_ready:
		return
	if controls_locked:
		#locks player movement when Scenes load some stuff
		velocity = Vector2.ZERO
		return
		
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta

	if Input.is_action_just_pressed("dash"):
		start_dash()

	var input_dir := Input.get_vector(
		"left",
		"right",
		"up",
		"down"
	)

	var desired_velocity := Vector2.ZERO

	if is_dashing:
		desired_velocity = dash_direction * dash_speed
	else:
		if input_dir != Vector2.ZERO:
			last_direction = input_dir.normalized()
			desired_velocity = input_dir.normalized() * max_speed

	var next_global_position := global_position + desired_velocity * delta
	var next_tile := frontlayer.local_to_map(frontlayer.to_local(next_global_position))

	if frontlayer and frontlayer.is_tile_walkable(next_tile):
		if is_dashing:
			velocity = desired_velocity
		else:
			velocity = desired_velocity
	else:
		velocity = Vector2.ZERO
		if is_dashing:
			stop_dash()

	_update_facing()
	move_and_slide()
	if is_dashing:
		dash_duration_timer -= delta

		if dash_duration_timer <= 0.0:
			stop_dash()
		else:
			dash_timer += delta

			if dash_timer >= AFTERIMG_INTERVAL:
				dash_timer = 0.0
				spawn_afterimage()
	else:
		dash_timer = 0.0



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

#Dashing
func start_dash():
	if is_dashing:
		return

	if dash_cooldown_timer > 0.0:
		return

	if last_direction == Vector2.ZERO:
		return

	is_dashing = true
	dash_duration_timer = dash_duration
	dash_timer = 0.0
	dash_cooldown_timer = dash_cooldown

	dash_direction = last_direction.normalized()


func stop_dash():
	is_dashing = false
	
func spawn_afterimage():
	var ghost = after_image_scene.instantiate()

	get_parent().add_child(ghost)

	ghost.global_position = global_position
	ghost.global_rotation = global_rotation
	ghost.scale = scale

	ghost.setup($PlayerSprite)


#Sprite update
func _update_facing() -> void:
	if last_direction == Vector2.ZERO:
		return

	var is_moving := velocity.length() > 5.0 and !is_dashing

	if abs(last_direction.x) > abs(last_direction.y):
		if last_direction.x > 0:
			if is_moving:
				$PlayerSprite.play("right_walk")
			else:
				$PlayerSprite.play("right_idle")
		else:
			if is_moving:
				$PlayerSprite.play("left_walk")
			else:
				$PlayerSprite.play("left_idle")
	else:
		if last_direction.y > 0:
			if is_moving:
				$PlayerSprite.play("front_walk")
			else:
				$PlayerSprite.play("front_idle")
		else:
			if is_moving:
				$PlayerSprite.play("back_walk")
			else:
				$PlayerSprite.play("back_idle")
