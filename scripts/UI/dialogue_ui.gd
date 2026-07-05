extends Control

@onready var portrait: AnimatedSprite2D = $DialogueBar/CharacterPict/Portrait
@onready var rich_text_label: RichTextLabel = $DialogueBar/DialogueBar/RichTextLabel
@onready var character_name: Label = $DialogueBar/CharacterTag/CharacterName
@onready var bg_image: TextureRect = $BG_Image

const PIXEL_ART_FUTURE = preload("uid://c1gtir630iu6e")
const PIXEL_ART_HOLE = preload("uid://7ig0g7drg7o7")
const PIXEL_ART_OFFICE = preload("uid://bhxlmtksvowx6")

@onready var next_arrow = $DialogueBar/DialogueBar/NextArrow

var typing := false
var full_text := ""
var text_speed := 0.03 

# Dialogue data
var dialogue = [
	{
		"name": "Cody",
		"text": "Where are we?",
		"animation": "MC",
		"background": PIXEL_ART_FUTURE
	},
	{
		"name": "MiniBot",
		"text": "Welcome!",
		"animation": "MiniBot"
	},
	{
		"name": "Cody",
		"text": "Let's keep going.",
		"animation": "MC"
	},
	{
		"name": "MiniBot",
		"text": "We arrived.",
		"animation": "MiniBot",
		"background": PIXEL_ART_OFFICE
	}
]

var dialogue_index = 0

func _ready() -> void:
	show_dialogue()

func _input(event):
	if !(event.is_action_pressed("ui_accept") or
		(event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)):
		return

	if typing:
		typing = false
	else:
		next_dialogue()

func show_dialogue():
	if dialogue_index >= dialogue.size():
		end_dialogue()
		return

	var current = dialogue[dialogue_index]

	character_name.text = current["name"]
	portrait.play(current["animation"])

	if current.has("background"):
		bg_image.texture = current["background"]

	full_text = current["text"]
	rich_text_label.text = ""
	next_arrow.hide()

	type_text()
	
func next_dialogue():
	dialogue_index += 1
	show_dialogue()

func end_dialogue():
	hide() # or queue_free()
	print("Dialogue Finished")

func type_text() -> void:
	typing = true

	for i in range(full_text.length()):
		if !typing:
			rich_text_label.text = full_text
			break

		rich_text_label.text += full_text[i]
		await get_tree().create_timer(text_speed).timeout

	typing = false
	next_arrow.show()
