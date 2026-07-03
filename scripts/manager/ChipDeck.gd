extends Resource
class_name ChipDeck

const DELETE_ICON = preload("res://assets/ui/Free-Skill-32x32-Icons-for-Cyberpunk-Game/1 Icons/1/Skillicon1_06.png")
const PATCH_ICON = preload("res://assets/ui/Free-Skill-32x32-Icons-for-Cyberpunk-Game/1 Icons/1/Skillicon1_23.png")
const QUARANTINE_ICON = preload("res://assets/ui/Free-Skill-32x32-Icons-for-Cyberpunk-Game/1 Icons/1/Skillicon1_12.png")
const FIREWALL_ICON = preload("res://assets/ui/Free-Skill-32x32-Icons-for-Cyberpunk-Game/1 Icons/1/Skillicon1_18.png")
const BACKUP_ICON = preload("res://assets/ui/Free-Skill-32x32-Icons-for-Cyberpunk-Game/1 Icons/1/Skillicon1_36.png")
const OPTIMIZE_ICON = preload("res://assets/ui/Free-Skill-32x32-Icons-for-Cyberpunk-Game/1 Icons/1/Skillicon1_21.png")

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
				{},
				["DELETE"],
				DELETE_ICON
			)
		)

	# PATCH 
	for i in range(3):
		deck.append(
			Chip.new(
				"Patch",
				15,
				999,
				"Deploys a security patch that auto-routes toward detected vulnerabilities in the system.",
				Chip.AttackType.HOMING,
				{
					"CommonBug": Unit.DamageType.SUPER_EFFECTIVE
				},
				[],
				PATCH_ICON
			)
		)

	# QUARANTINE x2
	for i in range(2):
		deck.append(
			Chip.new(
				"Isolation",
				5,
				999,
				"Isolates malicious threads and temporarily suspends their execution cycle.",
				Chip.AttackType.STUN_PROJECTILE,
				{},[],QUARANTINE_ICON
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
				{}, [],FIREWALL_ICON
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
				{}, [], BACKUP_ICON
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
				{}, [], OPTIMIZE_ICON
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
