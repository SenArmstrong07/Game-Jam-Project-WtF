extends Node

# THIS ARE BATTLESCENES (NOT ENEMY SCENES)
const COMMON_BUG = preload("res://scenes/battle/Battlescene.tscn")
const THROW_BUG = preload("res://scenes/battle/Battlescene2.tscn")
const TROJAN_ELITE = preload("res://scenes/battle/Battlescene3.tscn")
const BOSS_SPAG = preload("res://scenes/battle/BossScene1.tscn")


const BATTLE_POOL = [
	COMMON_BUG,
	THROW_BUG,
	TROJAN_ELITE
]

#story signals
var overworld_intro_played := false
var boss_dialogue_played := false

var current_encounter: EncounterData
var in_transition := false
var summon_boss_on_return := false
var overworld_state: Dictionary = {}
var player_lives: int = 5
var max_player_lives: int = 5
var respawn_to_safe_spawn := false

const SAVE_GAME_PATH := "user://saved_game.cfg"

# Victory signals
signal battle_won
signal victory_continue


func has_saved_game_state() -> bool:
	var config := ConfigFile.new()
	var err := config.load(SAVE_GAME_PATH)
	if err != OK:
		return false
	return config.has_section("save_state") and config.has_section_key("save_state", "overworld_state")


func save_current_game_state() -> bool:
	var snapshot: Dictionary = {}
	var scene_root = get_tree().current_scene
	if not is_instance_valid(scene_root):
		scene_root = get_tree().get_first_node_in_group("Cybermap")

	if is_instance_valid(scene_root):
		if scene_root.has_method("get_overworld_state"):
			snapshot = scene_root.get_overworld_state().duplicate(true)
		elif scene_root.has_method("store_overworld_state"):
			scene_root.store_overworld_state()
			snapshot = overworld_state.duplicate(true)

	if snapshot.is_empty() and not overworld_state.is_empty():
		snapshot = overworld_state.duplicate(true)

	if snapshot.is_empty():
		return false

	var config := ConfigFile.new()
	config.set_value("save_state", "version", 1)
	config.set_value("save_state", "timestamp", Time.get_datetime_string_from_system(false, true))
	config.set_value("save_state", "player_lives", player_lives)
	config.set_value("save_state", "max_player_lives", max_player_lives)
	config.set_value("save_state", "overworld_intro_played", overworld_intro_played)
	config.set_value("save_state", "boss_dialogue_played", boss_dialogue_played)
	config.set_value("save_state", "summon_boss_on_return", summon_boss_on_return)
	config.set_value("save_state", "overworld_state", snapshot)

	var err := config.save(SAVE_GAME_PATH)
	return err == OK


func load_saved_game_state() -> Dictionary:
	var config := ConfigFile.new()
	var err := config.load(SAVE_GAME_PATH)
	if err != OK:
		return {}

	var loaded_state: Dictionary = config.get_value("save_state", "overworld_state", {})
	if loaded_state is Dictionary and not loaded_state.is_empty():
		overworld_state = loaded_state.duplicate(true)
		SignalBus.overworld_state = overworld_state.duplicate(true)
	else:
		return {}

	player_lives = int(config.get_value("save_state", "player_lives", player_lives))
	max_player_lives = int(config.get_value("save_state", "max_player_lives", max_player_lives))
	overworld_intro_played = bool(config.get_value("save_state", "overworld_intro_played", overworld_intro_played))
	boss_dialogue_played = bool(config.get_value("save_state", "boss_dialogue_played", boss_dialogue_played))
	summon_boss_on_return = bool(config.get_value("save_state", "summon_boss_on_return", summon_boss_on_return))

	return overworld_state.duplicate(true)


func cache_overworld_state() -> void:
	var snapshot: Dictionary = {}
	var scene_root = get_tree().current_scene
	if not is_instance_valid(scene_root):
		scene_root = get_tree().get_first_node_in_group("Cybermap")

	if is_instance_valid(scene_root):
		if scene_root.has_method("get_overworld_state"):
			snapshot = scene_root.get_overworld_state().duplicate(true)
			print("[SIGNAL_BUS] Cached overworld state from live scene; enemies=", snapshot.get("enemy_count", 0))
		elif scene_root.has_method("store_overworld_state"):
			scene_root.store_overworld_state()
			snapshot = overworld_state.duplicate(true)
			print("[SIGNAL_BUS] Cached overworld state through cybermap store")

	if snapshot.is_empty() and not overworld_state.is_empty():
		snapshot = overworld_state.duplicate(true)
		print("[SIGNAL_BUS] Reusing cached overworld state")

	if not snapshot.is_empty():
		overworld_state = snapshot.duplicate(true)
		SignalBus.overworld_state = overworld_state.duplicate(true)

func start_battle(overworld_enemy):
	cache_overworld_state()
	player_lives = max(0, player_lives)

	var encounter := EncounterData.new()

	encounter.overworld_enemy = overworld_enemy
	encounter.overworld_enemy_position = overworld_enemy.global_position

	# Use the battle already assigned to this enemy
	encounter.battle_scene = overworld_enemy.battle_scene

	current_encounter = encounter

	call_deferred("_change_to_battle")


func _change_to_battle() -> void:

	in_transition = true

	await RenderingServer.frame_post_draw

	await EncounterTransition.transition_to_battle(
		current_encounter.battle_scene.resource_path
	)

func return_to_overworld(lost_battle: bool = false):
	respawn_to_safe_spawn = lost_battle
	cache_overworld_state()

	var enemy = current_encounter.overworld_enemy if current_encounter else null

	if not lost_battle and is_instance_valid(enemy):
		enemy.queue_free()
		await get_tree().process_frame

	if not lost_battle and current_encounter != null:
		#Return to overworld and remove defeated enemy from overworld state
		var defeated_pos = current_encounter.overworld_enemy_position
		if overworld_state.has("enemies"):
			overworld_state["enemies"] = overworld_state["enemies"].filter(
				func(e):
					return e["position"] != defeated_pos
			)
			if overworld_state["enemies"].is_empty():
				summon_boss_on_return = true
				print("[SIGNAL_BUS] Last overworld enemy defeated; boss summon queued on return")

	in_transition = true

	get_tree().change_scene_to_file(
		"res://scenes/overworld/CyberMap.tscn"
	)

	await EncounterTransition.transition_to_overworld()

	in_transition = false
