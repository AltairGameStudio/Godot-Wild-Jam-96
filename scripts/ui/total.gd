extends Label

@onready var sale_zone = $"../sale_zone"

func store_changed() -> int:
	return revaluate()

func revaluate() -> int:
	var total = 0
	for child_slot in sale_zone.get_children():
		total += child_slot.total_value
	text = str(total)
	return total
