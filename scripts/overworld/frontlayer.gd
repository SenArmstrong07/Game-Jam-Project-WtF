extends TileMapLayer

signal enemy_spawned(enemy: Node2D)
signal world_generation_started
signal world_generation_progress(progress: float)
signal world_generation_complete
signal overworld_ready

var moisture = FastNoiseLite.new() #x offset
var temperature = FastNoiseLite.new() #y offset
var altitude = FastNoiseLite.new() #for oceans and shit

var chunk_size = Vector2i(64, 64)  # Chunk dimensions
var width = 64
var height = 64
var tile_size = 64  # Pixel size of each tile

# World bounds - FIXED PLAYABLE AREA
var max_world_coord = 2  # ±2 chunks = 5x5 chunks total (20,480x20,480 pixels)
var world_bounds = max_world_coord

# Extra padding to expand the playable bounds slightly (in tiles)
@export var world_bounds_padding_tiles: int = 1
var is_world_ready = false

# Calculate world limits in world coordinates
var world_min_x: float
var world_max_x: float
var world_min_y: float
var world_max_y: float

@onready var player = get_parent().get_parent().get_node("OverworldPlayer")
@onready var camera: Camera2D = get_parent().get_parent().get_node("Camera2D")

var loaded_chunks = {}  # Dictionary: {Vector2i chunk_coord: true}

var camera_follow_enabled : bool = true

# Enemy spawning settings
var enemy_scene = preload("res://scenes/units/overworld_enemy.tscn")
var min_distance_between_enemies = 1000
var enemies_spawned_count = 0  # Track how many enemies have been spawned

# FINITE WORLD: All chunks are pre-generated once at startup and stay loaded permanently
# No dynamic loading/unloading to prevent infinite generation
var generation_started = false  # Guard to ensure generation only happens ONCE


func _ready():
	add_to_group("frontlayer")
	var overworld_root = get_parent().get_parent()
	if is_instance_valid(overworld_root):
		overworld_root.add_to_group("overworld_scene")
	# Create or restore random seeds for deterministic world generation
	if SignalBus.overworld_state.has("terrain_seeds"):
		var saved_seeds = SignalBus.overworld_state["terrain_seeds"]
		if saved_seeds.has("moisture"):
			moisture.seed = saved_seeds["moisture"]
		if saved_seeds.has("temperature"):
			temperature.seed = saved_seeds["temperature"]
		if saved_seeds.has("altitude"):
			altitude.seed = saved_seeds["altitude"]
	else:
		moisture.seed = randi()
		temperature.seed = randi()
		altitude.seed = randi()
	
	altitude.frequency = 0.01
	
	# Calculate world bounds in pixels
	# Ensure player cannot enter chunks outside [-world_bounds, world_bounds]
	world_min_x = -world_bounds * width * tile_size
	world_max_x = (world_bounds + 1) * width * tile_size - 1
	world_min_y = -world_bounds * height * tile_size
	world_max_y = (world_bounds + 1) * height * tile_size - 1
	
	# Safety check for player
	if player == null:
		print("ERROR: PlayerCharacter not found")
		print("Parent node: ", get_parent())
		if get_parent():
			print("Children of parent: ", get_parent().get_children())
		return
	
	# Start world generation in background (only once)
	if not generation_started:
		pre_generate_world()
	else:
		print("[WARNING] World generation already started, skipping duplicate call")

