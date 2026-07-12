extends Control

@onready var background: ColorRect = $Background
@onready var game_over_label: Label = $GameOverLabel
@onready var prompt_label: Label = $PromptLabel

const TITLE_SCREEN_PATH := "res://scenes/UI/TitleScreen.tscn"

func _ready() -> void:
	background.color = Color.BLACK
	game_over_label.modulate.a = 0.0
	prompt_label.modulate.a = 0.0
	await get_tree().process_frame
	await _play_sequence()
	SignalBus.in_transition = false

func _play_sequence() -> void:
	SignalBus.in_transition = true
	EncounterTransition.visible = true
	
	#Capture the last shot
	EncounterTransition.capture_screen(EncounterTransition.overworld_shot)
	var mat := EncounterTransition.glitch_overlay.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter(
			"screen_texture",
			EncounterTransition.overworld_shot.texture
		)
		
	#EncounterTransition.reset()
	#await get_tree().process_frame
	
	await EncounterTransition.play_game_over_intro()

	var tween := create_tween()
	tween.tween_property(game_over_label, "modulate:a", 1.0, 0.8)
	tween.parallel().tween_property(prompt_label, "modulate:a", 1.0, 0.8)
	await tween.finished

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file(TITLE_SCREEN_PATH)
