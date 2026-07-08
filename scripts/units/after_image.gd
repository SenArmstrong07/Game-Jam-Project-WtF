extends Node2D

@onready var ghost_sprite: AnimatedSprite2D = $ghost_sprite



func setup(source: AnimatedSprite2D):
	ghost_sprite.sprite_frames = source.sprite_frames
	ghost_sprite.animation = source.animation
	ghost_sprite.frame = source.frame
	ghost_sprite.flip_h = source.flip_h
	ghost_sprite.flip_v = source.flip_v
	ghost_sprite.scale = source.scale
	ghost_sprite.rotation = source.rotation

	modulate = Color(1, 1, 1, 0.7)

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.finished.connect(queue_free)
