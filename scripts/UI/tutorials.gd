extends CanvasLayer

signal tutorial_closed

@onready var dialogue_bar: Control = $DialogueBar
@onready var minibot: AnimatedSprite2D = $DialogueBar/CharacterPict/Control/minibot
@onready var mc: AnimatedSprite2D = $DialogueBar/CharacterPict/Control/mc
@onready var rich_text_label: RichTextLabel = $DialogueBar/DialogueBar/RichTextLabel
@onready var next_arrow: TextureRect = $DialogueBar/DialogueBar/NextArrow
@onready var character_name: Label = $DialogueBar/CharacterTag/CharacterName

var waiting := false

func _ready() -> void:
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

	# Stop both animations
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

	next_arrow.show()

	waiting = true


func _unhandled_input(event: InputEvent) -> void:

	if !waiting:
		return

	if event.is_action_pressed("ui_accept") \
	or (event is InputEventMouseButton \
	and event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT):

		waiting = false

		dialogue_bar.hide()

		mc.hide()
		minibot.hide()
		minibot.stop()

		tutorial_closed.emit()
