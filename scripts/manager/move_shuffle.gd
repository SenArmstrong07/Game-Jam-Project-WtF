extends Control

@onready var _1st: TextureRect = $"VBoxContainer/SLOT/1ST"
@onready var _2nd: TextureRect = $"VBoxContainer/SLOT2/2ND"
@onready var _3rd: TextureRect = $"VBoxContainer/SLOT3/3RD"
@onready var _4th: TextureRect = $"VBoxContainer/SLOT4/4TH"
@onready var _5th: TextureRect = $"VBoxContainer/SLOT5/5TH"


@export var slide_distance := 80.0
@export var slide_time := 0.35

var start_position: Vector2
var hidden_pos: Vector2
var shown_pos: Vector2

@onready var slots = [
	_1st,
	_2nd,
	_3rd,
	_4th,
	_5th
]

var selected_index := 0

func _ready():
	await get_tree().process_frame

	print("READY:", position)

	shown_pos = position
	hidden_pos = shown_pos + Vector2(size.x + 40, 0)

	position = hidden_pos
	visible = false
	
func show_chip_bar():

	visible = true

	position = shown_pos + Vector2(slide_distance, 0)
	modulate.a = 0.0

	var tween = create_tween()
	tween.set_parallel()

	tween.tween_property(self, "position", shown_pos, slide_time)
	tween.tween_property(self, "modulate:a", 1.0, slide_time)
	
func update_chip_display(chips: Array, selected_index: int):

	for i in range(slots.size()):

		if i >= chips.size():
			slots[i].texture = null
			slots[i].modulate = Color(1, 1, 1, 0) # fully invisible
			continue

		slots[i].texture = chips[i].icon

		if i == selected_index:
			slots[i].modulate = Color(1, 1, 1, 1) # selected = bright
		else:
			slots[i].modulate = Color(0.6, 0.6, 0.6, 1) # unselected = dim	

func hide_chip_bar():

	var tween = create_tween()
	tween.set_parallel()

	tween.tween_property(
		self,
		"position",
		shown_pos + Vector2(slide_distance, 0),
		0.25
	)

	tween.tween_property(
		self,
		"modulate:a",
		0.0,
		0.25
	)

	await tween.finished
	visible = false
	
func hide_bar():

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN)

	tween.tween_property(
		self,
		"position",
		hidden_pos,
		0.25
	)

	await tween.finished

	visible = false
	
func show_bar():
	print("SHOW:", shown_pos)
	visible = true

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		self,
		"position",
		shown_pos,
		0.35
	)
