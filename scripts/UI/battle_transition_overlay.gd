extends ColorRect

const GLITCH_OUT_TIME := 0.6
const GLITCH_IN_TIME := 0.4
const GLITCH_HOLD_TIME := 0.6

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	pass

func play_glitch_in():

	# Operate on `self` since this script is attached to the glitch overlay
	self.visible = true
	self.modulate.a = 0.35

	var mat := self.material as ShaderMaterial
	if mat == null:
		print("[BattleTransitionOverlay] play_glitch_in: no material on self")
	else:
		mat.set_shader_parameter("glitch_strength", 1.0)

	print("Glitch IN started")

	await get_tree().create_timer(GLITCH_HOLD_TIME * 0.5).timeout

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_EXPO)
	tween.set_ease(Tween.EASE_OUT)

	tween.parallel().tween_method(
		func(v):
			if mat != null:
				mat.set_shader_parameter("glitch_strength", v),
		1.0,
		0.0,
		GLITCH_IN_TIME
	)

	tween.parallel().tween_property(
		self,
		"modulate:a",
		0.0,
		GLITCH_IN_TIME
	)

	await tween.finished

	self.visible = false

	print("Glitch IN finished")
