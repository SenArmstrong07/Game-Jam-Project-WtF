extends CanvasLayer

@onready var control: Control = $Control
@onready var msg_container: ColorRect = $Control/MsgContainer
@onready var victory_message: Label = $Control/MsgContainer/VictoryMessage

var can_continue := false
var pulse_tween: Tween

func _ready() -> void:
	layer = 100
	visible = false
	can_continue = false

	msg_container.modulate.a = 0.0
	victory_message.scale = Vector2.ONE

	await get_tree().process_frame
	victory_message.pivot_offset = victory_message.size * 0.5


func show_victory() -> void:
	if get_parent():
		get_parent().move_child(self, get_parent().get_child_count() - 1)

	layer = 100

	if pulse_tween:
		pulse_tween.kill()

	visible = true
	can_continue = false
	msg_container.visible = true

	# Reset
	msg_container.modulate.a = 0.0
	victory_message.scale = Vector2.ONE

	# Update pivot in case the label resized
	victory_message.pivot_offset = victory_message.size * 0.5

	# Fade in only the container
	var tween := create_tween()
	tween.tween_property(msg_container, "modulate:a", 1.0, 0.3)

	await tween.finished

	can_continue = true

	# Pulse only the text
	pulse_tween = create_tween()
	pulse_tween.set_loops()

	pulse_tween.tween_property(
		victory_message,
		"scale",
		Vector2(1.08, 1.08),
		0.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	pulse_tween.tween_property(
		victory_message,
		"scale",
		Vector2.ONE,
		0.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _input(event):
	if !visible or !can_continue:
		return

	if event.is_action_pressed("continue"):
		SignalBus.victory_continue.emit()
