extends Node2D
class_name SplashScreen

@onready var animation_player: AnimationPlayer = $AnimationPlayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	BattleBgm.stop()	
	animation_player.play("black_in")
	await animation_player.animation_finished
	
	animation_player.play("black_out")
	await animation_player.animation_finished
	
	start_title_screen()

	
func start_title_screen():
	get_tree().change_scene_to_file("res://scenes/UI/TitleScreen.tscn")
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
