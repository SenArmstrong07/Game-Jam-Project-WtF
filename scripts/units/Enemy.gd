extends Unit #since we inherit from Unit, lahat ng properties and functions ni unit is applicable na dito.
class_name Enemy

var enemy_type

func _ready():
	team = Team.ENEMY

	#JUST SET SOME STUFF HERE:
	#EXAMPLE:
	# Virus Type A: Weak to GLITCH, resistant to OVERFLOW
	if enemy_type == "VirusA":
		weak_to = [DamageType.SUPER_EFFECTIVE]          # Takes 2x GLITCH damage
		resistant_to = [DamageType.INEFFECTIVE]    # Takes 0.5x OVERFLOW damage
	
	# Virus Type B: Weak to CRASH, resistant to LOGIC
	elif enemy_type == "VirusB":
		weak_to = [DamageType.SUPER_EFFECTIVE]
		resistant_to = [DamageType.INEFFECTIVE]
