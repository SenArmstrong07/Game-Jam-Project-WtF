extends Resource
class_name ChipComboDatabase

var combos := {
	"DELETE+DELETE": Chip.new(
		"REFORMAT",
		60,
		999,
		"Massive delete attack.",
		Chip.AttackType.COMBO
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
