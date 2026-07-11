extends CanvasLayer

signal closed

const SETTINGS_CONFIG_PATH := "user://game_settings.cfg"

@onready var container: Control = $Container

var settings_control_scheme := "wasd"
var settings_quest_toggle_key := "M"
var settings_dash_btn := "Ctrl"
var settings_music_volume := 0.8
var settings_sfx_volume := 0.8
var show_save_data_button := true
var return_to_title_screen_on_back := true
var button_group: ButtonGroup
var final_position: Vector2 = Vector2.ZERO

# Button and UI element references (will be set in _finish_ready)
@onready var wasd_button: Button = $Container/PanelContainer/MarginContainer/VBoxContainer/PlayerControlsRow/WASDButton
@onready var arrow_button: Button = $Container/PanelContainer/MarginContainer/VBoxContainer/PlayerControlsRow/ArrowButton
@onready var ctrl_button: Button = $Container/PanelContainer/MarginContainer/VBoxContainer/DashControlsRow/CTRLButton
@onready var z_button: Button = $Container/PanelContainer/MarginContainer/VBoxContainer/DashControlsRow/ZButton
@onready var quest_toggle_button: Button = $Container/PanelContainer/MarginContainer/VBoxContainer/QuestToggleRow/QuestToggleButton
@onready var music_slider: HSlider = $Container/PanelContainer/MarginContainer/VBoxContainer/MusicVolumeRow/MusicSlider
@onready var sfx_slider: HSlider = $Container/PanelContainer/MarginContainer/VBoxContainer/SFXVolumeRow/SFXSlider
@onready var save_button: Button = $Container/PanelContainer/MarginContainer/VBoxContainer/ActionRow/SaveButton
@onready var back_button: Button = $Container/PanelContainer/MarginContainer/VBoxContainer/ActionRow/BackButton

func _ready() -> void:
	await get_tree().process_frame
	final_position = container.position
	_ensure_audio_buses()
	_load_settings_from_disk()
	# Setup buttons and connections now that scene is fully loaded
	button_group = ButtonGroup.new()
	wasd_button.toggle_mode = true
	arrow_button.toggle_mode = true
	wasd_button.button_group = button_group
	arrow_button.button_group = button_group
	
	wasd_button.pressed.connect(func() -> void: _set_control_scheme("wasd"))
	arrow_button.pressed.connect(func() -> void: _set_control_scheme("arrows"))
	quest_toggle_button.pressed.connect(_on_quest_toggle_button_pressed)
	music_slider.value_changed.connect(func(value: float) -> void: _set_bus_volume("Music", value))
	sfx_slider.value_changed.connect(func(value: float) -> void: _set_bus_volume("SFX", value))
	save_button.pressed.connect(_on_save_pressed)
	back_button.pressed.connect(_on_back_to_menu_pressed)
	_apply_view_mode()
	_apply_settings_to_ui()
	hide()
	
func _apply_view_mode() -> void:
	if save_button != null:
		save_button.visible = show_save_data_button
	