func _process(delta):
	# Don't process until world generation is complete
	if not is_world_ready:
		return
	
	# Clamp player to world bounds (secondary enforcement)
	if player:
		var prev_pos = player.position
		var clamped_x = clamp(player.position.x, world_min_x, world_max_x)
		var clamped_y = clamp(player.position.y, world_min_y, world_max_y)
		player.position.x = clamped_x
		player.position.y = clamped_y
		
		# Debug: Show when player hits a boundary
		if prev_pos.x != clamped_x:
			print("[FRONTLAYER] X CLAMPED: ", prev_pos.x, " -> ", clamped_x)
		if prev_pos.y != clamped_y:
			print("[FRONTLAYER] Y CLAMPED: ", prev_pos.y, " -> ", clamped_y)
	else:
		print("[ERROR] player is NULL in frontlayer._process()")
	
	# Follow player with camera
	if camera and camera_follow_enabled:
		camera.global_position = player.global_position
		
		# Clamp camera to world bounds
		# Calculate camera's visible area based on zoom and viewport size
		var viewport_size = get_viewport().get_visible_rect().size
		var camera_zoom = camera.zoom
		var camera_half_width = (viewport_size.x / 2.0) / camera_zoom.x
		var camera_half_height = (viewport_size.y / 2.0) / camera_zoom.y
		
		# Clamp camera position so it doesn't show beyond world bounds
		camera.global_position.x = clamp(
			camera.global_position.x,
			world_min_x + camera_half_width,
			world_max_x - camera_half_width
		)
		camera.global_position.y = clamp(
			camera.global_position.y,
			world_min_y + camera_half_height,
			world_max_y - camera_half_height
		)
	
	# All chunks are pre-generated and permanently loaded - no dynamic unloading needed


func set_camera_follow_enabled(enabled: bool) -> void:
	camera_follow_enabled = enabled
	print("[FRONTLAYER] Camera follow enabled=", camera_follow_enabled)

func pre_generate_world() -> void:
	"""Pre-generate all chunks within world bounds once at startup.
	After this completes, no more generation or unloading occurs - FINITE WORLD."""
	# Guard: Prevent this function from being called multiple times
	if generation_started:
		print("[ERROR] pre_generate_world() called multiple times! Aborting.")
		return
	
	generation_started = true

	if SignalBus.overworld_state.has("terrain_tiles") and SignalBus.overworld_state["terrain_tiles"].size() > 0:
		print("[WORLD_GEN] Restoring saved terrain tiles instead of regenerating from noise.")
		restore_saved_terrain(SignalBus.overworld_state["terrain_tiles"])
		is_world_ready = true
		world_generation_complete.emit()
		_finish_world_setup()
		return

	print("[WORLD_GEN] Starting world generation...")
	world_generation_started.emit()
	
	var total_chunks = (world_bounds * 2 + 1) * (world_bounds * 2 + 1)
	var chunks_generated = 0
	
	# Generate all chunks within bounds
	for x in range(-world_bounds, world_bounds + 1):
		for y in range(-world_bounds, world_bounds + 1):
			var chunk_coord = Vector2i(x, y)
			generate_chunk(chunk_coord)
			loaded_chunks[chunk_coord] = true
			
			chunks_generated += 1
			var progress = float(chunks_generated) / float(total_chunks)
			world_generation_progress.emit(progress)
			
			# Yield every few chunks to prevent freezing
			if chunks_generated % 4 == 0:
				await get_tree().process_frame
	
	SignalBus.overworld_state["terrain_tiles"] = get_saved_terrain_data()
	_finish_world_setup()

