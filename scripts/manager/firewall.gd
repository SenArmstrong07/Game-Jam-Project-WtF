extends Node2D
class_name Firewall

@export var duration := 5.0
@export var hp := 3

signal firewall_destroyed(grid_pos: Vector2i)

var grid_pos: Vector2i

@onready var tile_fx: ColorRect = $TileFx
@onready var fire_anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var overlay_fx: ColorRect = $OverlayFX
@onready var lifetime_timer: Timer = $LifetimeTimer



func _ready():
	# =========================
	# TILE (GROUND LAYER)
	# =========================
	tile_fx.size = Vector2(64, 64)
	tile_fx.position = Vector2(-32, -32)
	tile_fx.color = Color(1.0, 0.35, 0.0, 0.25)
	tile_fx.z_index = 0  # BELOW characters

	# =========================
	# FIRE ANIMATION (MID LAYER)
	# =========================
	fire_anim.z_index = 15
	fire_anim.play("Anim") 

	# =========================
	# OVERLAY (TOP GLOW)
	# =========================
	overlay_fx.size = Vector2(64, 64)
	overlay_fx.position = Vector2(-32, -32)
	overlay_fx.color = Color(1.0, 0.5, 0.0, 0.35)
	overlay_fx.z_index = 4

	# =========================
	# LIFETIME
	# =========================
	lifetime_timer.wait_time = duration
	lifetime_timer.start()


func _process(delta):
	# pulsing glow effect
	var pulse = abs(sin(Time.get_ticks_msec() * 0.01))

	overlay_fx.color = Color(
		1.0,
		0.3 + pulse * 0.5,
		0.0,
		0.2 + pulse * 0.4
	)

	# slight flicker on sprite
	fire_anim.modulate = Color(1, 1, 1, 0.8 + pulse * 0.2)


func _on_lifetime_timer_timeout():
	firewall_destroyed.emit(grid_pos)
	queue_free()


func _on_area_2d_area_entered(area):
	if area.is_in_group("enemy_projectiles"):
		area.queue_free()

		hp -= 1

		if hp <= 0:
			firewall_destroyed.emit(grid_pos)
			queue_free()
