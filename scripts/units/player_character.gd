extends Unit

@onready var camera_2d: Camera2D = $"../Camera2D"
@onready var anim_player: AnimatedSprite2D = $AnimatedSprite2D

const GRID_WIDTH := 8
const GRID_HEIGHT := 4
const TILE_SIZE := 64
#player allowed tiles
const PLAYER_WIDTH := 4
const PLAYER_HEIGHT := 4

#postion in grid 
var grid_pos := Vector2i(0, 0)
#anti spam move
var moving := false
var move_speed := 400.0
#direction of the player
var target_position := Vector2.ZERO
var move_dir := Vector2i.ZERO
var last_anim := "Idle"
var lives: int = 5
var max_lives: int = 5

func _ready():
	# placed player
	position = grid_to_world(grid_pos)

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
	if moving:
		return

	move_dir = Vector2i.ZERO

	if event.is_action_pressed("ui_right"):
		move_dir = Vector2i(1, 0)
		last_anim = "Move_right"
	elif event.is_action_pressed("ui_left"):
		move_dir = Vector2i(-1, 0)
		last_anim = "Move_left"
	elif event.is_action_pressed("ui_down"):
		move_dir = Vector2i(0, 1)
		last_anim = "Move_Down"
	elif event.is_action_pressed("ui_up"):
		move_dir = Vector2i(0, -1)
		last_anim = "Move_up"

	if move_dir == Vector2i.ZERO:
		return

	var new_pos = grid_pos + move_dir
	#grids boundary limits
	new_pos.x = clamp(new_pos.x, 0, PLAYER_WIDTH - 1)
	new_pos.y = clamp(new_pos.y, 0, PLAYER_HEIGHT - 1)
	#player movement
	if new_pos != grid_pos:
		grid_pos = new_pos
		target_position = grid_to_world(grid_pos)
		moving = true

		anim_player.play(last_anim)
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
