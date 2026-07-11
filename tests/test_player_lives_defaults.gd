extends SceneTree

func _init() -> void:
	var signal_bus = load("res://scripts/manager/signal_bus.gd").new()
	assert(signal_bus.player_lives == 3)
	assert(signal_bus.max_player_lives == 3)
	print("Player lives default tests passed")
	quit()
