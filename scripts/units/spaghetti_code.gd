extends Unit

@onready var player_character: Unit = $"../PlayerCharacter"
@onready var anim_player: AnimatedSprite2D = $BossSC_Sprite
@onready var battle_scene: BattleBase = get_parent()
const ENEMY_BASIC_PROJECTILE = preload("uid://cnt0okx0i7ily")
const THROW_PROJECTILE = preload("uid://dieb2klqxxsjl")
@onready var BOSS_MARKER: Marker2D = $HitPoint
@export var projectile_speed :=450.0

const GRID_WIDTH := 4
const GRID_HEIGHT := 4
const TILE_SIZE := 64
const X_OFFSET := 4

var attack_timer := 0.0
var attack_interval := 1.5
var attack_locked := false
var basic_attack_count := 0
var attack_pause := false

var movement_locked := true  # boss never moves
var jumping := false

@export var jump_height := 450.0
@export var jump_time := 0.45
@onready var hp_label: Label = $HPLabel

# ============================================================
# INIT
# ============================================================
func _ready():
	z_index = 10
	team = Team.ENEMY
	add_to_group("enemies")

# ============================================================
# GRID SETUP (IMPORTANT)
# ============================================================
func init(pos: Vector2i) -> void:
	grid_pos = pos

	_reserve_tiles(true)

	position = get_boss_center_world()

func get_boss_center_world() -> Vector2:
	var top_left = grid_pos

	var center_tile = Vector2(
		top_left.x + 0.5,
		top_left.y + 0.5
	)

	return Vector2(
		(center_tile.x + X_OFFSET) * TILE_SIZE + TILE_SIZE / 2.0,
		center_tile.y * TILE_SIZE + TILE_SIZE / 2.0
	)
	
# ============================================================
# TILE OCCUPATION (4 TILES)
# ============================================================
func get_occupied_tiles(center: Vector2i) -> Array[Vector2i]:
	return [
		center,
		center + Vector2i.RIGHT,
		center + Vector2i.DOWN,
		center + Vector2i(1, 1)
	]

func _reserve_tiles(state: bool) -> void:
	for t in get_occupied_tiles(grid_pos):
		if state:
			battle_scene.occupied_tiles[t] = true
		else:
			battle_scene.occupied_tiles.erase(t)

# ============================================================
# WORLD POSITION (CENTER OF 2x2)
# ============================================================
func grid_to_world(cell: Vector2i) -> Vector2:
	var world_grid_x = cell.x + X_OFFSET

	return Vector2(
		world_grid_x * TILE_SIZE + TILE_SIZE / 2.0,
		cell.y * TILE_SIZE + TILE_SIZE / 2.0
	)
	
func clamp_to_arena(tile: Vector2i) -> Vector2i:
	var min_tile = grid_pos
	var max_tile = grid_pos + Vector2i(GRID_WIDTH - 1, GRID_HEIGHT - 1)

	return Vector2i(
		clamp(tile.x, min_tile.x, max_tile.x),
		clamp(tile.y, min_tile.y, max_tile.y)
	)
# ============================================================
# PROCESS (ONLY ATTACKS, NO MOVEMENT)
# ============================================================
func _process(delta):
	if battle_scene.current_phase != BattleBase.BattlePhase.BATTLE:
		return

	if is_dead:
		return

	if attack_pause:
		return

	attack_timer += delta

	if attack_timer >= attack_interval and !attack_locked:
		attack_timer = 0.0
		attack_locked = true

		start_attack()

