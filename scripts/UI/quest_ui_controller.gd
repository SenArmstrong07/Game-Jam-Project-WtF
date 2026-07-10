extends CanvasLayer

@onready var container: Control = $Container
@onready var label_1: Label = $Container/TEXT_CONTAINER/QUEST_CONTAINER/LIST_1/LIST_1_LABEL
@onready var label_2: Label = $Container/TEXT_CONTAINER/QUEST_CONTAINER/LIST_2/LIST_2_LABEL
@onready var label_3: Label = $Container/TEXT_CONTAINER/QUEST_CONTAINER/LIST_3/LIST_3_LABEL
@onready var label_4: Label = $Container/TEXT_CONTAINER/QUEST_CONTAINER/LIST_4/LIST_4_LABEL
@onready var label_5: Label = $Container/TEXT_CONTAINER/QUEST_CONTAINER/LIST_5/LIST_5_LABEL
@onready var icon_1: TextureRect = $Container/TEXT_CONTAINER/QUEST_CONTAINER/LIST_1/ICON_1
@onready var icon_2: TextureRect = $Container/TEXT_CONTAINER/QUEST_CONTAINER/LIST_2/ICON_2
@onready var icon_3: TextureRect = $Container/TEXT_CONTAINER/QUEST_CONTAINER/LIST_3/ICON_3
@onready var icon_4: TextureRect = $Container/TEXT_CONTAINER/QUEST_CONTAINER/LIST_4/ICON_4
@onready var icon_5: TextureRect = $Container/TEXT_CONTAINER/QUEST_CONTAINER/LIST_5/ICON_5

var icon_textures: Dictionary = {
	"common": preload("res://assets/ui/enemy_marker.png"),
	"elite": preload("res://assets/ui/elite_marker.png"),
	"boss": preload("res://assets/ui/boss_marker.png")
}

var mission_states: Dictionary = {
	"debug_viruses": {"completed": false, "count": 0},
	"debug_elites": {"completed": false, "count": 0},
	"final_boss": {"completed": false, "count": 0},
}

var final_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	visible = false
	_update_quest_ui()
	set_process(true)
	call_deferred("_finish_ready")

func _finish_ready() -> void:
	await get_tree().process_frame

	var viewport_size = get_viewport().get_visible_rect().size

	final_position = Vector2(
		(viewport_size.x - container.size.x) * 0.5,
		(viewport_size.y - container.size.y) * 0.5
	)

	container.position = Vector2(
		final_position.x,
		viewport_size.y + 120
	)

func _process(_delta: float) -> void:
	_update_quest_ui()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_quest"):
		var cybermap = get_tree().get_first_node_in_group("Cybermap")
		if cybermap and cybermap.has_method("is_event_in_progress") and cybermap.is_event_in_progress():
			return
		if visible:
			_hide_with_slide()
		else:
			_show_with_slide()

func toggle_quest_ui() -> void:
	if visible:
		_hide_with_slide()
	else:
		_show_with_slide()

func _show_with_slide() -> void:
	visible = true
	container.position = Vector2(final_position.x, get_viewport().get_visible_rect().size.y + 120)
	var tween = create_tween()
	tween.tween_property(container, "position:y", final_position.y, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _hide_with_slide() -> void:
	var tween = create_tween()
	var offscreen_y = get_viewport().get_visible_rect().size.y + 120
	tween.tween_property(container, "position:y", offscreen_y, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	visible = false
	container.position = Vector2(final_position.x, offscreen_y)

func _update_quest_ui() -> void:
	var enemies = get_tree().get_nodes_in_group("overworldmob")
	var common_remaining := 0
	var elite_remaining := 0
	var boss_present := false

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var tier = enemy.get("enemy_tier")
		if tier == 1:
			elite_remaining += 1
		elif tier == 2:
			boss_present = true
		else:
			common_remaining += 1

	mission_states["debug_viruses"]["count"] = common_remaining
	mission_states["debug_elites"]["count"] = elite_remaining
	mission_states["debug_viruses"]["completed"] = common_remaining <= 0
	mission_states["debug_elites"]["completed"] = elite_remaining <= 0

	if boss_present:
		_set_label_state(label_1, icon_1, null, "", false, false)
		_set_label_state(label_2, icon_2, null, "", false, false)
		_set_label_state(label_3, icon_3, icon_textures["boss"], "3. DEFEAT THE FINAL BOSS", false, true)
		_set_label_state(label_4, icon_4, null, "", false, false)
		_set_label_state(label_5, icon_5, null, "", false, false)
		mission_states["final_boss"]["completed"] = false
		return

	if mission_states["debug_viruses"]["completed"] and mission_states["debug_elites"]["completed"]:
		_set_label_state(label_1, icon_1, null, "", false, false)
		_set_label_state(label_2, icon_2, null, "", false, false)
		_set_label_state(label_3, icon_3, icon_textures["boss"], "3. DEFEAT THE FINAL BOSS", false, true)
		_set_label_state(label_4, icon_4, null, "", false, false)
		_set_label_state(label_5, icon_5, null, "", false, false)
		return

	_set_label_state(
		label_1,
		icon_1,
		icon_textures["common"],
		"1. D3BUG VIRUSES - %d left" % common_remaining,
		mission_states["debug_viruses"]["completed"],
		true
	)
	_set_label_state(
		label_2,
		icon_2,
		icon_textures["elite"],
		"2. D3BUG ELITE VIRUSES - %d left" % elite_remaining,
		mission_states["debug_elites"]["completed"],
		true
	)
	_set_label_state(label_3, icon_3, null, "", false, false)
	_set_label_state(label_4, icon_4, null, "", false, false)
	_set_label_state(label_5, icon_5, null, "", false, false)

func _set_label_state(label: Label, icon: TextureRect, icon_texture: Texture2D, text: String, completed: bool, visible_flag: bool) -> void:
	if label == null or icon == null:
		return
	label.visible = visible_flag
	icon.visible = visible_flag
	if not visible_flag:
		return
	label.text = text
	label.modulate = Color(0.75, 1.0, 0.75) if completed else Color.WHITE
	icon.texture = icon_texture

func _set_mission_state(mission_key: String, completed: bool) -> void:
	if mission_states.has(mission_key):
		mission_states[mission_key]["completed"] = completed
		_update_quest_ui()

func _get_progress_summary() -> Dictionary:
	return {
		"active_mission": "final_boss" if mission_states["debug_viruses"]["completed"] and mission_states["debug_elites"]["completed"] else "debug_viruses",
		"completed_count": int(mission_states["debug_viruses"]["completed"]) + int(mission_states["debug_elites"]["completed"]),
		"remaining_common": mission_states["debug_viruses"]["count"],
		"remaining_elite": mission_states["debug_elites"]["count"],
	}
