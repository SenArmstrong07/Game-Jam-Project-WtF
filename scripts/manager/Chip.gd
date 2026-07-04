extends Resource
class_name Chip

enum AttackType {
	PROJECTILE,
	HOMING,
	STUN_PROJECTILE,
	WALL,
	HEAL,
	BUFF,
	COMBO
}

@export var name: String
@export var power: int = 10
@export var range_tile: int = 1
@export var description: String = ""
@export var attack_type: AttackType
@export var icon: Texture2D
# List of chip names this chip can combine with
@export var combo_with: Array[String] = []

# Map enemy type (class name) to effectiveness level
# Example: {"CommonBug": Unit.DamageType.SUPER_EFFECTIVE}
var effectiveness_map: Dictionary = {}

func _init(
	p_name: String = "",
	p_power: int = 10,
	p_range: int = 1,
	p_description: String = "",
	p_attack_type: AttackType = AttackType.PROJECTILE,
	p_effectiveness_map: Dictionary = {},
	p_combo_with: Array[String] = [],
	chip_icon: Texture2D = null
) -> void:
	name = p_name
	power = p_power
	range_tile = p_range
	description = p_description
	attack_type = p_attack_type

	effectiveness_map = p_effectiveness_map.duplicate()
	combo_with = p_combo_with.duplicate()
	icon = chip_icon
	
# Returns true if this chip can combine with another chip
func can_combine_with(other: Chip) -> bool:
	return other.name in combo_with

# Get effectiveness against a specific enemy type
func get_effectiveness_against(enemy: Unit) -> Unit.DamageType:
	var enemy_class = enemy.get_class()

	if effectiveness_map.has(enemy_class):
		return effectiveness_map[enemy_class]

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
	return duplicate(true) as Chip
