extends Unit

@onready var camera_2d: Camera2D = $"../Camera2D"
@onready var anim_player: AnimatedSprite2D = $AnimatedSprite2D
const DELETE_PROJECTILE = preload("uid://cxcsd36elkqlv")
var battle_scene
signal lives_changed(player: Unit, lives: int)
@export var hurt_duration := 0.2
const PLAYER_HIT = preload("uid://cknnjkcfvuie1")

var stunned := false
var stun_timer := 0.0

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
var afterimage_timer := 0.0

func get_lives() -> int:
	return lives

func get_max_lives() -> int:
	return max_lives
	
func _ready():
	lives = max_lives

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

	battle_scene = find_battle_scene()

	if battle_scene == null:
		push_error("Battle scene not found!")
		return
	
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

func play_sfx(
	stream: AudioStream,
	volume_db: float = 0.0,
	pitch_scale: float = 1.0,
	bus: String = "Master"
):
	if stream == null:
		return

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.bus = bus

	add_child(player)
	player.play()

	player.finished.connect(func():
		player.queue_free()
	)

# Override take_damage function from Unit superclass to implement "1 hit = 1 life" mechanic (PLAYER ONLY)
func take_damage(amount: int, damage_type := Unit.DamageType.NEUTRAL, chip: Chip = null) -> void:
	play_sfx(PLAYER_HIT, -10)
	if is_dead:
		return

	lives -= 1

	lives_changed.emit(self, lives)

	play_hurt()

	if battle_scene:
		battle_scene.update_player_ui()

	print("Hit! Lives remaining: ", lives)

	# If the tutorial healed us, don't die.
	if lives > 0:
		return

	die()
	
#Converts grid coordinates to pixel position
func grid_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		cell.x * TILE_SIZE + TILE_SIZE / 2.0,
		cell.y * TILE_SIZE + TILE_SIZE / 2.0
	)

#player controls
func _unhandled_input(event):
	if battle_scene == null:
		return

	if battle_scene.current_phase != battle_scene.BattlePhase.BATTLE:
		return

	if movement_locked:
		return

	if moving:
		return

	move_dir = Vector2i.ZERO

	var action_map := {
		"right": Vector2i.RIGHT,
		"ui_right": Vector2i.RIGHT,
		"left": Vector2i.LEFT,
		"ui_left": Vector2i.LEFT,
		"down": Vector2i.DOWN,
		"ui_down": Vector2i.DOWN,
		"up": Vector2i.UP,
		"ui_up": Vector2i.UP
	}

	for action_name in action_map.keys():
		if event.is_action_pressed(action_name):
			move_dir = action_map[action_name]
			match action_name:
				"right", "ui_right":
					facing = Vector2i.RIGHT
				"left", "ui_left":
					facing = Vector2i.LEFT
				"down", "ui_down":
					facing = Vector2i.DOWN
				"up", "ui_up":
					facing = Vector2i.UP
			break

	if move_dir == Vector2i.ZERO:
		return

	var new_pos = grid_pos + move_dir

	# Stay inside player grid
	new_pos.x = clamp(new_pos.x, 0, PLAYER_WIDTH - 1)
	new_pos.y = clamp(new_pos.y, 0, PLAYER_HEIGHT - 1)

	# Don't walk onto broken or blocked tiles
	if !battle_scene.is_tile_walkable(new_pos):
		return

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

	dash_to_tile(target_position)
		
#movement loop		
func _process(delta):

	if moving:
		afterimage_timer += delta

		if afterimage_timer >= 0.02:
			afterimage_timer = 0.0
			create_dash_afterimage()

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

	lives_changed.emit(self, lives)

	play_heal()

	if battle_scene:
		battle_scene.update_player_ui()

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

func apply_stun(duration: float):

	if stunned:
		return

	stunned = true
	movement_locked = true

	anim_player.modulate = Color.YELLOW

	print("PLAYER STUNNED")

	await get_tree().create_timer(duration).timeout

	stunned = false
	movement_locked = false

	anim_player.modulate = Color.WHITE

	print("PLAYER RECOVERED")

func play_slam_hit():

	var start_pos = position

	var tween = create_tween()
	tween.set_parallel()

	# Squash
	tween.tween_property(self, "scale", Vector2(1.45, 0.50), 0.08)

	# Push down slightly
	tween.tween_property(self, "position:y", start_pos.y + 6, 0.08)

	await tween.finished

	tween = create_tween()
	tween.set_parallel()

	# Recover
	tween.tween_property(self, "scale", Vector2.ONE, 0.12)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	tween.tween_property(self, "position:y", start_pos.y, 0.12)

func dash_to_tile(target: Vector2):

	moving = true

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(self, "position", target, 0.08)
	tween.finished.connect(_on_dash_finished)

func _on_dash_finished():
	position = target_position
	moving = false
	anim_player.play("Idle")
		
func create_dash_afterimage():

	var ghost = anim_player.duplicate()

	get_parent().add_child(ghost)

	ghost.global_position = global_position + anim_player.position
	ghost.modulate = Color(0.5, 0.9, 1.0, 0.5)
	ghost.z_index = z_index - 1

	var tween = ghost.create_tween()

	tween.tween_property(
		ghost,
		"modulate:a",
		0.0,
		0.15
	)

	await tween.finished

	ghost.queue_free()

func find_battle_scene():
	var node = self

	while node:
		if node is BattleBase:
			return node
		node = node.get_parent()

	return null
