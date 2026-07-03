extends TileMapLayer

signal enemy_spawned(enemy: Node2D)
signal world_generation_started
signal world_generation_progress(progress: float)
signal world_generation_complete

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
var is_world_ready = false

# Calculate world limits in world coordinates
var world_min_x: float
var world_max_x: float
var world_min_y: float
var world_max_y: float

@onready var player = get_parent().get_parent().get_node("OverworldPlayer")
@onready var camera: Camera2D = get_parent().get_parent().get_node("Camera2D")

var loaded_chunks = {}  # Dictionary: {Vector2i chunk_coord: true}

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
	#create random seeds
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
	if camera:
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


func pre_generate_world() -> void:
	"""Pre-generate all chunks within world bounds once at startup.
	After this completes, no more generation or unloading occurs - FINITE WORLD."""
	# Guard: Prevent this function from being called multiple times
	if generation_started:
		print("[ERROR] pre_generate_world() called multiple times! Aborting.")
		return
	
	generation_started = true
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
	
	# Find valid spawn point and place player
	var spawn_pos = find_valid_spawn_tile()
	if spawn_pos != Vector2.ZERO:
		player.position = spawn_pos
	
	is_world_ready = true
	world_generation_complete.emit()
	print("\n=== WORLD GENERATION COMPLETE (FINITE WORLD) ===")
	print("Total chunks generated: ", total_chunks)
	print("World bounds: ±", world_bounds, " chunks")
	print("Playable area X: ", world_min_x, " to ", world_max_x)
	print("Playable area Y: ", world_min_y, " to ", world_max_y)
	print("All chunks will remain loaded - no dynamic unloading occurs")
	print("Node count should STABILIZE after this message")
	print("===================================================\n")
	
	# Now spawn a fixed number of enemies
	spawn_fixed_enemy_count()



func find_valid_spawn_tile() -> Vector2:
	"""Find a valid terrain tile near the center to spawn the player"""
	var center_chunk = Vector2i(0, 0)
	var base_x = center_chunk.x * width
	var base_y = center_chunk.y * height
	
	# Search for first valid land tile in center chunk
	for x in range(width):
		for y in range(height):
			var tile_x = base_x + x
			var tile_y = base_y + y
			var alt = altitude.get_noise_2d(tile_x, tile_y) * 10
			
			# Valid spawn = land (not water)
			if alt >= 0:
				var world_pos = map_to_local(Vector2i(tile_x, tile_y))
				return world_pos
	
	# Fallback to origin
	return map_to_local(Vector2i(0, 0))
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


func spawn_fixed_enemy_count() -> void:
	"""Spawn a fixed number of enemies (random between 3-10) after world generation."""
	var enemy_count = randi_range(3, 10)
	var spawned = 0
	var max_attempts = enemy_count * 5  # Try up to 5x attempts to place all enemies
	var attempt = 0
	var spawned_positions = []  # Track positions of spawned enemies
	
	print("[SPAWNING] Attempting to spawn ", enemy_count, " enemies...")
	
	while spawned < enemy_count and attempt < max_attempts:
		attempt += 1
		
		# Pick a random tile in the world
		var random_tile_x = randi_range(-world_bounds * width, (world_bounds + 1) * width - 1)
		var random_tile_y = randi_range(-world_bounds * height, (world_bounds + 1) * height - 1)
		
		# Check if it's valid land (not water)
		var alt = altitude.get_noise_2d(random_tile_x, random_tile_y) * 10
		if alt < 0:  # Water, skip
			continue
		
		var spawn_world_pos = map_to_local(Vector2i(random_tile_x, random_tile_y))
		
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
		new_enemy.position = spawn_world_pos
		get_parent().add_child.call_deferred(new_enemy)
		spawned_positions.append(spawn_world_pos)
		enemy_spawned.emit(new_enemy)
		spawned += 1
		
		print("[SPAWNING] Enemy ", spawned, "/", enemy_count, " spawned at: ", spawn_world_pos)
	
	enemies_spawned_count = spawned
	print("[SPAWNING] Successfully spawned ", spawned, " enemies (target was ", enemy_count, ")")


func get_world_bounds() -> Rect2:
	"""Returns the playable world bounds as a Rect2"""
	return Rect2(Vector2(world_min_x, world_min_y), Vector2(world_max_x - world_min_x, world_max_y - world_min_y))


func get_world_size() -> Vector2:
	"""Returns total world dimensions"""
	return Vector2(world_max_x - world_min_x, world_max_y - world_min_y)
