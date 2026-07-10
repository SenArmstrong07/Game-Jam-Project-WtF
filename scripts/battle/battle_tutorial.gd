extends BattleBase
class_name BattleTutorial

@onready var beam_center: Line2D = $SpawnBeamCenter
@onready var beam_left: Line2D = $SpawnBeamLeft
@onready var beam_right: Line2D = $SpawnBeamRight

@onready var camera: Camera2D = $Camera2D
@onready var ui: CanvasLayer = $PLAYER_HP_BATTLE_UI
@onready var player_muzzle: Marker2D =  $PlayerCharacter/PlayerMarker

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
var emergency_heal_used := false

signal battle_ended(winner: Unit)
var player_attack_locked := false
@export var player_attack_delay := 0.4

var selecting_buttons := false
@onready var player_ui = $PLAYER_HP_BATTLE_UI/PLAYER_LIVES
@onready var battle_preperations =  $PLAYER_HP_BATTLE_UI/BATTLE_PREPERATIONS
@onready var move_shuffle = $PLAYER_HP_BATTLE_UI/MOVE_SHUFFLE
@onready var tutorial: CanvasLayer = $TUTORIALS

var prep_tutorial_done := false
var battle_tutorial_done := false
var confirm_tutorial_done := false
var battle_controls_tutorial_done := false
	
var tutorial_mode := true

#put new vector to add enemy
var enemy_spawn_positions := [
	Vector2i(1, 2)
]

func _ready() -> void:
	player.visible = false
	
	for e in enemies:
		e.visible = false

	battle_preperations.visible = false
	ui.visible = false
	BgTitleToDial.stop()
	BattleBgm.process_mode = Node.PROCESS_MODE_ALWAYS
	BattleBgm.play_music(preload("res://assets/FX/BattleBGMTest.mp3"))
	
	player.lives_changed.connect(_on_player_lives_changed)
	battle_preperations.visible = false
	battle_scene = find_battle_scene()
	player_deck = ChipDeck.new()
	
	update_player_ui()
	
	player.unit_died.connect(_on_unit_died)
	player.hp_changed.connect(_on_player_hp_changed)
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

	await get_tree().process_frame
	await play_battle_intro()
	
	_start_preparation_phase()
	
func play_battle_intro() -> void:

	player.visible = false

	for enemy in enemies:
		enemy.visible = false

	ui.visible = false
	battle_preperations.visible = false

	await get_tree().create_timer(0.2).timeout

	await get_tree().create_timer(0.15).timeout
	
	await camera.play_intro()
	# Spawn player
	await laser_spawn(player)

	# Spawn enemies one after another
	for enemy in enemies:
		await get_tree().create_timer(0.1).timeout
		await laser_spawn(enemy)

	await get_tree().create_timer(0.2).timeout

	ui.visible = true
	battle_preperations.play_intro()

	# Wait until the animation finishes
	if battle_preperations.has_signal("intro_finished"):
		await battle_preperations.intro_finished
	else:
		await get_tree().create_timer(1).timeout
	
