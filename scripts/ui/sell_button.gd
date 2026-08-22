extends Control

@onready var sale_zone = $"../sale_zone"

func clear_store() -> void:
	var total = 0
	for child_slot in sale_zone.get_children():
		total += child_slot.slot_value
		child_slot.set_empty_slot()
	get_tree().current_scene.add_gold(total)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		clear_store()
