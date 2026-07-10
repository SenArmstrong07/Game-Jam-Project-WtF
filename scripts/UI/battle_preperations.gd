extends Control

#ELEMENTS DESIGNS
@onready var multiclor_wire: NinePatchRect = $MULTICLOR_WIRE
@onready var red_wire_decor: NinePatchRect = $RED_WIRE_DECOR
@onready var wire_decor: NinePatchRect = $WIRE_DECOR
@onready var bg_screen: NinePatchRect = $BG_SCREEN
@onready var blue_wire_decor: NinePatchRect = $BLUE_WIRE_DECOR
@onready var button_bg: NinePatchRect = $BUTTON_BG
@onready var blue_wire_2: NinePatchRect = $BLUE_WIRE_2

@onready var combine_title: NinePatchRect = $COMBINE_TITLE
@onready var combine_bg: NinePatchRect = $COMBINE_BG
@onready var battle_preperations: Control = $"."
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

@onready var move_slot_1: TextureRect = $SIDE_CONTAINER/NinePatchRect/VBoxContainer/NinePatchRect/MOVE_SLOT_1
@onready var move_slot_2: TextureRect = $SIDE_CONTAINER/NinePatchRect/VBoxContainer/NinePatchRect2/MOVE_SLOT_2
@onready var move_slot_3: TextureRect = $SIDE_CONTAINER/NinePatchRect/VBoxContainer/NinePatchRect3/MOVE_SLOT_3
@onready var move_slot_4: TextureRect = $SIDE_CONTAINER/NinePatchRect/VBoxContainer/NinePatchRect4/MOVE_SLOT_4
@onready var move_slot_5: TextureRect = $SIDE_CONTAINER/NinePatchRect/VBoxContainer/NinePatchRect5/MOVE_SLOT_5


@onready var select_button: Button = $BUTTON_CONTAINERS/SELECT_BUTTON
@onready var unselect_button: Button = $BUTTON_CONTAINERS/UNSELECT_BUTTON

@onready var combine_selected_1: TextureRect = $COMBINE_BG/CASE_1/COMBINE_SELECTED_1
@onready var combine_selected_2: TextureRect = $COMBINE_BG/CASE_2/COMBINE_SELECTED_2

var deck_slots : Array[TextureRect]
var move_slots : Array[TextureRect]
var cursor: Panel
var previous_selected_count := 0

@onready var module_deck = $MODULE_DECK
@onready var description_bg = $DESCRIPTION_BG
@onready var side_container = $SIDE_CONTAINER
@onready var button_container = $BUTTON_CONTAINERS
@onready var combo_bg = $COMBINE_BG

@onready var move_panel: NinePatchRect = $SIDE_CONTAINER/NinePatchRect
var move_panel_start_pos: Vector2
var last_displayed_chip = null
var description_flash_tween: Tween

func _ready():
	
	move_panel_start_pos = move_panel.position
	for slot in move_slots:
		slot.flip_v = true
		
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
	
	cursor = Panel.new()

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0) # transparent center
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = Color(1, 1, 0) # yellow

	cursor.add_theme_stylebox_override("panel", style)

	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor.visible = false
	cursor.z_index = 100

	$MODULE_DECK.add_child(cursor)

