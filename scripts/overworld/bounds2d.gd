extends Node2D

var minimap_script: Node
var outline: Line2D

func _ready() -> void:
	# Use a Line2D so we don't rely on CanvasItem.update() being available on this instance
	outline = Line2D.new()
	outline.width = 2.0
	outline.default_color = Color.WHITE
	outline.closed = true
	add_child(outline)
	set_process(true)

func _process(delta: float) -> void:
	if not minimap_script or not is_instance_valid(minimap_script.frontlayer):
		outline.points = []
		return

	var world_bounds: Rect2 = minimap_script.frontlayer.get_world_bounds()
	# Convert world bounds into Map-local coordinates used by the SubViewport Map node.
	# Account for TileNode offset (TileMap parent position) so the bounds align with the minimap Map node
	var tile_node_pos = minimap_script.frontlayer.get_parent().position if minimap_script.frontlayer.get_parent() else Vector2.ZERO
	var bpos = (world_bounds.position - tile_node_pos) / minimap_script.zoom_factor
	var bsize = world_bounds.size / minimap_script.zoom_factor

	# Compute rectangle corners in map-local space
	var p0 = bpos
	var p1 = bpos + Vector2(bsize.x, 0)
	var p2 = bpos + Vector2(bsize.x, bsize.y)
	var p3 = bpos + Vector2(0, bsize.y)

	outline.points = [p0, p1, p2, p3]
