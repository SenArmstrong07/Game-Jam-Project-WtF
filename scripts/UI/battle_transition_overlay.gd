extends ColorRect

@onready var glitch_overlay: ColorRect = $"."
const GLITCH_OUT_TIME := 0.6
const GLITCH_IN_TIME := 0.4
const GLITCH_HOLD_TIME := 0.6
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func play_glitch_in():
	print("Glitch IN started")
	var mat:= glitch_overlay.material as ShaderMaterial
	print("Material Used: ", mat)
	print("Visible:", visible)
	print("Alpha:", modulate.a)
	await get_tree().create_timer(GLITCH_HOLD_TIME * 0.5).timeout
	var tween := create_tween()
	
	tween.set_trans(Tween.TRANS_EXPO)
	tween.set_ease(Tween.EASE_OUT)
	
	tween.parallel().tween_method(
		func(v):
			mat.set_shader_parameter("glitch_strength", v),
		1.0,
		0.0,
		GLITCH_IN_TIME
	)

	tween.parallel().tween_property(
		glitch_overlay,
		"modulate:a",
		0.0,
		GLITCH_IN_TIME
	)

	await tween.finished
	print("Glitch IN finished")
	SignalBus.in_transition = false
	glitch_overlay.visible = false
