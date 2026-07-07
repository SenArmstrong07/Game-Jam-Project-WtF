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
	ELITE
}

var enemy_tier: EnemyTier = EnemyTier.COMMON
var battle_scene: PackedScene

func _ready() -> void:
	add_to_group("overworldmob")
	battle_scene = SignalBus.BATTLE_POOL.pick_random()

	if battle_scene == SignalBus.TROJAN_ELITE:
		enemy_tier = EnemyTier.ELITE
	else:
		enemy_tier = EnemyTier.COMMON
		
	if enemy_tier == EnemyTier.ELITE:
		make_elite()
		
	frontlayer = get_tree().get_first_node_in_group("frontlayer")
	if frontlayer == null:
		frontlayer = get_parent().get_node_or_null("TileNode/front")

	patrol_center = position
	pick_new_patrol_target()

func _physics_process(delta: float) -> void:
	var target_world_pos: Vector2 = patrol_target

	if player_chase and is_instance_valid(player):
		target_world_pos = player.position
		$sprite.play("s_walk")
		update_sprite_direction(target_world_pos)
	else:
		patrol_timer += delta
		if patrol_timer >= patrol_change_interval or position.distance_to(patrol_target) < 8.0:
			pick_new_patrol_target()
			patrol_timer = 0.0

		if position.distance_to(patrol_target) > 4.0:
			$sprite.play("s_walk")
			update_sprite_direction(patrol_target)
		else:
			$sprite.stop()

	var direction := target_world_pos - position
	if direction.length_squared() > 0.01:
		direction = direction.normalized()
		velocity = direction * speed
	else:
		velocity = Vector2.ZERO

	var next_position: Vector2 = position + velocity * delta
	if frontlayer:
		var next_tile: Vector2i = frontlayer.global_to_map(next_position)
		if not frontlayer.is_tile_walkable(next_tile):
			velocity = Vector2.ZERO
			if not player_chase:
				pick_new_patrol_target()

	move_and_slide()

func _on_detection_area_body_entered(body: Node2D) -> void:
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

	patrol_target = position

func update_sprite_direction(target_pos: Vector2) -> void:
	var horizontal_delta := target_pos.x - position.x
	if horizontal_delta > 2.0:
		$sprite.flip_h = true
	elif horizontal_delta < -2.0:
		$sprite.flip_h = false


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
