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

# World bounds
var world_bounds = 5  # ±5 chunks = 11x11 chunks total (4,096x4,096 tiles)
var is_world_ready = false

@onready var player = get_parent().get_parent().get_node("OverworldPlayer")
@onready var camera: Camera2D = get_parent().get_parent().get_node("Camera2D")

var loaded_chunks = {}  # Dictionary: {Vector2i chunk_coord: true}
var spawned_enemies = []  # Track spawned enemy positions

# Enemy spawning settings
var enemy_scene = preload("res://scenes/units/overworld_enemy.tscn")
var min_distance_between_enemies = 700  # Minimum pixels between enemy spawns
var spawn_chance_per_tile = 0.0001  # Chance to spawn enemy on each valid tile


func _ready():
	#create random seeds
	moisture.seed = randi()
	temperature.seed = randi()
	altitude.seed = randi()
	
	altitude.frequency = 0.01
	
	# Safety check for player
	if player == null:
		print("ERROR: PlayerCharacter not found")
		print("Parent node: ", get_parent())
		if get_parent():
			print("Children of parent: ", get_parent().get_children())
		return
	
	# Start world generation in background
	pre_generate_world()

func _process(delta):
	# Don't process until world generation is complete
	if not is_world_ready:
		return
	
	var player_tile_pos = local_to_map(player.position)
	
	# Convert tile position to chunk coordinates
	var chunk_coord = Vector2i(
		int(floor(player_tile_pos.x / float(width))),
		int(floor(player_tile_pos.y / float(height)))
	)
	
	# Follow player with camera
	if camera:
		camera.global_position = player.global_position
	
	# Unload distant chunks
	unload_distant_chunks(chunk_coord)


func pre_generate_world() -> void:
	"""Pre-generate all chunks within world bounds asynchronously"""
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
	print("World generation complete! Total chunks: ", total_chunks)


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
				cell_to_place = Vector2i(0, 0)  # impassable tile ("sea")
			else:
				# Land - use the altitude-based selection
				cell_to_place = tile_coords
				is_valid_spawn_tile = true
			
			var tile_world_pos = map_to_local(Vector2i(tile_x, tile_y))
			set_cell(Vector2i(tile_x, tile_y), 0, cell_to_place)
			
			# Try to spawn enemy on valid tiles
			if is_valid_spawn_tile and randf() < spawn_chance_per_tile:
				attempt_spawn_enemy(tile_world_pos)
			
			
func clear_chunk(chunk_coord: Vector2i):
	var base_x = chunk_coord.x * width
	var base_y = chunk_coord.y * height
	
	for x in range(width):
		for y in range(height):
			var tile_x = base_x + x
			var tile_y = base_y + y
			set_cell(Vector2i(tile_x, tile_y), -1, Vector2i(-1, -1))
	
func unload_distant_chunks(player_chunk_coord: Vector2i):
	var unload_dist = 3  # Distance in chunks (not tiles)
	var chunks_to_remove = []
	
	for chunk_coord in loaded_chunks.keys():
		var dist_to_player = player_chunk_coord.distance_to(chunk_coord)
		
		if dist_to_player > unload_dist:
			clear_chunk(chunk_coord)
			chunks_to_remove.append(chunk_coord)
			clean_spawned_enemies_in_chunk(chunk_coord)
	
	# Remove chunks after iteration to avoid modifying dict during iteration
	for chunk_coord in chunks_to_remove:
		loaded_chunks.erase(chunk_coord)


func clean_spawned_enemies_in_chunk(chunk_coord: Vector2i) -> void:
	"""Remove spawned enemy positions that are in this chunk"""
	var base_x = chunk_coord.x * width
	var base_y = chunk_coord.y * height
	var chunk_bounds = Rect2(base_x * tile_size, base_y * tile_size, width * tile_size, height * tile_size)
	
	var enemies_to_remove = []
	for enemy_pos in spawned_enemies:
		if chunk_bounds.has_point(enemy_pos):
			enemies_to_remove.append(enemy_pos)
	
	for enemy_pos in enemies_to_remove:
		spawned_enemies.erase(enemy_pos)
	
func dist(p1, p2):
	var r = Vector2(p1) - Vector2(p2)
	return sqrt(r.x ** 2 + r.y **2)


func get_altitude(x: int, y: int) -> float:
	"""Get altitude value for a tile position"""
	return altitude.get_noise_2d(x, y) * 10


func attempt_spawn_enemy(spawn_position: Vector2) -> void:
	# Check if this position is too close to existing enemies
	for enemy_pos in spawned_enemies:
		var distance = spawn_position.distance_to(enemy_pos)
		if distance < min_distance_between_enemies:
			return  # Too close to another enemy, don't spawn
	
	# Check if position is too close to player
	if spawn_position.distance_to(player.position) < min_distance_between_enemies:
		return  # Too close to player, don't spawn
	
	# Spawn the enemy
	var new_enemy = enemy_scene.instantiate()
	new_enemy.position = spawn_position
	get_parent().add_child.call_deferred(new_enemy)  # Add to same parent as tilemap
	spawned_enemies.append(spawn_position)
	
	# Emit signal so minimap can create a marker
	enemy_spawned.emit(new_enemy)
	
	print("Enemy spawned at: ", spawn_position)
