extends Resource
class_name ChipDeck

var deck: Array[Chip] = []

func _init() -> void:
	_initialize_deck()

func _initialize_deck() -> void:
	deck.clear()

	# DELETE x3
	for i in range(3):
		deck.append(
			Chip.new(
				"DELETE",
				35,
				999,
				"Forcefully terminates a target process and purges it from active system memory.",
				Chip.AttackType.PROJECTILE,
				{}
			)
		)

	# PATCH x3
	for i in range(3):
		deck.append(
			Chip.new(
				"Patch",
				25,
				999,
				"Deploys a security patch that auto-routes toward detected vulnerabilities in the system.",
				Chip.AttackType.HOMING,
				{
					"CommonBug": Unit.DamageType.SUPER_EFFECTIVE
				}
			)
		)

	# QUARANTINE x2
	for i in range(2):
		deck.append(
			Chip.new(
				"Quarantine",
				10,
				999,
				"Isolates malicious threads and temporarily suspends their execution cycle.",
				Chip.AttackType.STUN_PROJECTILE,
				{}
			)
		)

	# FIREWALL x2
	for i in range(2):
		deck.append(
			Chip.new(
				"Firewall",
				0,
				1,
				"Deploys a defensive network barrier that intercepts and blocks incoming hostile data packets.",
				Chip.AttackType.WALL,
				{}
			)
		)

	# BACKUP x2
	for i in range(2):
		deck.append(
			Chip.new(
				"Backup",
				1,
				0,
				"Restores system integrity by rolling back corrupted state and recovering 1 health unit.",
				Chip.AttackType.HEAL,
				{}
			)
		)

	# OPTIMIZE x2
	for i in range(2):
		deck.append(
			Chip.new(
				"Optimize",
				15,
				0,
				"Runs system optimization routines, increasing processing throughput and attack efficiency for a short duration.",
				Chip.AttackType.BUFF,
				{}
			)
		)

func draw_hand(hand_size: int = 10) -> Array[Chip]:
	var shuffled := deck.duplicate()
	shuffled.shuffle()

	var hand: Array[Chip] = []

	for i in range(min(hand_size, shuffled.size())):
		hand.append(shuffled[i])

	return hand

func select_chip(chip: Chip) -> Chip:
	var index := deck.find(chip)

	if index == -1:
		return null

	return deck.pop_at(index)

func remaining_chips() -> int:
	return deck.size()

func reset_deck() -> void:
	_initialize_deck()

func set_custom_deck(new_deck: Array[Chip]) -> void:
	deck = new_deck.duplicate()
