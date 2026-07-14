extends Unit


@onready var battle_scene: BattleBase = get_parent()
@onready var trojan_marker: Marker2D = $HitPoint

@onready var player_character: Unit = $"../PlayerCharacter"
@onready var anim_player: AnimatedSprite2D = $AnimatedSprite2D

const TROJAN_PROJECTILE = preload("uid://c7kgeep4y4jl1")
const TROJAN_THROWABLE = preload("uid://b6oe25yx1mgl3")

const ENEMY_HIT = preload("uid://b3k82ni30qus0")
const TRAP_PROJECTILE = preload("uid://dvj4kvagu5wy2")

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

var executing_stun_attack := false

func _ready():
	randomize()
	z_index = 10
	team = Team.ENEMY
	add_to_group("enemies")

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

	get_tree().current_scene.add_child(player)

	player.play()

	player.finished.connect(func():
		player.queue_free()
	)

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

	# HANDLE STUN TIMER
	if stunned:

		stun_timer -= delta

		if stun_timer <= 0:

			stunned = false

			if stun_tween:
				stun_tween.kill()
				stun_tween = null

			modulate = original_modulate

	# MOVEMENT ALWAYS HAPPENS
	position = position.move_toward(
		target_position,
		move_speed * delta
	)
	if moving and position.distance_to(target_position) < 1.0:

		position = target_position
		moving = false

		if !attack_locked and !is_hurt:
			anim_player.play("IDLE")
	# LOCK THINKING ONLY

	if attack_locked:
		return
	# STUN PREVENTS THINKIN
	if stunned:
		return
	# TIMERS
	follow_timer += delta
	shoot_timer += delta
	# AI MOVEMENT
	if !moving and follow_timer >= follow_interval:

		follow_timer = 0.0
		random_move()
	# ATTACK
	if shoot_timer >= shoot_interval:

		shoot_timer = 0.0

		if can_shoot_player():
			perform_attack()
			
# CORE MOVEMENT (LANE CONTROL AI)
func move_to_player(target_tile: Vector2i) -> bool:

	if moving:
		while moving:
			await get_tree().process_frame

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
	if attack_locked or is_dead or is_hurt:
		return

	attack_locked = true

	anim_player.play("ATTACK")

	# Wait only until the frame where the attack should happen
	await get_tree().create_timer(0.12).timeout

	if randi() % 100 < 65:
		throw_trap()
	else:
		shoot_projectile()

	# Finish the rest of the animation
	await get_tree().create_timer(0.18).timeout

	attack_locked = false

	if !moving:
		anim_player.play("IDLE")
		
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

	if executing_stun_attack:
		return

	executing_stun_attack = true
	attack_locked = true

	var reached = await move_to_player(player_character.grid_pos)

	if reached:
		anim_player.play("ATTACK")
		await get_tree().create_timer(0.12).timeout
		shoot_projectile()
		await get_tree().create_timer(0.15).timeout
		shoot_projectile()

	attack_locked = false
	executing_stun_attack = false

	if !moving:
		anim_player.play("IDLE")
		
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

	if is_hurt or attack_locked:
		return

	var delta := new_pos - old_pos

	if delta.x > 0:
		anim_player.play("MOVE_FORWARD")

	elif delta.x < 0:
		anim_player.play("MOVE_BACKWARD")

	elif delta.y != 0:
		anim_player.play("UP_AND_DOWN")

	else:
		anim_player.play("IDLE")
		
func play_hurt():

	if is_dead or is_hurt:
		return

	is_hurt = true

	anim_player.modulate = Color(1, 0.3, 0.3)
	anim_player.play("HURT")

	var frames = anim_player.sprite_frames
	var frame_count = frames.get_frame_count("HURT")
	var fps = frames.get_animation_speed("HURT")

	if fps <= 0:
		fps = 10.0

	await get_tree().create_timer(frame_count / fps).timeout

	anim_player.modulate = Color.WHITE
	is_hurt = false

	if !moving and !attack_locked:
		anim_player.play("IDLE")
		
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
	play_sfx(ENEMY_HIT, -15)
	super.take_damage(amount, damage_type, chip)
	
	update_hp_label()
	if not is_dead:
		play_hurt()

func is_tile_occupied(test_pos: Vector2i) -> bool:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and e.grid_pos == test_pos:
			return true
	return false
