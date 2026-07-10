extends Unit


@onready var battle_scene: BattleBase = get_parent()
@onready var trojan_marker: Marker2D = $HitPoint

@onready var player_character: Unit = $"../PlayerCharacter"
@onready var anim_player: AnimatedSprite2D = $AnimatedSprite2D

const TROJAN_PROJECTILE = preload("uid://c7kgeep4y4jl1")
const TROJAN_THROWABLE = preload("uid://b6oe25yx1mgl3")

const GRID_WIDTH := 4
const GRID_HEIGHT := 4
const X_OFFSET := 4
const TILE_SIZE := 64
var attack_count := 0
var active_trap_tiles: Array[Vector2i] = []

var last_trap_tile := Vector2i(-1, -1)
var target_position := Vector2.ZERO
var attack_locked := false
@export var attack_recovery := 0.25
@onready var hp_label: Label = $HPLabel

var stun_tween: Tween
var original_modulate := Color.WHITE
var movement_locked := false

var follow_timer := 0.0
var follow_interval := 0.5

var shoot_timer := 0.0
var shoot_interval := 0.5

var stunned := false
var stun_timer := 0.0

var move_speed := 220.0
var moving := false
var displayed_hp := 0
var hp_tween: Tween

func _ready():
	randomize()
	z_index = 10
	team = Team.ENEMY
	add_to_group("enemies")

func init(pos: Vector2i) -> void:
	grid_pos = pos
	position = grid_to_world(pos)
	target_position = position

func grid_to_world(cell: Vector2i) -> Vector2:
	var world_grid_x = cell.x + X_OFFSET
	
	return Vector2(
		world_grid_x * TILE_SIZE + TILE_SIZE / 2.0,
		cell.y * TILE_SIZE + TILE_SIZE / 2.0
	)
	

func _process(delta):
	if battle_scene.current_phase != BattleBase.BattlePhase.BATTLE:
		return

	if is_dead:
		return

	# ==========================================
	# Handle stun
	# ==========================================
	if stunned:
		stun_timer -= delta

		if stun_timer <= 0.0:
			stunned = false

			if stun_tween:
				stun_tween.kill()
				stun_tween = null

			modulate = original_modulate

	# ==========================================
	# Smooth movement
	# ==========================================
	position = position.move_toward(target_position, move_speed * delta)

	if moving and position.distance_to(target_position) < 1.0:

		position = target_position
		moving = false
	# Don't think while stunned
	if stunned:
		return

	# Timers should ALWAYS run
	follow_timer += delta
	shoot_timer += delta

	# ==========================================
	# Movement
	# ==========================================
	if !moving and follow_timer >= follow_interval:
		follow_timer = 0.0
		random_move()

	# ==========================================
	# Attack
	# ==========================================
	if shoot_timer >= shoot_interval:
		shoot_timer = 0.0

		if can_shoot_player():
			perform_attack()

# ============================================================
# CORE MOVEMENT (LANE CONTROL AI)
# ============================================================
func move_to_player(target_tile: Vector2i) -> bool:

	if moving:
		return false

	var choices = [
		target_tile + Vector2i.RIGHT,
		target_tile + Vector2i.LEFT,
		target_tile + Vector2i.UP,
		target_tile + Vector2i.DOWN
	]

	var target := grid_pos

	for pos in choices:

		pos.x = clamp(pos.x, 0, GRID_WIDTH - 1)
		pos.y = clamp(pos.y, 0, GRID_HEIGHT - 1)

		if battle_scene.is_tile_free(pos):

			target = pos
			break

	if target == grid_pos:
		return false

	moving = true

	battle_scene.occupied_tiles.erase(grid_pos)

	grid_pos = target

	battle_scene.occupied_tiles[grid_pos] = true

	target_position = grid_to_world(grid_pos)

	while position.distance_to(target_position) > 2.0:

		if !is_inside_tree():
			return false

		await get_tree().process_frame

	position = target_position

	moving = false

	return true
			
func random_move():

	if moving:
		return

	var old_grid_pos = grid_pos

	var directions = [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN
	]

	directions.shuffle()

	for dir in directions:

		var next_pos = grid_pos + dir

		next_pos.x = clamp(next_pos.x, 0, GRID_WIDTH - 1)
		next_pos.y = clamp(next_pos.y, 0, GRID_HEIGHT - 1)

		if battle_scene.is_tile_free(next_pos):

			battle_scene.occupied_tiles.erase(grid_pos)

			grid_pos = next_pos

			battle_scene.occupied_tiles[grid_pos] = true

			target_position = grid_to_world(grid_pos)

			play_move_animation(old_grid_pos, grid_pos)

			moving = true
			return
			
