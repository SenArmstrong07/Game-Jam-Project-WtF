extends BattleBase
class_name Battlescene

@onready var ui: CanvasLayer = $PLAYER_HP_BATTLE_UI
@onready var player_muzzle: Marker2D =  $PlayerCharacter/PlayerMarker
@onready var victory_overlay: Control = $VictoryOverlay

const QUARANTINE_PROJECTILE = preload("uid://ca4tyfdtbm2xw")
const PATCH_PROJECTILE = preload("uid://sv6571ybegto")
const DELETE_PROJECTILE = preload("uid://cxcsd36elkqlv")
const FIREWALL = preload("uid://x8y5dkw5aur6")
const REFORMAT_PROJECTILE = preload("uid://b6jh3cqvs8aej")
const COMMON_BUG_SCENE_PATH = "res://scenes/units/CommonBug.tscn"



@onready var grid = $Grid
@onready var player: Unit = $PlayerCharacter
var enemies: Array[Unit] = []
@export var max_selected_chips := 5
var battle_scene: BattleBase
# PLAYER ONLY uses chips now
var player_deck: ChipDeck
var player_hand: Array[Chip] = []

var selected_chips: Array[Chip] = []

var current_chip_index := 0
var player_chip_index: int = 0
var turn_locked := false
var battle_active: bool = false
var combo_database := ChipComboDatabase.new()
var combo_mode := false
var first_combo_chip: Chip = null
var second_combo_chip: Chip = null
var pending_combo: Chip = null
const DECK_COLUMNS := 5
var encounter: EncounterData

signal phase_changed(new_phase: BattlePhase)
signal player_chip_selected(chip: Chip)

signal battle_ended(winner: Unit)
var player_attack_locked := false
@export var player_attack_delay := 0.4

var selecting_buttons := false
@onready var player_ui = $PLAYER_HP_BATTLE_UI/PLAYER_LIVES
@onready var battle_preperations =  $PLAYER_HP_BATTLE_UI/BATTLE_PREPERATIONS
@onready var move_shuffle = $PLAYER_HP_BATTLE_UI/MOVE_SHUFFLE

#put new vector to add enemy
var enemy_spawn_positions := [
	Vector2i(1, 2),
	Vector2i(2, 1)
]

func _ready() -> void:
	victory_overlay.visible = false
	SignalBus.victory_continue.connect(_on_victory_continue)
	BgTitleToDial.stop()
	BattleBgm.play_music(preload("res://assets/FX/BattleBGMTest.mp3"))
	battle_preperations.visible = false
	battle_scene = find_battle_scene()
	player_deck = ChipDeck.new()
	update_player_ui()
	player.unit_died.connect(_on_unit_died)

	# IMPORTANT: store enemies properly
	enemies.clear()

	# Fetch the encounter data fresh from SignalBus (not cached at class load time)
	encounter = SignalBus.current_encounter

	if encounter != null:
		for i in range(encounter.enemy_count):
			if i < enemy_spawn_positions.size():
				spawn_enemy(enemy_spawn_positions[i])
	else:
		# Running the battle scene directly for testing
		#For testing: Spawning 2 enemies by default
		for pos in enemy_spawn_positions:
			spawn_enemy(pos)
	
	battle_preperations.select_button.pressed.connect(_on_select_pressed)
	battle_preperations.unselect_button.pressed.connect(_on_unselect_pressed)
	#NOTE KAY BIG BEN:
	#I'm currently in the process of tidying up yung transition from
	#overworld to battle scene on an encounter.
	#kung gusto mo magtest ng battle scene w/o overworld...
	#iunhighlight mo nalang yung first for loop dito
	
	#Test with overworld: 
	#How we spawn enemies based on encounter:
	#for i in encounter.enemy_count:
		#spawn_enemy(enemy_spawn_positions[i])
	#print("BattleScene READY FINISHED")
	await get_tree().process_frame
	_start_preparation_phase()

func _on_select_pressed():

	selecting_buttons = false
	_start_battle_phase()


func _on_unselect_pressed():

	selecting_buttons = false

	if !selected_chips.is_empty():
		var chip = selected_chips.pop_back()
		player_hand.append(chip)
		player_chip_index = player_hand.size() - 1

	# Remove keyboard focus from the buttons
	battle_preperations.select_button.release_focus()
	battle_preperations.unselect_button.release_focus()

	_update_ui()
	
func find_battle_scene() -> BattleBase:
	var node = self

	while node:
		if node is BattleBase:
			return node

		node = node.get_parent()

	return null

func _process(delta: float) -> void:

	match current_phase:
		BattlePhase.PREPARATION:
			_handle_preparation_input()
		BattlePhase.BATTLE:
			if battle_active:
				_handle_battle_input()
				
