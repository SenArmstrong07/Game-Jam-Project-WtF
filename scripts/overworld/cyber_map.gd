extends Node2D

@onready var player: Node2D = $OverworldPlayer
@onready var frontlayer: TileMapLayer = $TileNode/front
@onready var boss_summon_overlay: Control = $UI/Boss_Summon_Overlay
@onready var camera: Camera2D = $Camera2D

var overworld_state: Dictionary = {}
var boss_summon_in_progress := false
var boss_spawn_point: Marker2D
var boss_scene: PackedScene = preload("res://scenes/units/overworld_enemy.tscn")
var summon_anim_scene: PackedScene = preload("res://scenes/units/SummonAnimation.tscn")
var corruption_tile_script_path := "res://scripts/overworld/corruption_tile.gd"
var corruption_tile_script: Script = null
var CORRUPTION_SCALE := 1.0

const BOSS_SUMMON_DELAY_ON_RETURN := 1.5
const BOSS_POST_SUMMON_PAUSE := 2.4
const SETTINGS_SCENE_PATH := "res://scenes/UI/SettingsScene.tscn"
const FULL_HEART = preload("uid://ct06j0bja4ca6")
const EMPTY_HEART = preload("uid://dqb46x6jpp2bw")


@onready var overworld_bgm: AudioStreamPlayer = $OverworldBGM
@onready var boss_event_bgm: AudioStreamPlayer = $BossEventBGM
@onready var warning_fx: AudioStreamPlayer = $WarningFX
@onready var dialogues: CanvasLayer = $Dialogues
@onready var simulate_enemy_del: Button = $UI/SimulateEnemyDel

var intro_dialogue_running := false
var boss_dialogue_running := false
var dialogue_mode := true

func _ready() -> void:
	if overworld_state.is_empty() and not SignalBus.overworld_state.is_empty():
		overworld_state = SignalBus.overworld_state.duplicate(true)
	simulate_enemy_del.visible = false
	BattleBgm.stop()
	BgTitleToDial.stop()
	add_to_group("Cybermap")
	call_deferred("_refresh_quest_ui")

	if BgTitleToDial:
		BgTitleToDial.bus = "Music"
	if BattleBgm:
		BattleBgm.bus = "Music"
		
	if overworld_bgm:
		overworld_bgm.bus = "Music"
		overworld_bgm.play()
	
	if boss_event_bgm:
		boss_event_bgm.bus = "Music"
		boss_event_bgm.finished.connect(_on_boss_event_bgm_finished)

	# Try to load corruption tile script at runtime to avoid preload errors
	corruption_tile_script = load(corruption_tile_script_path)
	if corruption_tile_script == null:
		print("[BOSS] Warning: failed to load corruption tile script: ", corruption_tile_script_path)

	_setup_settings_toggle_input()
	set_lives(max(0, SignalBus.player_lives))

	#prep the loading screen to cover the tilenodes
	var loading_screen = get_node_or_null("LoadingScreen")
	var should_show_loading_screen: bool = !SignalBus.in_transition && SignalBus.overworld_state.is_empty()
	if should_show_loading_screen:
		_set_player_controls_locked(true)
		if loading_screen and loading_screen.has_method("_show_overlay"):
			loading_screen._show_overlay("Generating world...")
	else:
		_set_player_controls_locked(false)
		if loading_screen and loading_screen.has_method("_hide_overlay"):
			loading_screen._hide_overlay()

	if frontlayer and not frontlayer.is_connected("world_generation_complete", _on_world_generation_complete):
		frontlayer.world_generation_complete.connect(_on_world_generation_complete)
	
	#We start the overworld dialogue ONLY ONCE:
	if !SignalBus.overworld_intro_played:
		SignalBus.overworld_intro_played = true
		intro_dialogue_running = true
		_set_player_controls_locked(true)
		await get_tree().create_timer(1).timeout
		await start_overworld_dialogue()
		intro_dialogue_running = false
		_set_player_controls_locked(false)
	
	if boss_summon_overlay and not boss_summon_overlay.is_connected("summon_finished", _on_boss_summon_finished):
		boss_summon_overlay.summon_finished.connect(_on_boss_summon_finished)

	# If we're returning from a battle transition, preserve the cached state and let the return transition play.
	if SignalBus.in_transition:
		SignalBus.in_transition = false
		if overworld_state.is_empty() and not SignalBus.overworld_state.is_empty():
			overworld_state = SignalBus.overworld_state.duplicate(true)
	else:
		# Normal startup: capture and store current overworld state only if we still have a live scene snapshot.
		if not SignalBus.overworld_state.is_empty():
			overworld_state = SignalBus.overworld_state.duplicate(true)
		else:
			store_overworld_state()

