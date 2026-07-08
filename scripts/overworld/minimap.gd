extends CanvasLayer

@onready var minimap_cam: Camera2D = %minimapCam
@onready var map_markers: Node2D = %mapMarkers
@onready var terrain_visuals: Node2D = %TerrainVisuals
@onready var map_root: Node2D = $SubViewportContainer/SubViewport/Map
@onready var marker_scene = preload("res://scenes/overworld/Marker.tscn")
@onready var world_map_scene = preload("res://scenes/overworld/world_map_ui.tscn")
@onready var Bounds2DScript = preload("res://scripts/overworld/bounds2d.gd")

var zoom_factor = 8
var markers = []
var player: Node2D
var tracked_enemies: Dictionary = {}  # Dictionary to track which enemies have markers
var frontlayer: TileMapLayer
var marker_layer: Control  # Layer above minimap for markers to render on top
var bounds_drawer: Control  # Control node for drawing world bounds
var subviewport_container: SubViewportContainer  # Reference to minimap container
var world_map_ui = null

# Minimap circle clamping
var minimap_center = Vector2.ZERO  # Updated each frame to camera position
var minimap_radius = 96  # Radius of circular minimap in pixels

# Terrain rendering
var terrain_tiles: Dictionary = {}  # Store rendered terrain tiles: {tile_pos: ColorRect_node}
var tile_size = 64  # Match the tilemap tile size
var tile_colors = {
	0: Color(0.02, 0.169, 0.027, 1.0),  # empty space (dark/neon green)
	1: Color(0.527, 0.55, 0.957, 1.0),  # Land type 1 (light blue)
	2: Color(0.349, 0.727, 0.698, 1.0), # Land type 2 (lighter teal)
	3: Color(0.067, 0.492, 0.932, 1.0),  # Land type 3 (dark blue)
}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("minimap")
	if map_root == null or not is_instance_valid(map_root):
		var viewport_root = find_child("SubViewport", false)
		if viewport_root and viewport_root.has_node("Map"):
			map_root = viewport_root.get_node("Map")
		elif has_node("SubViewport/Map"):
			map_root = get_node("SubViewport/Map")
		elif has_node("Map"):
			map_root = get_node("Map")
		else:
			map_root = null
		print("[MINIMAP] Resolved map root: ", map_root)
	
	# Get reference to player
	player = get_tree().get_first_node_in_group("player")
	
	# Get reference to frontlayer and connect to enemy_spawned signal
	frontlayer = get_tree().get_first_node_in_group("frontlayer")
	if frontlayer:
		frontlayer.enemy_spawned.connect(_on_enemy_spawned)
	
	# Set up minimap camera
	if minimap_cam:
		minimap_cam.enabled = true
		minimap_cam.zoom = Vector2(0.5, 0.5)  # Zoom out to see more terrain
	
	# Create marker layer above the minimap to render markers on top of white border
	marker_layer = Control.new()
	marker_layer.name = "MarkerLayer"
	marker_layer.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	marker_layer.anchor_left = 1.0
	marker_layer.anchor_top = 1.0
	marker_layer.anchor_right = 1.0
	marker_layer.anchor_bottom = 1.0
	marker_layer.offset_left = -192.0
	marker_layer.offset_top = -192.0
	marker_layer.size = Vector2(192, 192)
	marker_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(marker_layer)
	move_child(marker_layer, get_child_count() - 1)  # Move to top layer
	
	# Get reference to SubViewportContainer for click detection
	subviewport_container = find_child("SubViewportContainer")
	if subviewport_container:
		# Connect the gui_input signal to detect minimap clicks
		if not subviewport_container.gui_input.is_connected(_on_minimap_gui_input):
			subviewport_container.gui_input.connect(_on_minimap_gui_input)
		print("[MINIMAP] Click handler connected - click minimap to open world map")
	else:
		print("[MINIMAP] WARNING: SubViewportContainer not found!")
	
	# Create background fill for empty minimap areas with the sea level/empty space color
	if terrain_visuals:
		var background = ColorRect.new()
		background.position = Vector2(-50000, -50000)
		background.size = Vector2(100000, 100000)
		background.color = tile_colors[0]  # empty space (dark/neon green)
		terrain_visuals.add_child(background)
		terrain_visuals.move_child(background, 0)  # Move to back so terrain tiles render on top
		print("[MINIMAP] Background fill added to terrain_visuals")
	
	# NOTE: We intentionally do NOT add the world-bounds overlay to the minimap
	# to avoid drawing the world boundary rectangle inside the minimap UI.
	# Bounds2DScript is kept available if needed for debug builds, but is not
	# instantiated here to prevent the white rectangle from appearing.
	pass

