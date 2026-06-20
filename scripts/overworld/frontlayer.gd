extends TileMapLayer

signal enemy_spawned(enemy: Node2D)

var moisture = FastNoiseLite.new() #x offset
var temperature = FastNoiseLite.new() #y offset
var altitude = FastNoiseLite.new() #for oceans and shit

var width = 64
var height = 64

@onready var player = get_parent().get_parent().get_node("OverworldPlayer")
@onready var camera: Camera2D = get_parent().get_parent().get_node("Camera2D")

var loaded_chunks = []
var spawned_enemies = []  # Track spawned enemy positions

# Enemy spawning settings
var enemy_scene = preload("res://scenes/units/overworld_enemy.tscn")
var min_distance_between_enemies = 700  # Minimum pixels between enemy spawns
var spawn_chance_per_tile = 0.000001  # Chance to spawn enemy on each valid tile


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

func _process(delta):
	var player_tile_pos = local_to_map(player.position) #places the player coords to the tile coords
	
	# Follow player with camera
	if camera:
		camera.global_position = player.global_position
	
	generate_chunk(player_tile_pos)

	#unloads chunks pag out of screen na
	unload_distant_chunks(player_tile_pos)
	
func generate_chunk(pos):
	for x in range(width):
		for y in range(height):
			
			var moist = moisture.get_noise_2d(
				pos.x - (width / 2) + x, 
				pos.y - (height / 2) + y,
				) * 10
			var temp = temperature.get_noise_2d(
				pos.x - (width / 2) + x, 
				pos.y - (height / 2) + y,
				) * 10
			var alt = altitude.get_noise_2d(
				pos.x - (width / 2) + x, 
				pos.y - (height / 2) + y,
				) * 10
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
				is_valid_spawn_tile = true  # Valid land tile for enemy spawning
			
			var tile_world_pos = map_to_local(Vector2i(pos.x - (width / 2) + x, pos.y - (height / 2) + y))
			set_cell(Vector2i(pos.x - (width / 2) + x, pos.y - (height / 2) + y), 0, cell_to_place)
			
			# Try to spawn enemy on valid tiles
			if is_valid_spawn_tile and randf() < spawn_chance_per_tile:
				attempt_spawn_enemy(tile_world_pos)
			
			if Vector2(pos.x, pos.y) not in loaded_chunks:
				loaded_chunks.append(Vector2(pos.x, pos.y))
			
			
func clear_chunk(pos):
	for x in range(width):
		for y in range(height):
			set_cell(Vector2i(pos.x - (width / 2) + x, pos.y - (height / 2) + y), -1, Vector2i(-1,-1))
	
func unload_distant_chunks(player_pos): 
	var unload_dist = (width * 2) + 1
	for chunk in loaded_chunks:
		var dist_to_player = dist(chunk, player_pos)
		
		if dist_to_player > unload_dist:
			clear_chunk(chunk)
			loaded_chunks.erase(chunk)
	
func dist(p1, p2):
	var r = Vector2(p1) - Vector2(p2)
	return sqrt(r.x ** 2 + r.y **2)


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
	get_parent().add_child(new_enemy)  # Add to same parent as tilemap
	spawned_enemies.append(spawn_position)
	
	# Emit signal so minimap can create a marker
	enemy_spawned.emit(new_enemy)
	
	print("Enemy spawned at: ", spawn_position)
