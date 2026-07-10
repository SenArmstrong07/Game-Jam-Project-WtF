extends CharacterBody2D

signal died

@export var speed = 100.0
var player_chase: bool = false
var player = null
var frontlayer: TileMapLayer

# Idle/patrol behavior
var patrol_center: Vector2
var patrol_radius: float = 200.0  # How far they can wander from spawn
var patrol_target: Vector2
var patrol_timer: float = 0.0
var patrol_change_interval: float = 3.0  # Change target every 3 seconds

# FOR BATTLESCENE ASSIGNMENT OF SPAWNED ENEMY
enum EnemyTier {
	COMMON,
	ELITE,
	BOSS
}
#Dash settings
@export var after_image_scene: PackedScene
var dash_timer : float = 0.0
var is_dashing : bool = false
const AFTERIMG_INTERVAL : float = 0.04
@export var dash_speed := 400.0
@export var dash_duration := 0.25
@export var dash_cooldown := 0.8

var dash_direction := Vector2.ZERO
var dash_duration_timer : float = 0.0
var dash_cooldown_timer : float = 0.0

var enemy_tier: EnemyTier = EnemyTier.COMMON
var battle_scene: PackedScene

const SPAWN_TYPE_COMMON := "common"
const SPAWN_TYPE_THROW := "throw"
const SPAWN_TYPE_ELITE := "elite"
const SPAWN_TYPE_BOSS := "boss"

func _ready() -> void:
	add_to_group("overworldmob")
	if battle_scene == null:
		battle_scene = _pick_random_battle_scene()

	_apply_battle_scene()
	
	frontlayer = get_tree().get_first_node_in_group("frontlayer")
	if frontlayer == null:
		frontlayer = get_parent().get_node_or_null("TileNode/front")

	patrol_center = global_position
	pick_new_patrol_target()

func _physics_process(delta: float) -> void:
	var target_world_pos: Vector2 = patrol_target
	
	#Dashers
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta

	if is_dashing:
		dash_duration_timer -= delta

		if dash_duration_timer <= 0.0:
			stop_dash()

		dash_timer += delta

		if dash_timer >= AFTERIMG_INTERVAL:
			dash_timer = 0.0
			spawn_afterimage()
	else:
		dash_timer = 0.0
	#Chasers
	if player_chase and is_instance_valid(player):
		target_world_pos = player.global_position
		$sprite.play("s_walk")
		update_sprite_direction(target_world_pos)
	else:
		patrol_timer += delta
		if patrol_timer >= patrol_change_interval or global_position.distance_to(patrol_target) < 8.0:
			pick_new_patrol_target()
			patrol_timer = 0.0

		if global_position.distance_to(patrol_target) > 4.0:
			$sprite.play("s_walk")
			update_sprite_direction(patrol_target)
		else:
			$sprite.stop()
	#enabling dash
	if player_chase and !is_dashing and dash_cooldown_timer <= 0.0:
		start_dash()

	if is_dashing:
		velocity = dash_direction * dash_speed
	else:
		var direction := target_world_pos - global_position

		if direction.length_squared() > 0.01:
			direction = direction.normalized()
			velocity = direction * speed
		else:
			velocity = Vector2.ZERO

	var next_position: Vector2 = global_position + velocity * delta
	if frontlayer:
		var next_tile: Vector2i = frontlayer.global_to_map(next_position)
		if not frontlayer.is_tile_walkable(next_tile):
			velocity = Vector2.ZERO
			if not player_chase:
				pick_new_patrol_target()

	move_and_slide()

	# Enforce world bounds so enemies cannot wander or be pushed outside the playable area
	if frontlayer:
		var bounds: Rect2 = frontlayer.get_world_bounds()
		var minx = bounds.position.x
		var maxx = bounds.position.x + bounds.size.x
		var miny = bounds.position.y
		var maxy = bounds.position.y + bounds.size.y
		var gp = global_position
		var clamped = Vector2(clamp(gp.x, minx, maxx), clamp(gp.y, miny, maxy))
		if gp != clamped:
			global_position = clamped
			velocity = Vector2.ZERO
			if not player_chase:
				# Reset patrol center/target to current clamped position
				patrol_center = global_position
				patrol_target = global_position

func _on_detection_area_body_entered(body: Node2D) -> void:
	# Use canonical player node if available to ensure we get global_position
	var canonical = get_tree().get_first_node_in_group("player")
	if canonical:
		player = canonical
	else:
		player = body
	player_chase = true

func _on_detection_area_body_exited(body: Node2D) -> void:
	player = null
	player_chase = false

func _on_battle_trigger_body_entered(body: Node2D) -> void:
	if body == player:
		trigger_battle()

