extends CanvasLayer

signal tutorial_closed
@onready var dialogue_bar_text_container: NinePatchRect = $DialogueBar/DialogueBar
@onready var dialogue_bar: Control = $DialogueBar
@onready var portrait: AnimatedSprite2D = $DialogueBar/CharacterPict/Portrait
@onready var rich_text_label: RichTextLabel = $DialogueBar/DialogueBar/RichTextLabel
@onready var next_arrow: TextureRect = $DialogueBar/DialogueBar/NextArrow
@onready var character_name: Label = $DialogueBar/CharacterTag/CharacterName

const TYPE_SPEED := 0.025 # seconds per character
var dialogue_bar_start_position: Vector2
var dialogue_bar_start_scale: Vector2
var waiting := false
var typing := false

func _ready():
	dialogue_bar_start_position = dialogue_bar.position
	dialogue_bar_start_scale = dialogue_bar.scale
	
	#Make scaling happen around the center
	dialogue_bar.pivot_offset = dialogue_bar.size / 2.0
	
	dialogue_bar.hide()
	next_arrow.hide()

func show_tutorial(name: String, portrait_anim: String, message: String):

	dialogue_bar.show()

	character_name.text = name
	portrait.play(portrait_anim)

	rich_text_label.text = message
	rich_text_label.visible_characters = 0

	next_arrow.show()

	waiting = true
	typing = true
	await _play_open_animation()
	_type_text()

#ANIMATE TYPING TEXT:
func _type_text() -> void:
	while rich_text_label.visible_characters < rich_text_label.get_total_character_count():

		rich_text_label.visible_characters += 1

		await get_tree().create_timer(TYPE_SPEED).timeout

		if !typing:
			break

	rich_text_label.visible_characters = rich_text_label.get_total_character_count()

	typing = false
	next_arrow.show()

#OPENING ANIMATION
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

#CLOSING ANIMATION
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
	
func _unhandled_input(event):

	if !waiting:
		return

	if event.is_action_pressed("ui_accept") \
	or (event is InputEventMouseButton \
	and event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT):
		
		#First Click: finish typing the line
		if typing:
			typing = false
			rich_text_label.visible_characters = rich_text_label.get_total_character_count()
			next_arrow.show()
			return
		#Second Click: continue dialogue
		waiting = false
		
		await _play_close_animation()
		dialogue_bar.hide()
		tutorial_closed.emit()