#LIFE CHECK:
func set_lives(current_lives: int) -> void:
	var hearts = $UI/MarginContainer/LivesUI.get_children()
	var safe_lives: int = clamp(current_lives, 0, hearts.size())
	SignalBus.player_lives = safe_lives

	for i in range(hearts.size()):
		var heart := hearts[i] as TextureRect
		heart.texture = FULL_HEART if i < safe_lives else EMPTY_HEART


#DIALOGUE STUFF
func dialogue_pop_up(name: String, portrait_anim: String, message: String):

	if !dialogue_mode:
		return

	dialogues.process_mode = Node.PROCESS_MODE_ALWAYS

	dialogues.show_tutorial(
		name,
		portrait_anim,
		message
	)

	await dialogues.tutorial_closed

	get_tree().paused = false

func start_overworld_dialogue() -> void:
	await dialogue_pop_up(
		"MiniBot",
		"MiniBot",
		"Welcome to the Cyber World, here you will DELETE some bugs and viruses. Once that's done, you can go home."
	)
	
	await dialogue_pop_up(
		"Cody",
		"MC",
		"How many do I need to DELETE before I can go?"
	)
	
	await dialogue_pop_up(
		"MiniBot",
		"MiniBot",
		"Oh great you are now cooperating, this makes things easier! you see the map? you can follow the markers to find the bugs you need to DELETE"
	)
	
	await dialogue_pop_up(
		"MiniBot",
		"MiniBot",
		"Afterwards, a 'Big' surprise will come to your way, you also need to DELETE that though"
	)
	
	await dialogue_pop_up(
		"Cody",
		"MC",
		"Surprise? why would I want to delete a surprise?"
	)
	
	await dialogue_pop_up(
		"MiniBot",
		"MiniBot",
		"Just think of it this way, alright? It's like getting rid of an cringey memory. You'll feel much better afterward!"
	)
	
	await dialogue_pop_up(
		"Cody",
		"MC",
		"What are you talking about?! we are talking about the bugs and now memories I don't get what you're saying"
	)
	
	await dialogue_pop_up(
		"MiniBot",
		"MiniBot",
		"Anywho, just do the DELETING and I'll let you go!"
	)
	
	await dialogue_pop_up(
		"Cody",
		"MC",
		"Oh man! How did I even get here in the first place?"
	)
	
func play_boss_dialogue() -> void:
	await dialogue_pop_up(
		"Cody",
		"MC",
		"Uhh... What was that just now?"
	)
	
	await dialogue_pop_up(
		"MiniBot",
		"MiniBot",
		"That's that 'cringey memory' I was talking to you about!"
	)
	await dialogue_pop_up(
		"Cody",
		"MC",
		"That thing just came out of nowhere! Who does it think it is?"
	)
	await dialogue_pop_up(
		"MiniBot",
		"MiniBot",
		"That thing is called a 'Master Virus'"
	)

	await dialogue_pop_up(
		"MiniBot",
		"MiniBot",
		"It's responsible mostly for the spread of viruses you saw before, plaguing the Cyber World."
	)
	await dialogue_pop_up(
		"MiniBot",
		"MiniBot",
		"It's not like any other enemies you've faced before, especially in battle."
	)
	await dialogue_pop_up(
		"Cody",
		"MC",
		"If that's the case, can I at least know how to get rid of this... thing?"
	)
	await get_tree().create_timer(1).timeout
	await dialogue_pop_up(
		"MiniBot",
		"MiniBot",
		"...Break a leg!"
	)
	await get_tree().create_timer(1).timeout
	await dialogue_pop_up(
		"Cody",
		"MC",
		"Wow, you're so thoughtful (-_-)"
	)
	await dialogue_pop_up(
		"Cody",
		"MC",
		"I'll give you a 'surprise' once I come back..."
	)

#SOUND STUFF
func _on_boss_event_bgm_finished() -> void:
	if overworld_bgm:
		overworld_bgm.play()

