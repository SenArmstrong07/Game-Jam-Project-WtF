extends Node2D

@onready var player: Node2D = $OverworldPlayer
@onready var frontlayer: TileMapLayer = $TileNode/front

var overworld_state: Dictionary = {}

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

	# If we're returning from a battle transition, let the return transition play while the saved state is restored immediately.
	if SignalBus.in_transition:
		SignalBus.in_transition = false
	else:
		# Normal startup: capture and store current overworld state
		store_overworld_state()

func _on_world_generation_complete() -> void:
	_set_player_controls_locked(false)
	var loading_screen = get_node_or_null("LoadingScreen")
	if loading_screen and loading_screen.has_method("_hide_overlay"):
		loading_screen._hide_overlay()

func _on_simulate_remove_enemy_pressed() -> void:
	var nearest_enemy = _find_nearest_overworld_enemy()
	if nearest_enemy:
		_remove_overworld_enemy(nearest_enemy)
		store_overworld_state()
		print("[CYBERMAP] Removed nearest overworld enemy: ", nearest_enemy.name)
	else:
		print("[CYBERMAP] No overworld enemy found to remove")

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
	if not enemy or not enemy.is_inside_tree():
		return
	# Remove any marker linked by minimap system if present
	if enemy.has_signal("died"):
		enemy.emit_signal("died")
	# Remove the enemy node itself
	enemy.queue_free()

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
		#print("[CYBERMAP] _restore_overworld_state: cannot load overworld enemy scene")
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
		print("[CYBERMAP] world_map_ui has no islands data yet")
	return island_info