func trigger_battle() -> void:
	var cybermap = get_tree().get_first_node_in_group("Cybermap")
	if cybermap:
		cybermap.store_overworld_state()

	SignalBus.start_battle(self)

func disappear() -> void:
	# Remove any marker linked by minimap system if present
	if has_signal("died"):
		emit_signal("died")
	queue_free()

func pick_new_patrol_target() -> void:
	var attempts := 0
	while attempts < 8:
		var angle := randf() * TAU
		var radius := randf() * patrol_radius
		var candidate := patrol_center + Vector2(cos(angle), sin(angle)) * radius
		if not frontlayer or frontlayer.is_tile_walkable(frontlayer.global_to_map(candidate)):
			patrol_target = candidate
			return
		attempts += 1
	patrol_target = global_position

func start_dash():
	if !player_chase:
		return

	if !is_instance_valid(player):
		return

	is_dashing = true
	dash_duration_timer = dash_duration
	dash_timer = 0.0

	dash_direction = (player.global_position - global_position).normalized()


func stop_dash():
	is_dashing = false
	dash_cooldown_timer = dash_cooldown

func update_sprite_direction(target_pos: Vector2) -> void:
	var horizontal_delta := target_pos.x - global_position.x
	if horizontal_delta > 2.0:
		$sprite.flip_h = true
	elif horizontal_delta < -2.0:
		$sprite.flip_h = false

func spawn_afterimage():
	var ghost = after_image_scene.instantiate()

	get_parent().add_child(ghost)

	ghost.global_position = global_position
	ghost.global_rotation = global_rotation
	ghost.scale = scale

	ghost.setup($sprite)

func _pick_random_battle_scene() -> PackedScene:
	var roll := randi_range(1, 100)
	if roll <= 38:
		return SignalBus.COMMON_BUG
	if roll <= 75:
		return SignalBus.THROW_BUG
	return SignalBus.TROJAN_ELITE

func _apply_battle_scene() -> void:
	if enemy_tier == EnemyTier.BOSS:
		make_boss()
		return

	if battle_scene == SignalBus.TROJAN_ELITE:
		enemy_tier = EnemyTier.ELITE
		make_elite()
	else:
		enemy_tier = EnemyTier.COMMON

func get_spawn_type() -> String:
	if enemy_tier == EnemyTier.BOSS:
		return SPAWN_TYPE_BOSS
	if battle_scene == SignalBus.TROJAN_ELITE:
		return SPAWN_TYPE_ELITE
	if battle_scene == SignalBus.THROW_BUG:
		return SPAWN_TYPE_THROW
	if battle_scene == SignalBus.COMMON_BUG:
		return SPAWN_TYPE_COMMON
	return SPAWN_TYPE_COMMON

func apply_spawn_type(spawn_type: String) -> void:
	match spawn_type:
		SPAWN_TYPE_ELITE:
			battle_scene = SignalBus.TROJAN_ELITE
			enemy_tier = EnemyTier.ELITE
		SPAWN_TYPE_THROW:
			battle_scene = SignalBus.THROW_BUG
			enemy_tier = EnemyTier.COMMON
		SPAWN_TYPE_COMMON:
			battle_scene = SignalBus.COMMON_BUG
			enemy_tier = EnemyTier.COMMON
		SPAWN_TYPE_BOSS:
			battle_scene = SignalBus.BOSS_SPAG
			enemy_tier = EnemyTier.BOSS
		_:
			battle_scene = _pick_random_battle_scene()
			enemy_tier = EnemyTier.COMMON

	_apply_battle_scene()

func make_elite() -> void:
	# Make the enemy slightly larger
	scale = Vector2(1.3, 1.3)

	# Create an infinite breathing tween
	var tween := create_tween()
	tween.set_loops()

	tween.tween_property(self, "scale", Vector2(1.42, 1.42), 0.15)
	tween.parallel().tween_property($sprite, "modulate", Color(1, 0.35, 0.35), 0.15)

	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.45)
	tween.parallel().tween_property($sprite, "modulate", Color.WHITE, 0.45)

func make_boss() -> void:
	# Bigger than elite
	scale = Vector2(1.6, 1.6)

	# Purple glow
	$sprite.modulate = Color(0.75, 0.25, 1.0)

	var tween := create_tween()
	tween.set_loops()

	# Grow
	tween.tween_property(self, "scale", Vector2(1.72, 1.72), 0.25)
	tween.parallel().tween_property(
		$sprite,
		"modulate",
		Color(1.0, 0.4, 1.0),
		0.25
	)

	# Shrink
	tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.4)
	tween.parallel().tween_property(
		$sprite,
		"modulate",
		Color(0.75, 0.25, 1.0),
		0.4
	)
