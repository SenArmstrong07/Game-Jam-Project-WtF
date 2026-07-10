extends Area2D

@export var speed := 600.0
const DELETE = preload("uid://bmjv1s0irpupu")

var direction := Vector2.RIGHT
var damage := 0
var chip: Chip

var hit_target := false

func _ready():
	body_entered.connect(_on_body_entered)
	play_sfx(DELETE, -15)
	
func play_sfx(
	stream: AudioStream,
	volume_db: float = 0.0,
	pitch_scale: float = 1.0,
	bus: String = "Master"
):
	if stream == null:
		return

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.bus = bus

	get_tree().current_scene.add_child(player)

	player.play()

	player.finished.connect(func():
		player.queue_free()
	)

func _process(delta):
	position += direction * speed * delta

func _on_body_entered(body):

	if hit_target:
		return

	if body is Unit:

		hit_target = true

		print("REFORMAT hit ", body.name)

		body.take_damage(
			damage,
			Unit.DamageType.NEUTRAL,
			chip
		)

		queue_free()
