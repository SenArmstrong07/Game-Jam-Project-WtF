extends Node2D
class_name Unit

enum Team {
	PLAYER,
	ENEMY
}

enum DamageType {
	#just add more types dito, or change the existing ones if you want. ni-AI ko lang sila, but you can use whatever you like.
	NEUTRAL,    # Standard damage with no special properties
	INEFFECTIVE, # damage halves (0.5)
	SUPER_EFFECTIVE # double damage (2)
}

var team : Team

var grid_x : int
var grid_y : int

var hp : int = 100
var max_hp : int = 100

var attack_power : int = 10 # Base damage (Expand with weapon types, etc.)
var attack_range : int = 4  # Grid tiles (Expand mo nalang with what you like)
var attack_cooldown : float = 1.0  # Seconds
var attack_damage_type : DamageType = DamageType.NEUTRAL

# Damage type resistances/weaknesses (list nalang sa array kung anong type ng damage ang effective or ineffective sa unit)

var dmg_eff : Array[DamageType] = []  # DMG Type indicator

#EXAMPLE USAGE:
# In Enemy._ready()
#

# When attacking
# attack_damage_type = Unit.DamageType.MALWARE


var _attack_cooldown_timer : float = 0.0 #spam prevention

signal attack_performed(attacker: Unit, target: Unit, damage: int, damage_type: DamageType)
signal unit_died(unit: Unit)

func _process(delta: float) -> void:
	if _attack_cooldown_timer > 0:
		_attack_cooldown_timer -= delta

#added a damage_type parameter to take_damage so we can apply type multipliers
func take_damage(amount: int, damage_type: DamageType = DamageType.NEUTRAL) -> void:
	# Calculate type multiplier
	var type_multiplier : float = 1.0
	
	if damage_type == DamageType.SUPER_EFFECTIVE:
		type_multiplier = 2.0  # Super effective - double damage
	elif damage_type == DamageType.INEFFECTIVE:
		type_multiplier = 0.5  # Ineffective - half damage
	
	var final_damage : int = int(amount * type_multiplier)
	hp -= final_damage
	
	var type_text : String = ""
	if type_multiplier == 2.0:
		type_text = " (SUPER EFFECTIVE!)"
	elif type_multiplier == 0.5:
		type_text = " (ineffective)"
	
	print(name + " took " + str(final_damage) + " damage" + type_text)
	
	if hp <= 0:
		die()

func restore_hp(amount: int) -> void:
	hp = min(hp + amount, max_hp)

func can_attack() -> bool:
	return _attack_cooldown_timer <= 0

func get_distance_to(target: Unit) -> int:
	return maxi(abs(grid_x - target.grid_x), abs(grid_y - target.grid_y))

func is_in_range(target: Unit) -> bool: #validates grid distance to target before attacking
	return get_distance_to(target) <= attack_range

func attack(target: Unit) -> bool:
	if target == null:
		print(name + " tried to attack null target")
		return false
	
	if not is_in_range(target):
		print(name + " is out of range to attack " + target.name)
		return false
	
	if not can_attack():
		print(name + " is on cooldown")
		return false
	
	# Calculate damage with small variance
	var damage : int = attack_power + randi_range(-2, 2)  # ±2 variance
	
	# Deal damage to target (type multipliers applied in take_damage)
	target.take_damage(damage, attack_damage_type)
	print(name + " attacked " + target.name + " for " + str(damage) + " damage")
	
	# Reset cooldown
	_attack_cooldown_timer = attack_cooldown
	
	# Emit signal for animations/effects
	attack_performed.emit(self, target, damage, attack_damage_type)
	
	return true

func die() -> void:
	print(name + " died")
	unit_died.emit(self)
	queue_free()
