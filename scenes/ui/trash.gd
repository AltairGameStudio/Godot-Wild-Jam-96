extends Control

func _ready() -> void:
	pass

func _can_drop_data(_at_position: Vector2, _data: Variant) -> bool:
	return true

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data.id == 0:
		return
	data.set_empty_slot()