func _finish_world_setup() -> void:
	var total_chunks: int = (world_bounds * 2 + 1) * (world_bounds * 2 + 1)

	# Resolve the player's spawn position from saved state when possible,
	# but only use it if it is confirmed to be a walkable terrain tile.
	var spawn_pos = resolve_spawn_position()
	if spawn_pos != Vector2.ZERO:
		player.position = spawn_pos
	else:
		push_error("[SPAWN] Failed to resolve a valid spawn tile.")
	
	is_world_ready = true
	world_generation_complete.emit()
	overworld_ready.emit()
	overworld_ready.emit()

	# Enemy restoration
	var saved_enemies: Array = SignalBus.overworld_state.get("enemies", [])
	var cached_enemy_count: int = int(SignalBus.overworld_state.get("enemy_count", 0))

	if saved_enemies.is_empty():
		if SignalBus.summon_boss_on_return:
			print("[TRANSITION] Skipping normal enemy respawn because boss summon is pending")
		elif cached_enemy_count > 0:
			print("[TRANSITION] Restoring cached enemy count instead of randomizing it: ", cached_enemy_count)
			spawn_fixed_enemy_count(cached_enemy_count)
		else:
			spawn_fixed_enemy_count()
	else:
		_spawn_saved_enemy_positions(saved_enemies)
		
		#Check to see if scene is in transition and overworld state isn't empty
	if SignalBus.in_transition and !SignalBus.overworld_state.is_empty():

		is_world_ready = true

		world_generation_complete.emit()

		return
	

	print("\n=== WORLD GENERATION COMPLETE (FINITE WORLD) ===")
	print("Total chunks generated: ", total_chunks)
	print("World bounds: ±", world_bounds, " chunks")
	print("Playable area X: ", world_min_x, " to ", world_max_x)
	print("Playable area Y: ", world_min_y, " to ", world_max_y)
	print("All chunks will remain loaded - no dynamic unloading occurs")
	print("Node count should STABILIZE after this message")
	print("===================================================\n")



func get_saved_terrain_data() -> Array:
	var terrain_tiles: Array = []
	for cell in get_used_cells():
		var atlas_coords = get_cell_atlas_coords(cell)
		if atlas_coords != Vector2i(-1, -1):
			terrain_tiles.append({
				"position": cell,
				"atlas": atlas_coords,
			})
	return terrain_tiles

func restore_saved_terrain(terrain_data: Array) -> void:
	clear()
	for entry in terrain_data:
		if entry is Dictionary and entry.has("position") and entry.has("atlas"):
			var tile_pos: Vector2i = entry["position"]
			var atlas: Vector2i = entry["atlas"]
			set_cell(tile_pos, 0, atlas)

func build_world_map_snapshot() -> Dictionary:
	var land_tiles: Array[Vector2i] = []
	var world_bounds_rect = get_world_bounds()
	var min_tile_x = int(world_bounds_rect.position.x / tile_size)
	var max_tile_x = int((world_bounds_rect.position.x + world_bounds_rect.size.x) / tile_size)
	var min_tile_y = int(world_bounds_rect.position.y / tile_size)
	var max_tile_y = int((world_bounds_rect.position.y + world_bounds_rect.size.y) / tile_size)

	for tile_x in range(min_tile_x, max_tile_x + 1):
		for tile_y in range(min_tile_y, max_tile_y + 1):
			var altitude = get_altitude(tile_x, tile_y)
			if altitude >= 0:
				land_tiles.append(Vector2i(tile_x, tile_y))

	var islands = _group_land_tiles_into_islands(land_tiles)
	return {
		"land_tiles": land_tiles,
		"islands": islands,
		"world_bounds": world_bounds_rect,
		"world_size": get_world_size(),
	}


func _group_land_tiles_into_islands(land_tiles: Array[Vector2i]) -> Array:
	var islands: Array = []
	var processed: Dictionary = {}
	var land_set: Dictionary = {}

	for tile in land_tiles:
		land_set[tile] = true

	for tile in land_tiles:
		if tile in processed:
			continue

		var island: Array[Vector2i] = []
		var queue = [tile]

		while queue.size() > 0:
			var current = queue.pop_front()
			if current in processed:
				continue

			processed[current] = true
			island.append(current)

			for neighbor in [
				current + Vector2i.RIGHT,
				current + Vector2i.LEFT,
				current + Vector2i.DOWN,
				current + Vector2i.UP,
			]:
				if neighbor in land_set and neighbor not in processed:
					queue.append(neighbor)

		if island.size() > 0:
			islands.append(island)

	return islands


func is_tile_walkable(tile: Vector2i) -> bool:
	"""Return true when the requested tile is land and inside the generated world."""
	if tile.x < -world_bounds * width or tile.x > (world_bounds + 1) * width - 1:
		return false
	if tile.y < -world_bounds * height or tile.y > (world_bounds + 1) * height - 1:
		return false
	return get_cell_source_id(tile) != -1


