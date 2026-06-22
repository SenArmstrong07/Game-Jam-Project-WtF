extends Sprite2D

var zoom_factor = 8
var enemy: Node2D = null

# Minimap constants
var minimap_center = Vector2(96, 96)  # Center of 192x192 viewport
var minimap_radius = 96  # Radius of circular minimap
var max_marker_scale = 1.0  # Scale when at minimap edge
var min_marker_scale = 0.4  # Scale when at center
var world_render_distance = 2000  # Distance at which marker reaches max size

func update_position(pos):
	global_position = pos / zoom_factor

func set_enemy(enemy_ref: Node2D) -> void:
	enemy = enemy_ref

func delete_marker():
	call_deferred("queue_free")

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	# Continuously update marker position based on enemy position
	if enemy:
		update_position(enemy.position)
		# var scaled_pos = enemy.position / zoom_factor
		# var to_enemy = scaled_pos - minimap_center
		# var distance = to_enemy.length()
		
		# # Check if outside the minimap circle
		# if distance > minimap_radius:
		# 	# Outside circle - clamp to edge and scale based on distance
		# 	var direction = to_enemy.normalized()
		# 	global_position = minimap_center + direction * minimap_radius
			
		# 	# Rotate marker to point toward enemy
		# 	rotation = direction.angle()
			
		# 	# Scale marker based on world distance
		# 	# Markers at the edge are larger (indicating far enemies)
		# 	scale = Vector2.ONE * max_marker_scale
		# else:
		# 	# Inside circle - show at actual position with distance-based scaling
		# 	global_position = scaled_pos
		# 	rotation = 0
			
		# 	# Scale based on proximity - closer = smaller, farther = larger
		# 	var world_distance = enemy.position.distance_to(get_tree().root.get_child(0).get_node("OverworldPlayer").position)
		# 	var proximity_scale = clamp(1.0 - (world_distance / world_render_distance), min_marker_scale, max_marker_scale)
		# 	scale = Vector2.ONE * proximity_scale

		
