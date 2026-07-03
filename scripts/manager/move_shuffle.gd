extends Control

@onready var _1st: TextureRect = $"VBoxContainer/SLOT/1ST"
@onready var _2nd: TextureRect = $"VBoxContainer/SLOT2/2ND"
@onready var _3rd: TextureRect = $"VBoxContainer/SLOT3/3RD"
@onready var _4th: TextureRect = $"VBoxContainer/SLOT4/4TH"
@onready var _5th: TextureRect = $"VBoxContainer/SLOT5/5TH"


@onready var slots = [
	_1st,
	_2nd,
	_3rd,
	_4th,
	_5th
]

var selected_index := 0

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
