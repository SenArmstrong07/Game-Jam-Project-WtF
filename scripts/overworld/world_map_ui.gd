extends Control

var frontlayer: TileMapLayer
var player: Node2D
var world_size: Vector2
var world_bounds_rect: Rect2
var zoom_factor: float
var tile_size = 64
var land_tiles: Array[Vector2i] = []  # Store all land tile positions
var tile_to_screen: Dictionary = {}  # Map tile positions to screen coordinates for clicking
var islands: Array[Array] = []  # Array of islands, each island is an array of connected tiles
var hovered_island: Array[Vector2i] = []  # Current hovered island tiles
var hovered_tile: Vector2i = Vector2i.ZERO  # Current hovered tile
var last_hovered_island_size: int = 0  # Track if island changed to minimize redraws
var is_island_grouping_complete: bool = false  # Flag to prevent interaction during grouping
var scanner_offset: float = 0.0
const SCANNER_SPEED: float = 250.0
const SCANNER_BEAM_HEIGHT: float = 80.0

func _ready() -> void:
	add_to_group("worldmap_ui")
	# Get references
	print("[WORLD MAP SCRIPT ATTACHED TO:]", self)
	print("CLASS:", get_class())
	var root = _find_overworld_root()
	if not is_instance_valid(root):
		print("[WORLD_MAP] Error: Could not find overworld root scene")
		queue_free()
		return
	
	frontlayer = root.get_node_or_null("TileNode/front")
	player = root.get_node_or_null("OverworldPlayer")
	
	if not frontlayer or not player:
		print("[WORLD_MAP] Error: Could not find frontlayer or player")
		if not frontlayer:
			print("  - frontlayer is NULL")
		if not player:
			print("  - player is NULL")
		queue_free()
		return

	# Ensure input is active only while the map is visible.
	set_process_input(true)
	
	# Get world bounds
	world_bounds_rect = frontlayer.get_world_bounds()
	world_size = frontlayer.get_world_size()
	
	if world_size.x <= 0 or world_size.y <= 0:
		print("[WORLD_MAP] Error: Invalid world size: ", world_size)
		queue_free()
		return
	
	# Calculate zoom to fit world on screen
	var viewport_size = get_viewport_rect().size
	var map_padding = 380  # Leave space for UI on left
	var available_width = viewport_size.x - map_padding
	var available_height = viewport_size.y - 40
	
	zoom_factor = min(
		available_width / world_size.x,
		available_height / world_size.y
	)
	
	if zoom_factor <= 0:
		print("[WORLD_MAP] Error: Invalid zoom factor: ", zoom_factor)
		queue_free()
		return
	
	print("[WORLD_MAP] Ready - scanning tiles...")
	
	
	var saved_map_data: Dictionary = {}
	if not SignalBus.overworld_state.is_empty() and "world_map_data" in SignalBus.overworld_state:
		saved_map_data = SignalBus.overworld_state["world_map_data"]

	if saved_map_data.has("land_tiles") and saved_map_data["land_tiles"].size() > 0:
		_restore_from_map_snapshot(saved_map_data)
		mouse_filter = Control.MOUSE_FILTER_STOP
		queue_redraw()
		print("[WORLD_MAP] Restored map layout from saved overworld state")
		return

	# Pre-scan all land tiles and group into islands
	_scan_all_land_tiles()
	print("[WORLD_MAP] Scanned ", land_tiles.size(), " land tiles, grouping into islands...")
	
	# Start the scanner animation while islands load
	scanner_offset = -SCANNER_BEAM_HEIGHT
	set_process(true)
	
	# Group islands over multiple frames to prevent freeze
	await _group_tiles_into_islands_async()
	
	# Set mouse filter to stop clicks from passing through
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Draw the map
	queue_redraw()
	print("[WORLD_MAP] Map ready and drawn")