func laser_spawn(unit: Unit) -> void:

	var top: Vector2 = unit.global_position - Vector2(0, 300)
	var bottom: Vector2 = unit.global_position + Vector2(0, 16)

	unit.visible = false

	var beams: Array[Line2D] = [
		beam_center,
		beam_left,
		beam_right
	]

	for beam: Line2D in beams:
		beam.visible = true
		beam.modulate = Color.WHITE
		beam.clear_points()


	# Beam setup
	beam_center.width = 32
	beam_left.width = 16
	beam_right.width = 16

	beam_center.add_point(top)
	beam_center.add_point(top)

	beam_left.add_point(top + Vector2(-22, 0))
	beam_left.add_point(top + Vector2(-22, 0))

	beam_right.add_point(top + Vector2(22, 0))
	beam_right.add_point(top + Vector2(22, 0))


	# Beam travelling down
	var duration: float = 0.14
	var elapsed: float = 0.0

	while elapsed < duration:

		var ratio: float = elapsed / duration
		var y: float = lerp(top.y, bottom.y, ratio)

		beam_center.set_point_position(1, Vector2(top.x, y))
		beam_left.set_point_position(1, Vector2(top.x - 22, y))
		beam_right.set_point_position(1, Vector2(top.x + 22, y))

		elapsed += get_process_delta_time()
		await get_tree().process_frame


	# Beam hits tile
	beam_center.set_point_position(1, Vector2(top.x, bottom.y))
	beam_left.set_point_position(1, Vector2(top.x - 22, bottom.y))
	beam_right.set_point_position(1, Vector2(top.x + 22, bottom.y))


	# Create tile lightning effect
	var tile_flash := ColorRect.new()

	tile_flash.color = Color.WHITE
	tile_flash.size = Vector2(64,64)

	tile_flash.global_position = unit.global_position - Vector2(32,32)

	# behind unit
	tile_flash.z_index = unit.z_index - 1

	# starting opacity
	tile_flash.modulate.a = 0.15

	add_child(tile_flash)


	unit.visible = true


	var sprite := unit.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

	# Strong lightning while laser stays

	for i in range(5):

		if sprite:
			sprite.modulate = Color(4,4,5)

		tile_flash.modulate.a = 0.45


		await get_tree().create_timer(0.035).timeout


		if sprite:
			sprite.modulate = Color.WHITE

		tile_flash.modulate.a = 0.12


		await get_tree().create_timer(0.04).timeout


	# Beam collapse

	var collapse_time: float = 0.10
	elapsed = 0.0


	while elapsed < collapse_time:

		var ratio: float = elapsed / collapse_time
		var offset: float = lerp(22.0,0.0,ratio)

		beam_left.set_point_position(
			0,
			top + Vector2(-offset,0)
		)

		beam_left.set_point_position(
			1,
			bottom + Vector2(-offset,0)
		)


		beam_right.set_point_position(
			0,
			top + Vector2(offset,0)
		)

		beam_right.set_point_position(
			1,
			bottom + Vector2(offset,0)
		)


		beam_center.width = lerp(32.0,0.0,ratio)
		beam_left.width = lerp(16.0,0.0,ratio)
		beam_right.width = lerp(16.0,0.0,ratio)


		var alpha: float = lerp(1.0,0.0,ratio)

		beam_center.modulate.a = alpha
		beam_left.modulate.a = alpha
		beam_right.modulate.a = alpha


		elapsed += get_process_delta_time()
		await get_tree().process_frame



	# Remove laser
	for beam: Line2D in beams:
		beam.visible = false
		beam.clear_points()


	# Residual fading electricity

	for i in range(3):

		if sprite:
			sprite.modulate = Color(2.5,2.5,3)

		tile_flash.modulate.a = 0.25


		await get_tree().create_timer(0.08).timeout


		if sprite:
			sprite.modulate = Color.WHITE

		tile_flash.modulate.a = 0.05


		await get_tree().create_timer(0.12).timeout



	# Final fade

	var fade := create_tween()

	fade.tween_property(
		tile_flash,
		"modulate:a",
		0.0,
		0.3
	)


	await fade.finished


	tile_flash.queue_free()
	
func _on_player_hp_changed(unit: Unit, hp: int) -> void:
	if emergency_heal_used:
		return

	if hp != 1:
		return

	emergency_heal_used = true

	_emergency_tutorial_heal()

func _emergency_tutorial_heal() -> void:
	battle_active = false
	player.movement_locked = true

	await tutorial_popup(
		"MiniBot",
		"MiniBot",
		"Oh Wow... 4 years of college just to be like that?"
	)

	await tutorial_popup(
		"MiniBot",
		"MiniBot",
		"I leave you alone for a second and you're about to get DELETED."
	)

	await tutorial_popup(
		"Cody",
		"MC",
		"Hey!"
	)

	await tutorial_popup(
		"MiniBot",
		"MiniBot",
		"Fine. Since this is still the tutorial, I'll patch you up."
	)

	update_player_ui()

	await tutorial_popup(
		"MiniBot",
		"MiniBot",
		"Don't get used to it. Next time you're on your own."
	)

	player.movement_locked = false
	battle_active = true
	
func _on_select_pressed():

	selecting_buttons = false
	if !confirm_tutorial_done:
		confirm_tutorial_done = true
		await tutorial_popup(
			"MiniBot",
			"MiniBot",
			"Great! You've selected your Modules. lets delete that bugger shall we!"
		)
		await tutorial_popup(
			"MiniBot",
			"MiniBot",
			"You can click Confirm or use 'SPACE' if you are ready, or Wait if you want some changes on your Module"
		)
		await tutorial_popup(
			"Cody",
			"MC",
			"What are you kidding me! I did not study programming to fight an actual bug!"
		)
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