func update_ui(
	player_hand: Array,
	selected_chips: Array,
	selected_index: int,
	combo_mode: bool,
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

			# Combo colors
			if combo_mode:

				if chip == first_combo_chip:
					deck_slots[i].modulate = Color(0.6, 0.6, 0.6)

				elif first_combo_chip.can_combine_with(chip):
					deck_slots[i].modulate = Color(0.5, 1.0, 0.5)

				else:
					deck_slots[i].modulate = Color(0.3, 0.3, 0.3)

			else:
				deck_slots[i].modulate = Color.WHITE

			# Remove scaling (cursor frame will indicate selection)
			deck_slots[i].scale = Vector2.ONE

			# Selected slot
			var cursor_index: int = clampi(selected_index, 0, max(player_hand.size() - 1, 0))
			if i == cursor_index:

				# Move the cursor frame over this slot
				cursor.visible = true
				cursor.position = deck_slots[i].get_global_rect().position - cursor.get_parent().global_position
				cursor.size = deck_slots[i].size

				if last_displayed_chip != chip:
					last_displayed_chip = chip
					flash_description()

				move_icon.texture = chip.icon
				module_name.text = chip.name
				module_damage.text = "POWER: %d" % chip.power
				module_range.text = "RANGE: %d" % chip.range_tile
				move_description.text = chip.description

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

	# Hide cursor if hand is empty
	if player_hand.is_empty():
		cursor.visible = false

		move_icon.texture = null
		module_name.text = ""
		module_damage.text = ""
		module_range.text = ""
		move_description.text = ""

	# -------------------------
	# Draw Selected Move Slots
	# -------------------------
	for i in range(move_slots.size()):

		if i < selected_chips.size():
			move_slots[i].texture = selected_chips[i].icon
			move_slots[i].visible = true

			# Animate only the newly filled slot
			if selected_chips.size() > previous_selected_count \
			and i == selected_chips.size() - 1:
				animate_move_slot(move_slots[i])

		else:
			move_slots[i].texture = null
			move_slots[i].visible = true

	update_combo_preview(
		player_hand,
		selected_index,
		combo_mode,
		first_combo_chip
	)
	
	previous_selected_count = selected_chips.size()

func flash_description() -> void:
	if description_flash_tween:
		description_flash_tween.kill()

	var original_pos = description_bg.position
	var original_size = description_bg.size
	var target_scale = Vector2(1.03, 1.03)

	# Offset so scaling happens around the center
	var offset = (original_size * (target_scale - Vector2.ONE)) * 0.5

	description_bg.scale = target_scale
	description_bg.position = original_pos - offset
	description_bg.modulate = Color(1.35, 1.35, 1.35, 1.0)

	description_flash_tween = create_tween()
	description_flash_tween.set_parallel(true)

	description_flash_tween.tween_property(
		description_bg,
		"scale",
		Vector2.ONE,
		0.15
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	description_flash_tween.tween_property(
		description_bg,
		"position",
		original_pos,
		0.15
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	description_flash_tween.tween_property(
		description_bg,
		"modulate",
		Color.WHITE,
		0.15
	)
				
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

func animate_move_slot(slot: TextureRect):

	var panel := slot.get_parent() as Control

	var original_pos := panel.position

	# Slam animation on the icon
	slot.scale = Vector2(2.2, 2.2)
	slot.rotation_degrees = -8
	slot.modulate = Color(2.5, 2.5, 2.5)

	var tween = create_tween()

	tween.set_trans(Tween.TRANS_EXPO)
	tween.set_ease(Tween.EASE_OUT)

	tween.parallel().tween_property(slot, "scale", Vector2(0.62, 1.0), 0.05)
	tween.parallel().tween_property(slot, "rotation_degrees", 1.0, 0.05)
	tween.parallel().tween_property(slot, "modulate", Color.WHITE, 0.05)

	tween.tween_property(slot, "scale", Vector2(0.85, 0.92), 0.05)
	tween.parallel().tween_property(slot, "rotation_degrees", -1.0, 0.05)

	tween.tween_property(slot, "scale", Vector2.ONE, 0.06)
	tween.parallel().tween_property(slot, "rotation_degrees", 0.0, 0.06)

	# Shake only this NinePatchRect
	tween.tween_property(panel, "position", original_pos + Vector2(-5, 0), 0.02)
	tween.tween_property(panel, "position", original_pos + Vector2(5, 0), 0.02)
	tween.tween_property(panel, "position", original_pos + Vector2(-3, 0), 0.02)
	tween.tween_property(panel, "position", original_pos + Vector2(3, 0), 0.02)
	tween.tween_property(panel, "position", original_pos, 0.02)
	
func shake_move_panel():

	move_panel.position = move_panel_start_pos

	var tween = create_tween()

	tween.tween_property(move_panel, "position",
		move_panel_start_pos + Vector2(-5, 0), 0.02)

	tween.tween_property(move_panel, "position",
		move_panel_start_pos + Vector2(5, 0), 0.02)

	tween.tween_property(move_panel, "position",
		move_panel_start_pos + Vector2(-3, 0), 0.02)

	tween.tween_property(move_panel, "position",
		move_panel_start_pos + Vector2(3, 0), 0.02)

	tween.tween_property(move_panel, "position",
		move_panel_start_pos, 0.02)
		
	await tween.finished
	
func play_intro():

	modulate.a = 0
	cursor.visible = false

	# Save original positions
	var deck_pos = module_deck.position
	var desc_pos = description_bg.position
	var side_pos = side_container.position
	var button_bg_pos = button_bg.position
	var button_container_pos = button_container.position
	var combine_title_pos = combine_title.position
	var combine_bg_pos = combine_bg.position

	# Move offscreen
	module_deck.position.x -= 500
	description_bg.position.y -= 220
	side_container.position.x += 320

	button_bg.position.y += 180
	button_container.position.y += 180

	combine_title.position.y += 180
	combine_bg.position.y += 180

	# Hide everything
	module_deck.visible = false
	description_bg.visible = false
	side_container.visible = false
	button_bg.visible = false
	button_container.visible = false
	combine_title.visible = false
	combine_bg.visible = false

	create_tween().tween_property(self, "modulate:a", 1.0, 0.12)

	# Deck
	await animate_module_deck(deck_pos)

	await get_tree().create_timer(0.02).timeout

	# Description
	await heavy_drop(description_bg, desc_pos)

	await get_tree().create_timer(0.02).timeout

	# Side panel
	await heavy_drop(side_container, side_pos)

	await get_tree().create_timer(0.02).timeout

	# Buttons together
	button_bg.visible = true
	button_container.visible = true

	heavy_drop(button_bg, button_bg_pos)
	heavy_drop(button_container, button_container_pos)

	await get_tree().create_timer(0.22).timeout

	# Combine UI together
	combine_title.visible = true
	combine_bg.visible = true

	heavy_drop(combine_title, combine_title_pos)
	heavy_drop(combine_bg, combine_bg_pos)

	await get_tree().create_timer(0.22).timeout

	# Cursor
	cursor.visible = true
	cursor.scale = Vector2(1.35, 1.35)

	create_tween()\
		.tween_property(cursor, "scale", Vector2.ONE, 0.12)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

func animate_module_deck(target: Vector2) -> void:

	module_deck.visible = true

	var t = create_tween()

	t.set_trans(Tween.TRANS_EXPO)
	t.set_ease(Tween.EASE_OUT)

	t.tween_property(
		module_deck,
		"position",
		target + Vector2(-8, 0),
		0.18
	)

	t.tween_property(
		module_deck,
		"position",
		target + Vector2(3, 0),
		0.05
	)

	t.tween_property(
		module_deck,
		"position",
		target,
		0.03
	)

	await t.finished

	heavy_shake(module_deck)
		
func heavy_drop(panel: Control, target: Vector2) -> void:

	panel.visible = true

	var t = create_tween()

	t.set_trans(Tween.TRANS_EXPO)
	t.set_ease(Tween.EASE_OUT)

	t.tween_property(
		panel,
		"position",
		target + Vector2(0, 6),
		0.20
	)

	t.tween_property(
		panel,
		"position",
		target - Vector2(0, 2),
		0.04
	)

	t.tween_property(
		panel,
		"position",
		target,
		0.03
	)

	await t.finished

	heavy_shake(panel)
	
func heavy_shake(panel: Control) -> void:

	var p = panel.position

	var t = create_tween()

	t.tween_property(panel, "position", p + Vector2(-3, 0), 0.012)
	t.tween_property(panel, "position", p + Vector2(2, 0), 0.012)
	t.tween_property(panel, "position", p + Vector2(-1, 0), 0.012)
	t.tween_property(panel, "position", p, 0.018)
