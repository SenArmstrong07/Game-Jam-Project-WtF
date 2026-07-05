extends CharacterBody2D 

#temporary overworld enemy object lang toh

signal died

@export var speed = 70.0
var player_chase : bool = false
var player = null
var frontlayer: TileMapLayer
var path_grid: AStar2D
var current_path: Array[Vector2i] = []
var path_index := 0

# Idle/patrol behavior
var is_idle : bool = true
var patrol_center : Vector2
var patrol_radius : float = 200.0  # How far they can wander from spawn
var patrol_target : Vector2
var patrol_speed : float = 50.0  # Slower than chase speed
var patrol_timer : float = 0.0
var patrol_change_interval : float = 3.0  # Change target every 3 seconds
var move_timer := 0.0
var move_interval := 0.2

func _ready() -> void:
	add_to_group("overworldmob")
	frontlayer = get_tree().get_first_node_in_group("frontlayer")
	if frontlayer == null:
		frontlayer = get_parent().get_node_or_null("TileNode/front")
	# Set patrol center to spawn position
	patrol_center = position
	_ensure_path_grid()
	pick_new_patrol_target()

func _physics_process(delta: float) -> void:
	_ensure_path_grid()

	var desired_velocity := Vector2.ZERO
	var target_world_pos := patrol_target
	if player_chase and is_instance_valid(player):
		is_idle = false
		target_world_pos = player.position
		$sprite.play("s_walk")
		update_sprite_direction(target_world_pos)
	else:
		if not is_idle:
			is_idle = true
			pick_new_patrol_target()

		patrol_timer += delta
		
		# Periodically pick a new patrol target
		if patrol_timer >= patrol_change_interval:
			pick_new_patrol_target()
			patrol_timer = 0.0

		target_world_pos = patrol_target
		if position.distance_to(target_world_pos) > 4.0:
			$sprite.play("s_walk")
			update_sprite_direction(target_world_pos)
		else:
			$sprite.stop()

	if current_path.is_empty() or path_index >= current_path.size() or position.distance_to(target_world_pos) < 8.0:
		_update_path_to(target_world_pos)

	if current_path.size() > 1 and path_index < current_path.size():
		var next_waypoint := current_path[path_index]
		var next_world_pos := frontlayer.map_to_local(next_waypoint)
		if position.distance_to(next_world_pos) < 4.0:
			path_index += 1
			if path_index < current_path.size():
				next_world_pos = frontlayer.map_to_local(current_path[path_index])
			else:
				current_path.clear()
				path_index = 0
		if not current_path.is_empty() and path_index < current_path.size():
			desired_velocity = (next_world_pos - position).normalized() * speed

	var next_position := position + desired_velocity * delta
	var next_tile := frontlayer.local_to_map(next_position)
	if frontlayer and frontlayer.is_tile_walkable(next_tile):
		velocity = desired_velocity
	else:
		velocity = Vector2.ZERO
		if not player_chase:
			pick_new_patrol_target()

	move_and_slide()


func _get_best_walkable_step(target_world_pos: Vector2) -> Vector2i:
	if not frontlayer:
		return Vector2i(-1, -1)

	var current_tile := frontlayer.local_to_map(position)
	var target_tile := frontlayer.local_to_map(target_world_pos)
	var delta := target_tile - current_tile
	var candidates: Array[Vector2i] = []

	if abs(delta.x) > abs(delta.y):
		if delta.x != 0:
			candidates.append(Vector2i(signi(delta.x), 0))
		if delta.y != 0:
			candidates.append(Vector2i(0, signi(delta.y)))
	else:
		if delta.y != 0:
			candidates.append(Vector2i(0, signi(delta.y)))
		if delta.x != 0:
			candidates.append(Vector2i(signi(delta.x), 0))

	for direction in candidates:
		var candidate_tile := current_tile + direction
		if frontlayer.is_tile_walkable(candidate_tile):
			return candidate_tile

	var neighbors: Array[Vector2i] = frontlayer.get_walkable_neighbor_tiles(current_tile)
	if neighbors.is_empty():
		return Vector2i(-1, -1)

	var best_tile := neighbors[0]
	var best_distance := INF
	for tile in neighbors:
		var distance := tile.distance_squared_to(target_tile)
		if distance < best_distance:
			best_distance = distance
			best_tile = tile
	return best_tile