#WORLD STUFF
func _on_world_generation_complete() -> void:
	if !intro_dialogue_running:
		_set_player_controls_locked(false)
	ensure_one_elite()
	store_overworld_state()
	_refresh_quest_ui()

	if SignalBus.respawn_to_safe_spawn:
		_apply_safe_respawn_position()
		SignalBus.respawn_to_safe_spawn = false

	var loading_screen = get_node_or_null("LoadingScreen")
	if loading_screen and loading_screen.has_method("_hide_overlay"):
		loading_screen._hide_overlay()
	
	if SignalBus.summon_boss_on_return and not boss_summon_in_progress:
		print("[BOSS] Delaying boss summon on overworld return by ", BOSS_SUMMON_DELAY_ON_RETURN, " seconds")
		call_deferred("_delayed_return_boss_summon")

func _apply_safe_respawn_position() -> void:
	if player == null or frontlayer == null:
		return

	var enemy_position: Vector2 = Vector2.ZERO
	if SignalBus.current_encounter and is_instance_valid(SignalBus.current_encounter.overworld_enemy):
		enemy_position = SignalBus.current_encounter.overworld_enemy.global_position

	var bounds = frontlayer.get_world_bounds()
	var min_x := int(floor(bounds.position.x / frontlayer.tile_size))
	var min_y := int(floor(bounds.position.y / frontlayer.tile_size))
	var max_x := int(ceil((bounds.position.x + bounds.size.x) / frontlayer.tile_size))
	var max_y := int(ceil((bounds.position.y + bounds.size.y) / frontlayer.tile_size))

	var candidate_tiles: Array[Vector2i] = []
	for x in range(min_x, max_x):
		for y in range(min_y, max_y):
			var tile := Vector2i(x, y)
			if not frontlayer.is_tile_walkable(tile):
				continue
			var tile_position : Vector2i = frontlayer.map_to_global(tile)
			if enemy_position != Vector2.ZERO and tile_position.distance_to(enemy_position) < 800.0:
				continue
			candidate_tiles.append(tile)

	if candidate_tiles.is_empty():
		player.global_position = frontlayer.find_valid_spawn_tile()
		store_overworld_state()
		print("[RESPAWN] No safe respawn tiles found, using fallback spawn")
		return

	var chosen_tile = candidate_tiles[randi() % candidate_tiles.size()]
	player.global_position = frontlayer.map_to_global(chosen_tile)
	store_overworld_state()
	print("[RESPAWN] Player respawned to safe tile: ", chosen_tile)

func ensure_one_elite() -> void:
	var enemies = get_tree().get_nodes_in_group("overworldmob")

	if enemies.is_empty():
		return

	# Already have an elite?
	for enemy in enemies:
		if enemy.battle_scene == SignalBus.TROJAN_ELITE:
			return

	# Promote one random enemy
	var elite = enemies.pick_random()

	elite.battle_scene = SignalBus.TROJAN_ELITE
	elite.enemy_tier = elite.EnemyTier.ELITE

	if elite.has_method("make_elite"):
		elite.make_elite()
		
func _on_simulate_remove_enemy_pressed() -> void:
	var nearest_enemy = _find_nearest_overworld_enemy()
	if nearest_enemy:
		_remove_overworld_enemy(nearest_enemy)
		store_overworld_state()
		print("[STATE] Removed nearest overworld enemy: ", nearest_enemy.name)
	else:
		print("[STATE] No overworld enemy found to remove")

func _find_nearest_overworld_enemy() -> Node2D:
	var nearest_enemy: Node2D = null
	var shortest_dist = INF
	for enemy in get_tree().get_nodes_in_group("overworldmob"):
		if not enemy or not enemy.is_inside_tree():
			continue
		var enemy_node = enemy as Node2D
		if enemy_node == null:
			continue
		var distance = player.global_position.distance_to(enemy_node.global_position)
		if distance < shortest_dist:
			shortest_dist = distance
			nearest_enemy = enemy_node
	return nearest_enemy

func _remove_overworld_enemy(enemy: Node2D) -> void:
	print("[BOSS] Removing enemy, id=", enemy.get_instance_id(), " name=", enemy.name)
	if not enemy or not enemy.is_inside_tree():
		return
	if enemy.has_method("disappear"):
		enemy.disappear()
	else:
		# Remove the enemy node itself through here
		enemy.queue_free()
	#wait one queue frame
	await get_tree().process_frame
	print("[BOSS] Enemy removed, storing state")
	store_overworld_state()
	print("[BOSS] State stored, checking boss validity")
	_check_for_boss_summon_validity()