func is_tile_free(tile: Vector2i) -> bool:
	return not occupied_tiles.has(tile)
	


# ============================================================
# PREPARATION PHASE
# ============================================================
func _update_ui():

	if battle_preperations == null:
		return

	battle_preperations.visible = current_phase == BattlePhase.PREPARATION

	if current_phase != BattlePhase.PREPARATION:
		return

	battle_preperations.update_ui(
		player_hand,
		selected_chips,
		player_chip_index,
		combo_mode,
		first_combo_chip,
		pending_combo
	)

func update_player_ui():
	print("Updating player UI")

	if player_ui == null:
		print("player_ui is null")
		return

	player_ui.update_player_lives(
		player.get_lives()
	)
	
func spawn_enemy(pos: Vector2i) -> void:
	while is_enemy_on_tile(pos):
		pos.x += 1

	# Load the scene fresh to avoid cache issues
	var enemy_scene = load(COMMON_BUG_SCENE_PATH)
	if enemy_scene == null:
		push_error("Failed to load CommonBug scene from ", COMMON_BUG_SCENE_PATH)
		return

	var e: Unit = enemy_scene.instantiate()
	if e == null:
		push_error("Failed to instantiate CommonBug scene from ", COMMON_BUG_SCENE_PATH)
		return

	add_child(e)

	e.add_to_group("enemies")
	e.init(pos)

	# =========================
	# SET ENEMY STATS HERE
	# =========================
	e.max_hp = 100

	e.hp = e.max_hp
	
	e.update_hp_label()
	enemies.append(e)
	occupied_tiles[pos] = true

	if not e.unit_died.is_connected(_on_unit_died):
		e.unit_died.connect(_on_unit_died)
	
func is_enemy_on_tile(pos: Vector2i) -> bool:
	for n in enemies:
		if n.grid_pos == pos:
			return true
	return false
	
func _start_preparation_phase() -> void:
	current_phase = BattlePhase.PREPARATION

	player_ui.hide_hp_ui()
	move_shuffle.hide_bar()

	await get_tree().create_timer(0.35).timeout

	phase_changed.emit(current_phase)

	player_hand = player_deck.draw_hand(10)

	selected_chips.clear()
	current_chip_index = 0
	player_chip_index = 0

	_update_ui()

func move_cursor_right():
	if player_hand.is_empty():
		return

	player_chip_index = (player_chip_index + 1) % player_hand.size()


func move_cursor_left():
	if player_hand.is_empty():
		return

	player_chip_index = (player_chip_index - 1 + player_hand.size()) % player_hand.size()


func move_cursor_down():
	if player_hand.is_empty():
		return

	var new_index = player_chip_index + DECK_COLUMNS

	if new_index < player_hand.size():
		player_chip_index = new_index


func move_cursor_up():
	if player_hand.is_empty():
		return

	var new_index = player_chip_index - DECK_COLUMNS

	if new_index >= 0:
		player_chip_index = new_index
				
func _handle_preparation_input() -> void:
	# ----------------------------------
	# If a combo is waiting to be accepted
	# ----------------------------------
	if selecting_buttons:
		return
		
	if pending_combo != null:

		if Input.is_action_just_pressed("ui_accept"):

			selected_chips.append(pending_combo)
			pending_combo = null

			if selected_chips.size() >= max_selected_chips:
				selecting_buttons = true
				battle_preperations.select_button.grab_focus()
				_update_ui()
				return

		return

	if player_hand.is_empty():
		return

	# ----------------------------------
	# Move Cursor
	# ----------------------------------
	if Input.is_action_just_pressed("ui_right"):
		move_cursor_right()
		_update_ui()

	if Input.is_action_just_pressed("ui_left"):
		move_cursor_left()
		_update_ui()

	if Input.is_action_just_pressed("ui_down"):
		move_cursor_down()
		_update_ui()

	if Input.is_action_just_pressed("ui_up"):
		move_cursor_up()
		_update_ui()

	# ----------------------------------
	# Cancel Combo Mode
	# ----------------------------------
	if Input.is_action_just_pressed("ui_cancel") and combo_mode:
		combo_mode = false
		first_combo_chip = null
		_update_ui()
		return
	
	if Input.is_action_just_pressed("remove_chip"):

		if !selected_chips.is_empty():

			var chip = selected_chips.pop_back()
			player_hand.append(chip)

			# Select the returned chip
			player_chip_index = player_hand.size() - 1

			_update_ui()

		return

	# ----------------------------------
	# SPACE = Select Chip
	# ----------------------------------
	if Input.is_action_just_pressed("ui_accept"):

		var chip = player_hand[player_chip_index]

		# ==========================
		# Finish Combo
		# ==========================
		if combo_mode:

			if chip == first_combo_chip:
				return

			if !first_combo_chip.can_combine_with(chip):
				print("Cannot combine.")
				return

			var combo = combo_database.get_combo(first_combo_chip, chip)

			if combo == null:
				print("No combo exists.")
				return

			# Remove both chips from the hand
			player_hand.erase(first_combo_chip)
			player_hand.erase(chip)

			# Show combo in the info panel
			pending_combo = combo

			combo_mode = false
			first_combo_chip = null

			if player_hand.is_empty():
				player_chip_index = 0
			else:
				player_chip_index = clamp(player_chip_index, 0, player_hand.size() - 1)

			print(combo.name, " created!")

			_update_ui()
			return

		# ==========================
		# Normal Chip Selection
		# ==========================
		selected_chips.append(chip)
		player_hand.remove_at(player_chip_index)

		if player_hand.is_empty():
			player_chip_index = 0
		else:
			player_chip_index = clamp(player_chip_index, 0, player_hand.size() - 1)

		if selected_chips.size() >= max_selected_chips:
			selecting_buttons = true
			battle_preperations.select_button.grab_focus()
			_update_ui()
			return

		_update_ui()
		return

	# ----------------------------------
	# ENTER = Begin Combo Selection
	# ----------------------------------
	if Input.is_action_just_pressed("combo_select"):

		var chip = player_hand[player_chip_index]

		if chip.combo_with.is_empty():
			print("This chip cannot combine.")
			return

		first_combo_chip = chip
		combo_mode = true

		print("Choose another chip to combine with ", chip.name)

		_update_ui()
		
