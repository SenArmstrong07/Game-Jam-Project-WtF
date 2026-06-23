extends Resource
class_name Chip

enum AttackType {
	PROJECTILE,
	HOMING,
	STUN_PROJECTILE,
	WALL,
	HEAL,
	BUFF,
}

@export var name: String
@export var power: int = 10
@export var range_tile: int = 1
@export var description: String = ""
@export var attack_type: AttackType


# Map enemy type (class name) to effectiveness level
# Example: {"CommonBug": Unit.DamageType.SUPER_EFFECTIVE, "Virus": Unit.DamageType.INEFFECTIVE}
var effectiveness_map: Dictionary = {}

func _init(p_name: String = "", p_power: int = 10, p_range: int = 1, 
		   p_description: String = "", p_attack_type: AttackType = AttackType.PROJECTILE , p_effectiveness_map: Dictionary = {}) -> void:
	name = p_name
	power = p_power
	range_tile = p_range
	description = p_description
	attack_type = p_attack_type
	effectiveness_map = p_effectiveness_map.duplicate()

# Get effectiveness against a specific enemy type
func get_effectiveness_against(enemy: Unit) -> Unit.DamageType:
	var enemy_class = enemy.get_class()
	
	# Check if we have specific effectiveness data for this enemy type
	if effectiveness_map.has(enemy_class):
		return effectiveness_map[enemy_class]
	
	# Default to NEUTRAL if no specific effectiveness defined
	return Unit.DamageType.NEUTRAL

# Get damage multiplier based on enemy type
func get_damage_multiplier(enemy: Unit) -> float:
	var effectiveness = get_effectiveness_against(enemy)
	
	match effectiveness:
		Unit.DamageType.SUPER_EFFECTIVE:
			return 2.0
		Unit.DamageType.INEFFECTIVE:
			return 0.5
		_:
			return 1.0

func clone_chip() -> Chip:
	var copy = duplicate(true) as Chip
	return copy