func _show_with_slide() -> void:
	await get_tree().process_frame

	show()

	# Start below the screen
	container.position = final_position
	container.position.y += get_viewport().get_visible_rect().size.y + 120

	var tween := create_tween()
	tween.tween_property(
		container,
		"position",
		final_position,
		0.35
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func toggle() -> void:
	if visible:
		_hide_with_slide()
	else:
		_show_with_slide()

func _ensure_audio_buses() -> void:
	var music_index := AudioServer.get_bus_index("Music")
	if music_index < 0:
		AudioServer.add_bus()
		music_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(music_index, "Music")

	var sfx_index := AudioServer.get_bus_index("SFX")
	if sfx_index < 0:
		AudioServer.add_bus()
		sfx_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(sfx_index, "SFX")

func _set_control_scheme(scheme: String) -> void:
	settings_control_scheme = scheme
	if scheme == "wasd":
		_apply_input_scheme("wasd")
		wasd_button.button_pressed = true
	else:
		_apply_input_scheme("arrows")
		arrow_button.button_pressed = true

func _apply_input_scheme(scheme: String) -> void:
	var key_map: Dictionary = {
		"wasd": {"left": KEY_A, "right": KEY_D, "up": KEY_W, "down": KEY_S},
		"arrows": {"left": KEY_LEFT, "right": KEY_RIGHT, "up": KEY_UP, "down": KEY_DOWN}
	}
	for action_name in ["left", "right", "up", "down"]:
		InputMap.action_erase_events(action_name)
		var event := InputEventKey.new()
		event.keycode = key_map[scheme][action_name]
		InputMap.action_add_event(action_name, event)

func _set_quest_toggle_key(key_name: String) -> void:
	settings_quest_toggle_key = key_name
	quest_toggle_button.text = "Toggle: " + key_name
	InputMap.action_erase_events("toggle_quest")
	var event := InputEventKey.new()
	if key_name == "Tab":
		event.keycode = KEY_TAB
	else:
		event.keycode = KEY_M
	InputMap.action_add_event("toggle_quest", event)

func _on_quest_toggle_button_pressed() -> void:
	if settings_quest_toggle_key == "M":
		_set_quest_toggle_key("Tab")
	else:
		_set_quest_toggle_key("M")

func _set_bus_volume(bus_name: String, value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	if value <= 0.0:
		AudioServer.set_bus_mute(bus_index, true)
	else:
		AudioServer.set_bus_mute(bus_index, false)
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
	if bus_name == "Music":
		settings_music_volume = value
	elif bus_name == "SFX":
		settings_sfx_volume = value

func _load_settings_from_disk() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_CONFIG_PATH)
	if err != OK:
		return
	settings_control_scheme = config.get_value("controls", "scheme", "wasd")
	settings_quest_toggle_key = config.get_value("controls", "quest_toggle", "M")
	settings_music_volume = config.get_value("audio", "music", 0.8)
	settings_sfx_volume = config.get_value("audio", "sfx", 0.8)

func _apply_settings_to_ui() -> void:
	if settings_control_scheme == "wasd":
		wasd_button.button_pressed = true
		_apply_input_scheme("wasd")
	else:
		arrow_button.button_pressed = true
		_apply_input_scheme("arrows")
	quest_toggle_button.text = "Toggle: " + settings_quest_toggle_key
	_set_quest_toggle_key(settings_quest_toggle_key)
	music_slider.value = settings_music_volume
	sfx_slider.value = settings_sfx_volume
	_set_bus_volume("Music", settings_music_volume)
	_set_bus_volume("SFX", settings_sfx_volume)

func _save_settings_to_disk() -> void:
	var config := ConfigFile.new()
	config.set_value("controls", "scheme", settings_control_scheme)
	config.set_value("controls", "quest_toggle", settings_quest_toggle_key)
	config.set_value("audio", "music", settings_music_volume)
	config.set_value("audio", "sfx", settings_sfx_volume)
	config.save(SETTINGS_CONFIG_PATH)
	SignalBus.save_current_game_state()

func _on_save_pressed() -> void:
	_save_settings_to_disk()
	save_button.text = "Saved!"
	await get_tree().create_timer(0.7).timeout
	save_button.text = "Save Current Data"

func _on_back_to_menu_pressed() -> void:
	_save_settings_to_disk()
	await _hide_with_slide()
	if return_to_title_screen_on_back:
		get_tree().change_scene_to_file("res://scenes/UI/TitleScreen.tscn")

func _hide_with_slide() -> void:
	var tween := create_tween()
	var offscreen_y = get_viewport().get_visible_rect().size.y + 120

	tween.tween_property(
		container,
		"position:y",
		offscreen_y,
		0.25
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await tween.finished
	emit_signal("closed")
	hide()
