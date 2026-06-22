extends Unit

@onready var anim_player: AnimatedSprite2D = $AnimatedSprite2D
const EnemyBasicProjectile = preload("res://scenes/Attacks/enemy_basic_projectile.tscn")

@onready var player_character: Unit = $"../PlayerCharacter"
@onready var battle_scene: Battlescene = $".."
@onready var ProjectileShootPoint: Marker2D = $CommonBugMarker

const GRID_WIDTH := 4
const GRID_HEIGHT := 4
const X_OFFSET := 4
const TILE_SIZE := 64

var target_position := Vector2.ZERO
var attack_locked := false
@export var attack_recovery := 0.5

var follow_timer := 0.0
var follow_interval := 0.35

var shoot_timer := 0.0
var shoot_interval := 1.0

var stunned := false
var stun_timer := 0.0

var move_speed := 220.0
var attack_count := 0

# internal lane oscillation state
var lane_direction := 1
var lane_timer := 0.0
var lane_switch_interval := 0.6


func _ready():
	grid_pos = Vector2i(2, 2)
	position = grid_to_world(grid_pos)
	grid_x = grid_pos.x
	grid_y = grid_pos.y
	target_position = position


func grid_to_world(cell: Vector2i) -> Vector2:
	var world_grid_x = cell.x + X_OFFSET

	return Vector2(
		world_grid_x * TILE_SIZE + TILE_SIZE / 2.0,
		cell.y * TILE_SIZE + TILE_SIZE / 2.0
	)


func _process(delta):

	if battle_scene.current_phase != Battlescene.BattlePhase.BATTLE:
		return

	# =========================
	# STUN HARD BLOCK 
	# =========================
	if stunned:
		stun_timer -= delta

		if stun_timer <= 0:
			stunned = false

		return

	# timers
	follow_timer += delta
	shoot_timer += delta
	lane_timer += delta

	# switch lane direction
	if lane_timer >= lane_switch_interval:
		lane_timer = 0.0
		lane_direction *= -1

	# movement
	if follow_timer >= follow_interval:
		follow_timer = 0.0
		follow_player()

	position = position.move_toward(target_position, move_speed * delta)

	if position.distance_to(target_position) < 2.0:
		if anim_player.animation in ["Up", "Down", "Left", "Right"]:
			anim_player.play("Idle")
	# shooting
	if shoot_timer >= shoot_interval and not attack_locked:
		shoot_timer = 0.0

		if player_in_front():
			shoot()


# ============================================================
# CORE MOVEMENT (LANE CONTROL AI)
# ============================================================
func follow_player():
	if player_character == null:
		return
		
	var old_grid_pos = grid_pos
	var player_row := player_character.grid_pos.y
	var player_col := player_character.grid_pos.x

	var my_row := grid_pos.y
	var my_col := grid_pos.x

	# ----------------------------------------------------
	# Decide whether to move horizontally or vertically
	# (NO diagonal movement allowed)
	# ----------------------------------------------------
	var move_axis := randi() % 2  # 0 = Y, 1 = X

	# ----------------------------------------------------
	# VERTICAL MOVE (lane control)
	# ----------------------------------------------------
	if move_axis == 0:
		if my_row < player_row:
			grid_pos.y += 1
		elif my_row > player_row:
			grid_pos.y -= 1
		else:
			# if already aligned, still move slightly for pressure
			grid_pos.y += [-1, 1].pick_random()

	# ----------------------------------------------------
	# HORIZONTAL MOVE (positioning / back & forth)
	# ----------------------------------------------------
	else:
		# don't sit in same column as player
		var target_col := player_col + 1

		# oscillation so it moves across tiles, not stuck
		if int(Time.get_ticks_msec() / 700) % 2 == 0:
			target_col = player_col + 1
		else:
			target_col = player_col + 2

		target_col = clamp(target_col, 0, GRID_WIDTH - 1)

		if my_col < target_col:
			grid_pos.x += 1
		elif my_col > target_col:
			grid_pos.x -= 1

	# ----------------------------------------------------
	# FINAL SAFETY CLAMPS 
	# ----------------------------------------------------
	grid_pos.x = clamp(grid_pos.x, 0, GRID_WIDTH - 1)
	grid_pos.y = clamp(grid_pos.y, 0, GRID_HEIGHT - 1)
	play_move_animation(old_grid_pos, grid_pos)

	grid_x = grid_pos.x
	grid_y = grid_pos.y

	target_position = grid_to_world(grid_pos)
	
# ============================================================
# SHOOT LOGIC
# ============================================================
func player_in_front() -> bool:
	# slightly forgiving so enemy doesn't feel dumb
	return abs(player_character.grid_pos.y - grid_pos.y) <= 1


func shoot():
	if attack_locked:
		return

	attack_locked = true

	attack_count += 1

	if attack_count % 3 == 0:
		shoot_double()
	else:
		shoot_single()

	await get_tree().create_timer(attack_recovery).timeout

	attack_locked = false
	
func shoot_single():
	var projectile = EnemyBasicProjectile.instantiate()

	projectile.global_position = ProjectileShootPoint.global_position
	projectile.direction = Vector2.LEFT
	projectile.damage = attack_power

	get_tree().current_scene.add_child(projectile)
	
func shoot_double():
	print("SPECIAL ATTACK!")

	var projectile = EnemyBasicProjectile.instantiate()
	projectile.global_position = ProjectileShootPoint.global_position
	projectile.direction = Vector2.LEFT
	projectile.damage = attack_power + 5
	get_tree().current_scene.add_child(projectile)

	await get_tree().create_timer(0.15).timeout

	if is_dead:
		return

	projectile = EnemyBasicProjectile.instantiate()
	projectile.global_position = ProjectileShootPoint.global_position
	projectile.direction = Vector2.LEFT
	projectile.damage = attack_power + 5
	get_tree().current_scene.add_child(projectile)
# ============================================================
# STUN
# ============================================================
func apply_stun(duration: float):
	print(name, " STUNNED for ", duration)

	stunned = true
	stun_timer = duration

func play_move_animation(old_pos: Vector2i, new_pos: Vector2i):
	var delta = new_pos - old_pos

	if delta.x > 0:
		anim_player.play("Right")
	elif delta.x < 0:
		anim_player.play("Left")
	elif delta.y > 0:
		anim_player.play("Down")
	elif delta.y < 0:
		anim_player.play("Up")
	else:
		anim_player.play("Idle")