func is_global_rect_walkable(global_rect: Rect2) -> bool:
	"""Return true when all tiles overlapped by the global rectangle are walkable."""
	if global_rect.size.x <= 0 or global_rect.size.y <= 0:
		return is_position_on_walkable_tile(global_rect.position)

	var min_tile = global_to_map(global_rect.position)
	var max_tile = global_to_map(global_rect.position + global_rect.size - Vector2(0.001, 0.001))
	for x in range(min_tile.x, max_tile.x + 1):
		for y in range(min_tile.y, max_tile.y + 1):
			if not is_tile_walkable(Vector2i(x, y)):
				return false
	return true


func get_player_collision_radius_tiles() -> Vector2i:
	var radius = Vector2i(1, 1)
	if player and player.has_node("CollisionShape2D"):
		var collision_node = player.get_node("CollisionShape2D")
		var shape = collision_node.shape
		if shape is RectangleShape2D:
			radius.x = int(ceil((abs(shape.size.x) * 0.5) / tile_size))
			radius.y = int(ceil((abs(shape.size.y) * 0.5) / tile_size))
	return radius


func is_tile_region_walkable(center_tile: Vector2i, tile_radius: Vector2i) -> bool:
	if tile_radius == Vector2i.ZERO:
		return is_tile_walkable(center_tile)

	for x in range(center_tile.x - tile_radius.x, center_tile.x + tile_radius.x + 1):
		for y in range(center_tile.y - tile_radius.y, center_tile.y + tile_radius.y + 1):
			if not is_tile_walkable(Vector2i(x, y)):
				return false
	return true


func is_position_on_walkable_tile(position: Vector2) -> bool:
	var tile = global_to_map(position)
	return is_tile_walkable(tile)


func resolve_spawn_position() -> Vector2:
	var tile_radius = get_player_collision_radius_tiles()

	if SignalBus.overworld_state.has("player_position"):
		var saved_player_pos = SignalBus.overworld_state["player_position"]
		if saved_player_pos is Vector2i:
			if is_tile_region_walkable(saved_player_pos, tile_radius):
				return map_to_global(saved_player_pos)
		elif saved_player_pos is Vector2:
			var saved_tile = global_to_map(saved_player_pos)
			if is_tile_region_walkable(saved_tile, tile_radius):
				return map_to_global(saved_tile)
	elif SignalBus.overworld_state.has("player_tile"):
		var saved_tile = SignalBus.overworld_state["player_tile"]
		if saved_tile is Vector2i and is_tile_region_walkable(saved_tile, tile_radius):
			return map_to_global(saved_tile)

	return find_valid_spawn_tile(tile_radius)


func get_walkable_neighbor_tiles(tile: Vector2i) -> Array[Vector2i]:
	"""Return all walkable surrounding tiles around a given tile, including diagonals."""
	var neighbors: Array[Vector2i] = []
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
		var candidate = tile + direction
		if is_tile_walkable(candidate):
			neighbors.append(candidate)
	return neighbors


func find_valid_spawn_tile(tile_radius: Vector2i = Vector2i.ZERO) -> Vector2:
	"""Find the closest walkable terrain tile to the world center for spawning the player."""
	var best_tile: Vector2i = Vector2i.ZERO
	var best_distance: float = INF

	for x in range(-world_bounds * width, (world_bounds + 1) * width):
		for y in range(-world_bounds * height, (world_bounds + 1) * height):
			var tile = Vector2i(x, y)
			if tile_radius != Vector2i.ZERO and not is_tile_region_walkable(tile, tile_radius):
				continue
			if not is_tile_walkable(tile):
				continue

			var distance = abs(tile.x) + abs(tile.y)
			if distance < best_distance:
				best_distance = distance
				best_tile = tile

	if best_tile != Vector2i.ZERO or is_tile_walkable(best_tile):
		print("[SPAWN] Selected valid terrain tile at: ", best_tile)
		return map_to_global(best_tile)

	push_error("No valid land tile found!")
	return map_to_global(Vector2i(0, 0))
