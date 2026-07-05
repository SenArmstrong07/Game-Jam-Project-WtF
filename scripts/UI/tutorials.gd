extends CanvasLayer

signal tutorial_closed

@onready var dialogue_bar: Control = $DialogueBar
@onready var portrait: AnimatedSprite2D = $DialogueBar/CharacterPict/Portrait
@onready var rich_text_label: RichTextLabel = $DialogueBar/DialogueBar/RichTextLabel
@onready var next_arrow: TextureRect = $DialogueBar/DialogueBar/NextArrow
@onready var character_name: Label = $DialogueBar/CharacterTag/CharacterName

var waiting := false

func _ready():
	dialogue_bar.hide()
	next_arrow.hide()

func show_tutorial(name: String, portrait_anim: String, message: String):

	dialogue_bar.show()

	character_name.text = name
	portrait.play(portrait_anim)

	rich_text_label.text = message

	next_arrow.show()

	waiting = true

func _unhandled_input(event):

	if !waiting:
		return

	if event.is_action_pressed("ui_accept") \
	or (event is InputEventMouseButton \
	and event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT):

		waiting = false

		dialogue_bar.hide()

		tutorial_closed.emit()
