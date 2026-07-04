@tool
extends ColorRect

@export var background_color := Color(0.03, 0.05, 0.12)
@export var grid_color := Color(0.0, 0.9, 1.0, 0.45)

@export var grid_spacing := 48.0
@export var scroll_speed := 140.0
@export var line_thickness := 2.0

var scroll := 0.0

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if Engine.is_editor_hint():
		set_process(true)

	queue_redraw()

func _process(delta):
	scroll += scroll_speed * delta

	if scroll > grid_spacing:
		scroll -= grid_spacing

	queue_redraw()

func _draw():

	var size = self.size

	# Background
	draw_rect(Rect2(Vector2.ZERO, size), background_color)

	# Horizontal lines
	var y = -grid_spacing + scroll

	while y < size.y + grid_spacing:
		draw_line(
			Vector2(0, y),
			Vector2(size.x, y),
			grid_color,
			line_thickness
		)
		y += grid_spacing

	# Vertical lines
	var x := 0.0

	while x <= size.x:
		draw_line(
			Vector2(x, 0),
			Vector2(x, size.y),
			grid_color,
			line_thickness
		)
		x += grid_spacing

	# Scanlines
	for yy in range(0, int(size.y), 4):
		draw_line(
			Vector2(0, yy),
			Vector2(size.x, yy),
			Color(0,0,0,0.05),
			1
		)
