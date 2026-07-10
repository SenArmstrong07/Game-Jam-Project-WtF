extends Node2D
class_name Firewall

const FIREWALL = preload("uid://r7b0kh8j4p6e")

@export var duration := 5.0
@export var hp := 3

signal firewall_destroyed(grid_pos: Vector2i)

var grid_pos: Vector2i

@onready var tile_fx: ColorRect = $TileFx
@onready var fire_anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var overlay_fx: ColorRect = $OverlayFX
@onready var lifetime_timer: Timer = $LifetimeTimer

func _ready():
	play_sfx(FIREWALL, -15)
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
	await destroy()


func _on_area_2d_area_entered(area):
	if area.is_in_group("enemy_projectiles"):
		area.queue_free()

		hp -= 1

		if hp <= 0:
			await destroy()

func destroy():

	lifetime_timer.stop()
	set_process(false)

	var tween = create_tween()

	# Blink like a dying fire
	for i in range(4):
		tween.tween_property(fire_anim, "modulate:a", 0.15, 0.06)
		tween.tween_property(fire_anim, "modulate:a", 1.0, 0.06)

	# Final fade
	tween.set_parallel()

	tween.tween_property(fire_anim, "modulate:a", 0.0, 0.25)
	tween.tween_property(tile_fx, "modulate:a", 0.0, 0.25)
	tween.tween_property(overlay_fx, "modulate:a", 0.0, 0.25)

	await tween.finished

	firewall_destroyed.emit(grid_pos)
	queue_free()
	
func play_spawn():

	scale = Vector2(0.2, 0.2)
	modulate.a = 0.0

	var tween = create_tween()
	tween.set_parallel()

	tween.tween_property(self, "scale", Vector2.ONE, 0.25)
	tween.tween_property(self, "modulate:a", 1.0, 0.25)