func store_overworld_state() -> void:
	var snapshot: Dictionary = get_overworld_state().duplicate(true)
	if snapshot.get("enemies", []).is_empty() and overworld_state.has("enemies") and not overworld_state["enemies"].is_empty():
		snapshot["enemies"] = overworld_state["enemies"].duplicate(true)
		snapshot["enemy_count"] = snapshot["enemies"].size()
		print("[STATE] Preserved previous enemy roster during overwrite: ", snapshot["enemy_count"])

	overworld_state = snapshot.duplicate(true)
	SignalBus.overworld_state = overworld_state.duplicate(true)
	SignalBus.save_current_game_state()
	_refresh_quest_ui()

func is_event_in_progress() -> bool:
	return intro_dialogue_running or boss_dialogue_running or boss_summon_in_progress

func _refresh_quest_ui() -> void:
	var quest_ui = get_node_or_null("UI/Quest_UI")
	if quest_ui and quest_ui.has_method("_update_quest_ui"):
		quest_ui._update_quest_ui()

func _set_player_controls_locked(locked: bool) -> void:
	if player and player.has_method("set_controls_locked"):
		player.set_controls_locked(locked)
	elif player:
		player.controls_locked = locked

func _setup_settings_toggle_input() -> void:
	if not InputMap.has_action("toggle_settings"):
		InputMap.add_action("toggle_settings")
	InputMap.action_erase_events("toggle_settings")
	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	InputMap.action_add_event("toggle_settings", escape_event)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.is_action_pressed("toggle_settings"):
		_toggle_settings_window()
		get_viewport().set_input_as_handled()

func _toggle_settings_window() -> void:
	var settings_ui = get_node_or_null("UI/SettingsScene")
	if settings_ui and settings_ui.has_method("toggle"):
		settings_ui.toggle()

func _on_bottom_quest_pressed() -> void:
	var quest_ui = get_node_or_null("UI/Quest_UI")
	if quest_ui and quest_ui.has_method("toggle_quest_ui"):
		quest_ui.toggle_quest_ui()

func _on_bottom_settings_pressed() -> void:
	_toggle_settings_window()

func _on_close_settings_pressed() -> void:
	var settings_panel = get_node_or_null("UI/SettingsPanel")
	if settings_panel:
		settings_panel.visible = false

func _on_close_scan_pressed() -> void:
	var scan_panel = get_node_or_null("UI/ScanPanel")
	if scan_panel:
		scan_panel.visible = false

func _restore_overworld_state(state: Dictionary) -> void:
	if state.is_empty():
		return

	# Restore player to the saved tile
	#if state.has("player_tile"):
		#player.position = frontlayer.map_to_local(state["player_tile"])

	# Spawn enemies based on saved data
	#var enemy_scene = load("res://scenes/units/overworld_enemy.tscn")
	#if enemy_scene == null:
		#print("[STATE] _restore_overworld_state: cannot load overworld enemy scene")
		#return
#
	#if "enemies" in state:
		#for einfo in state.enemies:
			#var ne = enemy_scene.instantiate()
			#add_child(ne)
			#if ne is Node2D and "position" in einfo:
				#ne.global_position = einfo.position

	# Update stored state after restoration
	store_overworld_state()

#BOSS SUMMONING SEQUENCES
func _check_for_boss_summon_validity() -> void:
	var enemies = get_tree().get_nodes_in_group("overworldmob")
	print("[BOSS] Checking boss summon validity: enemy_count=", enemies.size(), " boss_in_progress=", boss_summon_in_progress)
	if enemies.is_empty():
		print("[STATE] All enemies are defeated. Summoning Boss...")
		print("[BOSS] Calling _begin_boss_summon_sequence()")
		_begin_boss_summon_sequence()

var boss_spawn_pending_position: Vector2 = Vector2.ZERO

func _on_boss_summon_finished() -> void:
	if not boss_summon_in_progress:
		print("[BOSS] Received summon_finished but no summon is pending")
		return

	print("[BOSS] Overlay finished callback received")
	print("[BOSS] Pending boss spawn position: ", boss_spawn_pending_position)
	_execute_boss_spawn_sequence(boss_spawn_pending_position)

