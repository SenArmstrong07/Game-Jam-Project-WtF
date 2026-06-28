extends CanvasLayer

@onready var hand_container: HBoxContainer = %PlayerHandBox

@onready var selected_container: HBoxContainer = $PanelContainer/VBoxContainer/SelectedContainer

@onready var chip_name_label: Label = %ChipNameLabel
@onready var chip_description_label: Label = %ChipDescriptionLabel
@onready var chip_power_label: Label = %ChipPowerLabel
@onready var selection_count_label: Label = %SelectionCountLabel

@onready var player_hp_label: Label = $PanelContainer2/VBoxContainer/PlayerHPLabel
@onready var enemy_hp_label: Label = $PanelContainer2/VBoxContainer/EnemyHPLabel

func update_ui(
	hand: Array[Chip],
	selected: Array[Chip],
	cursor_index: int,
	max_selected: int,
	player_lives: int,
	player_max_lives: int,
	enemy_hp: int,
	enemy_max_hp: int
) -> void:

	if hand.is_empty():
		return

	cursor_index = clamp(cursor_index, 0, hand.size() - 1)

	_clear_containers()
	_build_hand(hand, cursor_index)
	_build_selected(selected)
	_update_chip_info(hand, cursor_index)

	selection_count_label.text = "Selected: %d / %d" % [
		selected.size(),
		max_selected
	]
	
	player_hp_label.text = "Lives: %d / %d" % [player_lives, player_max_lives]
	enemy_hp_label.text = "Enemy HP: %d / %d" % [enemy_hp, enemy_max_hp]

func _clear_containers():

	for child in hand_container.get_children():
		child.queue_free()

	for child in selected_container.get_children():
		child.queue_free()

func _build_hand(hand: Array[Chip], cursor_index: int):

	for i in range(hand.size()):

		var label := Label.new()

		label.text = hand[i].name

		if i == cursor_index:
			label.text = "[" + label.text + "]"

		hand_container.add_child(label)
		
func _build_selected(selected: Array[Chip]):

	for chip in selected:

		var label := Label.new()

		label.text = chip.name

		selected_container.add_child(label)

func _update_chip_info(
	hand: Array[Chip],
	cursor_index: int
):

	if hand.is_empty():
		return

	var chip = hand[cursor_index]

	chip_name_label.text = chip.name

	chip_description_label.text = chip.description

	chip_power_label.text = \
		"Power: %d | Range: %d" % [
			chip.power,
			chip.range_tile
		]
