extends Sprite2D

var zoom_factor = 8
var enemy: Node2D = null
var minimap_script: Node = null  # Reference to minimap.gd

# Minimap constants
var minimap_radius = 96  # Radius of circular minimap in pixels
var max_marker_scale = 1.0  # Scale when at minimap edge
var min_marker_scale = 0.4  # Scale when at center
var world_render_distance = 2000  # Distance at which marker reaches max size

func update_position(pos: Vector2) -> void:
	# Expect world-space coordinates in the same root space as player and minimap visuals
	global_position = pos / zoom_factor

func set_enemy(enemy_ref: Node2D) -> void:
	enemy = enemy_ref

func delete_marker():
	call_deferred("queue_free")

func _ready() -> void:
	# Get reference to minimap script to access camera and player
	var minimap_node = get_tree().get_first_node_in_group("minimap")
	if minimap_node:
		minimap_script = minimap_node

func _process(delta: float) -> void:
	# Continuously update marker position based on enemy position
	if enemy and minimap_script:
		var minimap_cam = minimap_script.minimap_cam
		var camera_pos = minimap_script.player.global_position / zoom_factor
		var enemy_pos = enemy.global_position / zoom_factor
		
		# Position relative to camera in minimap world space
		var relative_to_camera = enemy_pos - camera_pos
		
		# Convert to viewport pixel space using camera zoom
		var viewport_pixel_offset = relative_to_camera * minimap_cam.zoom.x
		var distance_from_center = viewport_pixel_offset.length()
		
		# Minimap viewport center and screen position
		var viewport_center = Vector2(96, 96)
		var minimap_screen_pos = get_tree().root.get_visible_rect().size - Vector2(192, 192)  # Bottom-right corner
		
		# Clamp to minimap circle if outside radius
		if distance_from_center > minimap_radius:
			# Outside circle - clamp to edge
			var direction = viewport_pixel_offset.normalized()
			var clamped_viewport_offset = direction * minimap_radius
			var clamped_world_offset = clamped_viewport_offset / minimap_cam.zoom.x
			
			# Convert to screen position
			var viewport_pos = viewport_center + clamped_viewport_offset
			global_position = minimap_screen_pos + viewport_pos
			
			# Rotate marker to point toward enemy
			rotation = direction.angle()
			scale = Vector2.ONE * max_marker_scale
		else:
			# Inside circle - show at actual enemy position
			var viewport_pos = viewport_center + viewport_pixel_offset
			global_position = minimap_screen_pos + viewport_pos
			rotation = 0
			
			# Scale based on proximity - closer = smaller, farther = larger
			var world_distance = enemy.global_position.distance_to(minimap_script.player.global_position)
			var proximity_scale = clamp(1.0 - (world_distance / world_render_distance), min_marker_scale, max_marker_scale)
			scale = Vector2.ONE * proximity_scale

		