func _begin_boss_summon_sequence() -> void:
	if boss_summon_in_progress:
		print("[BOSS] Sequence already in progress, aborting")
		return

	boss_summon_in_progress = true
	if SignalBus.summon_boss_on_return:
		SignalBus.summon_boss_on_return = false
		print("[BOSS] Cleared return-queued boss summon flag")

	print("[BOSS] Entered _begin_boss_summon_sequence")
	print("[BOSS] player=", player, " boss_summon_overlay=", boss_summon_overlay)
	if boss_summon_overlay == null:
		print("[BOSS] ERROR: boss_summon_overlay is null")
		boss_summon_in_progress = false
		return
	print("[BOSS] boss_summon_overlay inside_tree=", boss_summon_overlay.is_inside_tree())
	_set_player_controls_locked(true)
	if overworld_bgm.playing:
		overworld_bgm.stop()
	if boss_event_bgm:
		boss_event_bgm.play()
		warning_fx.play()
	if frontlayer and frontlayer.has_method("set_camera_follow_enabled"):
		frontlayer.set_camera_follow_enabled(false)
	print("[BOSS] Player controls locked")

	boss_spawn_pending_position = _find_valid_boss_spawn_position()
	print("[BOSS] Starting boss summon overlay")
	print("[BOSS] Calculated boss spawn position: ", boss_spawn_pending_position)
	print("[BOSS] boss_summon_overlay has_method summon_message=", boss_summon_overlay.has_method("summon_message"))
	boss_summon_overlay.call_deferred("summon_message")
	print("[BOSS] summon_message() deferred")
	print("[BOSS] Waiting for summon_finished signal")

func _execute_boss_spawn_sequence(spawn_position: Vector2) -> void:
	var spawn_point = _create_boss_spawn_point(spawn_position)
	print("[BOSS] Moving camera to boss spawn")
	await _move_camera_to_position(spawn_position, 0.9)
	#give some pause after camera movement
	await get_tree().create_timer(1).timeout
	# Play summon animation at spawn point and wait for it to finish
	if summon_anim_scene:
		print("[BOSS] Instantiating summon animation")
		var summon = summon_anim_scene.instantiate()
		summon.global_position = spawn_point.global_position
			# Use modest z_index values so we can layer corruption and characters predictably
		summon.z_index = 6
		add_child(summon)

		var sprite = summon.get_node_or_null("summon_sprite")
		if sprite:
			print("[BOSS] Starting summon sprite playback")
			# Ensure animation starts from the beginning and plays
			if sprite.has_method("play"):
				if sprite.sprite_frames and sprite.sprite_frames.has_animation("glitch_summon"):
					# reset to first frame then play the named animation
					sprite.frame = 0
					sprite.frame_progress = 0.0
					sprite.play("glitch_summon")
				else:
					# fallback: just start playback (uses current animation if any)
					sprite.frame = 0
					sprite.frame_progress = 0.0
					sprite.play()
			# Start corruption ripple concurrently with the summon animation
			print("[BOSS] Starting corrupted tile ripple (concurrent)")
			# Start without awaiting so it runs in parallel
			_corrupt_tiles_around(spawn_point.global_position)
			# Small, low-intensity screen shake while summon plays
			_screen_shake(0.7, 3.5)

			# Wait until the sprite emits the finished signal
			await sprite.animation_finished
		else:
			# Fallback wait if no sprite/signal available
			await get_tree().create_timer(0.9).timeout

		# Spawn boss right after summon animation finishes and place it behind the summon
		print("[BOSS] Spawning boss behind summon animation")
		# Spawn boss at z_index above corruption and same as player
		var boss = _spawn_boss_enemy(spawn_point.global_position, 7)

		# Immediately clean up summon visual now that boss exists
		if is_instance_valid(summon):
			summon.queue_free()

		# Allow a longer pause while the camera lingers on the summoned boss
		await get_tree().create_timer(BOSS_POST_SUMMON_PAUSE).timeout

		print("[BOSS] Resuming camera return to player")
		await _move_camera_to_position(player.global_position, 0.8)
	if frontlayer and frontlayer.has_method("set_camera_follow_enabled"):
		frontlayer.set_camera_follow_enabled(true)
	#Play the boss dialogue
	if !SignalBus.boss_dialogue_played:
		SignalBus.boss_dialogue_played = true
		boss_dialogue_running = true
		await get_tree().create_timer(1).timeout #let the boss animation finish first
		await play_boss_dialogue()
		boss_dialogue_running = false

	_set_player_controls_locked(false)

	boss_summon_in_progress = false
	boss_spawn_pending_position = Vector2.ZERO

