extends CanvasLayer

signal finished
const GLITCH_OUT_TIME := 0.4
const GLITCH_IN_TIME := 0.6
const GLITCH_HOLD_TIME := 0.6
@onready var overworld_shot: TextureRect = $OverworldShot

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
	await get_tree().create_timer(GLITCH_HOLD_TIME).timeout
	


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
	
	visible = false
	finished.emit()
	
func reset():

	var mat1 := overworld_shot.material as ShaderMaterial

	mat1.set_shader_parameter("glitch_strength", 0.0)
	
	overworld_shot.visible = true
	
	overworld_shot.modulate.a = 1.0

	fade.modulate.a = 0.0
	flash.modulate.a = 0.0
