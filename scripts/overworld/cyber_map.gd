extends Node2D

@onready var player: Node2D = $OverworldPlayer
@onready var frontlayer: TileMapLayer = $TileNode/front
@onready var boss_summon_overlay: Control = $UI/Boss_Summon_Overlay
@onready var camera: Camera2D = $Camera2D

var overworld_state: Dictionary = {}
var boss_summon_in_progress := false
var boss_spawn_point: Marker2D
var boss_scene: PackedScene = preload("res://scenes/units/overworld_enemy.tscn")
const BOSS_SUMMON_DELAY_ON_RETURN := 1.5

func _ready() -> void:
	BattleBgm.stop()
	BgTitleToDial.stop()
	add_to_group("Cybermap")

	var loading_screen = get_node_or_null("LoadingScreen")
	var should_show_loading_screen := not SignalBus.in_transition and SignalBus.overworld_state.is_empty()
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

	if boss_summon_overlay and not boss_summon_overlay.is_connected("summon_finished", _on_boss_summon_finished):
		boss_summon_overlay.summon_finished.connect(_on_boss_summon_finished)

	# If we're returning from a battle transition, let the return transition play while the saved state is restored immediately.
	if SignalBus.in_transition:
		SignalBus.in_transition = false
	else:
		# Normal startup: capture and store current overworld state
		store_overworld_state()

func _on_world_generation_complete() -> void:
	_set_player_controls_locked(false)
	ensure_one_elite()
	
	var loading_screen = get_node_or_null("LoadingScreen")
	if loading_screen and loading_screen.has_method("_hide_overlay"):
		loading_screen._hide_overlay()

	if SignalBus.summon_boss_on_return and not boss_summon_in_progress:
		print("[BOSS] Delaying boss summon on overworld return by ", BOSS_SUMMON_DELAY_ON_RETURN, " seconds")
		call_deferred("_delayed_return_boss_summon")

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
	overworld_state = get_overworld_state()
	SignalBus.overworld_state = overworld_state

func _set_player_controls_locked(locked: bool) -> void:
	if player and player.has_method("set_controls_locked"):
		player.set_controls_locked(locked)
	elif player:
		player.controls_locked = locked


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
	print("[BOSS] Spawning boss")
	_spawn_boss_enemy(spawn_point.global_position)
	print("[BOSS] Boss spawned, pausing before camera return")
	await get_tree().create_timer(1.7).timeout
	print("[BOSS] Resuming camera return to player")
	await _move_camera_to_position(player.global_position, 0.8)
	if frontlayer and frontlayer.has_method("set_camera_follow_enabled"):
		frontlayer.set_camera_follow_enabled(true)
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

func _delayed_return_boss_summon() -> void:
	if not SignalBus.summon_boss_on_return or boss_summon_in_progress:
		return

	await get_tree().create_timer(BOSS_SUMMON_DELAY_ON_RETURN).timeout
	if boss_summon_in_progress:
		return

	SignalBus.summon_boss_on_return = false
	print("[BOSS] Starting boss summon after return delay")
	_begin_boss_summon_sequence()

func _move_camera_to_position(target_position: Vector2, duration: float) -> void:
	if camera == null:
		return
	var tween = create_tween()
	tween.tween_property(camera, "global_position", target_position, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	await tween.finished

func _spawn_boss_enemy(spawn_position: Vector2) -> void:
	var boss_instance = boss_scene.instantiate()
	if boss_instance is Node2D:
		boss_instance.global_position = spawn_position
		boss_instance.name = "BossSummon"
		add_child(boss_instance)
		if not boss_instance.is_in_group("overworldmob"):
			boss_instance.add_to_group("overworldmob")
		print("[STATE] Spawned overworld boss at: ", spawn_position)
		if frontlayer and frontlayer.has_signal("enemy_spawned"):
			print("[STATE] Emitting enemy_spawned for minimap")
			frontlayer.emit_signal("enemy_spawned", boss_instance)
		else:
			print("[STATE] frontlayer signal enemy_spawned unavailable")

func get_overworld_state() -> Dictionary:
	var enemies = []
	for enemy in get_tree().get_nodes_in_group("overworldmob"):
		if enemy and enemy.is_inside_tree():
			var enemy_node = enemy as Node2D
			if enemy_node == null:
				continue
			enemies.append({
				"name": enemy_node.name,
				"position": enemy_node.global_position,
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