func _create_boss_spawn_point(spawn_position: Vector2) -> Marker2D:
	if is_instance_valid(boss_spawn_point):
		boss_spawn_point.queue_free()

	boss_spawn_point = Marker2D.new()
	boss_spawn_point.name = "BossSpawnPoint"
	boss_spawn_point.global_position = spawn_position
	add_child(boss_spawn_point)
	return boss_spawn_point

func _find_valid_boss_spawn_position() -> Vector2:
	if frontlayer == null:
		return player.global_position + Vector2(240, -70)

	var player_tile = frontlayer.global_to_map(player.global_position)
	var bounds = frontlayer.get_world_bounds()
	var min_distance := 14
	var valid_tiles: Array[Vector2i] = []
	var far_tiles: Array[Vector2i] = []

	var min_x := int(floor(bounds.position.x / frontlayer.tile_size))
	var min_y := int(floor(bounds.position.y / frontlayer.tile_size))
	var max_x := int(ceil((bounds.position.x + bounds.size.x) / frontlayer.tile_size))
	var max_y := int(ceil((bounds.position.y + bounds.size.y) / frontlayer.tile_size))

	print("[BOSS] World bounds (pixels): ", bounds)
	print("[BOSS] World bounds (tiles): min=(", min_x, ",", min_y, ") max=(", max_x, ",", max_y, ")")

	for x in range(min_x, max_x):
		for y in range(min_y, max_y):
			var tile = Vector2i(x, y)
			if not frontlayer.is_tile_walkable(tile):
				continue
			valid_tiles.append(tile)
			if player_tile.distance_to(tile) >= min_distance:
				far_tiles.append(tile)

	var chosen_tile: Vector2i = Vector2i.ZERO
	if far_tiles.size() > 0:
		chosen_tile = far_tiles[randi() % far_tiles.size()]
	elif valid_tiles.size() > 0:
		chosen_tile = valid_tiles[randi() % valid_tiles.size()]
	else:
		chosen_tile = player_tile + Vector2i(6, -6)

	print("[BOSS] Selected boss spawn tile: ", chosen_tile, " valid_tiles=", valid_tiles.size(), " far_tiles=", far_tiles.size())
	return frontlayer.map_to_global(chosen_tile)


func _corrupt_tiles_around(spawn_position: Vector2) -> void:
	# Create a small, irregular burst of corruption overlay tiles (black / purple)
	if frontlayer == null:
		return

	var center_tile: Vector2i = frontlayer.global_to_map(spawn_position)
	var max_radius := 2
	var tile_budget := 18 + randi() % 10
	var spread_tiles: Array[Vector2i] = []

	# Generate a jittered cluster so the corruption looks rough and uneven rather than square.
	for attempt in range(0, tile_budget * 3):
		var radius := int(round(randf_range(0.0, max_radius)))
		var angle := randf() * TAU
		var drift_x := randi_range(-1, 1)
		var drift_y := randi_range(-1, 1)

		var dx := int(round(cos(angle) * radius)) + drift_x
		var dy := int(round(sin(angle) * radius)) + drift_y
		var t := center_tile + Vector2i(dx, dy)

		if not frontlayer.is_tile_walkable(t):
			continue
		if spread_tiles.has(t):
			continue

		spread_tiles.append(t)
		if spread_tiles.size() >= tile_budget:
			break

	if spread_tiles.is_empty():
		spread_tiles.append(center_tile)

	spread_tiles.shuffle()

	for t in spread_tiles:
		var pos = frontlayer.map_to_global(t)
		var node := Node2D.new()
		node.set_script(corruption_tile_script)
		if node is Node2D:
				# Parent corruption overlays to the frontlayer so their positions align
				# with the tilemap's local coordinates and transforms.
				frontlayer.add_child(node)
				# compute scaled tile size and center the overlay on the tile
				var tile_sz := int(frontlayer.tile_size * CORRUPTION_SCALE)
				node.set("tile_size", tile_sz)
				# frontlayer.to_local(pos) gives the tile position in frontlayer local coords
				var local_center := frontlayer.to_local(pos)
				# position node so its top-left aligns to center - half tile_sz
				node.position = local_center - Vector2(tile_sz / 2.0, tile_sz / 2.0)
				# place corruption overlay above tiles but below characters
				if node is CanvasItem:
					node.z_index = 5
				# Randomize color between black and purple
				var c = Color(0, 0, 0) if randi() % 2 == 0 else Color(0.45, 0.0, 0.45)
				node.set("color", c)
				# allow scaling handled earlier; no further action

		# small delay between tiles to create ripple
		await get_tree().create_timer(0.06).timeout

