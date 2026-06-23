extends CharacterBody2D
class_name Unit

# ============================================================
# TEAM
# ============================================================
enum Team {
	PLAYER,
	ENEMY
}
@onready var common_bug: AnimatedSprite2D = $AnimatedSprite2D

var is_hurt := false
var team: Team
var is_dead: bool = false
var action_locked := false
# ============================================================
# GRID POSITION (IMPORTANT: SINGLE SOURCE OF TRUTH)
# ============================================================
var grid_pos: Vector2i = Vector2i.ZERO
var grid_x: int = 0
var grid_y: int = 0

func set_grid_pos(pos: Vector2i) -> void:
	grid_pos = pos
	grid_x = pos.x
	grid_y = pos.y

# ============================================================
# STATS
# ============================================================
var hp: int = 100
var max_hp: int = 100

var attack_power: int = 10
var attack_range: int = 4
var attack_cooldown: float = 1.0
var attack_damage_type: DamageType = DamageType.NEUTRAL

var dmg_eff: Array[DamageType] = []

# ============================================================
# DAMAGE TYPES
# ============================================================
enum DamageType {
	NEUTRAL,
	INEFFECTIVE,
	SUPER_EFFECTIVE
}

# ============================================================
# COOLDOWN
# ============================================================
var _attack_cooldown_timer: float = 0.0

# ============================================================
# SIGNALS
# ============================================================
signal attack_performed(attacker: Unit, target: Unit, damage: int, damage_type: DamageType)
signal unit_died(unit: Unit)

# ============================================================
# PROCESS (COOLDOWN TICK)
# ============================================================
func _process(delta: float) -> void:
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta
		
func lock_actions():
	action_locked = true

func unlock_actions():
	action_locked = false

# ============================================================
# DAMAGE SYSTEM
# ============================================================
func take_damage(amount: int, damage_type: DamageType = DamageType.NEUTRAL, chip: Chip = null) -> void:
	if hp <= 0:
		return # ignore all further damage

	var multiplier: float = 1.0

	if chip != null:
		multiplier = chip.get_damage_multiplier(self)
	elif damage_type == DamageType.SUPER_EFFECTIVE:
		multiplier = 2.0
	elif damage_type == DamageType.INEFFECTIVE:
		multiplier = 0.5

	var final_damage: int = int(amount * multiplier)
	hp -= final_damage
	
	print(name, " took ", final_damage)
	print(name, " HP after: ", hp)


	if hp <= 0:
		hp = 0
		die()
		
func play_hurt():
	if is_dead or is_hurt:
		return

	is_hurt = true

	# Red flash
	common_bug.modulate = Color(1, 0.3, 0.3)

	common_bug.play("Hurt")

	await get_tree().create_timer(0.15).timeout

	# Return color
	common_bug.modulate = Color.WHITE

	is_hurt = false

	common_bug.play("Idle")
# ============================================================
# HEALING
# ============================================================
func restore_hp(amount: int) -> void:
	hp = min(hp + amount, max_hp)

# ============================================================
# COMBAT HELPERS
# ============================================================
func can_attack() -> bool:
	return _attack_cooldown_timer <= 0.0

func get_distance_to(target: Unit) -> int:
	return maxi(abs(grid_x - target.grid_x), abs(grid_y - target.grid_y))

func is_in_range(target: Unit) -> bool:
	return get_distance_to(target) <= attack_range

# ============================================================
# CHIP ATTACK (PLAYER SYSTEM)
# ============================================================
func attack_with_chip(target: Unit, chip: Chip) -> bool:
	if target == null:
		return false

	if not is_in_range(target):
		print("OUT OF RANGE")
		return false

	if not can_attack():
		return false
	
	var damage: int = chip.power + randi_range(-2, 2)

	target.take_damage(damage, DamageType.NEUTRAL, chip)

	_attack_cooldown_timer = attack_cooldown

	attack_performed.emit(self, target, damage, attack_damage_type)

	print(name + " used chip " + chip.name + " for " + str(damage))

	return true

# ============================================================
# BASIC ATTACK 
# ============================================================
func attack(target: Unit) -> bool:
	if target == null:
		return false

	if not is_in_range(target):
		return false

	if not can_attack():
		return false

	var damage: int = attack_power + randi_range(-2, 2)

	target.take_damage(damage, attack_damage_type)

	_attack_cooldown_timer = attack_cooldown

	attack_performed.emit(self, target, damage, attack_damage_type)

	return true

# ============================================================
# DEATH
# ============================================================

func die() -> void:
	if is_dead:
		return

	is_dead = true
	hp = 0

	print(name + " died")

	set_process(false)
	set_physics_process(false)

	var start_pos = position
	var knockback_dir := 1.0

	match team:
		Team.PLAYER:
			knockback_dir = -1.0

		Team.ENEMY:
			knockback_dir = 1.0
	var tween = create_tween()

	# Launch
	tween.tween_property(
		self,
		"position",
		start_pos + Vector2(40 * knockback_dir, -22),
		0.18
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Bounce 1
	tween.tween_property(
		self,
		"position",
		start_pos + Vector2(65 * knockback_dir, 0),
		0.22
	).set_trans(Tween.TRANS_BOUNCE)

	# Bounce 2
	tween.tween_property(
		self,
		"position",
		start_pos + Vector2(82 * knockback_dir, -12),
		0.18
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		self,
		"position",
		start_pos + Vector2(95 * knockback_dir, 0),
		0.20
	).set_trans(Tween.TRANS_BOUNCE)

	await tween.finished

	# =====================================================
	# DRAMATIC PAUSE
	# =====================================================
	await get_tree().create_timer(0.2).timeout

	# =====================================================
	# BLINK
	# =====================================================
	for i in range(4):
		visible = false
		await get_tree().create_timer(0.05).timeout

		visible = true
		await get_tree().create_timer(0.05).timeout

	# =====================================================
	# SHRINK + FADE
	# =====================================================
	tween = create_tween()
	tween.set_parallel()

	tween.tween_property(
		self,
		"scale",
		Vector2.ZERO,
		0.20
	)

	tween.tween_property(
		self,
		"modulate:a",
		0.0,
		0.20
	)

	await tween.finished

	unit_died.emit(self)
