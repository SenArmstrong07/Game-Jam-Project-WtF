extends Control

@onready var msg_container: PanelContainer = $MsgContainer
@onready var msg_player: AnimationPlayer = $MsgContainer/MsgPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false
	print("victory overlay ready")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func show_victory():
	print("SHOW VICTORY CALLED")
	visible = true
	msg_container.visible = true
	msg_player.play("victory_reveal")
	
func _input(event):
	if !visible:
		return
	if event.is_action_pressed("continue"):
		print("Emitting Signal!")
		SignalBus.victory_continue.emit()
