extends Area2D

var damage := 10

var bounce_count := 0
var max_bounces := 5

var is_special := false
var special_target_tile := Vector2i.ZERO

const ARENA_WIDTH := 8
const ARENA_HEIGHT := 4
const TILE_SIZE := 64
const X_OFFSET := 4

var hit_targets := []

# First throw is highest, then smaller bounces
var bounce_heights := [
	80.0,
	50.0,
	30.0,
	15.0
]

func _ready():
	add_to_group("enemy_projectiles")

func _process(delta):
	var battle = get_tree().get_first_node_in_group("battle_scene")

	if battle and battle.current_phase != Battlescene.BattlePhase.BATTLE:
		return
# ============================================================
# ENTRY POINT
# ============================================================
func throw_bounce():
	global_position = snap_to_tile_center(global_position)

	# Throw from the front/lower part of the sprite.
	global_position += Vector2(-16, 24)

	var first_tile = snap_to_tile_center(global_position) + Vector2(-TILE_SIZE, 0)

	await bounce_to_tile(first_tile, bounce_heights[0], 0.40)

	on_land(global_position)
	bounce()

# ============================================================
# BOUNCE LOOP
# ============================================================

func bounce():

	if bounce_count >= max_bounces:
		await disappear()
		return

	var next_pos = snap_to_tile_center(global_position) + Vector2(-TILE_SIZE, 0)
	bounce_count += 1

	var height = bounce_heights[
		min(bounce_count, bounce_heights.size() - 1)
	]

	await bounce_to_tile(
		next_pos,
		height,
		0.30
	)

	on_land(global_position)

	bounce()


# ============================================================
# SPECIAL THROW
# ============================================================

func throw_special(target_tile: Vector2i):
	is_special = true
	special_target_tile = target_tile

	var target_pos = Vector2(
		target_tile.x * TILE_SIZE + TILE_SIZE * 0.5,
		target_tile.y * TILE_SIZE + TILE_SIZE * 0.5
	)

	await bounce_to_tile(
		target_pos,
		140.0,
		0.55
	)

	on_special_land(target_pos)

func on_special_land(tile_pos: Vector2):

	var offsets = [
		Vector2.ZERO,
		Vector2(TILE_SIZE, 0),
		Vector2(-TILE_SIZE, 0),
		Vector2(0, TILE_SIZE),
		Vector2(0, -TILE_SIZE)
	]

	spawn_plus_tile_effect(tile_pos)

	for offset in offsets:
		hit_player_at_tile(tile_pos + offset)

	await disappear()
	
func spawn_plus_tile_effect(center_pos: Vector2):

	var offsets = [
		Vector2.ZERO,
		Vector2(TILE_SIZE, 0),
		Vector2(-TILE_SIZE, 0),
		Vector2(0, TILE_SIZE),
		Vector2(0, -TILE_SIZE)
	]

	for offset in offsets:

		var pos = center_pos + offset

		if !is_tile_in_grid(pos):
			continue

		var fx := ColorRect.new()

		fx.size = Vector2(TILE_SIZE, TILE_SIZE)
		fx.position = pos - Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
		fx.color = Color(1.0, 0.2, 0.2, 0.6)

		get_tree().current_scene.add_child(fx)

		var tween = fx.create_tween()
		tween.tween_property(fx, "modulate:a", 0.0, 0.25)

		tween.finished.connect(func():
			if is_instance_valid(fx):
				fx.queue_free()
		)
# ============================================================
# CORE HIT LOGIC (FIXED SYSTEM)
# ============================================================

func hit_player_at_position(pos: Vector2, radius := 40.0):

	if !is_inside_tree():
		return

	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return

	if player in hit_targets:
		return

	if pos.distance_to(player.global_position) <= radius:
		player.take_damage(damage)
		hit_targets.append(player)


func on_land(pos: Vector2):

	hit_player_at_position(pos, 40.0)
	show_tile_warning(pos)


