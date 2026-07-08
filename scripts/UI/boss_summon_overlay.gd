extends Control

signal summon_finished

var _summon_finished_emitted := false
var _summon_fallback_timer: Timer

@onready var msg_container: PanelContainer = $MsgContainer
@onready var smn_player: AnimationPlayer = $MsgContainer/SmnPlayer
@onready var blink_rect: ColorRect = $BlinkRect
@onready var summon_msg: Label = $MsgContainer/MarginContainer/SummonMsg

func _ready() -> void:
	visible = false
	msg_container.visible = false
	blink_rect.visible = false
	summon_msg.visible = false
	summon_msg.text = ""
	print("summon overlay ready")
	

func summon_message():
	print("SUMMON MESSAGE CALLED")
	_summon_finished_emitted = false

	# Reset to a blank, hidden state before the animation starts so the full
	# text cannot flash briefly on the first frame.
	smn_player.stop()
	smn_player.seek(0.0)
	summon_msg.text = ""
	summon_msg.visible = false
	msg_container.visible = false
	blink_rect.visible = false
	visible = false
	
	visible = true
	msg_container.visible = true
	blink_rect.visible = true
	print("[OVERLAY] smn_player=", smn_player)
	print("[OVERLAY] has animation play_summon=", smn_player.has_animation("play_summon"))
	smn_player.play("play_summon")
	print("[OVERLAY] play() called")

	var anim = smn_player.get_animation("play_summon")
	var duration := 2.2
	if anim:
		duration = anim.length
	print("[OVERLAY] animation duration=", duration)

	if _summon_fallback_timer and _summon_fallback_timer.is_inside_tree():
		_summon_fallback_timer.queue_free()

	_summon_fallback_timer = Timer.new()
	_summon_fallback_timer.one_shot = true
	_summon_fallback_timer.wait_time = duration + 0.05
	_summon_fallback_timer.connect("timeout", Callable(self, "_on_summon_fallback_timer_timeout"))
	add_child(_summon_fallback_timer)
	_summon_fallback_timer.start()
	print("[OVERLAY] Fallback timer started")

func _on_summon_fallback_timer_timeout() -> void:
	print("[OVERLAY] Fallback timer fired")
	if not _summon_finished_emitted:
		_finish_summon()

func _finish_summon() -> void:
	visible = false
	blink_rect.visible = false
	msg_container.visible = false
	if _summon_finished_emitted:
		return
	_summon_finished_emitted = true
	print("[OVERLAY] summon_finished emitted")
	emit_signal("summon_finished")

func _on_smn_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "play_summon":
		print("[OVERLAY] animation_finished received: ", anim_name)
		_finish_summon()
