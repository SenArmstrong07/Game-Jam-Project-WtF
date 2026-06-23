extends Node2D

@onready var center: Sprite2D = $CENTER
@onready var left: Sprite2D = $LEFT
@onready var right: Sprite2D = $RIGHT


func _ready():
	var tex = preload("res://icon.svg")


	for node in [left, center, right]:
		node.texture = tex
		node.scale = Vector2(1, 1)  # KEEP NORMAL
		node.modulate = Color(0.2, 0.8, 1.0, 0.6)

	center.modulate = Color(0.2, 1.0, 1.0, 0.9)

	left.position = Vector2(-64, 0)
	center.position = Vector2(0, 0)
	right.position = Vector2(64, 0)
	
func start_scan():
	rotation_degrees = 0
	scale = Vector2(0.8, 0.8)

	var tween = create_tween()

	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(self, "rotation_degrees", -25, 0.1)
	tween.tween_property(self, "rotation_degrees", 25, 0.2)
	tween.tween_property(self, "rotation_degrees", 0, 0.1)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.4)

	await tween.finished
	queue_free()