func generate_chunk(chunk_coord: Vector2i):
	var base_x = chunk_coord.x * width
	var base_y = chunk_coord.y * height
	
	for x in range(width):
		for y in range(height):
			var tile_x = base_x + x
			var tile_y = base_y + y
			
			var moist = moisture.get_noise_2d(tile_x, tile_y) * 10
			var temp = temperature.get_noise_2d(tile_x, tile_y) * 10
			var alt = altitude.get_noise_2d(tile_x, tile_y) * 10
			
			# Pick one of our 4 tiles based on altitude
			var tile_idx = int((alt + 10) / 20.0 * 4) % 4  # Maps -10 to 10 range → 0,1,2,3 alt
			var tile_coords = [
				Vector2i(4, 2),
				Vector2i(5, 2),
				Vector2i(6, 2),
				Vector2i(7, 2)
			][tile_idx]
			
			# Determine which tile to place based on altitude
			var cell_to_place: Vector2i
			var is_valid_spawn_tile = false
			if alt < 0:
				#cell_to_place = Vector2i(0, 0)  # impassable tile ("sea")
				#We skip painting water tiles to replace that with a moving background (TextureRect)
				continue
			else:
				# Land - use the altitude-based selection
				cell_to_place = tile_coords
				is_valid_spawn_tile = true
			
			var tile_world_pos = map_to_local(Vector2i(tile_x, tile_y))
			set_cell(Vector2i(tile_x, tile_y), 0, cell_to_place)
			
			# Enemy spawning moved to post-generation function
			
			
# DEPRECATED: Chunk unloading functions removed for finite world
# All chunks are permanently loaded to prevent infinite generation
	
func dist(p1, p2):
	var r = Vector2(p1) - Vector2(p2)
	return sqrt(r.x ** 2 + r.y **2)


func get_altitude(x: int, y: int) -> float:
	"""Get altitude value for a tile position"""
	return altitude.get_noise_2d(x, y) * 10


func spawn_fixed_enemy_count(target_count: int = -1) -> void:
	"""Spawn a fixed number of enemies after world generation.
	When a cached count is provided, preserve that count instead of randomizing it."""
	var enemy_count := target_count if target_count > 0 else randi_range(3, 10)
	var spawned = 0
	var max_attempts = enemy_count * 10  # Try up to 10x attempts to place all enemies
	var attempt = 0
	var spawned_positions = []  # Track positions of spawned enemies
	
	print("[SPAWNING] Attempting to spawn ", enemy_count, " enemies...")
	
	while spawned < enemy_count and attempt < max_attempts:
		attempt += 1
		
		# Pick a random tile in the world
		var random_tile = Vector2i(
			randi_range(-world_bounds * width, (world_bounds + 1) * width - 1),
			randi_range(-world_bounds * height, (world_bounds + 1) * height - 1)
		)
		
		# Ensure this tile is actually walkable land
		if not is_tile_walkable(random_tile):
			continue
		
		var spawn_world_pos = map_to_global(random_tile)
		var spawn_local_pos = get_parent().to_local(spawn_world_pos)
		
		# Check distance to player
		if spawn_world_pos.distance_to(player.position) < min_distance_between_enemies:
			continue
		
		# Check distance to other spawned enemies
		var too_close = false
		for other_pos in spawned_positions:
			if spawn_world_pos.distance_to(other_pos) < min_distance_between_enemies:
				too_close = true
				break
		
		if too_close:
			continue
		
		# Valid spawn location - spawn enemy
		var new_enemy = enemy_scene.instantiate()
		new_enemy.position = spawn_local_pos
		get_parent().add_child.call_deferred(new_enemy)
		spawned_positions.append(spawn_world_pos)
		await new_enemy.tree_entered
		enemy_spawned.emit(new_enemy)
		spawned += 1
		
		print("[SPAWNING] Enemy ", spawned, "/", enemy_count, " spawned at: ", spawn_world_pos)
	
	enemies_spawned_count = spawned
	print("[SPAWNING] Successfully spawned ", spawned, " enemies (target was ", enemy_count, ")")

