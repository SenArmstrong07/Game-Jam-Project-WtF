extends CanvasLayer

signal finished

const GLITCH_OUT_TIME := 0.3
const GLITCH_IN_TIME := 0.4
const GLITCH_HOLD_TIME := 0.2
const RETURN_FADE_TIME := 0.2
@onready var overworld_shot: TextureRect = $OverworldShot
@onready var glitch_overlay: ColorRect = $GlitchOverlay
@onready var reconstruction_overlay: ColorRect = $ReconstructionOverlay
@onready var flash: ColorRect = $Flash
@onready var fade: ColorRect = $Fade
@onready var glitch_player: AudioStreamPlayer = $GlitchPlayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false
	# Ensure this CanvasLayer renders above other layers
	self.layer = 100
	_apply_z_order()
	print("[EncounterTransition] ready; layer=", self.layer)


func _process(_delta: float) -> void:
	pass


func _apply_z_order() -> void:
	_set_z_index(overworld_shot, 0)
	_set_z_index(fade, 1)
	_set_z_index(glitch_overlay, 2)
	_set_z_index(reconstruction_overlay, 3)
	_set_z_index(flash, 4)


func _set_z_index(node: CanvasItem, index: int) -> void:
	if is_instance_valid(node):
		node.z_index = index


func _set_visible(node: CanvasItem, should_show: bool) -> void:
	if is_instance_valid(node):
		node.visible = should_show


func _set_alpha(node: CanvasItem, alpha: float) -> void:
	if is_instance_valid(node):
		node.modulate.a = alpha


func capture_screen(target: TextureRect) -> void:
	if not is_instance_valid(target):
		print("[EncounterTransition] capture_screen: target is invalid")
		return

	var image = get_viewport().get_texture().get_image()
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


func _play_glitch_sfx() -> void:
	if is_instance_valid(glitch_player):
		glitch_player.stop()
		glitch_player.play()

func _wait_for_current_scene() -> Node:
	var tree := get_tree()
	if tree == null:
		return null

	for i in range(3):
		await tree.process_frame
		var scene_root := tree.current_scene
		if is_instance_valid(scene_root):
			return scene_root

	return null

func play_out() -> void:
	if not is_instance_valid(glitch_overlay):
		print("[EncounterTransition] play_out: glitch_overlay is unavailable")
		return

	_play_glitch_sfx()
	_set_visible(glitch_overlay, true)
	_set_visible(fade, true)
	_set_alpha(fade, 0.0)
	_set_alpha(glitch_overlay, 0.35)

	_set_visible(overworld_shot, true)
	_set_alpha(overworld_shot, 1.0)

	await get_tree().process_frame

	if is_instance_valid(glitch_overlay) and glitch_overlay.has_method("play_glitch_out"):
		await glitch_overlay.play_glitch_out()
	else:
		var mat := glitch_overlay.material as ShaderMaterial
		if mat == null:
			print("[EncounterTransition] play_out: no material on glitch_overlay")
		else:
			mat.set_shader_parameter("glitch_strength", 0.0)

		var tween = create_tween()
		tween.parallel().tween_method(
			func(v):
				if mat != null:
					mat.set_shader_parameter("glitch_strength", v),
			0.0,
			1.0,
			GLITCH_OUT_TIME
		)
		tween.parallel().tween_property(fade, "modulate:a", 0.85, GLITCH_OUT_TIME)
		tween.parallel().tween_property(overworld_shot, "modulate:a", 0.35, GLITCH_OUT_TIME)
		await tween.finished

	await get_tree().create_timer(GLITCH_HOLD_TIME).timeout
	print("[EncounterTransition] play_out finished")