# ============================================================
#  BOSS ATTACK
# ============================================================
func jump_slam():
	jumping = true
	attack_locked = true

	var start_pos = global_position
	var target_tile := player_character.grid_pos

	var sprite_offset := anim_player.position

	var target = Vector2(
		player_character.grid_pos.x * TILE_SIZE + TILE_SIZE,
		player_character.grid_pos.y * TILE_SIZE + TILE_SIZE
	)

	target -= sprite_offset
	
	show_jump_warning(target_tile)

	# =========================
	# JUMP UP (squash + lift)
	# =========================
	var up = create_tween()
	up.set_parallel()

	up.tween_property(self, "scale", Vector2(0.7, 1.3), jump_time * 0.3)
	up.tween_property(self, "global_position:y", global_position.y - jump_height, jump_time)
	up.tween_property(self, "rotation", deg_to_rad(-8), jump_time * 0.5)

	await up.finished

	# small air hang feel
	var hang = create_tween()
	hang.tween_property(self, "scale", Vector2(0.6, 0.6), 0.1)
	await hang.finished

	visible = false
	await get_tree().create_timer(0.6).timeout

	global_position = Vector2(target.x, -jump_height)
	visible = true

	show_jump_warning(target_tile)

	await get_tree().create_timer(0.4).timeout

	# =========================
	# DESCEND (drop + prepare impact)
	# =========================
	var down = create_tween()
	down.set_parallel()

	down.tween_property(self, "global_position", target, jump_time * 0.75)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)

	down.tween_property(self, "scale", Vector2(1.4, 0.6), jump_time * 0.5)

	await down.finished

	# =========================
	# IMPACT PUNCH
	# =========================
	var impact = create_tween()
	impact.set_parallel()

	impact.tween_property(self, "scale", Vector2(1.25, 0.75), 0.05)
	impact.tween_property(self, "scale", Vector2.ONE, 0.12)
	impact.tween_property(self, "rotation", 0.0, 0.1)

	slam_damage(target_tile)
	break_slam_tiles(target_tile) 
	screen_shake(10.0)

	await impact.finished

	# =========================
	# RETURN
	# =========================
	var retreat = create_tween()
	retreat.tween_property(self, "global_position", start_pos, 0.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

	await retreat.finished

	jumping = false
	attack_locked = false

func break_slam_tiles(center: Vector2i):

	var tiles = [
		center,
		center + Vector2i.RIGHT,
		center + Vector2i.DOWN,
		center + Vector2i(1, 1)
	]

	for tile in tiles:
		battle_scene.break_tile(tile)

	# Push player away if standing on a broken tile
	if player_character.grid_pos in tiles:
		push_player_out(tiles)

	await get_tree().create_timer(3.0).timeout

	for tile in tiles:
		battle_scene.restore_tile(tile)
				
func show_jump_warning(tile: Vector2i):

	var tiles = [
		tile,
		tile + Vector2i.RIGHT,
		tile + Vector2i.DOWN,
		tile + Vector2i(1, 1)
	]

	for t in tiles:

		if !is_grid_tile(t):
			continue

		var marker := ColorRect.new()
		marker.size = Vector2(TILE_SIZE, TILE_SIZE)
		marker.position = Vector2(
			t.x * TILE_SIZE,
			t.y * TILE_SIZE
		)
		marker.color = Color(1, 0, 0, 0.45)

		get_tree().current_scene.add_child(marker)

		var tween = marker.create_tween()
		tween.set_loops(5)
		tween.tween_property(marker, "modulate:a", 1.0, 0.08)
		tween.tween_property(marker, "modulate:a", 0.2, 0.08)

		tween.finished.connect(func():
			if is_instance_valid(marker):
				marker.queue_free()
		)

	await get_tree().create_timer(0.6).timeout

func push_player_out(broken_tiles: Array):

	var directions = [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN
	]

	for dir in directions:

		var test = player_character.grid_pos + dir

		# Stay inside player's arena
		if test.x < 0 or test.x > 3:
			continue

		if test.y < 0 or test.y > 3:
			continue

		if battle_scene.is_tile_walkable(test):

			player_character.grid_pos = test
			player_character.target_position = player_character.grid_to_world(test)
			player_character.moving = true
			var tween = create_tween()
			tween.tween_property(
				player_character,
				"position",
				player_character.grid_to_world(test),
				0.18
			).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

			await tween.finished

			player_character.moving = false

			return
				
func is_grid_tile(tile: Vector2i) -> bool:
	if tile.y < 0 or tile.y >= GRID_HEIGHT:
		return false

	# Player side (0-3)
	if tile.x >= 0 and tile.x < GRID_WIDTH:
		return true

	# Enemy side (4-7)
	if tile.x >= X_OFFSET and tile.x < X_OFFSET + GRID_WIDTH:
		return true

	return false

func start_attack():

	if basic_attack_count >= 3:
		basic_attack_count = 0

		if randf() < 1:
			await jump_slam()
		else:
			await throw_barrage()

		await get_tree().create_timer(1.0).timeout

	else:
		basic_attack_count += 1
		await shoot_spread()

	attack_locked = false
	
func slam_damage(tile: Vector2i):

	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return

	var hit_tiles = [
		tile,
		tile + Vector2i.RIGHT,
		tile + Vector2i.DOWN,
		tile + Vector2i(1, 1)
	]

	if player.grid_pos in hit_tiles:
		player.take_damage(attack_power + 20)
		player.play_slam_hit()
		
func screen_shake(intensity := 8.0):
	var tree := get_tree()
	if tree == null:
		return

	var cam := tree.get_first_node_in_group("Camera") as Camera2D
	if cam == null:
		cam = get_viewport().get_camera_2d()

	if cam == null:
		return

	var original := cam.position

	for i in range(6):
		if !is_inside_tree():
			break

		cam.position = original + Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)

		await tree.create_timer(0.02).timeout

	cam.position = original
			
