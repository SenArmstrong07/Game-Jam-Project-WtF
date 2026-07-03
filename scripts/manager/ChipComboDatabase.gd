extends Resource
class_name ChipComboDatabase

const REFORMAT_ICON = preload("res://assets/ui/Free-Skill-32x32-Icons-for-Cyberpunk-Game/1 Icons/1/Skillicon1_37.png")



var combos := {
	"DELETE+DELETE": Chip.new(
		"RESET",
		60,
		999,
		"Performs a full system reset, forcefully erasing corrupted processes and dealing massive damage to a single target.",
		Chip.AttackType.COMBO,
		{},
		[],
		REFORMAT_ICON
	)
}

func get_combo(chip1: Chip, chip2: Chip) -> Chip:

	var key = chip1.name + "+" + chip2.name

	if combos.has(key):
		return combos[key].clone_chip()

	key = chip2.name + "+" + chip1.name

	if combos.has(key):
		return combos[key].clone_chip()

	return null
