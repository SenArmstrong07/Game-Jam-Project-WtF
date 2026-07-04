extends ColorRect

signal finished

func play_out():

	var mat := self.material as ShaderMaterial

	visible = true

	if mat == null:
		print("[BattleReconstructionOverlay] play_out: no material assigned")
	else:
		mat.set_shader_parameter("pixel_size", 64.0)

	modulate.a = 1.0

	var tween := create_tween()

	tween.set_trans(Tween.TRANS_EXPO)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_method(
		func(v):
			mat.set_shader_parameter("pixel_size", v),
		64.0,
		1.0,
		0.8
	)

	await tween.finished

	visible = false

	finished.emit()
	
	
func play_in():

	var mat := self.material as ShaderMaterial

	visible = true

	# Start with a heavily pixelated image
	if mat == null:
		print("[BattleReconstructionOverlay] play_in: no material assigned")
	else:
		mat.set_shader_parameter("pixel_size", 64.0)

	modulate.a = 1.0

	var tween := create_tween()

	tween.set_trans(Tween.TRANS_EXPO)
	tween.set_ease(Tween.EASE_OUT)

	# Gradually sharpen the world
	tween.parallel().tween_method(
		func(v):
			mat.set_shader_parameter("pixel_size", v),
		64.0,
		1.0,
		0.8
	)

	# Fade the overlay away as the image becomes clear
	tween.parallel().tween_property(
		self,
		"modulate:a",
		0.0,
		0.8
	)

	await tween.finished

	visible = false

	finished.emit()
