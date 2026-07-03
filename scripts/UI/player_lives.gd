extends Control

@onready var hit_points: Label = $Player_Life_Counter/MarginContainer/HitPoints
@onready var hp_bar: HBoxContainer = $Player_Life_Counter/HPBar

# Call this whenever the player's HP changes
func update_player_lives(current_lives: int) -> void:
	# Number text
	hit_points.text = str(current_lives)

	# Heart/HP bar
	for i in hp_bar.get_child_count():
		var heart = hp_bar.get_child(i)

		if i < current_lives:
			heart.visible = true
		else:
			heart.visible = false