func _ensure_path_grid() -> void:
	if path_grid != null or not frontlayer:
		return

	var used_rect: Rect2i = frontlayer.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		used_rect = Rect2i(
			Vector2i(-frontlayer.world_bounds * frontlayer.width, -frontlayer.world_bounds * frontlayer.height),
			Vector2i((frontlayer.world_bounds * 2 + 1) * frontlayer.width, (frontlayer.world_bounds * 2 + 1) * frontlayer.height)
		)

	var min_x: int = used_rect.position.x
	var max_x: int = used_rect.position.x + used_rect.size.x - 1
	var min_y: int = used_rect.position.y
	var max_y: int = used_rect.position.y + used_rect.size.y - 1

	var new_grid := AStar2D.new()
	var point_ids: Dictionary = {}

	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			var tile := Vector2i(x, y)
			if frontlayer.is_tile_walkable(tile):
				var point_id := _tile_to_point_id(tile)
				new_grid.add_point(point_id, Vector2(tile.x, tile.y))
				point_ids[tile] = point_id

	for tile in point_ids.keys():
		var point_id := int(point_ids[tile])
		for direction in [
			Vector2i.RIGHT,
			Vector2i.LEFT,
			Vector2i.UP,
			Vector2i.DOWN,
			Vector2i(1, 1),
			Vector2i(1, -1),
			Vector2i(-1, 1),
			Vector2i(-1, -1)
		]:
			var neighbor: Vector2i = tile + direction
			if point_ids.has(neighbor):
				new_grid.connect_points(point_id, int(point_ids[neighbor]), false)

	path_grid = new_grid


func _update_path_to(target_world_pos: Vector2) -> void:
	_ensure_path_grid()
	if not frontlayer or path_grid == null:
		current_path.clear()
		path_index = 0
		return

	var start_tile := frontlayer.local_to_map(position)
	var target_tile := frontlayer.local_to_map(target_world_pos)
	if start_tile == target_tile:
		current_path.clear()
		path_index = 0
		return

	var start_id := _tile_to_point_id(start_tile)
	var target_id := _tile_to_point_id(target_tile)
	if not path_grid.has_point(start_id) or not path_grid.has_point(target_id):
		current_path.clear()
		path_index = 0
		return

	var path := path_grid.get_point_path(start_id, target_id)
	var path_points: Array[Vector2i] = []
	for point in path:
		path_points.append(Vector2i(point))

	if path_points.size() > 1:
		current_path = path_points
		path_index = 1
	else:
		current_path.clear()
		path_index = 0


func _on_detection_area_body_entered(body: Node2D) -> void:
	player = body
	player_chase = true


func _on_detection_area_body_exited(body: Node2D) -> void:
	player = null
	player_chase = false


func _on_battle_trigger_body_entered(body: Node2D) -> void:
	# Check if the body is the player
	if body == player:
		trigger_battle() # (COLLISION) NOTE TO SELF: DAPAT PAREHAS YUNG LAYER AND MASK INDEX WITH THE LAYER AND MASK INDEX NG PLAYER TO TRIGGER A BATTLE SEQUENCE


func trigger_battle() -> void:
	# Save the current overworld before leaving it
	var cybermap = get_tree().get_first_node_in_group("Cybermap")

	if cybermap:
		cybermap.store_overworld_state()

	SignalBus.start_battle(self)

func disappear() -> void:
	if has_signal("died"):
		emit_signal("died")
	queue_free()

func pick_new_patrol_target() -> void:
	if not frontlayer:
		patrol_target = position
		return

	var current_tile := frontlayer.local_to_map(position)
	var neighbors: Array[Vector2i] = frontlayer.get_walkable_neighbor_tiles(current_tile)
	if neighbors.is_empty():
		patrol_target = position
		return

	patrol_target = frontlayer.map_to_local(neighbors.pick_random())


func _tile_to_point_id(tile: Vector2i) -> int:
	return (tile.x + 100000) * 1000000 + (tile.y + 100000)

func update_sprite_direction(target_pos: Vector2) -> void:
	var horizontal_delta := target_pos.x - position.x
	if horizontal_delta > 2.0:
		$sprite.flip_h = true
	elif horizontal_delta < -2.0:
		$sprite.flip_h = false
