extends Area2D

var target: Unit
var damage: int = 10
var chip: Chip = null
var speed := 300.0

@onready var particles: GPUParticles2D = $GPUParticles2D

func _ready():
	particles.emitting = true

func _process(delta):
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
