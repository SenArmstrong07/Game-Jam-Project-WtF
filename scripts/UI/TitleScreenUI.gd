extends Control

@onready var d_3: Label = $TEXT_CONTAINER/D3
@onready var bu: Label = $TEXT_CONTAINER/BU
@onready var gged: Label = $TEXT_CONTAINER/GGED
@onready var press_key: Label = $TEXT_CONTAINER/PRESS_KEY

@onready var menu_buttons: VBoxContainer = $Menu_Buttons
@onready var continue_button: Button = $Menu_Buttons/Continue_button
@onready var new_button: Button = $Menu_Buttons/New_button
@onready var exit_button: Button = $Menu_Buttons/Exit_button
@onready var settings_button: Button = $Menu_Buttons/Settings_Button

const OVERWORLD_SCENE_PATH := "res://scenes/overworld/CyberMap.tscn"
const SETTINGS_SCENE_PATH := "res://scenes/UI/SettingsScene.tscn"

var menu_open := false
var menu_start_pos: Vector2
var labels : Array[Label]
var settings_scene_instance: CanvasLayer

func _on_new_game_pressed():
	new_button.disabled = true
	continue_button.disabled = true
	exit_button.disabled = true

	await _transition_to_scene("res://scenes/UI/opening_dialogue.tscn")


func _on_continue_pressed() -> void:
	continue_button.disabled = true
	new_button.disabled = true
	exit_button.disabled = true

	if not SignalBus.has_saved_game_state():
		SignalBus.is_loading_saved_game = false
		_show_no_save_dialog()
		continue_button.disabled = false
		new_button.disabled = false
		exit_button.disabled = false
		return

	SignalBus.load_saved_game_state()
	SignalBus.is_loading_saved_game = true
	await _transition_to_scene(OVERWORLD_SCENE_PATH)


func _show_no_save_dialog() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "No saved game"
	dialog.dialog_text = "There are no saved states available yet."
	dialog.exclusive = true
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

func _on_settings_pressed() -> void:
	if settings_scene_instance == null:
		settings_scene_instance = load(SETTINGS_SCENE_PATH).instantiate() as CanvasLayer
		settings_scene_instance.set("show_save_data_button", false)
		settings_scene_instance.set("return_to_title_screen_on_back", false)
		add_child(settings_scene_instance)

	if settings_scene_instance.has_method("toggle"):
		settings_scene_instance.toggle()

func _transition_to_scene(target_scene_path: String) -> void:
	var fade := ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.modulate.a = 0.0

	var canvas := CanvasLayer.new()
	canvas.layer = 100
	canvas.add_child(fade)
	add_child(canvas)

	var tween = create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 0.4)
	await tween.finished

	get_tree().change_scene_to_file(target_scene_path)

	
func _ready():
	BattleBgm.stop()
	BgTitleToDial.play_music(preload("res://assets/FX/TitleScreen.ogg"))
	blink_press_key()
	menu_buttons.visible = false
	randomize()

	labels = [d_3, bu, gged]

	for l in labels:
		l.modulate = Color.WHITE
		
	menu_start_pos = menu_buttons.position
	menu_buttons.position += Vector2(0, 50)
	menu_buttons.modulate.a = 0.0
	menu_buttons.visible = false
	exit_button.pressed.connect(_on_exit_pressed)
	new_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	
	title_loop()
	
func _on_exit_pressed():
	get_tree().quit()
	
func _unhandled_input(event):

	if menu_open:
		return

	if event is InputEventKey and event.pressed:
		show_menu()

	elif event is InputEventMouseButton and event.pressed:
		show_menu()
		
func show_menu():

	menu_open = true

	# Stop blinking
	press_key.visible = false

	menu_buttons.visible = true

	var tween = create_tween()

	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)

	tween.parallel().tween_property(
		menu_buttons,
		"position",
		menu_start_pos,
		0.45
	)

	tween.parallel().tween_property(
		menu_buttons,
		"modulate:a",
		1.0,
		0.30
	)
	
func blink_press_key():

	while !menu_open:

		var tween = create_tween()

		tween.tween_property(press_key, "modulate:a", 0.25, 0.6)
		tween.tween_property(press_key, "modulate:a", 1.0, 0.6)

		await tween.finished
			
func title_loop() -> void:

	while true:

		await get_tree().create_timer(randf_range(0.8, 2.0)).timeout

		match randi() % 4:
			0:
				await cyber_glitch()

			1:
				await power_flash()

			2:
				await cyan_pulse()
			
			3:
				await electric_surge()

			4:
				await cyber_glitch()
				await electric_surge()
				await get_tree().create_timer(0.08).timeout
				await power_flash()
				


func cyber_glitch():

	var l = labels.pick_random()

	l.modulate = Color(0.2, 1.7, 2.5)

	await get_tree().create_timer(0.04).timeout

	l.modulate = Color.WHITE

	await get_tree().create_timer(0.02).timeout

	l.modulate = Color(1.5, 1.5, 1.5)

	await get_tree().create_timer(0.03).timeout

	l.modulate = Color.WHITE


func power_flash():

	for l in labels:
		l.modulate = Color(2.2, 2.2, 2.2)

	await get_tree().create_timer(0.05).timeout

	for l in labels:
		l.modulate = Color.WHITE


func cyan_pulse():

	for l in labels:
		l.modulate = Color(0.6, 2.0, 2.5)

	var tween = create_tween()

	for l in labels:
		tween.parallel().tween_property(
			l,
			"modulate",
			Color.WHITE,
			0.25
		)

	await tween.finished

func electric_surge():

	var colors = [
		Color.WHITE,
		Color(0.4, 1.7, 3.0),
		Color(0.8, 2.2, 3.5)
	]

	for i in range(8):

		var c = colors.pick_random()

		for l in labels:
			l.modulate = c

		await get_tree().create_timer(randf_range(0.015, 0.04)).timeout

	for l in labels:
		l.modulate = Color(2.8, 2.8, 2.8)

	await get_tree().create_timer(0.04).timeout

	for l in labels:
		l.modulate = Color.WHITE
