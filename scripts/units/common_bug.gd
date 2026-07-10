extends Unit

const EnemyBasicProjectile = preload("res://scenes/Attacks/enemy_basic_projectile.tscn")
const ENEMY_HIT_SFX = preload("uid://b3k82ni30qus0")
const ENEMY_PROJECTILE_SFX = preload("uid://bnle2l36i7wf4")

const GRID_WIDTH := 4
const GRID_HEIGHT := 4
const X_OFFSET := 4
const TILE_SIZE := 64

var anim_player: AnimatedSprite2D
var player_character: Unit
var battle_scene: BattleBase
var ProjectileShootPoint: Marker2D
var hp_label: Label

var target_position := Vector2.ZERO
var attack_locked := false
@export var attack_recovery := 0.5

var stun_tween: Tween
var original_modulate := Color.WHITE
var movement_locked := false

var follow_timer := 0.0
var follow_interval := 0.25

var shoot_timer := 0.0
var shoot_interval := 0.75

var stunned := false
var stun_timer := 0.0

var move_speed := 220.0
var attack_count := 0

# internal lane oscillation state
var lane_direction := 1
var lane_timer := 0.0
var lane_switch_interval := 0.6
var displayed_hp := 0
var hp_tween: Tween



func _ready():
	# Call parent's _ready first to initialize sprite and hp
	super._ready()
	
	z_index = 10
	team = Team.ENEMY
	add_to_group("enemies")
	
	# Cache node references now that we're in the tree
	anim_player = $AnimatedSprite2D
	hp_label = $HPLabel
	ProjectileShootPoint = $HitPoint
	battle_scene = get_parent()
	
	# Get player character from the battle scene
	if battle_scene:
		player_character = battle_scene.find_child("PlayerCharacter", true, false) as Unit
	
	displayed_hp = hp
	if hp_label:
		hp_label.text = str(displayed_hp)
	
	update_hp_label()

func init(pos: Vector2i) -> void:
	grid_pos = pos
	position = grid_to_world(pos)
	target_position = position

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

func grid_to_world(cell: Vector2i) -> Vector2:
	var world_grid_x = cell.x + X_OFFSET
	
	return Vector2(
		world_grid_x * TILE_SIZE + TILE_SIZE / 2.0,
		cell.y * TILE_SIZE + TILE_SIZE / 2.0
	)
	

func _process(delta):
	if battle_scene.current_phase != BattleBase.BattlePhase.BATTLE:
		return
	if movement_locked:
	# still allow smooth interpolation ONLY
		position = position.move_toward(target_position, move_speed * delta)
		return
	# =========================
	# STUN TIMER ONLY
	# =========================
	if stunned:
		stun_timer -= delta
	if stun_timer <= 0:
		stunned = false

		# restore color
		if stun_tween:
			stun_tween.kill()
			stun_tween = null

		modulate = original_modulate

	# =========================
	# ALWAYS MOVE TOWARD TILE
	# =========================
	position = position.move_toward(target_position, move_speed * delta)

	# If still stunned → stop AI decisions here
	if stunned:
		return

	# =========================
	# NORMAL AI BELOW
	# =========================

	follow_timer += delta
	shoot_timer += delta
	lane_timer += delta

	# switch lane direction
	if lane_timer >= lane_switch_interval:
		lane_timer = 0.0
		lane_direction *= -1

	if follow_timer >= follow_interval:
		follow_timer = 0.0
		follow_player()

	if shoot_timer >= shoot_interval and not attack_locked:
		shoot_timer = 0.0

		if can_shoot_player():
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

	var move_axis := randi() % 2
	var next_pos := grid_pos

	# vertical
	if move_axis == 0:
		if my_row < player_row:
			next_pos.y += 1
		elif my_row > player_row:
			next_pos.y -= 1
		else:
			next_pos.y += [-1, 1].pick_random()

	# horizontal
	else:
		var target_col := player_col + 1

		if int(Time.get_ticks_msec() / 700) % 2 == 0:
			target_col = player_col + 1
		else:
			target_col = player_col + 2

		target_col = clamp(target_col, 0, GRID_WIDTH - 1)

		if my_col < target_col:
			next_pos.x += 1
		elif my_col > target_col:
			next_pos.x -= 1

	# ❗ HARD BLOCK: ONLY ONE AUTHORITY
	if battle_scene.is_tile_free(next_pos):

		# release old tile
		battle_scene.occupied_tiles.erase(grid_pos)

		# reserve new tile IMMEDIATELY
		grid_pos = next_pos
		battle_scene.occupied_tiles[grid_pos] = true

	# update visuals ALWAYS
	play_move_animation(old_grid_pos, grid_pos)
	target_position = grid_to_world(grid_pos)

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
	
func shoot():
	if attack_locked:
		return

	attack_locked = true
	movement_locked = true

	attack_count += 1

	# Play attack animation
	if anim_player.sprite_frames.has_animation("Attack"):
		anim_player.play("Attack")

	# Wait for most of the animation before firing
	await get_tree().create_timer(0.2).timeout

	if is_dead:
		return

	if attack_count % 3 == 0:
		await shoot_double()
	else:
		await shoot_single()

	# Return to movement/idle animation
	play_move_animation(grid_pos, grid_pos)

	await get_tree().create_timer(attack_recovery).timeout

	attack_locked = false
	movement_locked = false
	
func shoot_single():
	var projectile = EnemyBasicProjectile.instantiate()

	var spawn_pos = ProjectileShootPoint.global_position
	projectile.global_position = spawn_pos

	projectile.direction = Vector2.LEFT
	projectile.damage = attack_power
	play_sfx(ENEMY_PROJECTILE_SFX, -15)
	get_tree().current_scene.add_child(projectile)
	
func shoot_double():
	print("SPECIAL ATTACK!")

	var spawn_pos = ProjectileShootPoint.global_position

	play_sfx(ENEMY_PROJECTILE_SFX, -15)

	var projectile = EnemyBasicProjectile.instantiate()
	projectile.global_position = spawn_pos
	projectile.direction = Vector2.LEFT
	projectile.damage = attack_power + 5
	get_tree().current_scene.add_child(projectile)

	await get_tree().create_timer(0.15).timeout

	if is_dead:
		return

	play_sfx(ENEMY_PROJECTILE_SFX, -15)

	projectile = EnemyBasicProjectile.instantiate()
	projectile.global_position = spawn_pos
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
		
func play_hurt():
	if is_dead or is_hurt:
		return

	is_hurt = true
	play_sfx(ENEMY_HIT_SFX, -15)
	anim_player.modulate = Color(1, 0.3, 0.3)

	if anim_player.sprite_frames.has_animation("Hurt"):
		anim_player.play("Hurt")

		var frame_count = anim_player.sprite_frames.get_frame_count("Hurt")
		var fps = anim_player.sprite_frames.get_animation_speed("Hurt")

		if fps <= 0:
			fps = 10.0

		var duration = float(frame_count) / fps
		await get_tree().create_timer(duration).timeout

	anim_player.modulate = Color.WHITE
	is_hurt = false

	play_move_animation(grid_pos, grid_pos)
	
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
	
