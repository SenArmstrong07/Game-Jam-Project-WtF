extends Control

@onready var d_3: Label = $TEXT_CONTAINER/D3
@onready var bu: Label = $TEXT_CONTAINER/BU
@onready var gged: Label = $TEXT_CONTAINER/GGED
@onready var press_key: Label = $TEXT_CONTAINER/PRESS_KEY

@onready var menu_buttons: VBoxContainer = $Menu_Buttons
@onready var continue_button: Button = $Menu_Buttons/Continue_button
@onready var new_button: Button = $Menu_Buttons/New_button
@onready var exit_button: Button = $Menu_Buttons/Exit_button

var menu_open := false
var menu_start_pos: Vector2
var labels : Array[Label]

func _on_new_game_pressed():
	new_button.disabled = true
	continue_button.disabled = true
	exit_button.disabled = true

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

	get_tree().change_scene_to_file("res://scenes/UI/opening_dialogue.tscn")

	
func _ready():
	
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
