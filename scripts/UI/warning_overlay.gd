extends Control

@onready var msg_container: PanelContainer = $MsgContainer
@onready var wrn_player: AnimationPlayer = $MsgContainer/WrnPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false
	print("warning overlay ready!")


func show_warning():
	print("SHOW WARNING CALLED")
	visible = true
	msg_container.visible = true
	wrn_player.play("show_warning")
