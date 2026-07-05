extends CanvasLayer

@onready var color_rect: ColorRect = $Transition_rect
@onready var label: Label = $Transition_rect/Transition_label

@export var fade_time := 1.0
@export var hold_time := 2.0

func transition_to_scene(scene_path: String, message: String) -> void:
	label.text = message

	# Start fully transparent
	color_rect.modulate.a = 0.0
	label.modulate.a = 0.0

	# Fade to black
	var tween = create_tween()
	tween.parallel().tween_property(color_rect, "modulate:a", 1.0, fade_time)
	tween.parallel().tween_property(label, "modulate:a", 1.0, fade_time)
	await tween.finished

	# Wait while showing the message
	await get_tree().create_timer(hold_time).timeout

	# Change scene while still black
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame

	# Fade back in (if this transition node persists)
	var tween2 = create_tween()
	tween2.parallel().tween_property(color_rect, "modulate:a", 0.0, fade_time)
	tween2.parallel().tween_property(label, "modulate:a", 0.0, fade_time)
	await tween2.finished

	queue_free()