func throw_barrage():
	anim_player.play("ATTACK")
	await get_tree().create_timer(0.25).timeout
	
	var rows = [0,1,2,3]
	rows.shuffle()

	for row in rows:

		var projectile = THROW_PROJECTILE.instantiate()
		get_tree().current_scene.add_child(projectile)

		projectile.global_position = BOSS_MARKER.global_position
		projectile.global_position.y = grid_to_world(Vector2i(3, row)).y
		projectile.damage = attack_power

		projectile.throw_bounce()

		await get_tree().create_timer(0.20).timeout
		anim_player.play("IDLE")
	# Wait for the last bounce attack to mostly finish
	await get_tree().create_timer(2.0).timeout
	
func shoot_spread():

	anim_player.play("ATTACK")

	await get_tree().create_timer(0.25).timeout

	var safe_row := randi_range(0, 3)

	for row in range(4):
		if row == safe_row:
			continue

		var projectile = ENEMY_BASIC_PROJECTILE.instantiate()
		get_tree().current_scene.add_child(projectile)

		projectile.global_position = BOSS_MARKER.global_position
		projectile.global_position.y += (row - 1.5) * TILE_SIZE

		projectile.direction = Vector2.LEFT
		projectile.damage = attack_power
		projectile.speed = projectile_speed

	
	await get_tree().create_timer(0.25).timeout
	anim_player.play("IDLE")
	
func shoot_row(row: int):
	var projectile = ENEMY_BASIC_PROJECTILE.instantiate()

	get_tree().current_scene.add_child(projectile)

	# Spawn from the boss's side, aligned with this row
	projectile.global_position = grid_to_world(Vector2i(3, row))

	projectile.direction = Vector2.LEFT
	projectile.damage = attack_power
	
# ============================================================
# PLAYER EFFECT TO BOSS
# ===============================================

func play_hurt():
	if is_dead or is_hurt:
		return

	is_hurt = true

	anim_player.modulate = Color(1, 0.3, 0.3)

	if anim_player.sprite_frames.has_animation("Hurt"):
		anim_player.play("Hurt")

	await get_tree().create_timer(0.15).timeout

	anim_player.modulate = Color.WHITE

	if anim_player.sprite_frames.has_animation("Idle"):
		anim_player.play("Idle")

	is_hurt = false

func update_hp_label():
	hp_label.text = str(hp)
	
func take_damage(amount: int, damage_type = DamageType.NEUTRAL, chip = null):
	super.take_damage(amount, damage_type, chip)

	update_hp_label()
	if not is_dead:
		play_hurt()
