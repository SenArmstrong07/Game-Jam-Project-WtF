extends Area2D

@onready var sparks: GPUParticles2D = $Sparks
signal player_stunned(tile: Vector2i)

const TILE_SIZE := 64
const X_OFFSET := 0
@export var lifespan: float = 5.0
var triggered := false
var landed := false
var grid_pos := Vector2i.ZERO
const BOSS_PROJECTILE = preload("uid://dpqks7y6diyji")
const TRAP_PROJECTILE = preload("uid://dvj4kvagu5wy2")

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
	var battle = get_tree().get_first_node_in_group("battle_scene")

	if battle and battle.current_phase != Battlescene.BattlePhase.BATTLE:
		return
	if landed:

		modulate.a = 1 + sin(Time.get_ticks_msec() / 120.0) * 0.5

		for body in get_overlapping_bodies():
			_on_body_entered(body)

func _ready():
	play_sfx(BOSS_PROJECTILE, -15)
	body_entered.connect(_on_body_entered)
	add_to_group("enemy_projectiles")
	
func grid_to_world(cell:Vector2i)->Vector2:

	return Vector2(
		(cell.x * TILE_SIZE) + TILE_SIZE/2,
		(cell.y * TILE_SIZE) + TILE_SIZE/2
	)
	
func throw_to(target_tile: Vector2i):
	grid_pos = target_tile

	var start := global_position
	var end := grid_to_world(target_tile)

	var flight_time: float = 0.65
	var arc_height: float = 140.0

	var elapsed: float = 0.0

	rotation = 0

	while elapsed < flight_time:

		var t: float = elapsed / flight_time

		# Smooth horizontal movement
		var pos: Vector2 = start.lerp(end, t)

		# Parabolic arc
		pos.y -= 4.0 * arc_height * t * (1.0 - t)

		global_position = pos

		# Spin while flying
		rotation += 20.0 * get_process_delta_time()

		elapsed += get_process_delta_time()

		await get_tree().process_frame

	global_position = end
	rotation = 0

	landed = true
	start_lifespan()
	
	# Change spark color
	var mat := sparks.process_material as ParticleProcessMaterial
	mat.color = Color(1.0, 1.0, 1.0, 1.0) # Gold/yellow

	# Play landing sparks
	sparks.emitting = false
	sparks.restart()
	sparks.emitting = true

	# Small squash on landing
	scale = Vector2(1.15, 0.8)

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.12)

	# If the player is already standing here, stun immediately
	for body in get_overlapping_bodies():
		_on_body_entered(body)
			
func start_lifespan():
	play_sfx(TRAP_PROJECTILE, -15)
	await get_tree().create_timer(lifespan).timeout

	if landed:
		queue_free()
		
func _on_body_entered(body):

	if triggered:
		return

	if !landed:
		return

	if !body.is_in_group("player"):
		return

	triggered = true

	body.apply_stun(2.0)

	player_stunned.emit(grid_pos)

	queue_free()