func perform_attack():

	if attack_locked or is_dead:
		return

	attack_locked = true

	if randi() % 100 < 65:
		throw_trap()
	else:
		shoot_projectile()

	await get_tree().create_timer(attack_recovery).timeout

	if is_instance_valid(self):
		attack_locked = false
		
# ============================================================
# SHOOT LOGIC
# ============================================================
func player_in_front() -> bool:
	return player_character != null

func can_shoot_player() -> bool:
	if player_character == null:
		return false

	# must be roughly aligned vertically (same lane system)
	if abs(player_character.grid_pos.y - grid_pos.y) > 1:
		return false

	# check if ANY enemy is between this enemy and player
	var player_x = player_character.grid_pos.x
	var my_x = grid_pos.x

	var step = sign(player_x - my_x)

	# if player is behind or same tile, skip
	if step == 0:
		return false

	var x = my_x + step

	while x != player_x:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e != self and e.grid_pos.x == x and abs(e.grid_pos.y - grid_pos.y) <= 1:
				return false
		x += step

	return true

func shoot_projectile():

	var projectile = TROJAN_PROJECTILE.instantiate()

	get_tree().current_scene.add_child(projectile)

	projectile.global_position = trojan_marker.global_position

	projectile.direction = Vector2.LEFT
	projectile.damage = attack_power

	projectile.shooter = self
	
func throw_trap():

	var candidates: Array[Vector2i] = []

	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):

			var tile := Vector2i(x, y)

			if tile == last_trap_tile:
				continue

			if active_trap_tiles.has(tile):
				continue

			candidates.append(tile)

	if candidates.is_empty():
		return

	var random_tile = candidates.pick_random()

	last_trap_tile = random_tile
	active_trap_tiles.append(random_tile)

	var trap = TROJAN_THROWABLE.instantiate()

	get_tree().current_scene.add_child(trap)

	trap.global_position = trojan_marker.global_position

	trap.player_stunned.connect(_on_player_stunned)

	trap.tree_exited.connect(func():
		active_trap_tiles.erase(random_tile)
	)

	trap.throw_to(random_tile)
	
# ============================================================
# STUN
# ============================================================
func _on_player_stunned(tile: Vector2i):

	if attack_locked:
		return

	var reached = await move_to_player(tile)

	if !reached:
		return

	shoot_projectile()

	await get_tree().create_timer(0.15).timeout

	if is_instance_valid(self):
		shoot_projectile()
			
func apply_stun(duration: float):
	print(name, " STUNNED for ", duration)

	stunned = true
	stun_timer = duration

	# save original color once
	original_modulate = modulate

	# stop old tween if exists
	if stun_tween:
		stun_tween.kill()

	# turn yellow
	modulate = Color(1, 1, 0)

	# electric flicker effect
	stun_tween = create_tween()
	stun_tween.set_loops()

	stun_tween.tween_property(self, "modulate", Color(1, 1, 0.4), 0.1)
	stun_tween.tween_property(self, "modulate", Color(1, 1, 0.9), 0.1)

func play_move_animation(old_pos: Vector2i, new_pos: Vector2i):

	if is_hurt:
		return

	var delta := new_pos - old_pos

	# Horizontal movement
	if delta.x != 0:
		anim_player.flip_h = delta.x > 0
		anim_player.play("MOVE")

	# Vertical movement
	elif delta.y != 0:
		anim_player.flip_h = false
		anim_player.play("UP_AND_DOWN")

	# No movement
	else:
		anim_player.flip_h = false
		anim_player.play("IDLE")

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

	if hp_tween:
		hp_tween.kill()

	# Flash red
	hp_label.modulate = Color.RED

	hp_tween = create_tween()

	hp_tween.set_parallel(true)

	# Count down
	hp_tween.tween_method(
		func(value):
			displayed_hp = roundi(value)
			hp_label.text = str(displayed_hp),
		displayed_hp,
		hp,
		0.25
	)

	# Return to white
	hp_tween.tween_property(
		hp_label,
		"modulate",
		Color.WHITE,
		0.25
	)

func take_damage(amount: int, damage_type = DamageType.NEUTRAL, chip = null):
	super.take_damage(amount, damage_type, chip)
	
	update_hp_label()
	if not is_dead:
		play_hurt()

func is_tile_occupied(test_pos: Vector2i) -> bool:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and e.grid_pos == test_pos:
			return true
	return false
