extends TextureRect

@export var amplitude := 2.0      # How many pixels it moves
@export var speed := 10.0           # How fast it bounces

var start_position: Vector2
var time := 0.0

func _ready():
	start_position = position

func _process(delta):
	if !visible:
		return

	time += delta
	position.y = start_position.y + sin(time * speed) * amplitude
