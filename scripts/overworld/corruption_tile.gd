extends Node2D

@export var tile_size: int = 64
@export var color: Color = Color(0, 0, 0)
@export var lifetime: float = 9999.0

func _ready() -> void:
	# start invisible and fade in
	modulate.a = 0.0
	# schedule a redraw if supported (some base types may not expose update())
	if has_method("update"):
		call_deferred("update")
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.12)
	if lifetime > 0 and lifetime < 9999.0:
		# fade out after lifetime
		await get_tree().create_timer(lifetime).timeout
		if is_instance_valid(self):
			var t2 = create_tween()
			t2.tween_property(self, "modulate:a", 0.0, 0.3)
			await t2.finished
			queue_free()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(tile_size, tile_size)), color)

func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		if has_method("update"):
			# Ensure we use discrete drawing
			call_deferred("update")
