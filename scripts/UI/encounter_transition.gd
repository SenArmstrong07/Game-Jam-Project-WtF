extends CanvasLayer

signal finished

@onready var overworld_shot: TextureRect = $OverworldShot
@onready var battle_shot: TextureRect = $BattleShot

@onready var flash: ColorRect = $Flash
@onready var fade: ColorRect = $Fade

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
	
func capture_screen(target: TextureRect):

	# Capture current screen
	var image = get_viewport().get_texture().get_image()
	print("Image size:", image.get_size())
	var texture = ImageTexture.create_from_image(image)

	target.texture = texture
	print("Texture assigned:", target.texture != null)

func play_out():
	var mat := overworld_shot.material as ShaderMaterial

	var tween = create_tween()

	tween.parallel().tween_method(
		func(v):
			mat.set_shader_parameter("glitch_strength",v),
				0.0,
				1.0,
				0.45
	)

	tween.parallel().tween_property(
		fade,
		"modulate:a",
		0.85,
		0.45
	)
	
	tween.parallel().tween_property(
		overworld_shot,
		"modulate:a",
		0.35,
		0.45
	)

	await tween.finished

func play_in():

	var mat := battle_shot.material as ShaderMaterial

	var tween = create_tween()

	tween.parallel().tween_method(
		func(v):
			mat.set_shader_parameter("glitch_strength",v),
			1.0,
			0.0,
			0.45
	)

	tween.parallel().tween_property(
		fade,
		"modulate:a",
		0.0,
		0.35
	)
	
	tween.parallel().tween_property(
		battle_shot,
		"modulate:a",
		1.0,
		0.35
	)

	await tween.finished

func transition_to_battle(battlescene: String):

	visible = true
	reset()
	
	#Capture Overworld
	await RenderingServer.frame_post_draw
	capture_screen(overworld_shot)
	
	#Corruption
	await play_out()
	
	#load Battle
	get_tree().change_scene_to_file(battlescene)
	
	#Wait till battle scene is rendered
	await RenderingServer.frame_post_draw #still animating overworld
	
	overworld_shot.visible = false
	battle_shot.visible = false
	
	await RenderingServer.frame_post_draw #animating battle scene
	
	print(get_tree().current_scene.name)
	#Capture screen again
	capture_screen(battle_shot)
	
	battle_shot.visible = true
	
	#Reconstruct
	await play_in()
	
	visible = false
	finished.emit()
	
func reset():

	var mat1 := overworld_shot.material as ShaderMaterial
	var mat2 := battle_shot.material as ShaderMaterial

	mat1.set_shader_parameter("glitch_strength", 0.0)
	mat2.set_shader_parameter("glitch_strength", 1.0)
	
	overworld_shot.visible = true
	battle_shot.visible = false
	
	overworld_shot.modulate.a = 1.0
	battle_shot.modulate.a = 0.35

	fade.modulate.a = 0.0
	flash.modulate.a = 0.0
