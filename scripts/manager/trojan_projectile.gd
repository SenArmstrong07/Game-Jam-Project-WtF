extends Area2D

@export var speed := 550.0

var direction := Vector2.LEFT
var damage := 20

var shooter: Unit = null
var hit := false

const ENEMY_PROJECTILE = preload("uid://bnle2l36i7wf4")

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

func _ready():
	play_sfx(ENEMY_PROJECTILE, -15)
	body_entered.connect(_on_body_entered)
	add_to_group("enemy_projectiles")
	
	

func _process(delta):
	position += direction * speed * delta

func _on_body_entered(body):

	if hit:
		return

	if !(body is Unit):
		return

	# Ignore the shooter itself
	if body == shooter:
		return

	# Ignore teammates
	if shooter != null and body.team == shooter.team:
		return

	hit = true

	body.take_damage(damage)

	queue_free()
