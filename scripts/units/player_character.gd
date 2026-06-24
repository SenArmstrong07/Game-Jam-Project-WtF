extends Unit

@onready var camera_2d: Camera2D = $"../Camera2D"
@onready var anim_player: AnimatedSprite2D = $AnimatedSprite2D
const DELETE_PROJECTILE = preload("uid://cxcsd36elkqlv")
@onready var battle_scene = get_parent()
@export var hurt_duration := 0.2

const GRID_WIDTH := 8
const GRID_HEIGHT := 4
const TILE_SIZE := 64
var optimize_particles: GPUParticles2D

#player allowed tiles
const PLAYER_WIDTH := 4
const PLAYER_HEIGHT := 4


#anti spam move
var moving := false
var optimized := false
var base_move_speed := 400.0
var optimize_damage_bonus := 15
var move_speed := base_move_speed

#direction of the player
var target_position := Vector2.ZERO
var move_dir := Vector2i.ZERO
var lives: int = 5
var max_lives: int = 5
var facing: Vector2i = Vector2i.RIGHT
var movement_locked := false

func get_lives() -> int:
	return lives

func get_max_lives() -> int:
	return max_lives
	
func _ready():
	# placed player
	add_to_group("player")
	team = Team.PLAYER
	z_index = 10
	grid_pos = Vector2i(1, 2)
	optimize_particles = GPUParticles2D.new()
	add_child(optimize_particles)
	
	position = grid_to_world(grid_pos)
	grid_x = grid_pos.x
	grid_y = grid_pos.y
	anim_player.play("Idle")
	
	# Safety check for camera
	if camera_2d == null:
		print("ERROR: Camera2D not found at path '../Camera2D'")
		print("Current node path: ", get_path())
		print("Parent: ", get_parent())
		return
	
	# center camera on grid
	var grid_center = Vector2(
		GRID_WIDTH * TILE_SIZE / 2.0,
		GRID_HEIGHT * TILE_SIZE / 2.0
	)

	camera_2d.global_position = grid_center

	camera_2d.zoom = Vector2(1.8,1.8)


# Override take_damage function from Unit superclass to implement "1 hit = 1 life" mechanic (PLAYER ONLY)
func take_damage(amount: int, damage_type: Unit.DamageType = Unit.DamageType.NEUTRAL, chip: Chip = null) -> void:
	# Check if hit connects (even if "1 hit = 1 life", we could add dodge chance)
	lives -= 1
	play_hurt()

	print("Hit! Lives remaining: ", lives)
	
	if lives <= 0:
		die()



#Converts grid coordinates to pixel position
func grid_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		cell.x * TILE_SIZE + TILE_SIZE / 2.0,
		cell.y * TILE_SIZE + TILE_SIZE / 2.0
	)

#player controls
func _unhandled_input(event):
	if battle_scene.current_phase != battle_scene.BattlePhase.BATTLE:
		return
	if movement_locked:
		return
		
	if moving:
		return

	move_dir = Vector2i.ZERO

	if event.is_action_pressed("ui_right"):
		move_dir = Vector2i(1, 0)
		facing = Vector2i.RIGHT
	elif event.is_action_pressed("ui_left"):
		move_dir = Vector2i(-1, 0)
		facing = Vector2i.LEFT
	elif event.is_action_pressed("ui_down"):
		move_dir = Vector2i(0, 1)
		facing = Vector2i.DOWN
	elif event.is_action_pressed("ui_up"):
		move_dir = Vector2i(0, -1)
		facing = Vector2i.UP

	if move_dir == Vector2i.ZERO:
		return
	var new_pos: Vector2i = grid_pos + move_dir
	
	if battle_scene.blocked_tiles.has(new_pos):
		return
	
	#grids boundary limits
	new_pos.x = clamp(new_pos.x, 0, PLAYER_WIDTH - 1)
	new_pos.y = clamp(new_pos.y, 0, PLAYER_HEIGHT - 1)
	#player movement
	if battle_scene.blocked_tiles.has(new_pos):
		return

	if new_pos != grid_pos:
		grid_pos = new_pos

		grid_x = grid_pos.x
		grid_y = grid_pos.y

		target_position = grid_to_world(grid_pos)
		moving = true

		if move_dir == Vector2i.RIGHT:
			anim_player.play("Move_right")
		elif move_dir == Vector2i.LEFT:
			anim_player.play("Move_left")
		elif move_dir == Vector2i.UP:
			anim_player.play("Move_up")
		elif move_dir == Vector2i.DOWN:
			anim_player.play("Move_Down")

#movement loop		
func _process(delta):
	if moving:
		position = position.move_toward(
			target_position,
			move_speed * delta
		)

		if position.distance_to(target_position) < 1.0:
			position = target_position
			moving = false
			anim_player.play("Idle")

func update_animation(input_dir: Vector2):
	if input_dir == Vector2.ZERO:
		anim_player.play("Idle")
		return

	if abs(input_dir.x) > abs(input_dir.y):
		if input_dir.x > 0:
			anim_player.play("Move_right")
		else:
			anim_player.play("Move_left")
	else:
		if input_dir.y > 0:
			anim_player.play("Move_down")
		else:
			anim_player.play("Move_up")
			
func play_hurt():
	if is_hurt or is_dead:
		return

	is_hurt = true
	movement_locked = true

	anim_player.modulate = Color(1, 0.3, 0.3)
	anim_player.play("Hurt")

	await get_tree().create_timer(hurt_duration).timeout

	anim_player.modulate = Color.WHITE
	anim_player.play("Idle")

	movement_locked = false
	is_hurt = false
	
func play_optimize_effect():

	var mat := ParticleProcessMaterial.new()

	mat.direction = Vector3(0, -1, 0)
	mat.spread = 0

	mat.initial_velocity_min = 250
	mat.initial_velocity_max = 250

	mat.gravity = Vector3.ZERO


	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(20, 4, 0)

	optimize_particles.process_material = mat

	optimize_particles.amount = 50
	optimize_particles.lifetime = 0.3
	optimize_particles.emitting = true

	anim_player.modulate = Color(0.4, 0.8, 1.0)
	
func heal(amount: int):
	lives = min(lives + amount, max_lives)

	play_heal()

	print("Lives: ", lives, "/", max_lives)

func play_heal():
	anim_player.modulate = Color.GREEN

	var effect := Label.new()
	effect.text = "+1"
	effect.scale = Vector2(1, 1)

	add_child(effect)

	effect.position = Vector2(0, -50)

	var tween = create_tween()

	tween.parallel().tween_property(
		effect,
		"position",
		effect.position + Vector2(0, -40),
		0.8
	)

	tween.parallel().tween_property(
		effect,
		"modulate:a",
		0.0,
		0.8
	)

	await tween.finished

	effect.queue_free()

	anim_player.modulate = Color.WHITE

func activate_optimize(damage_bonus: int, duration: float):

	if optimized:
		return

	optimized = true

	move_speed += 200
	attack_power += damage_bonus

	play_optimize_effect()

	print("OPTIMIZE ACTIVE")

	await get_tree().create_timer(duration).timeout

	move_speed -= 200
	attack_power -= damage_bonus

	optimized = false

	stop_optimize_effect()

	print("OPTIMIZE EXPIRED")

func stop_optimize_effect():

	optimize_particles.emitting = false

	anim_player.modulate = Color.WHITE