func _find_overworld_root() -> Node:
	var current_root = get_tree().current_scene
	if is_instance_valid(current_root):
		if current_root.has_node("TileNode/front") and current_root.has_node("OverworldPlayer"):
			return current_root
		if current_root.is_in_group("overworld_scene"):
			return current_root

	var grouped_root = get_tree().get_first_node_in_group("overworld_scene")
	if is_instance_valid(grouped_root):
		return grouped_root

	for child in get_tree().root.get_children():
		if is_instance_valid(child) and child.has_node("TileNode/front") and child.has_node("OverworldPlayer"):
			return child

	return null

func _restore_from_map_snapshot(snapshot: Dictionary) -> void:
	land_tiles.clear()
	tile_to_screen.clear()
	islands.clear()

	if snapshot.has("land_tiles"):
		for tile in snapshot["land_tiles"]:
			if tile is Vector2i:
				land_tiles.append(tile)

	if snapshot.has("islands"):
		islands.clear()
		for island_data in snapshot["islands"]:
			if island_data is Array:
				var typed_island: Array[Vector2i] = []
				for tile in island_data:
					if tile is Vector2i:
						typed_island.append(tile)
				if typed_island.size() > 0:
					islands.append(typed_island)

	for tile_pos in land_tiles:
		var world_pos = frontlayer.map_to_global(tile_pos)
		var screen_pos = _world_to_screen(world_pos)
		tile_to_screen[tile_pos] = screen_pos

	is_island_grouping_complete = true
	set_process(false)


func _scan_all_land_tiles() -> void:
	"""Scan all tiles within world bounds and store land tile positions."""
	land_tiles.clear()
	tile_to_screen.clear()
	
	# Convert world pixel bounds to tile coordinates
	var min_tile_x = int(world_bounds_rect.position.x / tile_size)
	var max_tile_x = int(world_bounds_rect.position.x + world_bounds_rect.size.x) / tile_size
	var min_tile_y = int(world_bounds_rect.position.y / tile_size)
	var max_tile_y = int(world_bounds_rect.position.y + world_bounds_rect.size.y) / tile_size
	
	for tile_x in range(min_tile_x, max_tile_x + 1):
		for tile_y in range(min_tile_y, max_tile_y + 1):
			var altitude = frontlayer.get_altitude(tile_x, tile_y)
			
			# Only include land tiles (altitude >= 0)
			if altitude >= 0:
				var tile_pos = Vector2i(tile_x, tile_y)
				land_tiles.append(tile_pos)
				
				# Convert to screen coordinates for clicking
				var world_pos = frontlayer.map_to_global(tile_pos)
				var screen_pos = _world_to_screen(world_pos)
				tile_to_screen[tile_pos] = screen_pos

func _group_tiles_into_islands() -> void:
	"""Group connected land tiles into islands using flood fill."""
	islands.clear()
	var processed = {}
	var total_tiles = land_tiles.size()
	
	print("[WORLD_MAP] Starting island grouping for ", total_tiles, " tiles...")
	
	for idx in range(total_tiles):
		var tile_pos = land_tiles[idx]
		
		if tile_pos not in processed:
			var island = _flood_fill_island(tile_pos, processed)
			if island.size() > 0:
				islands.append(island)
		
		# Log progress every 5000 tiles
		if (idx + 1) % 5000 == 0:
			print("[WORLD_MAP] Processed ", idx + 1, "/", total_tiles, " tiles - ", islands.size(), " islands so far")
	
	print("[WORLD_MAP] Island grouping complete - found ", islands.size(), " islands")

func _group_tiles_into_islands_async() -> void:
	"""Async version of island grouping to prevent frame freezes."""
	islands.clear()
	var processed = {}
	var total_tiles = land_tiles.size()
	
	print("[WORLD_MAP] Starting ASYNC island grouping for ", total_tiles, " tiles...")
	
	for idx in range(total_tiles):
		var tile_pos = land_tiles[idx]
		
		if tile_pos not in processed:
			var island = _flood_fill_island(tile_pos, processed)
			if island.size() > 0:
				islands.append(island)
		
		# Yield every 100 tiles to allow other processing
		if (idx + 1) % 100 == 0:
			if (idx + 1) % 5000 == 0:
				print("[WORLD_MAP] Processed ", idx + 1, "/", total_tiles, " tiles - ", islands.size(), " islands so far")
			await get_tree().process_frame
	
	print("[WORLD_MAP] ASYNC island grouping complete - found ", islands.size(), " islands")
	is_island_grouping_complete = true
	set_process(false)
	queue_redraw()
	print("[WORLD_MAP] Island interaction now enabled")