func can_select_chip(chip: Chip) -> bool:
	if !combo_mode:
		return true

	if chip == first_combo_chip:
		return false

	return first_combo_chip.can_combine_with(chip)
	
# ============================================================
# BATTLE PHASE
# ============================================================
func next_chip():

	if selected_chips.is_empty():
		return

	current_chip_index = (current_chip_index + 1) % selected_chips.size()

	_apply_current_chip()


func previous_chip():

	if selected_chips.is_empty():
		return

	current_chip_index = (current_chip_index - 1 + selected_chips.size()) % selected_chips.size()

	_apply_current_chip()


func _apply_current_chip():

	var chip := selected_chips[current_chip_index]

	player.attack_range = chip.range_tile
	player.attack_power = chip.power

	move_shuffle.update_chip_display(selected_chips, current_chip_index)
	
func _start_battle_phase() -> void:
	get_tree().paused = false

	current_phase = BattlePhase.BATTLE
	battle_active = true
	current_chip_index = 0

	update_player_ui()
	player_ui.show_hp_ui()

	move_shuffle.update_chip_display(
		selected_chips,
		current_chip_index
	)

	move_shuffle.show_bar()

	var first_chip := selected_chips[0]
	player.attack_range = first_chip.range_tile
	player.attack_power = first_chip.power

	_update_ui()
	
func _handle_battle_input() -> void:
	if player_attack_locked:
		return

	if selected_chips.is_empty():
		return

	if current_chip_index >= selected_chips.size():
		return
		
	if Input.is_action_just_pressed("next_chip"):
		next_chip()
		return

	if Input.is_action_just_pressed("previous_chip"):
		previous_chip()
		return
		
	if Input.is_action_just_pressed("select"):

		player_attack_locked = true
		var chip = selected_chips[current_chip_index]

		use_chip(chip)

		print("Used chip: ", chip.name)

		selected_chips.remove_at(current_chip_index)

		if current_chip_index >= selected_chips.size():
			current_chip_index = max(selected_chips.size() - 1, 0)

		move_shuffle.update_chip_display(selected_chips, current_chip_index)

		await get_tree().create_timer(player_attack_delay).timeout

		player_attack_locked = false

		if current_chip_index >= selected_chips.size():
			battle_active = false

			await get_tree().create_timer(1.0).timeout

			if current_phase != BattlePhase.END:
				_next_round()
		
		_update_ui()
							
func use_chip(chip: Chip):
	match chip.attack_type:

		Chip.AttackType.PROJECTILE:
			use_delete(chip)

		Chip.AttackType.HOMING:
			use_patch(chip)

		Chip.AttackType.STUN_PROJECTILE:
			use_quarantine(chip)
			
		Chip.AttackType.WALL:
			use_firewall(chip)
		
		Chip.AttackType.HEAL:
			use_backup(chip)
			
		Chip.AttackType.BUFF:
			use_optimize(chip)
			
		Chip.AttackType.COMBO:
			use_reformat(chip)
# ============================================================
# ROUND MANAGEMENT
# ============================================================

