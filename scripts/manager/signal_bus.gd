extends Node

#This signal sends specific mob data to the battle scene
var current_encounter : EncounterData
var in_transition := false
func start_battle(overworld_enemy):

	var encounter := EncounterData.new()

	encounter.enemy_count = randi_range(1,2)
	encounter.overworld_enemy = overworld_enemy

	current_encounter = encounter

	#await BattleTransition.play()

	call_deferred("_change_to_battle")
	
func _change_to_battle():
	SignalBus.in_transition = true
	await EncounterTransition.transition_to_battle(
		"res://scenes/battle/BattleScene.tscn"
	)
	SignalBus.in_transition = false
