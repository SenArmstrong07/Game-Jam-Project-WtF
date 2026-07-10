extends Sprite2D

@onready var common_marker_texture: Texture2D = preload("res://assets/ui/enemy_marker.png")
@onready var elite_marker_texture: Texture2D = preload("res://assets/ui/elite_marker.png")
@onready var boss_marker_texture: Texture2D = preload("res://assets/ui/boss_marker.png")

var zoom_factor := 8.0

var enemy: Node2D
var minimap_script

# Marker behaviour
var minimap_radius := 96.0
var max_marker_scale := 1.0
var min_marker_scale := 0.5
var world_render_distance := 2000.0
var base_scale: Vector2 = Vector2.ONE
var _debug_logged := false


func _ready():
	minimap_script = get_tree().get_first_node_in_group("minimap")
	if minimap_script == null:
		call_deferred("_resolve_minimap_script")
	centered = true
	if minimap_script and minimap_script.has_node("playerMarker"):
		var pm = minimap_script.player_marker
		if pm:
			base_scale = pm.scale
	scale = base_scale


func _resolve_minimap_script() -> void:
	if minimap_script == null:
		minimap_script = get_tree().get_first_node_in_group("minimap")


func set_enemy(enemy_ref: Node2D) -> void:
	enemy = enemy_ref
	_update_marker_texture()


func delete_marker():
	queue_free()


func _update_marker_texture():

	if enemy == null:
		return

	var marker_type := "common"

	if enemy.has_method("get_spawn_type"):
		marker_type = enemy.get_spawn_type()

	match marker_type:
		"elite":
			texture = elite_marker_texture

		"boss":
			texture = boss_marker_texture

		_:
			texture = common_marker_texture


func _process(_delta):

	if enemy == null:
		return

	if minimap_script == null:
		minimap_script = get_tree().get_first_node_in_group("minimap")
	if minimap_script == null:
		return

	if minimap_script.player == null:
		minimap_script.player = get_tree().get_first_node_in_group("player")
		if minimap_script.player == null:
			return

	_update_marker_texture()

	var cam : Camera2D = minimap_script.minimap_cam

	# Convert world coordinates into minimap coordinates
	var enemy_pos = enemy.global_position / zoom_factor

	# Offset from minimap camera in viewport space
	var offset = (enemy_pos - cam.position) * cam.zoom.x

	# Distance from minimap center
	var distance = offset.length()
	var visible_radius = minimap_radius
	var minimap_center_screen = minimap_script.subviewport_container.global_position + Vector2(minimap_radius, minimap_radius)

	# One-shot debug log to inspect coordinate space mismatch
	if not _debug_logged and Engine.get_physics_frames() % 120 == 0:
		_debug_logged = true
		print("[MARKER-DEBUG] enemy.global=", enemy.global_position, " enemy_pos=", enemy_pos, " camera_pos=", cam.position, " cam_zoom=", cam.zoom, " offset=", offset, " distance=", distance, " visible_radius=", visible_radius, " center=", minimap_center_screen)

	var output_position: Vector2 = minimap_center_screen + offset

	if distance > visible_radius:

		offset = offset.normalized() * visible_radius
		output_position = minimap_center_screen + offset

		rotation = offset.angle()
		scale = base_scale * max_marker_scale

	else:

		rotation = 0.0

		var world_distance = enemy.global_position.distance_to(
			minimap_script.player.global_position
		)

		var s = clamp(
			1.0 - world_distance / world_render_distance,
			min_marker_scale,
			max_marker_scale
		)

		scale = base_scale * s

	# IMPORTANT:
	# mapMarkers should be placed in map space and rely on the minimap camera to center.
	position = output_position
