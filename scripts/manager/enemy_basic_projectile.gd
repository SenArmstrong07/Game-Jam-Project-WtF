extends Area2D

var direction := Vector2.LEFT
var speed := 500.0
var damage := 10

var hit := false

func _ready():
	body_entered.connect(_on_body_entered)
	add_to_group("enemy_projectiles")

func _process(delta):
	position += direction * speed * delta

func _on_body_entered(body):
	if hit:
		return

	print("Hit: ", body.name)

	if body is Unit:
		if body.is_dead:
			queue_free()
			return

		body.take_damage(damage)

	queue_free() 
