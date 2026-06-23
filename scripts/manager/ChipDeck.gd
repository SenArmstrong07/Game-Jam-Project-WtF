extends Resource
class_name ChipDeck

var deck: Array[Chip] = []

func _init() -> void:
	_initialize_deck()
	
func _initialize_deck() -> void:
	deck = [
		Chip.new(
			"DELETE",
			35,
			999,
			"Forcefully terminates a target process and purges it from active system memory.",
			Chip.AttackType.PROJECTILE,
			{}
		),

		Chip.new(
			"Patch",
			25,
			999,
			"Deploys a security patch that auto-routes toward detected vulnerabilities in the system.",
			Chip.AttackType.HOMING,
			{
				"CommonBug": Unit.DamageType.SUPER_EFFECTIVE
			}
		),

		Chip.new(
			"Quarantine",
			10,
			999,
			"Isolates malicious threads and temporarily suspends their execution cycle.",
			Chip.AttackType.STUN_PROJECTILE,
			{}
		),

		Chip.new(
			"Firewall",
			0,
			1,
			"Deploys a defensive network barrier that intercepts and blocks incoming hostile data packets.",
			Chip.AttackType.WALL,
			{}
		),

		Chip.new(
			"Backup",
			1,
			0,
			"Restores system integrity by rolling back corrupted state and recovering 1 health unit.",
			Chip.AttackType.HEAL,
			{}
		),

		Chip.new(
			"Optimize",
			15,
			0,
			"Runs system optimization routines, increasing processing throughput and attack efficiency for a short duration.",
			Chip.AttackType.BUFF,
			{}
		),
	]

func draw_hand(hand_size: int = 5) -> Array[Chip]:
	var hand: Array[Chip] = []
	var available_indices: Array[int] = []
	
	# Build available indices
	for i in range(deck.size()):
		available_indices.append(i)
	
	# Draw unique chips
	for i in range(mini(hand_size, deck.size())):
		if available_indices.is_empty():
			break
		var random_idx = randi() % available_indices.size()
		var deck_idx = available_indices[random_idx]
		hand.append(deck[deck_idx].duplicate())
		available_indices.remove_at(random_idx)
	
	return hand

func set_custom_deck(new_deck: Array[Chip]) -> void:
	deck = new_deck