func _physics_process(delta: float) -> void:
	if player:
		# Compute desired minimap camera center (map world -> minimap space)
		var desired_cam_pos = player.position / zoom_factor

		# If frontlayer/world bounds available, clamp camera so viewport doesn't show beyond world edges
		if frontlayer and frontlayer.has_method("get_world_bounds"):
			var wb: Rect2 = frontlayer.get_world_bounds()
			# Map world bounds into minimap space
			var min_cam = wb.position / zoom_factor
			var max_cam = (wb.position + wb.size) / zoom_factor

			# Use minimap radius (half of 192) to ensure the circular minimap doesn't extend past edges
			var pad = Vector2(minimap_radius, minimap_radius)
			min_cam += pad
			max_cam -= pad

			# If world smaller than viewport, center the camera inside world
			if min_cam.x > max_cam.x:
				desired_cam_pos.x = (min_cam.x + max_cam.x) * 0.5
			else:
				desired_cam_pos.x = clamp(desired_cam_pos.x, min_cam.x, max_cam.x)

			if min_cam.y > max_cam.y:
				desired_cam_pos.y = (min_cam.y + max_cam.y) * 0.5
			else:
				desired_cam_pos.y = clamp(desired_cam_pos.y, min_cam.y, max_cam.y)

		minimap_cam.position = desired_cam_pos
		minimap_center = desired_cam_pos  # Update center to camera position
		
		# Ensure camera is enabled
		if minimap_cam:
			minimap_cam.enabled = true
	
	# Periodically render nearby terrain chunks while managing memory
	render_nearby_terrain_chunks()
	
	# Redraw the bounds on the bounds drawer
	if bounds_drawer:
		bounds_drawer.queue_redraw()
	
	# Debug: Print terrain_tiles count every 60 frames
	if Engine.get_physics_frames() % 60 == 0:
		print("[MINIMAP] Active terrain tiles: ", terrain_tiles.size())

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_enemy_spawned(enemy: Node2D) -> void:
	# Create marker when enemy is spawned
	var marker = create_marker_for_enemy(enemy)
	tracked_enemies[enemy] = marker


func create_marker_for_enemy(enemy: Node2D) -> Sprite2D:
	var marker = marker_scene.instantiate()
	
	# Link marker to enemy for continuous position updates
	marker.set_enemy(enemy)
	
	# Set initial position immediately to avoid visual glitch
	marker.update_position(enemy.global_position)
	
	# Add to marker layer (above minimap) instead of inside viewport
	marker_layer.add_child(marker)
	
	# Connect death signal if it exists
	if enemy.has_signal("died"):
		enemy.died.connect(marker.delete_marker)
		enemy.died.connect(func(): tracked_enemies.erase(enemy))
	
	return marker


