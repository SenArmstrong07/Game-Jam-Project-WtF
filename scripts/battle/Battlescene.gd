extends Node2D
class_name Battlescene

enum BattlePhase {
	PREPARATION,
	BATTLE,
	END
}

@onready var ui: CanvasLayer = $BattlePhaseUI
@onready var enemy_hitpoint: Marker2D = $CommonBug/CommonBugMarker
@onready var player_muzzle: Marker2D =  $PlayerCharacter/PlayerMarker
var current_phase: BattlePhase = BattlePhase.PREPARATION

const QUARANTINE_PROJECTILE = preload("uid://ca4tyfdtbm2xw")
const PATCH_PROJECTILE = preload("uid://sv6571ybegto")
const DELETE_PROJECTILE = preload("uid://cxcsd36elkqlv")

@onready var grid = $Grid
@onready var player: Unit = $PlayerCharacter
@onready var enemy: Unit = $CommonBug
@export var max_selected_chips := 2
# PLAYER ONLY uses chips now
var player_deck: ChipDeck
var player_hand: Array[Chip] = []

var selected_chips: Array[Chip] = []
var current_chip_index := 0
var player_chip_index: int = 0
var turn_locked := false
var battle_active: bool = false

signal phase_changed(new_phase: BattlePhase)
signal player_chip_selected(chip: Chip)
signal battle_ended(winner: Unit)
var player_attack_locked := false
@export var player_attack_delay := 0.4

func _ready() -> void:
	player_deck = ChipDeck.new()

	player.unit_died.connect(_on_unit_died)
	enemy.unit_died.connect(_on_unit_died)

	_start_preparation_phase()

func _process(delta: float) -> void:
	match current_phase:
		BattlePhase.PREPARATION:
			_handle_preparation_input()
		BattlePhase.BATTLE:
			if battle_active:
				_handle_battle_input()

# ============================================================
# PREPARATION PHASE
# ============================================================
func _update_ui() -> void:
	if ui == null:
		return

	ui.visible = current_phase == BattlePhase.PREPARATION

	if current_phase != BattlePhase.PREPARATION:
		return

	ui.update_ui(
		player_hand,
		selected_chips,
		player_chip_index,
		max_selected_chips,
		player.get_lives(),
		player.get_max_lives(),
		enemy.hp,
		enemy.max_hp
	)

func _start_preparation_phase() -> void:
	print("=== PREPARATION PHASE ===")

	current_phase = BattlePhase.PREPARATION
	phase_changed.emit(current_phase)

	player_hand = player_deck.draw_hand(5)

	selected_chips.clear()
	current_chip_index = 0
	player_chip_index = 0

	var chip_names := []

	for chip in player_hand:
		chip_names.append(chip.name)
		
	_update_ui()
	print("Player hand: ", chip_names)

func _handle_preparation_input() -> void:
	if player_hand.is_empty():
		return

	if Input.is_action_just_pressed("ui_right"):
		player_chip_index = (player_chip_index + 1) % player_hand.size()

	if Input.is_action_just_pressed("ui_left"):
		player_chip_index = (player_chip_index - 1 + player_hand.size()) % player_hand.size()

	if Input.is_action_just_pressed("ui_accept"):
		var chip = player_hand[player_chip_index]

		if selected_chips.has(chip):
			return

		selected_chips.append(chip)

		if selected_chips.size() >= max_selected_chips:
			_start_battle_phase()

	_update_ui()

# ============================================================
# BATTLE PHASE
# ============================================================

func _start_battle_phase() -> void:
	current_phase = BattlePhase.BATTLE

	battle_active = true
	current_chip_index = 0

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

	if Input.is_action_just_pressed("ui_accept"):

		player_attack_locked = true

		var chip = selected_chips[current_chip_index]

		use_chip(chip)

		print("Used chip: ", chip.name)

		current_chip_index += 1

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
# ============================================================
# ROUND MANAGEMENT
# ============================================================

func _next_round() -> void:
	player.movement_locked = false

	selected_chips.clear()
	current_chip_index = 0
	player_chip_index = 0

	_start_preparation_phase()
	
# ============================================================
# CHIPS / MOVES
# ============================================================

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
	projectile.target = enemy

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
		
# ============================================================
# DEATH / END BATTLE
# ============================================================

func _on_unit_died(unit: Unit) -> void:
	if current_phase == BattlePhase.END:
		return

	current_phase = BattlePhase.END
	battle_active = false

	print(unit.name, " died!")

	var winner: Unit

	if unit == player:
		winner = enemy
		print("Enemy wins!")
	else:
		winner = player
		print("Player wins!")

	battle_ended.emit(winner)

	await get_tree().create_timer(1.0).timeout
	get_tree().reload_current_scene()
