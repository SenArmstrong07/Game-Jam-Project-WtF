extends Control

@onready var msg_container: PanelContainer = $MsgContainer
@onready var smn_player: AnimationPlayer = $MsgContainer/SmnPlayer
@onready var blink_rect: ColorRect = $BlinkRect
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false
	print("summon overlay ready")
	
func summon_message():
	print("SUMMON MESSAGE CALLED")
	print(blink_rect.size)
	visible = true
	blink_rect.visible = true
	msg_container.visible = true
	smn_player.play("play_summon")
	print(smn_player.current_animation)
	print(smn_player.is_playing())


func _on_smn_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "play_summon":
		visible = false
