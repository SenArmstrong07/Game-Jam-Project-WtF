extends Node2D
class_name Battlescene

#
# Battle scene flow:
# Preparation Phase:
# 	Draw phase — Both player and enemy randomly draw 5 chips from their deck
# Selection phase —
# 	Player sees chips displayed (you scroll with arrow keys)
# 	Player presses Enter to select ONE chip
# 	Enemy AI randomly picks ONE chip
# 	UI shows — "You selected: DELETE (15 power, super effective vs CommonBug)"
# Battle Phase (with selected chip):
# 	The selected chip's stats become the unit's stats for this round:
# 	attack_power = 15
# 	attack_range = 1
# 	offensive_chip_selected = DELETE
# 	Player moves around the grid in real-time
# 	When enemy is within range, press a button to attack
# 	Attack uses the chip's damage type → effectiveness is checked against enemy type
# 	Attack connects → loops back to Preparation Phase for new chips
#
enum BattlePhase {
	PREPARATION,  # Phase 1: Select chips
	BATTLE,       # Phase 2: RTS battle
	END           # Battle ended
}

var current_phase: BattlePhase = BattlePhase.PREPARATION

@onready var grid = $Grid
@onready var player: Unit = get_node("PlayerCharacter")
@onready var enemy: Unit = get_node("CommonBug")

var player_deck: ChipDeck
var enemy_deck: ChipDeck

var player_hand: Array[Chip] = []
var enemy_hand: Array[Chip] = []

var player_selected_chip: Chip = null
var enemy_selected_chip: Chip = null

var player_chip_index: int = 0
var enemy_chip_index: int = 0

var battle_active: bool = false
var enemy_attack_timer: float = 0.0
var enemy_attack_interval: float = 2.0  # Enemy attacks every 2 seconds

signal phase_changed(new_phase: BattlePhase)
signal player_chip_selected(chip: Chip)
signal enemy_chip_selected(chip: Chip)
signal battle_ended(winner: Unit)

func _ready() -> void:
	# Initialize chip decks for both units
	player_deck = ChipDeck.new()
	enemy_deck = ChipDeck.new()
	
	# Connect to unit death signals
	player.unit_died.connect(_on_unit_died.bindv([player]))
	enemy.unit_died.connect(_on_unit_died.bindv([enemy]))
	
	# Start battle
	_start_preparation_phase()

func _process(delta: float) -> void:
	match current_phase:
		BattlePhase.PREPARATION:
			_handle_preparation_input()
		BattlePhase.BATTLE:
			_handle_battle_input()

# ============================================================
# PHASE 1: PREPARATION
# ============================================================

func _start_preparation_phase() -> void:
	print("=== PHASE 1: PREPARATION ===")
	current_phase = BattlePhase.PREPARATION
	phase_changed.emit(current_phase)
	
	# Draw hands for both player and enemy
	player_hand = player_deck.draw_hand(5)
	enemy_hand = enemy_deck.draw_hand(5)
	
	player_chip_index = 0
	enemy_chip_index = 0
	player_selected_chip = null
	enemy_selected_chip = null

	var chip_names_p = []
	var chip_names_e = []
	for chip in player_hand:
		chip_names_p.append(chip.name)
	for chip in enemy_hand:
		chip_names_e.append(chip)
	print("Player hand: ", chip_names_p)
	print("Enemy hand: ", chip_names_e)
	
	# TODO: Show UI for chip selection
	# For now, auto-select after a delay for testing
	await get_tree().create_timer(1.0).timeout
	_ai_select_chip()
	
	await get_tree().create_timer(0.5).timeout
	if player_selected_chip == null:
		player_selected_chip = player_hand[0]
		player_chip_selected.emit(player_selected_chip)

func _handle_preparation_input() -> void:
	if player_selected_chip != null and enemy_selected_chip != null:
		_start_battle_phase()
	
	# Player scrolls through chips
	if Input.is_action_just_pressed("ui_right"):
		player_chip_index = (player_chip_index + 1) % player_hand.size()
		print("Player viewing chip: ", player_hand[player_chip_index].name)
	
	if Input.is_action_just_pressed("ui_left"):
		player_chip_index = (player_chip_index - 1) % player_hand.size()
		print("Player viewing chip: ", player_hand[player_chip_index].name)
	
	# Player selects chip
	if Input.is_action_just_pressed("ui_accept"):
		player_selected_chip = player_hand[player_chip_index]
		player_chip_selected.emit(player_selected_chip)
		print("Player selected: ", player_selected_chip.name)

func _ai_select_chip() -> void:
	# Simple AI: random chip selection
	enemy_chip_index = randi() % enemy_hand.size()
	enemy_selected_chip = enemy_hand[enemy_chip_index]
	enemy_chip_selected.emit(enemy_selected_chip)
	print("Enemy selected: ", enemy_selected_chip.name)

# ============================================================
# PHASE 2: RTS BATTLE
# ============================================================

func _start_battle_phase() -> void:
	print("=== PHASE 2: RTS BATTLE ===")
	current_phase = BattlePhase.BATTLE
	phase_changed.emit(current_phase)
	battle_active = true
	enemy_attack_timer = 0.0
	
	# Apply selected chips to units
	player.attack_range = player_selected_chip.range_tile
	enemy.attack_range = enemy_selected_chip.range_tile
	
	print("Battle started! Player has: ", player_selected_chip.name)
	print("Battle started! Enemy has: ", enemy_selected_chip.name)
	
	# TODO: Implement real-time movement and attack logic

func _handle_battle_input() -> void:
	# Player movement with arrow keys
	var move_dir = Vector2i.ZERO
	if Input.is_action_pressed("ui_right"):
		move_dir.x += 1
	if Input.is_action_pressed("ui_left"):
		move_dir.x -= 1
	if Input.is_action_pressed("ui_down"):
		move_dir.y += 1
	if Input.is_action_pressed("ui_up"):
		move_dir.y -= 1
	
	# TODO: Implement player movement logic
	
	# Player attacks when in range
	if Input.is_action_just_pressed("ui_accept"):
		if player.attack_with_chip(enemy, player_selected_chip):
			print("Player used ", player_selected_chip.name)
			# After attack, enter next round
			await get_tree().create_timer(1.0).timeout
			_next_round()
	
	# Enemy AI attacking
	enemy_attack_timer += get_process_delta_time()
	if enemy_attack_timer >= enemy_attack_interval:
		enemy_attack_timer = 0.0
		if enemy.attack_with_chip(player, enemy_selected_chip):
			print("Enemy used ", enemy_selected_chip.name)

func _next_round() -> void:
	# Draw new chips and return to preparation phase
	player_selected_chip = null
	enemy_selected_chip = null
	_start_preparation_phase()

# ============================================================
# UTILITIES
# ============================================================

func _on_unit_died(unit: Unit) -> void:
	battle_active = false
	current_phase = BattlePhase.END
	phase_changed.emit(current_phase)
	
	var winner = enemy if unit == player else player
	print(unit.name, " died! Winner: ", winner.name)
	battle_ended.emit(winner)
