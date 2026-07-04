extends Node

#This signal sends specific mob data to the battle scene
var current_encounter : EncounterData
var in_transition := false
var overworld_state : Dictionary = {}
func start_battle(overworld_enemy):

	var encounter := EncounterData.new()

	encounter.enemy_count = randi_range(1,2)
	encounter.overworld_enemy = overworld_enemy
	encounter.overworld_enemy_position = overworld_enemy.global_position

	current_encounter = encounter

	#await BattleTransition.play()

	call_deferred("_change_to_battle")
	
func _change_to_battle() -> void:
	SignalBus.in_transition = true

	# Wait until the current frame has actually been drawn.
	await RenderingServer.frame_post_draw

	await EncounterTransition.transition_to_battle(
		"res://scenes/battle/Battlescene.tscn"
	)

func return_to_overworld():

	var enemy = current_encounter.overworld_enemy

	# Remove defeated enemy from the current overworld
	if is_instance_valid(enemy):
		enemy.queue_free()
		await get_tree().process_frame

	# Remove the defeated enemy from the SAVED overworld state
	var defeated_pos = current_encounter.overworld_enemy_position

	if overworld_state.has("enemies"):
		overworld_state["enemies"] = overworld_state["enemies"].filter(
			func(e):
				return e["position"] != defeated_pos
		)

	in_transition = true

	get_tree().change_scene_to_file(
		"res://scenes/overworld/CyberMap.tscn"
	)

	await EncounterTransition.transition_to_overworld()

	in_transition = false
