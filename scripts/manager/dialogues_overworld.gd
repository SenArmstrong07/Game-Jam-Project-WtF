extends CanvasLayer

signal tutorial_closed

@onready var dialogue_bar_text_container: NinePatchRect = $DialogueBar/DialogueBar
@onready var dialogue_bar: Control = $DialogueBar

@onready var mc: AnimatedSprite2D = $DialogueBar/CharacterPict/Control/mc
@onready var minibot: AnimatedSprite2D = $DialogueBar/CharacterPict/Control/minibot

@onready var rich_text_label: RichTextLabel = $DialogueBar/DialogueBar/RichTextLabel
@onready var next_arrow: TextureRect = $DialogueBar/DialogueBar/NextArrow
@onready var character_name: Label = $DialogueBar/CharacterTag/CharacterName

const TYPE_SPEED := 0.025

var dialogue_bar_start_scale: Vector2
var waiting := false
var typing := false


func _ready() -> void:
	dialogue_bar_start_scale = dialogue_bar_text_container.scale

	# Make scaling happen around the center
	dialogue_bar_text_container.pivot_offset = dialogue_bar_text_container.size / 2.0

	dialogue_bar.hide()
	next_arrow.hide()

	mc.hide()
	minibot.hide()


func show_tutorial(name: String, portrait_anim: String, message: String) -> void:
	dialogue_bar.show()

	character_name.text = name

	# Hide both portraits
	mc.hide()
	minibot.hide()

	# Stop previous animations
	mc.stop()
	minibot.stop()

	# Show the correct portrait
	match portrait_anim:
		"MC":
			mc.show()
			mc.play("mc")

		"MiniBot":
			minibot.show()
			minibot.play("minibot")

	rich_text_label.text = message
	rich_text_label.visible_characters = 0

	next_arrow.hide()

	waiting = true
	typing = true

	await _play_open_animation()
	_type_text()


func _type_text() -> void:
	while rich_text_label.visible_characters < rich_text_label.get_total_character_count():

		rich_text_label.visible_characters += 1

		await get_tree().create_timer(TYPE_SPEED).timeout

		if !typing:
			break

	rich_text_label.visible_characters = rich_text_label.get_total_character_count()

	typing = false
	next_arrow.show()


func _play_open_animation() -> void:
	dialogue_bar_text_container.scale = Vector2(
		dialogue_bar_start_scale.x,
		0.0
	)

	dialogue_bar_text_container.modulate.a = 1.0

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		dialogue_bar_text_container,
		"scale",
		dialogue_bar_start_scale,
		0.22
	)

	await tween.finished


func _play_close_animation() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN)

	tween.tween_property(
		dialogue_bar_text_container,
		"scale",
		Vector2(dialogue_bar_start_scale.x, 0.0),
		0.18
	)

	await tween.finished

	dialogue_bar_text_container.scale = dialogue_bar_start_scale


func _unhandled_input(event: InputEvent) -> void:
	if !waiting:
		return

	if event.is_action_pressed("ui_accept") \
	or (event is InputEventMouseButton \
	and event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT):

		# First click: finish typing
		if typing:
			typing = false
			rich_text_label.visible_characters = rich_text_label.get_total_character_count()
			next_arrow.show()
			return

		# Second click: close
		waiting = false

		await _play_close_animation()

		dialogue_bar.hide()

		mc.hide()
		minibot.hide()

		mc.stop()
		minibot.stop()

		tutorial_closed.emit()
