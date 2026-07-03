extends Control

@onready var move_description: RichTextLabel = $DESCRIPTION_BG/MOVE_DESCRIPTION
@onready var module_name: Label = $DESCRIPTION_BG/HBoxContainer/VBoxContainer/MODULE_NAME
@onready var module_damage: Label = $DESCRIPTION_BG/HBoxContainer/VBoxContainer/MODULE_DAMAGE
@onready var module_range: Label = $DESCRIPTION_BG/HBoxContainer/VBoxContainer/MODULE_RANGE
@onready var move_icon: TextureRect = $DESCRIPTION_BG/HBoxContainer/MOVE_ICON

@onready var player_deck_slot_1: TextureRect = $MODULE_DECK/GridContainer/Player_deck_slot_1
@onready var player_deck_slot_2: TextureRect = $MODULE_DECK/GridContainer/Player_deck_slot_2
@onready var player_deck_slot_3: TextureRect = $MODULE_DECK/GridContainer/Player_deck_slot_3
@onready var player_deck_slot_4: TextureRect = $MODULE_DECK/GridContainer/Player_deck_slot_4
@onready var player_deck_slot_5: TextureRect = $MODULE_DECK/GridContainer/Player_deck_slot_5
@onready var player_deck_slot_6: TextureRect = $MODULE_DECK/GridContainer/Player_deck_slot_6
@onready var player_deck_slot_7: TextureRect = $MODULE_DECK/GridContainer/Player_deck_slot_7
@onready var player_deck_slot_8: TextureRect = $MODULE_DECK/GridContainer/Player_deck_slot_8
@onready var player_deck_slot_9: TextureRect = $MODULE_DECK/GridContainer/Player_deck_slot_9
@onready var player_deck_slot_10: TextureRect = $MODULE_DECK/GridContainer/Player_deck_slot_10

@onready var move_slot_1: TextureRect = $SELECTED_BG/CONTAINER/GridContainer/MOVE_SLOT_1
@onready var move_slot_2: TextureRect = $SELECTED_BG/CONTAINER/GridContainer/MOVE_SLOT_2
@onready var move_slot_3: TextureRect = $SELECTED_BG/CONTAINER/GridContainer/MOVE_SLOT_3
@onready var move_slot_4: TextureRect = $SELECTED_BG/CONTAINER/GridContainer/MOVE_SLOT_4
@onready var move_slot_5: TextureRect = $SELECTED_BG/CONTAINER/GridContainer/MOVE_SLOT_5

@onready var select_button: Button = $BUTTON_CONTAINERS/SELECT_BUTTON
@onready var unselect_button: Button = $BUTTON_CONTAINERS/UNSELECT_BUTTON

@onready var combine_selected_1: TextureRect = $COMBINE_BG/CASE_1/COMBINE_SELECTED_1
@onready var combine_selected_2: TextureRect = $COMBINE_BG/CASE_2/COMBINE_SELECTED_2

var deck_slots : Array[TextureRect]
var move_slots : Array[TextureRect]

func _ready():

	deck_slots = [
		player_deck_slot_1,
		player_deck_slot_2,
		player_deck_slot_3,
		player_deck_slot_4,
		player_deck_slot_5,
		player_deck_slot_6,
		player_deck_slot_7,
		player_deck_slot_8,
		player_deck_slot_9,
		player_deck_slot_10
	]

	move_slots = [
		move_slot_1,
		move_slot_2,
		move_slot_3,
		move_slot_4,
		move_slot_5
	]

func update_ui(
	player_hand:Array,
	selected_chips:Array,
	selected_index:int,
	combo_mode:bool,
	first_combo_chip,
	pending_combo
):

	# -------------------------
	# Draw Player Hand
	# -------------------------
	for i in range(deck_slots.size()):

		if i < player_hand.size():
			var chip = player_hand[i]

			deck_slots[i].texture = chip.icon
			deck_slots[i].visible = true

			# Color chips depending on combo mode
			if combo_mode:

				if chip == first_combo_chip:
					deck_slots[i].modulate = Color(0.6, 0.6, 0.6)

				elif first_combo_chip.can_combine_with(chip):
					deck_slots[i].modulate = Color(0.5, 1.0, 0.5)

				else:
					deck_slots[i].modulate = Color(0.3, 0.3, 0.3)

			else:
				deck_slots[i].modulate = Color.WHITE

			# Cursor highlight
			if i == selected_index:
				deck_slots[i].scale = Vector2(1.2, 1.2)

				move_icon.texture = chip.icon
				module_name.text = chip.name
				module_damage.text = "POWER: %d" % chip.power
				module_range.text = "RANGE: %d" % chip.range_tile
				move_description.text = chip.description
			else:
				deck_slots[i].scale = Vector2.ONE
				
			if pending_combo != null:

				move_icon.texture = pending_combo.icon
				module_name.text = pending_combo.name
				module_damage.text = "POWER: %d" % pending_combo.power
				module_range.text = "RANGE: %d" % pending_combo.range_tile
				move_description.text = pending_combo.description
		else:
			deck_slots[i].texture = null
			deck_slots[i].visible = false
			deck_slots[i].scale = Vector2.ONE
			deck_slots[i].modulate = Color.WHITE

	# -------------------------
	# Draw Selected Move Slots
	# -------------------------
	for i in range(move_slots.size()):

		if i < selected_chips.size():
			move_slots[i].texture = selected_chips[i].icon
			move_slots[i].visible = true
		else:
			move_slots[i].texture = null
			move_slots[i].visible = true
			
		update_combo_preview(
			player_hand,
			selected_index,
			combo_mode,
			first_combo_chip
		)
	
	if player_hand.is_empty():
		move_icon.texture = null
		module_name.text = ""
		module_damage.text = ""
		module_range.text = ""
		move_description.text = ""
		

			
func draw_player_hand(hand:Array[Chip], selected_index:int):

	for i in range(deck_slots.size()):

		if i < hand.size():
			deck_slots[i].texture = hand[i].icon
			deck_slots[i].visible = true

			if i == selected_index:
				deck_slots[i].modulate = Color(1,1,0) # yellow highlight
			else:
				deck_slots[i].modulate = Color.WHITE

		else:
			deck_slots[i].texture = null
			deck_slots[i].visible = false

func draw_selected_moves(selected:Array[Chip]):

	for i in range(move_slots.size()):

		if i < selected.size():
			move_slots[i].texture = selected[i].icon
		else:
			move_slots[i].texture = null
			
func update_combo_preview(
	player_hand: Array,
	selected_index: int,
	combo_mode: bool,
	first_combo_chip
) -> void:

	combine_selected_1.texture = null
	combine_selected_2.texture = null

	combine_selected_1.visible = false
	combine_selected_2.visible = false

	if !combo_mode or first_combo_chip == null:
		return

	combine_selected_1.texture = first_combo_chip.icon
	combine_selected_1.visible = true

	# Leave the second slot empty while choosing
	combine_selected_2.texture = null
	combine_selected_2.visible = true
