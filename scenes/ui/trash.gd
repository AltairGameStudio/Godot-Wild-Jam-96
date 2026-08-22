extends Control
class_name trash

func _ready() -> void:
	pass

func _can_drop_data(_at_position: Vector2, _data: Variant) -> bool:
	return true

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data.id == 0 or data is buy_slot:
		return
	data.set_empty_slot()
