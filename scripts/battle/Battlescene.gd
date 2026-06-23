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
const FIREWALL = preload("uid://x8y5dkw5aur6")
const SCAN_EFFECT = preload("uid://bty6pm1am7ebp")
const COMMON_BUG_SCENE = preload("uid://bx0l221gdwc3i")

@onready var grid = $Grid
@onready var player: Unit = $PlayerCharacter
var enemies: Array[Unit] = []
@export var max_selected_chips := 2
# PLAYER ONLY uses chips now
var player_deck: ChipDeck
var player_hand: Array[Chip] = []

var selected_chips: Array[Chip] = []
var current_chip_index := 0
var player_chip_index: int = 0
var turn_locked := false
var battle_active: bool = false
var blocked_tiles: Array[Vector2i] = []
var occupied_tiles := {}

signal phase_changed(new_phase: BattlePhase)
signal player_chip_selected(chip: Chip)
signal battle_ended(winner: Unit)
var player_attack_locked := false
@export var player_attack_delay := 0.4

#put new vector to add enemy
var enemy_spawn_positions := [
	Vector2i(1, 2),
	Vector2i(2, 1)
]

func _ready() -> void:
	player_deck = ChipDeck.new()

	player.unit_died.connect(_on_unit_died)

	# IMPORTANT: store enemies properly
	enemies.clear()

	for pos in enemy_spawn_positions:
		spawn_enemy(pos)

	_start_preparation_phase()

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
func _update_ui() -> void:
	if ui == null:
		return

	ui.visible = current_phase == BattlePhase.PREPARATION

	if current_phase != BattlePhase.PREPARATION:
		return

	var total_hp := 0
	var total_max := 0

	for e in enemies:
		total_hp += e.hp
		total_max += e.max_hp

	ui.update_ui(
		player_hand,
		selected_chips,
		player_chip_index,
		max_selected_chips,
		player.get_lives(),
		player.get_max_lives(),
		total_hp,
		total_max
	)
	
func spawn_enemy(pos: Vector2i) -> void:
	while is_enemy_on_tile(pos):
		pos.x += 1

	var e: Unit = COMMON_BUG_SCENE.instantiate()
	get_tree().current_scene.add_child(e)

	e.add_to_group("enemies")
	e.init(pos)

	enemies.append(e)
	occupied_tiles[pos] = true

	# IMPORTANT SAFETY
	if not e.unit_died.is_connected(_on_unit_died):
		e.unit_died.connect(_on_unit_died)
	
func is_enemy_on_tile(pos: Vector2i) -> bool:
	for n in enemies:
		if n.grid_pos == pos:
			return true
	return false
	
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
			
		Chip.AttackType.WALL:
			use_firewall(chip)
		
		Chip.AttackType.HEAL:
			use_backup(chip)
			
		Chip.AttackType.BUFF:
			use_optimize(chip)
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

func _check_win_condition():
	# remove invalid references
	enemies = enemies.filter(func(e):
		return is_instance_valid(e) and not e.is_dead
	)

	if enemies.size() == 0:
		current_phase = BattlePhase.END
		battle_active = false

		print("Player wins!")
		battle_ended.emit(player)

		# HARD STOP ALL ENEMIES
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e):
				e.queue_free()

		await get_tree().create_timer(0.5).timeout
		get_tree().reload_current_scene()
		
func get_alive_enemies() -> Array:
	return enemies.filter(func(e):
		return is_instance_valid(e) and not e.is_dead
	)
