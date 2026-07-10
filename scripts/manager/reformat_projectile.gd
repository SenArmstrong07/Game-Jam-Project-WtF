extends Area2D

@export var speed := 700.0
const DELETE_BUT_4_REFORMAT = preload("uid://bmjv1s0irpupu")

var direction := Vector2.RIGHT
var damage := 0
var chip: Chip

func _ready():
	print("REFORMAT SPAWNED")
	play_sfx(DELETE_BUT_4_REFORMAT, -15, -1.0)
	
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
func _physics_process(delta):
	position += direction * speed * delta
	print(position)

func _on_body_entered(body):
	print("COLLIDED WITH:", body.name)

	if body is Unit:
		print("DAMAGING")
		body.take_damage(damage, Unit.DamageType.NEUTRAL, chip)
		queue_free()
