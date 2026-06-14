extends CharacterBody2D

@onready var anim_player: AnimatedSprite2D = $AnimatedSprite2D

const GRID_WIDTH := 4
const GRID_HEIGHT := 4
const X_OFFSET := 4 
const TILE_SIZE := 64

var grid_pos := Vector2i(0, 0) 
var target_position := Vector2.ZERO

var move_timer := 0.0
var move_interval := 1.0

var move_speed := 200.0

func _ready():
	position = grid_to_world(grid_pos)
	target_position = position 

func grid_to_world(cell: Vector2i) -> Vector2:
	var world_grid_x = cell.x + X_OFFSET

	return Vector2(
		world_grid_x * TILE_SIZE + TILE_SIZE / 2.0,
		cell.y * TILE_SIZE + TILE_SIZE / 2.0
	) + Vector2(0, -TILE_SIZE / 2.0)

func _process(delta):
	move_timer += delta

	if move_timer >= move_interval:
		move_timer = 0
		choose_random_move()

	# smooth movement
	position = position.move_toward(target_position, move_speed * delta)

func choose_random_move():
	var directions = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]

	var dir = directions[randi() % directions.size()]
	var new_pos = grid_pos + dir

	new_pos.x = clamp(new_pos.x, 0, GRID_WIDTH - 1)
	new_pos.y = clamp(new_pos.y, 0, GRID_HEIGHT - 1)

	if new_pos != grid_pos:
		grid_pos = new_pos
		target_position = grid_to_world(grid_pos)
		anim_player.play("Move")
