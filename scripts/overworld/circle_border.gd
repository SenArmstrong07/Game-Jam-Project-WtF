extends Control

func _draw() -> void:
	var center = size / 2
	var radius = 96
	draw_arc(center, radius, 0, TAU, 64, Color.WHITE, 3.0)