func _next_round() -> void:
	move_shuffle.hide_bar()
	player.movement_locked = false

	selected_chips.clear()
	current_chip_index = 0
	player_chip_index = 0

	_start_preparation_phase()
	
# ============================================================
# CHIPS / MOVES
# ============================================================
func use_optimize(chip: Chip):
	player.activate_optimize(chip.power, 8.0)

func use_backup(chip: Chip):
	player.heal(chip.power)

	print("BACKUP restored ", chip.power, " life")
	
func use_delete(chip: Chip):
	var projectile = DELETE_PROJECTILE.instantiate()
	get_tree().current_scene.add_child(projectile)

	# spawn at player muzzle
	projectile.global_position = player_muzzle.global_position
	projectile.direction = Vector2.RIGHT

	# base damage from chip
	projectile.damage = chip.power

	# IMPORTANT: pass chip so super effective works later if needed
	projectile.chip = chip

	print("DELETE used for ", chip.power, " base damage")
	
func use_patch(chip: Chip):
	var projectile = PATCH_PROJECTILE.instantiate()
	get_tree().current_scene.add_child(projectile)

	projectile.global_position = player_muzzle.global_position
	projectile.target = get_closest_enemy()

	projectile.damage = chip.power
	projectile.chip = chip

	print("PATCH used")

func use_quarantine(chip: Chip):
	var projectile = QUARANTINE_PROJECTILE.instantiate()
	get_tree().current_scene.add_child(projectile)

	projectile.global_position = player_muzzle.global_position
	projectile.direction = Vector2.RIGHT

	projectile.speed = 900.0
	projectile.damage = chip.power
	projectile.stun_duration = 2.0
	projectile.chip = chip

	print("QUARANTINE used")

func get_closest_enemy() -> Unit:
	var best: Unit = null
	var best_dist := INF

	for e in enemies:
		if e == null:
			continue

		var d := player.global_position.distance_to(e.global_position)
		if d < best_dist:
			best_dist = d
			best = e

	return best
	
func use_firewall(chip: Chip):
	z_index = 10
	var firewall = FIREWALL.instantiate()
	get_tree().current_scene.add_child(firewall)

	# tile directly in front of player
	var firewall_tile = player.grid_pos + Vector2i.RIGHT

	firewall.grid_pos = firewall_tile
	firewall.position = player.grid_to_world(firewall_tile)

	blocked_tiles.append(firewall_tile)

	firewall.firewall_destroyed.connect(_on_firewall_destroyed)

	print("FIREWALL deployed at ", firewall_tile)
	
func _on_firewall_destroyed(tile: Vector2i):
	blocked_tiles.erase(tile)

func use_reformat(chip: Chip):

	var projectile = REFORMAT_PROJECTILE.instantiate()

	get_tree().current_scene.add_child(projectile)

	projectile.global_position = player_muzzle.global_position
	projectile.direction = Vector2.RIGHT

	projectile.damage = chip.power
	projectile.chip = chip

	print("REFORMAT used!")

# ============================================================
# DEATH / END BATTLE
# ============================================================

func _on_unit_died(unit: Unit) -> void:
	if current_phase == BattlePhase.END:
		return

	if unit.is_in_group("enemies"):

		# remove safely
		enemies.erase(unit)

		if occupied_tiles.has(unit.grid_pos):
			occupied_tiles.erase(unit.grid_pos)

		unit.remove_from_group("enemies")

		# IMPORTANT: delay free (prevents tree corruption)
		unit.call_deferred("queue_free")

		# check AFTER engine updates
		call_deferred("_check_win_condition")
		return

	# PLAYER DIED
	current_phase = BattlePhase.END
	battle_active = false

	print("Enemy wins!")
	battle_ended.emit(enemies[0] if enemies.size() > 0 else null)

	await get_tree().create_timer(1.0).timeout
	get_tree().reload_current_scene()

func end_battle() -> void:
	SignalBus.return_to_overworld()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_O:
		print("[BATTLE] O pressed - simulating return to overworld")
		end_battle()

func _check_win_condition():
	# remove invalid references
	enemies = enemies.filter(func(e):
		return is_instance_valid(e) and not e.is_dead
	)

	if enemies.size() == 0:
		current_phase = BattlePhase.END
		battle_active = false
		battle_preperations.visible = false
		move_shuffle.hide_bar()

		print("Player wins!")
		victory_overlay.show_victory()
		battle_ended.emit(player)

		# HARD STOP ALL ENEMIES
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e):
				e.queue_free()

		await get_tree().create_timer(0.5).timeout
		
func _on_victory_continue():
	print("BattleScene received signal!")
	end_battle()
		
func get_alive_enemies() -> Array:
	return enemies.filter(func(e):
		return is_instance_valid(e) and not e.is_dead
	)
