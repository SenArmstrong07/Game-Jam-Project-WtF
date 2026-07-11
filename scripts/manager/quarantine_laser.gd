extends Area2D
const ISOLATION = preload("uid://ctcutosgfkvp5")

var direction: Vector2 = Vector2.RIGHT
var speed: float = 900.0
var damage: int = 10
var stun_duration: float = 2.0
var chip: Chip = null

var hit := false

func _ready():
	body_entered.connect(_on_body_entered)
	play_sfx(ISOLATION, -15)
	add_to_group("projectiles")
	
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
	if hit:
		return

	if body is Unit:
		hit = true

		body.take_damage(damage, Unit.DamageType.NEUTRAL, chip)

		if body.has_method("apply_stun"):
			body.apply_stun(stun_duration)

		queue_free()