func _flood_fill_island(start_tile: Vector2i, processed: Dictionary) -> Array[Vector2i]:
	"""Flood fill to find all connected tiles (one island)."""
	var island: Array[Vector2i] = []
	var queue = [start_tile]
	var land_set = {}  # Use a set for O(1) lookups
	
	for tile in land_tiles:
		land_set[tile] = true
	
	while queue.size() > 0:
		var current = queue.pop_front()
		if current in processed:
			continue
		
		processed[current] = true
		island.append(current)
		
		# Check 4-connected neighbors
		for neighbor in [
			current + Vector2i.RIGHT,
			current + Vector2i.LEFT,
			current + Vector2i.DOWN,
			current + Vector2i.UP
		]:
			if neighbor in land_set and neighbor not in processed:
				queue.append(neighbor)
	
	return island

func _world_to_screen(world_pos: Vector2) -> Vector2:
	"""Convert world coordinates to screen coordinates."""
	var relative_pos = world_pos - world_bounds_rect.position
	return relative_pos * zoom_factor + Vector2(360, 20)

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	"""Convert screen coordinates back to world coordinates."""
	var relative_screen = screen_pos - Vector2(360, 20)
	return (relative_screen / zoom_factor) + world_bounds_rect.position

func _draw() -> void:
	"""Draw the world map."""
	var viewport_size = get_viewport_rect().size
	
	# Draw map background
	var map_rect = Rect2(Vector2(360, 20), world_size * zoom_factor)
	draw_rect(map_rect, Color(0.1, 0.1, 0.15), true)
	draw_rect(map_rect, Color(0.5, 0.5, 0.5), false, 2)
	
	# Draw all land tiles only after grouping completes
	var tile_screen_size = tile_size * zoom_factor
	if is_island_grouping_complete:
		for tile_pos in land_tiles:
			var screen_pos = tile_to_screen[tile_pos]
			var rect = Rect2(screen_pos, Vector2(tile_screen_size, tile_screen_size))
			
			# Color based on altitude (optional visual variety)
			var altitude = frontlayer.get_altitude(tile_pos.x, tile_pos.y)
			var color_variant = clamp((altitude + 10) / 20.0, 0.0, 1.0)
			var tile_color = Color(0.2 + color_variant * 0.4, 0.6 + color_variant * 0.2, 0.3, 0.8)
			
			draw_rect(rect, tile_color, true)
	
		# Draw glow effect on hovered island
		if hovered_island.size() > 0:
			for tile_pos in hovered_island:
				# Make sure we have screen coordinates for this tile
				if tile_pos not in tile_to_screen:
					var world_pos = frontlayer.map_to_global(tile_pos)
					var screen_pos = _world_to_screen(world_pos)
					tile_to_screen[tile_pos] = screen_pos
				
				var screen_pos = tile_to_screen[tile_pos]
				var rect = Rect2(screen_pos, Vector2(tile_screen_size, tile_screen_size))
				
				# Draw bright yellow glow border
				draw_rect(rect, Color.YELLOW, false, 3)
				
				# Draw a semi-transparent highlight on top
				draw_rect(rect, Color(1, 1, 0, 0.3), true)
	
		# Draw player current position marker
		var player_world_pos = player.position
		var player_screen_pos = _world_to_screen(player_world_pos)
		draw_circle(player_screen_pos, 8, Color.YELLOW)
		draw_circle(player_screen_pos, 8, Color.WHITE, false, 2)
	else:
		_draw_loading_scanner(map_rect)

	# Show loading message if still grouping islands
	if not is_island_grouping_complete:
		draw_set_transform(Vector2(get_viewport_rect().size.x / 2, get_viewport_rect().size.y / 2), 0, Vector2.ONE)
		draw_string(ThemeDB.fallback_font, Vector2(-100, -20), "Loading world map...", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _draw_loading_scanner(map_rect: Rect2) -> void:
	var beam_rect = Rect2(
		map_rect.position.x,
		map_rect.position.y + scanner_offset,
		map_rect.size.x,
		SCANNER_BEAM_HEIGHT
	)
	var visible_top = max(beam_rect.position.y, map_rect.position.y)
	var visible_bottom = min(beam_rect.position.y + beam_rect.size.y, map_rect.position.y + map_rect.size.y)
	
	if visible_bottom <= visible_top:
		# Nothing visible yet, just redraw the dimmed map area
		draw_rect(map_rect, Color(0, 0, 0, 0.5), true)
		return
	
	var visible_beam_rect = Rect2(
		beam_rect.position.x,
		visible_top,
		beam_rect.size.x,
		visible_bottom - visible_top
	)
	
	# Dim the map area behind the scanner
	draw_rect(map_rect, Color(0, 0, 0, 0.5), true)
	# Draw a soft scanner beam inside the map bounds
	draw_rect(visible_beam_rect, Color(0.3, 0.8, 1.0, 0.18), true)
	draw_rect(visible_beam_rect, Color(0.6, 1.0, 1.0, 0.35), false, 2)
	# Glow lines at the top and bottom of the visible beam
	draw_line(visible_beam_rect.position, visible_beam_rect.position + Vector2(visible_beam_rect.size.x, 0), Color(0.6, 1.0, 1.0, 0.6), 2)
	draw_line(visible_beam_rect.position + Vector2(0, visible_beam_rect.size.y), visible_beam_rect.position + Vector2(visible_beam_rect.size.x, visible_beam_rect.size.y), Color(0.6, 1.0, 1.0, 0.6), 2)

func _process(delta: float) -> void:
	if not is_island_grouping_complete:
		scanner_offset += SCANNER_SPEED * delta
		var map_rect = Rect2(Vector2(360, 20), world_size * zoom_factor)
		if scanner_offset > map_rect.size.y + SCANNER_BEAM_HEIGHT:
			scanner_offset = -SCANNER_BEAM_HEIGHT
		queue_redraw()

func _input(event: InputEvent) -> void:
	"""Handle input for teleportation."""
	# Ignore input when the map UI is hidden or not in the scene tree.
	if not is_visible_in_tree():
		return

	print(
		"[WORLD_MAP] INPUT:",
		" visible=", visible,
		" in_tree=", is_visible_in_tree()
	)

	if event is InputEventMouseMotion:
		_handle_mouse_motion(event.position)
	elif event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_handle_left_click(event.position)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_close_map()
	elif event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			_close_map()

func _handle_mouse_motion(screen_pos: Vector2) -> void:
	"""Handle mouse movement to detect hovered island."""
	# Don't process input until island grouping is complete
	if not is_island_grouping_complete:
		return
	
	# Check if mouse is within map bounds
	var map_rect = Rect2(Vector2(360, 20), world_size * zoom_factor)
	if not map_rect.has_point(screen_pos):
		if hovered_island.size() > 0:
			hovered_island.clear()
			hovered_tile = Vector2i.ZERO
			last_hovered_island_size = 0
			queue_redraw()
		return
	
	# Convert screen position to world position
	var world_pos = _screen_to_world(screen_pos)
	
	# Find the tile under the cursor (global-aware)
	var tile_under_cursor = frontlayer.global_to_map(world_pos)
	
	# Check if this tile is land
	if tile_under_cursor not in land_tiles:
		if hovered_island.size() > 0:
			hovered_island.clear()
			hovered_tile = Vector2i.ZERO
			last_hovered_island_size = 0
			queue_redraw()
		return
	
	# Only recalculate if we moved to a different tile
	if tile_under_cursor != hovered_tile:
		hovered_tile = tile_under_cursor
		_find_island_for_tile(tile_under_cursor)
		
		# Only redraw if the island actually changed (different size = different island)
		if hovered_island.size() != last_hovered_island_size:
			last_hovered_island_size = hovered_island.size()
			print("[WORLD_MAP] Hovered island changed - Size: ", hovered_island.size())
			queue_redraw()

func _find_island_for_tile(tile_pos: Vector2i) -> void:
	"""Find which island a tile belongs to and set it as hovered."""
	#hovered_island.clear()
	hovered_island = []
	
	if islands.size() == 0:
		print("[WORLD_MAP] Warning: No islands found!")
		return
	
	for island_idx in range(islands.size()):
		var island = islands[island_idx]
		if tile_pos in island:
			hovered_island = island.duplicate()
			# Silently found the island - glow will show it
			return
	
	# This shouldn't happen if island grouping is complete
	# but if it does, silently clear highlighting

func _handle_left_click(screen_pos: Vector2) -> void:
	"""Handle left click on the map - teleport player to clicked tile."""
	# Don't allow clicks until island grouping is complete
	print("[WORLD_MAP] Handle_left_click")
	if not is_island_grouping_complete:
		print("[WORLD_MAP] Island grouping still in progress, please wait...")
		return
	
	# Check if click is within map bounds
	var map_rect = Rect2(Vector2(360, 20), world_size * zoom_factor)
	if not map_rect.has_point(screen_pos):
		return
	
	# Convert screen position to world position
	var world_pos = _screen_to_world(screen_pos)
	
	# Find nearest land tile to clicked position
	var nearest_tile = _find_nearest_land_tile(world_pos)
	if nearest_tile == Vector2i.ZERO:
		print("[WORLD_MAP] No land tile found near click")
		return
	
	print("[WORLD_MAP] ABOUT TO TELEPORT")

	# Teleport player to that tile (convert to global coords)
	var tile_world_pos = frontlayer.map_to_global(nearest_tile)
	player.position = tile_world_pos
	
	print("[WORLD_MAP] Teleported player to tile: ", nearest_tile, " at world pos: ", tile_world_pos)
	
	# Close the map after teleporting
	_close_map()

func _find_nearest_land_tile(world_pos: Vector2) -> Vector2i:
	"""Find the nearest land tile to a given world position."""
	var nearest_tile = Vector2i.ZERO
	var min_distance = INF
	
	# Convert world position to approximate tile (global-aware)
	var approx_tile = frontlayer.global_to_map(world_pos)
	
	# Search in a small radius around the approximation
	var search_range = 3
	for dx in range(-search_range, search_range + 1):
		for dy in range(-search_range, search_range + 1):
			var check_tile = approx_tile + Vector2i(dx, dy)
			
			# Check if this tile is in our land tiles list
			if check_tile in land_tiles:
				var tile_world_pos = frontlayer.map_to_global(check_tile)
				var distance = world_pos.distance_to(tile_world_pos)
				
				if distance < min_distance:
					min_distance = distance
					nearest_tile = check_tile
	
	return nearest_tile

func _close_map() -> void:
	"""Close the world map UI and ensure proper cleanup."""
	# Clear references and stop input while hidden
	print(
	"[WORLD_MAP] state:",
	" visible=", visible,
	" processing=", is_processing(),
	" input=", is_processing_input()
)
	hovered_island.clear()
	hovered_tile = Vector2i.ZERO
	
	#unlock player movement here
	player.controls_locked = false

	set_process(false)
	set_process_input(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if get_parent():
		get_parent().visible = false
	else:
		print("[WORLD_MAP] Warning: No parent to remove from")

	print("SELF: ", self)

	if get_parent():
		print("PARENT:", get_parent().name)
		print("PARENT TYPE:", get_parent().get_class())

	print("[WORLD_MAP] Map closed")
