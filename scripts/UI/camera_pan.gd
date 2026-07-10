extends Camera2D

@export var intro_offset := Vector2(0, -80)
@export var intro_duration := 1.2

var target_position: Vector2

func _ready() -> void:
	target_position = global_position

	# Camera starts above the battlefield before the first frame
	global_position += intro_offset


func play_intro() -> void:

	var tween := create_tween()

	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		self,
		"global_position",
		target_position,
		intro_duration
	)

	await tween.finished


func shake(
	intensity: float = 8.0,
	duration: float = 0.20
) -> void:

	var start := global_position

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var elapsed := 0.0

	while elapsed < duration:

		global_position = start + Vector2(
			rng.randf_range(-intensity, intensity),
			rng.randf_range(-intensity, intensity)
		)

		elapsed += get_process_delta_time()
		await get_tree().process_frame

	global_position = start
