extends Node

# THIS ARE BATTLESCENES (NOT ENEMY SCENES)
const COMMON_BUG = preload("res://scenes/battle/Battlescene.tscn")
const THROW_BUG = preload("res://scenes/battle/Battlescene2.tscn")
const TROJAN_ELITE = preload("res://scenes/battle/Battlescene3.tscn")

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

# Victory signals
signal battle_won
signal victory_continue


func start_battle(overworld_enemy):

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

func return_to_overworld():

	var enemy = current_encounter.overworld_enemy

	# Remove defeated overworld enemy
	if is_instance_valid(enemy):
		enemy.queue_free()
		await get_tree().process_frame

	# Remove it from saved overworld state
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
