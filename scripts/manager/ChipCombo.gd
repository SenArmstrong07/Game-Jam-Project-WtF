extends Resource
class_name ChipCombo

enum ComboType {
	REFORMAT,
}

@export var combo_name: String
@export var chips: Array[String]
@export var combo_type: ComboType

func _init(
	p_name := "",
	p_chips := [],
	p_type := ComboType.REFORMAT
):
	combo_name = p_name
	chips = p_chips
	combo_type = p_type