func transition_to_battle(battlescene: String) -> void:
	visible = true
	reset()
	
	# Give the overlay one frame to actually appear.
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	
	#then capture overworld shot
	capture_screen(overworld_shot)

	var glitch_mat: ShaderMaterial = null
	if is_instance_valid(glitch_overlay):
		glitch_mat = glitch_overlay.material as ShaderMaterial
	if glitch_mat != null and is_instance_valid(overworld_shot) and overworld_shot.texture != null:
		glitch_mat.set_shader_parameter("screen_texture", overworld_shot.texture)

	_set_visible(overworld_shot, true)

	await play_out()
	
	#load Battle
	get_tree().change_scene_to_file(battlescene)
	
	
	#wait till Battlesene has rendered
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	var scene_root := await _wait_for_current_scene()
	if is_instance_valid(scene_root):
		print("Current scene:", scene_root.name)
	else:
		print("Current scene unavailable during transition")

	_set_visible(overworld_shot, false)

	if is_instance_valid(glitch_overlay) and glitch_overlay.has_method("play_glitch_in"):
		await glitch_overlay.play_glitch_in()

	_set_visible(glitch_overlay, false)
	_set_visible(fade, false)
	_set_visible(flash, false)

	visible = false

	if is_instance_valid(overworld_shot):
		print("OverworldShot visible:", overworld_shot.visible)
		print("Overworld alpha:", overworld_shot.modulate.a)
		print("Overworld texture:", overworld_shot.texture)
		print("Material:", overworld_shot.material)

	print("Transition visible:", visible)
	finished.emit()


func transition_to_overworld() -> void:
	visible = true
	reset()

	# Show glitch immediately
	_set_visible(glitch_overlay, true)
	_set_alpha(glitch_overlay, 0.35)

	await get_tree().process_frame

	# Wait until the overworld is actually ready for player input
	var frontlayer = get_tree().get_first_node_in_group("frontlayer")

	if frontlayer:
		var timer = get_tree().create_timer(5.0)
		var completed : bool = false
		frontlayer.overworld_ready.connect(
			func():
				completed = true,
			CONNECT_ONE_SHOT
		)
		while !completed and timer.time_left > 0:
			await get_tree().process_frame

		if !completed:
			push_warning("[EncounterTransition] Timed out waiting for overworld_ready.")

	# NOW reveal it
	await play_return_fade()

	reset()

	visible = false
	finished.emit()

#SPECIFICALLY FOR GAME OVER:

func play_game_over_intro() -> void:
	visible = true
	reset()

	await get_tree().process_frame

	capture_screen(overworld_shot)

	var mat := glitch_overlay.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter(
			"screen_texture",
			overworld_shot.texture
		)

	overworld_shot.visible = true

	await play_return_fade()

	overworld_shot.visible = false

func play_return_fade() -> void:
	reset()
	visible = true
	await get_tree().process_frame

	_play_glitch_sfx()
	_set_visible(glitch_overlay, true)
	_set_visible(fade, true)
	_set_alpha(glitch_overlay, 0.35)
	_set_alpha(fade, 0.0)

	var mat := glitch_overlay.material as ShaderMaterial
	if mat == null:
		_set_visible(glitch_overlay, false)
		_set_visible(fade, false)
		return

	mat.set_shader_parameter("glitch_strength", 1.0)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_EXPO)
	tween.set_ease(Tween.EASE_OUT)

	for i in range(3):
		tween.tween_method(
			func(v):
				if mat != null:
					mat.set_shader_parameter("glitch_strength", v),
			1.0,
			0.0,
			GLITCH_IN_TIME / 3.0
		)
		tween.tween_method(
			func(v):
				if mat != null:
					mat.set_shader_parameter("glitch_strength", v),
			0.0,
			1.0,
			GLITCH_IN_TIME / 3.0
		)

	tween.parallel().tween_property(glitch_overlay, "modulate:a", 0.0, GLITCH_IN_TIME)
	tween.parallel().tween_property(fade, "modulate:a", 0.35, GLITCH_IN_TIME * 0.5)

	await tween.finished

	_set_visible(glitch_overlay, false)
	_set_visible(fade, false)


func reset() -> void:
	if is_instance_valid(glitch_overlay):
		var mat := glitch_overlay.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("glitch_strength", 0.0)
		glitch_overlay.visible = false
		glitch_overlay.modulate.a = 0.0

	if is_instance_valid(overworld_shot):
		overworld_shot.visible = false
		overworld_shot.modulate.a = 1.0

	if is_instance_valid(fade):
		fade.visible = false
		fade.modulate.a = 0.0

	if is_instance_valid(flash):
		flash.visible = false
		flash.modulate.a = 0.0

	if is_instance_valid(reconstruction_overlay):
		reconstruction_overlay.visible = false
		reconstruction_overlay.modulate.a = 0.0