func render_nearby_terrain_chunks() -> void:
	if not frontlayer or not terrain_visuals:
		return
	
	var camera_tile_pos = frontlayer.global_to_map(player.position)
	var render_range = 25  # Adjusted for smaller 192×192 viewport
	
	# Render terrain tiles in range (but only those inside the generated world bounds)
	var wb = frontlayer.world_bounds
	var min_tile_x = -wb * frontlayer.width
	var max_tile_x = (wb + 1) * frontlayer.width - 1
	var min_tile_y = -wb * frontlayer.height
	var max_tile_y = (wb + 1) * frontlayer.height - 1

	for x in range(camera_tile_pos.x - render_range, camera_tile_pos.x + render_range):
		for y in range(camera_tile_pos.y - render_range, camera_tile_pos.y + render_range):
			var tile_pos = Vector2i(x, y)

			# Skip tiles outside the world's generated bounds
			if tile_pos.x < min_tile_x or tile_pos.x > max_tile_x or tile_pos.y < min_tile_y or tile_pos.y > max_tile_y:
				continue

			# Skip if already rendered
			if tile_pos in terrain_tiles:
				continue

			# Get altitude and determine tile type
			var altitude = frontlayer.get_altitude(x, y)
			var tile_type = 0 if altitude < 0 else int((altitude + 10) / 20.0 * 4) % 4

			# Render tile to minimap
			render_terrain_tile(tile_pos, tile_type)
	
	# Clean up tiles that are too far away - ACTUALLY DELETE THE NODES
	var tiles_to_remove = []
	for tile_pos in terrain_tiles:
		var dist = camera_tile_pos.distance_to(tile_pos)
		if dist > render_range + 10:
			tiles_to_remove.append(tile_pos)
	
	for tile_pos in tiles_to_remove:
		var rect_node = terrain_tiles[tile_pos]
		if rect_node and not rect_node.is_queued_for_deletion():
			rect_node.queue_free()  # Actually delete the ColorRect node
		terrain_tiles.erase(tile_pos)


func render_terrain_tile(tile_pos: Vector2i, tile_type: int) -> void:
	if not terrain_visuals:
		return
		
	var rect = ColorRect.new()
	var world_pos = frontlayer.map_to_global(tile_pos) / zoom_factor
	
	rect.position = world_pos - Vector2(tile_size / 2 / zoom_factor, tile_size / 2 / zoom_factor)
	rect.size = Vector2(tile_size / zoom_factor, tile_size / zoom_factor)
	rect.color = tile_colors.get(tile_type, Color.GRAY)
	
	terrain_visuals.add_child(rect)
	
	# IMPORTANT: Store reference to the node so we can delete it later
	terrain_tiles[tile_pos] = rect

 


func _on_minimap_gui_input(event: InputEvent) -> void:
	"""Handle clicks on the minimap to open the full world map."""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Open the world map UI
		print("[MINIMAP] CLICK DETECTED")
		_open_world_map()
		#lock player movement first when overworld ui map is opened
		player.controls_locked = true


func _open_world_map() -> void:
	"""Show world map UI."""
	print("[MINIMAP] OPEN WORLD MAP CALLED")
	print("world_map_ui = ", world_map_ui)
	print("valid = ", is_instance_valid(world_map_ui))

	if not world_map_scene:
		print("[MINIMAP] Error: world_map_scene not loaded")
		return

	# Create only once, or recreate if the reference was freed
	if world_map_ui == null or not is_instance_valid(world_map_ui):
		print("[MINIMAP] Creating world map for first time...")
		world_map_ui = world_map_scene.instantiate()

		if not world_map_ui:
			print("[MINIMAP] Error: Failed to instantiate world_map_scene")
			return

		get_tree().root.add_child(world_map_ui)

	# Show existing map
	# Re-add to tree if it was removed
	if world_map_ui.get_parent() == null:
		get_tree().root.add_child(world_map_ui)

	# Show existing map
	world_map_ui.visible = true

	print("[MINIMAP] World map opened")

	var map_container = world_map_ui.get_node_or_null("MapContainer")
	if map_container:
		map_container.mouse_filter = Control.MOUSE_FILTER_STOP
		map_container.set_process_input(true)
	world_map_ui.set_process(true)
