extends SceneTree

func _init() -> void:
    var quest_logic = load("res://scripts/overworld/quest_ui_controller.gd").new()
    quest_logic._set_mission_state("debug_viruses", true)
    quest_logic._set_mission_state("debug_elites", true)

    var summary = quest_logic._get_progress_summary()
    assert(summary["active_mission"] == "final_boss")
    assert(summary["completed_count"] == 2)
    assert(summary["remaining_common"] == 0)
    assert(summary["remaining_elite"] == 0)

    print("Quest logic tests passed")
    quit()
