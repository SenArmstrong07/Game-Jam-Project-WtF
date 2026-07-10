extends SceneTree

func _init() -> void:
	var quest_logic = load("res://scripts/UI/quest_ui_controller.gd").new()
	var boss_node = Node.new()
	boss_node.add_to_group("overworldmob")
	boss_node.set("enemy_tier", 2)
	get_root().add_child(boss_node)

	quest_logic._update_quest_ui()

	var summary = quest_logic._get_progress_summary()
	assert(summary["active_mission"] == "final_boss")
	assert(summary["completed_count"] == 2)
	assert(summary["remaining_common"] == 0)
	assert(summary["remaining_elite"] == 0)

	print("Quest logic tests passed")
	quit()
