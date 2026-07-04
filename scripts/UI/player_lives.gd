extends Control

@onready var hit_points: Label = $Player_Life_Counter/MarginContainer/HitPoints
@onready var hp_bar: HBoxContainer = $Player_Life_Counter/HPBar

@export var slide_distance := 80.0
@export var slide_time := 0.35

var start_position: Vector2
var slide_tween: Tween

func _ready():
	await get_tree().process_frame

	start_position = position

	position = start_position + Vector2(0, -slide_distance)

	visible = false
	
# Call this whenever the player's HP changes
func update_player_lives(current_lives: int) -> void:
	# Number text
	hit_points.text = str(current_lives)

	# Heart/HP bar
	for i in hp_bar.get_child_count():
		var heart = hp_bar.get_child(i)

		if i < current_lives:
			heart.modulate = Color.WHITE
		else:
			heart.modulate = Color(1.0, 0.604, 0.596, 0.416) # faded

func show_hp_ui():

	if slide_tween:
		slide_tween.kill()

	visible = true
	position = start_position + Vector2(0, -slide_distance)

	slide_tween = create_tween()
	slide_tween.set_trans(Tween.TRANS_BACK)
	slide_tween.set_ease(Tween.EASE_OUT)

	slide_tween.tween_property(
		self,
		"position",
		start_position,
		slide_time
	)
	
func hide_hp_ui():

	if slide_tween:
		slide_tween.kill()

	slide_tween = create_tween()
	slide_tween.set_trans(Tween.TRANS_QUAD)
	slide_tween.set_ease(Tween.EASE_IN)

	slide_tween.tween_property(
		self,
		"position",
		start_position + Vector2(0, -slide_distance),
		0.25
	)

	await slide_tween.finished

	visible = false