func _delayed_return_boss_summon() -> void:
	if not SignalBus.summon_boss_on_return or boss_summon_in_progress:
		return

	await get_tree().create_timer(BOSS_SUMMON_DELAY_ON_RETURN).timeout
	if boss_summon_in_progress:
		return

	SignalBus.summon_boss_on_return = false
	print("[BOSS] Starting boss summon after return delay")
	_begin_boss_summon_sequence()


func _screen_shake(duration: float = 0.7, intensity: float = 4.0) -> void:
	# Minimal camera shake centered on current camera global position
	if camera == null:
		return
	var original := camera.global_position
	var elapsed := 0.0
	var step := 0.02
	while elapsed < duration:
		var ox := (randf() * 2.0 - 1.0) * intensity
		var oy := (randf() * 2.0 - 1.0) * intensity
		camera.global_position = original + Vector2(ox, oy)
		await get_tree().create_timer(step).timeout
		elapsed += step
	# restore exact position
	camera.global_position = original

func _move_camera_to_position(target_position: Vector2, duration: float) -> void:
	if camera == null:
		return
	var tween = create_tween()
	tween.tween_property(camera, "global_position", target_position, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	await tween.finished

func _spawn_boss_enemy(spawn_position: Vector2, z_idx: int = -1) -> Node2D:
	var boss_instance = boss_scene.instantiate()

	if boss_instance is Node2D:
		boss_instance.global_position = spawn_position
		boss_instance.name = "BossSummon"

		if z_idx >= 0 and boss_instance is CanvasItem:
			boss_instance.z_index = z_idx

		add_child(boss_instance)

		if not boss_instance.is_in_group("overworldmob"):
			boss_instance.add_to_group("overworldmob")

		# Make this enemy a boss
		boss_instance.apply_spawn_type("boss")

		if boss_instance.has_method("apply_spawn_type"):
			boss_instance.apply_spawn_type("boss")
		elif boss_instance.has("enemy_tier"):
			boss_instance.enemy_tier = 2

		print("[STATE] Spawned overworld boss at: ", spawn_position)

		if frontlayer and frontlayer.has_signal("enemy_spawned"):
			frontlayer.emit_signal("enemy_spawned", boss_instance)

		return boss_instance

	return null
	
func get_overworld_state() -> Dictionary:
	var enemies = []
	for enemy in get_tree().get_nodes_in_group("overworldmob"):
		if enemy and enemy.is_inside_tree():
			var enemy_node = enemy as Node2D
			if enemy_node == null:
				continue
			var enemy_type := ""
			if enemy_node.has_method("get_spawn_type"):
				enemy_type = enemy_node.get_spawn_type()
			enemies.append({
				"name": enemy_node.name,
				"position": enemy_node.global_position,
				"enemy_type": enemy_type,
				"distance_to_player": player.global_position.distance_to(enemy_node.global_position)
			})

	var island_data = _collect_island_data()
	var player_tile = frontlayer.global_to_map(player.position)
	var world_map_data: Dictionary = {}
	if frontlayer and frontlayer.has_method("build_world_map_snapshot"):
		world_map_data = frontlayer.build_world_map_snapshot()

	return {
		"player_position": player_tile,
		"enemy_count": enemies.size(),
		"enemies": enemies,
		"islands": island_data,
		"world_map_data": world_map_data,
		"terrain_seeds": {
			"moisture": frontlayer.moisture.seed,
			"temperature": frontlayer.temperature.seed,
			"altitude": frontlayer.altitude.seed,
		},
		"world_bounds": frontlayer.get_world_bounds(),
		"world_size": frontlayer.get_world_size(),
	}

func _collect_island_data() -> Array:
	var world_map_ui = get_tree().get_first_node_in_group("worldmap_ui")
	if not world_map_ui:
		return []
	var island_info = []
	if "islands" in world_map_ui:
		for island in world_map_ui.islands:
			island_info.append({
				"size": island.size(),
				"tiles": island,
			})
	else:
		print("[STATE] world_map_ui has no islands data yet")
	return island_info