func tutorial_popup(name: String, portrait_anim: String, message: String):

	if !tutorial_mode:
		return

	get_tree().paused = true

	tutorial.process_mode = Node.PROCESS_MODE_ALWAYS

	tutorial.show_tutorial(
		name,
		portrait_anim,
		message
	)

	await tutorial.tutorial_closed

	get_tree().paused = false
	
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
	e.max_hp = 200

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
	
	if !prep_tutorial_done:
		prep_tutorial_done = true
		await tutorial_popup(
			"MiniBot",
			"MiniBot",
			"Hey Cody! I know you're confused, but right now there's a bug in front of you."
		)

		await tutorial_popup(
			"MiniBot",
			"MiniBot",
			"You need to fight it with the Debugger Gauntlet you have!"
		)
		await tutorial_popup(
			"Cody",
			"MC",
			"What! Where am I!"
		)
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
	
	if !battle_tutorial_done:
		battle_tutorial_done = true
		await tutorial_popup(
			"MiniBot",
			"MiniBot",
			"As you can see below is your Module Deck you can use 'Arrow Keys' then 'Space' to select you Module!"
		)
		await tutorial_popup(
			"MiniBot",
			"MiniBot",
			"And on the your right side is the Module Hand you selected, you can use 'B' to remove a Module on the Hand"
		)
		await tutorial_popup(
			"MiniBot",
			"MiniBot",
			"And you can click 'C' on a move that you want to COMBINE but right now you can only COMBINE DELETE Module with each other!"
		)
		await tutorial_popup(
			"MiniBot",
			"MiniBot",
			"You can click 'ESC' to cancel COMBINE Module"
		)
		
		await tutorial_popup(
			"MiniBot",
			"MiniBot",
			"Careful now. If you get DELETED here, you'll be DELETED in real life too. That's one way to erase your digital footprint... eh?"
		)
		await tutorial_popup(
			"Cody",
			"MC",
			"Huh?! I don't wanna die"
		)
		
	
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

	await get_tree().process_frame

	if !battle_controls_tutorial_done:
		battle_controls_tutorial_done = true
		await get_tree().create_timer(1.5).timeout
		await tutorial_popup(
			"MiniBot",
			"MiniBot",
			"As you can see on your right is your Module Hand. You can use 'Q' and 'E' to switch between Modules."
		)

		await tutorial_popup(
			"MiniBot",
			"MiniBot",
			"At the top are your lives. You can only take 5 hits before you're DELETED, so dodge those bullets... unless you want some bullet holes on ya!"
		)

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

	await tutorial_popup(
		"MiniBot",
		"MiniBot",
		"Looks like you got DELETED... I told you this wouldn't always be easy."
	)

	await tutorial_popup(
		"MiniBot",
		"MiniBot",
		"Well... see you next time! Let me know if there's a robot heaven."
	)
	await tutorial_popup(
		"MiniBot",
		"MiniBot",
		"...Or hell. Honestly, I'll take either one. See ya."
	)

	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/UI/TitleScreen.tscn")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_O:
		print("[BATTLE] O pressed - simulating return to overworld")


func _check_win_condition():
	enemies = enemies.filter(func(e):
		return is_instance_valid(e) and not e.is_dead
	)

	if enemies.size() == 0:
		current_phase = BattlePhase.END
		battle_active = false

		print("Player wins!")
		battle_ended.emit(player)

		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e):
				e.queue_free()

		await tutorial_popup(
			"MiniBot",
			"MiniBot",
			"Nice work! You successfully DELETED the bug!"
		)

		await tutorial_popup(
			"Cody",
			"MC",
			"I... actually did it?"
		)

		await tutorial_popup(
			"MiniBot",
			"MiniBot",
			"See? Debugging isn't just about fixing code anymore. Get ready—there are plenty more bugs waiting for you."
		)
		await tutorial_popup(
			"MiniBot",
			"MiniBot",
			"Im Sending you to the CyberMap now go and eliminate all bugs you'll see!"
		)
		await tutorial_popup(
			"Cody",
			"MC",
			"No! No! No! No! No! Wait! Wait! Wait WAI-"
		)

		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://scenes/overworld/CyberMap.tscn")
		# Continue to the next scene or end the tutorial here.
		
func get_alive_enemies() -> Array:
	return enemies.filter(func(e):
		return is_instance_valid(e) and not e.is_dead
	)

func _on_player_lives_changed(_player: Unit, lives: int) -> void:
	if emergency_heal_used:
		return

	if lives != 1:
		return

	emergency_heal_used = true

	# Heal immediately so take_damage() won't call die()
	player.heal(4)

	# Show the dialogue separately
	_emergency_tutorial_heal.call_deferred()
