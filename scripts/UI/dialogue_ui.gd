extends Control

@onready var portrait: AnimatedSprite2D = $DialogueBar/CharacterPict/Portrait
@onready var rich_text_label: RichTextLabel = $DialogueBar/DialogueBar/RichTextLabel
@onready var character_name: Label = $DialogueBar/CharacterTag/CharacterName
@onready var bg_image: TextureRect = $BG_Image

const PIXEL_ART_FUTURE = preload("uid://c1gtir630iu6e")
const PIXEL_ART_HOLE = preload("uid://7ig0g7drg7o7")
const PIXEL_ART_OFFICE = preload("uid://bhxlmtksvowx6")
const PIXEL_ART_DESAMPLE = preload("uid://br1lxtg6bfeqa")

@onready var next_arrow = $DialogueBar/DialogueBar/NextArrow
@onready var transition_rect: ColorRect = $"../Transition/Transition_rect"
@onready var transition_label: Label = $"../Transition/Transition_rect/Transition_label"
@onready var vortex: ColorRect = $"../Transition/Transition_rect"

@export var fade_time := 1.0
@export var hold_time := 2.0
var typing := false
var full_text := ""
var text_speed := 0.03 
var transition_finished := false

# Dialogue data
var dialogue = [
		{
			"name": "Cody",
			"text": "Hey! I'm Cody. I recently graduated with a degree in IT, and today is my very first day working at an IT company.",
			"animation": "MC",
			"background": PIXEL_ART_FUTURE
		},

		{
			"name": "Cody",
			"text": "They are called D3BUGGED, The company claims they've developed a new and much faster way to deal with computer bugs and viruses.",
			"animation": "MC"
		},

		{
			"name": "Cody",
			"text": "But... they also mentioned there are potential 'physical risks' involved. That's... kind of weird.",
			"animation": "MC"
		},
		{
			"name": "Cody",
			"text": "Oh! I think im already here.",
			"animation": "MC"
		},
		{
			"name": "Cody",
			"text": "Excuse me! Im here for my internship",
			"animation": "MC",
			"background": PIXEL_ART_OFFICE
		},
		{
			"name": "MiniBot",
			"text": "Welcome!",
			"animation": "MiniBot"
		},
		{
			"name": "Cody",
			"text": "Whoa! (A Robot of this model, this company must be top class im lucky!)",
			"animation": "MC"
		},
		{
			"name": "MiniBot",
			"text": "No need to be surprise Cody Bogues, We are expecting you!",
			"animation": "MiniBot"
		},
		{
			"name": "Cody",
			"text": "(Yeesh! They even know my name... That's kinda scary.)",
			"animation": "MC"
		},
		{
			"name": "MiniBot",
			"text": "Let us not waste time Mr. Bogues, I will be taking you to the Downsampling Area",
			"animation": "MiniBot"
		},
		{
			"name": "Cody",
			"text": "Uh... But im suppose to work on IT Department here.",
			"animation": "MC"
		},
		{
			"name": "MiniBot",
			"text": ". . . .",
			"animation": "MiniBot"
		},	
		{
			"name": "MiniBot",
			"text": "Follow me this way please!",
			"animation": "MiniBot"
		}
		,{
			"name": "Cody",
			"text": "Okay. . .",
			"animation": "MC"
		},
		{
			"name": "Cody",
			"text": "Like I said earlier im working for the IT department I think you are making a mistake.",
			"animation": "MC"
		},
		{
			"name": "MiniBot",
			"text": "Analyzing. . . . . .",
			"animation": "MiniBot"
		},
		{
			"name": "MiniBot",
			"text": "Based on my analysis. Mistake is something my model does not do",
			"animation": "MiniBot"
		},
		{
			"name": "MiniBot",
			"text": "You can now stand on the Downsampling pad!",
			"animation": "MiniBot",
			"background": PIXEL_ART_DESAMPLE
		},
		{
			"name": "Cody",
			"text": "Oh no, What should I do?!",
			"animation": "MC"
		},
		{
			"name": "Cody",
			"text": "(Should I make a run for it? This place is scary, I think I should just go)",
			"animation": "MC"
		},
		{
			"name": "Cody",
			"text": "Um, Actually im in the wrong building I just remember. Tee hee!",
			"animation": "MC"
		},
		{
			"name": "MiniBot",
			"text": "Sure you are :) (Click!)",
			"animation": "MiniBot"
		},
		{
			"name": "Cody",
			"text": "Um, Whats Th-",
			"animation": "MC"
		},
		{
			"name": "Cody",
			"text": "Ahhhhhhhhhh!!!",
			"animation": "MC",
			"background": PIXEL_ART_HOLE
		},
]

var dialogue_index = 0

func _ready() -> void:
	BattleBgm.stop()
	BgTitleToDial.play_music(preload("res://assets/FX/TitleScreen.ogg"))
	show_dialogue()   # Set the correct name, portrait, background, etc.
	await play_intro_transition("IN THE FUTURE\nFAR FROM NOW...")
	transition_finished = true
	
func play_intro_transition(message: String) -> void:
	transition_label.text = message

	# Start completely black
	transition_rect.modulate.a = 1.0
	transition_label.modulate.a = 1.0

	# Hold the message
	await get_tree().create_timer(hold_time).timeout

	# Fade away
	var tween = create_tween()
	tween.parallel().tween_property(transition_rect, "modulate:a", 0.0, fade_time)
	tween.parallel().tween_property(transition_label, "modulate:a", 0.0, fade_time)

	await tween.finished

	$"../Transition".visible = false

func _input(event):
	if !transition_finished:
		return
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
	await play_end_transition()
	get_tree().change_scene_to_file("res://scenes/battle/BattleTutorial.tscn")

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


func play_end_transition():

	$"../Transition".visible = true

	var transition = $"../Transition"

	# Remove old blocks if any
	for c in transition.get_children():
		c.queue_free()

	var screen = get_viewport_rect().size

	const COLS = 12
	const ROWS = 8

	var block_w = screen.x / COLS
	var block_h = screen.y / ROWS

	var tween = create_tween()
	tween.set_parallel(true)

	for y in ROWS:
		for x in COLS:

			var rect = ColorRect.new()
			rect.color = Color.BLACK
			rect.size = Vector2(block_w + 2, block_h + 2)

			var final_pos = Vector2(
				x * block_w,
				y * block_h
			)

			# Alternate direction
			if (x + y) % 2 == 0:
				rect.position = final_pos + Vector2(0, -screen.y)
			else:
				rect.position = final_pos + Vector2(0, screen.y)

			transition.add_child(rect)

			tween.parallel().tween_property(
				rect,
				"position",
				final_pos,
				0.35
			).set_delay((x + y) * 0.015)

	await tween.finished
