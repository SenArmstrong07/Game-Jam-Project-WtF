extends CanvasLayer

signal finished
const GLITCH_OUT_TIME := 0.4
const GLITCH_IN_TIME := 0.6
const GLITCH_HOLD_TIME := 0.6
const RETURN_FADE_TIME := 0.4
@onready var overworld_shot: TextureRect = $OverworldShot
@onready var glitch_overlay: ColorRect = $GlitchOverlay
@onready var reconstruction_overlay: ColorRect = $ReconstructionOverlay
@onready var flash: ColorRect = $Flash
@onready var fade: ColorRect = $Fade

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false
	# Ensure this CanvasLayer renders above other layers
	self.layer = 100
	# Draw order: screenshot first, fade next, glitch overlay on top.
	overworld_shot.z_index = 0
	fade.z_index = 1
	glitch_overlay.z_index = 2
	reconstruction_overlay.z_index = 3
	flash.z_index = 4
	print("[EncounterTransition] ready; layer=", self.layer)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
	
func capture_screen(target: TextureRect):

	# Capture current screen
	# Try to capture the current viewport image reliably
	var image = null
	# The caller should await RenderingServer.frame_post_draw before calling
	image = get_viewport().get_texture().get_image()
	if image == null:
		print("[EncounterTransition] capture_screen: failed to get image from viewport")
		return

	# Log size for debugging
	print("Image size:", image.get_size())

	var texture = null
	# Protect against invalid images
	if image.get_size().x > 0 and image.get_size().y > 0:
		texture = ImageTexture.create_from_image(image)
	else:
		print("[EncounterTransition] capture_screen: image has zero size")

	if texture != null:
		target.texture = texture
		print("[EncounterTransition] captured image size:", image.get_size(), " texture assigned:", target.texture != null)
	else:
		print("[EncounterTransition] capture_screen: failed to create texture from image")

func play_out():

	glitch_overlay.visible = true
	fade.visible = true
	fade.modulate.a = 0.0
	glitch_overlay.modulate.a = 0.35
	var mat := glitch_overlay.material as ShaderMaterial
	if mat == null:
		print("[EncounterTransition] play_out: no material on glitch_overlay")
	else:
		mat.set_shader_parameter("glitch_strength", 0.0)
	print("Material:", mat)
	var tween = create_tween()
	
	print("Starting glitch out")

	tween.parallel().tween_method(
		func(v):
			if mat != null:
				print("Glitch:", v)
				mat.set_shader_parameter("glitch_strength", v),
		0.0,
		1.0,
		GLITCH_OUT_TIME
	)

	tween.parallel().tween_property(
		fade,
		"modulate:a",
		0.85,
		GLITCH_OUT_TIME
	)
	
	tween.parallel().tween_property(
		overworld_shot,
		"modulate:a",
		0.35,
		GLITCH_OUT_TIME
	)

	await tween.finished
	print("[EncounterTransition] play_out finished")
	await get_tree().create_timer(GLITCH_HOLD_TIME).timeout
	


func transition_to_battle(battlescene: String):

	visible = true
	reset()
	
	# Give the overlay one frame to actually appear.
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	
	#then capture overworld shot
	capture_screen(overworld_shot)
	
	# Bind the screenshot to the glitch shader so the effect is visible.
	var glitch_mat := glitch_overlay.material as ShaderMaterial
	if glitch_mat != null and overworld_shot.texture != null:
		glitch_mat.set_shader_parameter("screen_texture", overworld_shot.texture)
	
	# Make sure the screenshot is what is currently displayed.
	overworld_shot.visible = true
	
	#Corruption
	await play_out()
	
	#load Battle
	get_tree().change_scene_to_file(battlescene)
	
	
	#wait till Battlesene has rendered
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	
	print("Current scene:", get_tree().current_scene.name)
	
	# IMPORTANT:
	# Remove the screenshot BEFORE revealing the battle.
	overworld_shot.visible = false

	await glitch_overlay.play_glitch_in()
	
	glitch_overlay.visible = false
	fade.visible = false
	flash.visible = false

	visible = false
	
	
	print("OverworldShot visible:", overworld_shot.visible)
	print("Overworld alpha:", overworld_shot.modulate.a)
	print("Transition visible:", visible)
	print("Overworld texture:", overworld_shot.texture)
	print("Material:", overworld_shot.material)
	
	finished.emit()
	
func transition_to_overworld():

	visible = true

	# Let the new overworld render first.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	await play_return_fade()

	reset()

	visible = false
	finished.emit()

func play_return_fade():

	reset()
	visible = true
	fade.visible = true
	fade.modulate.a = 0.0

	var tween_in := create_tween()
	tween_in.tween_property(
		fade,
		"modulate:a",
		1.0,
		RETURN_FADE_TIME
	)

	await tween_in.finished

	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var tween_out := create_tween()
	tween_out.tween_property(
		fade,
		"modulate:a",
		0.0,
		RETURN_FADE_TIME
	)

	await tween_out.finished
	
func reset():

	var mat := glitch_overlay.material as ShaderMaterial
	mat.set_shader_parameter("glitch_strength", 0.0)

	glitch_overlay.visible = false
	glitch_overlay.modulate.a = 0.0

	overworld_shot.visible = false
	overworld_shot.modulate.a = 1.0

	fade.visible = false
	fade.modulate.a = 0.0

	flash.visible = false
	flash.modulate.a = 0.0

	reconstruction_overlay.visible = false
	reconstruction_overlay.modulate.a = 0.0