func _spawn_saved_enemy_positions(enemy_data: Array) -> void:
	var spawned = 0
	for enemy_info in enemy_data:
		if enemy_info is Dictionary and enemy_info.has("position"):
			var enemy_pos = enemy_info["position"]
			if enemy_pos is Vector2i:
				enemy_pos = Vector2(enemy_pos)
			if enemy_pos is Vector2:
				var tile = global_to_map(enemy_pos)
				if not is_tile_walkable(tile):
					print("[SPAWNING] Saved enemy position invalid, relocating: ", enemy_pos, " tile=", tile)
					enemy_pos = _find_nearest_valid_land_position(enemy_pos)
					print("[SPAWNING] Relocated saved enemy to valid land: ", enemy_pos)
				
				var new_enemy = enemy_scene.instantiate()
				var enemy_local_pos = get_parent().to_local(enemy_pos)
				new_enemy.position = enemy_local_pos
				if enemy_info.has("enemy_type") and new_enemy.has_method("apply_spawn_type"):
					new_enemy.apply_spawn_type(str(enemy_info["enemy_type"]))
				get_parent().add_child.call_deferred(new_enemy)
				enemy_spawned.emit(new_enemy)
				spawned += 1
				print("[SPAWNING] Restored enemy at", enemy_pos)

	enemies_spawned_count = spawned
	print("[SPAWNING] Restored ", spawned, " saved enemies")

func _find_nearest_valid_land_position(global_position: Vector2, max_distance_tiles: int = 30) -> Vector2:
	var start_tile = global_to_map(global_position)
	if is_tile_walkable(start_tile):
		return map_to_global(start_tile)

	var queue: Array = [start_tile]
	var visited: Dictionary = {start_tile: true}
	var directions = [
		Vector2i.RIGHT,
		Vector2i.LEFT,
		Vector2i.UP,
		Vector2i.DOWN,
	]

	while queue.size() > 0:
		var tile: Vector2i = queue.pop_front()
		for dir in directions:
			var next_tile = tile + dir
			if next_tile in visited:
				continue
			visited[next_tile] = true
			if abs(next_tile.x - start_tile.x) > max_distance_tiles or abs(next_tile.y - start_tile.y) > max_distance_tiles:
				continue
			if is_tile_walkable(next_tile):
				return map_to_global(next_tile)
			queue.append(next_tile)

	print("[SPAWNING] No nearby valid land tile found for saved enemy at", global_position, "; using fallback spawn")
	return find_valid_spawn_tile()

func get_world_bounds() -> Rect2:
	"""Returns the playable world bounds as a Rect2"""
	var rect = Rect2(Vector2(world_min_x, world_min_y), Vector2(world_max_x - world_min_x, world_max_y - world_min_y))

	# Expand bounds by padding (in tiles) if configured
	if world_bounds_padding_tiles != 0:
		var pad_pixels = Vector2(tile_size * world_bounds_padding_tiles, tile_size * world_bounds_padding_tiles)
		rect.position -= pad_pixels
		rect.size += pad_pixels * 2

	return rect


func get_world_size() -> Vector2:
	"""Returns total world dimensions"""
	return Vector2(world_max_x - world_min_x, world_max_y - world_min_y)


## Coordinate helpers to account for TileNode parent offsets
func map_to_global(tile: Vector2i) -> Vector2:
	# Convert tile->local (TileMap) then translate by TileNode position to get CyberMap local coords
	var local_pos = map_to_local(tile)
	var node = get_parent()
	if node:
		return local_pos + node.position
	return local_pos

func global_to_map(global_pos: Vector2) -> Vector2i:
	# Convert global (CyberMap local) pos to TileMap local, then to tile coords
	var node = get_parent()
	var local_pos = global_pos
	if node:
		local_pos = global_pos - node.position
	return local_to_map(local_pos)
