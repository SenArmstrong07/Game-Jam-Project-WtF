extends Area2D
const PATCH_MAYBE = preload("uid://ckvnavbanq64e")

var target: Unit
var damage: int = 10
var chip: Chip = null
var speed := 300.0

@onready var gpu_particles_2d_2: GPUParticles2D = $GPUParticles2D2
@onready var particles: GPUParticles2D = $GPUParticles2D
var trail_angle := 0.0
const TRAIL_RADIUS := 20.0
const TRAIL_SPEED := 15.0

func _ready():
	particles.emitting = true
	play_sfx(PATCH_MAYBE, -15)
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
	trail_angle += TRAIL_SPEED * delta

	gpu_particles_2d_2.position = Vector2(
		cos(trail_angle),
		sin(trail_angle)
	) * TRAIL_RADIUS

	particles.position = Vector2(
		cos(trail_angle + PI),
		sin(trail_angle + PI)
	) * TRAIL_RADIUS
	if !is_instance_valid(target):
		queue_free()
		return

	var target_pos := target.global_position

	var hit_point := target.find_child("HitPoint", true, false)
	if is_instance_valid(hit_point):
		target_pos = hit_point.global_position

	var dir = global_position.direction_to(target_pos)

	rotation = lerp_angle(rotation, dir.angle(), 8.0 * delta)
	global_position += dir * speed * delta

	if global_position.distance_to(target_pos) < 10:
		if is_instance_valid(target):
			target.take_damage(damage, Unit.DamageType.NEUTRAL, chip)

		queue_free()
		set_process(false) # stop immediately
		return