# ============================================================
# TILE EFFECTS
# ============================================================

func spawn_tile_effect(tile_pos: Vector2):

	var fx := ColorRect.new()
	fx.size = Vector2(TILE_SIZE, TILE_SIZE)
	fx.position = tile_pos - Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	fx.color = Color(1, 0.2, 0.2, 0.5)

	get_tree().current_scene.add_child(fx)

	fx.scale = Vector2(0.6, 0.6)

	var tween = create_tween()
	tween.set_parallel()

	tween.tween_property(fx, "scale", Vector2(1.3, 1.3), 0.15)
	tween.tween_property(fx, "modulate:a", 0.0, 0.25)

	await tween.finished
	fx.queue_free()

func show_tile_warning(tile_pos: Vector2):
	if !is_tile_in_grid(tile_pos):
		return

	if !is_inside_tree():
		return

	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return

	var marker := ColorRect.new()
	marker.size = Vector2(TILE_SIZE, TILE_SIZE)
	marker.color = Color(1, 0, 0, 0.45)
	marker.position = tile_pos - Vector2(TILE_SIZE / 2, TILE_SIZE / 2)

	tree.current_scene.add_child(marker)

	var tween = marker.create_tween()
	tween.set_loops(3)
	tween.tween_property(marker, "modulate:a", 0.9, 0.06)
	tween.tween_property(marker, "modulate:a", 0.15, 0.06)

	await tree.create_timer(0.4).timeout

	if is_instance_valid(marker):
		marker.queue_free()
# ============================================================
# MOVEMENT
# ============================================================

func bounce_to_tile(target_pos: Vector2, arc_height: float, duration: float) -> void:
	var start_pos: Vector2 = global_position
	var elapsed: float = 0.0

	while elapsed < duration:
		if !is_inside_tree():
			return

		var battle := get_tree().get_first_node_in_group("battle_scene")

		while battle and battle.current_phase != Battlescene2.BattlePhase.BATTLE:
			await get_tree().process_frame

			if !is_inside_tree():
				return

			battle = get_tree().get_first_node_in_group("battle_scene")

		await get_tree().process_frame

		elapsed += get_process_delta_time()

		var t: float = clampf(elapsed / duration, 0.0, 1.0)

		global_position = start_pos.lerp(target_pos, t)
		global_position.y -= sin(t * PI) * arc_height

	if is_inside_tree():
		global_position = target_pos
		
# ============================================================
# CLEANUP
# ============================================================

func disappear():

	var tween = create_tween()
	tween.set_parallel()

	tween.tween_property(self, "position:y", position.y + 32, 0.40)
	tween.tween_property(self, "scale", Vector2(0.7, 0.2), 0.40)
	tween.tween_property(self, "modulate:a", 0.0, 0.40)

	await tween.finished
	queue_free()

# ============================================================
# UTILITY
# ============================================================

func snap_to_tile_center(pos: Vector2) -> Vector2:
	return Vector2(
		floor(pos.x / TILE_SIZE) * TILE_SIZE + TILE_SIZE * 0.5,
		floor(pos.y / TILE_SIZE) * TILE_SIZE + TILE_SIZE * 0.5
	)

func hit_player_at_tile(tile_pos: Vector2):

	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return

	if player in hit_targets:
		return

	# convert player to grid
	var player_tile = player.grid_pos

	# convert impact to grid
	var impact_tile = Vector2i(
		int(tile_pos.x / TILE_SIZE),
		int(tile_pos.y / TILE_SIZE)
	)

	if player_tile == impact_tile:
		player.take_damage(damage)
		hit_targets.append(player)

func is_tile_in_grid(world_pos: Vector2) -> bool:
	var tile := Vector2i(
		floor(world_pos.x / TILE_SIZE),
		floor(world_pos.y / TILE_SIZE)
	)

	return (
		tile.x >= 0 and tile.x < ARENA_WIDTH and
		tile.y >= 0 and tile.y < ARENA_HEIGHT
	)
