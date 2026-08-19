extends CanvasLayer

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		$inventario.visible = not $inventario.visible
	pass

func add_item_inventory(item: Area2D) -> bool:
	var empty = null
	for inv_slot in $inventario/Container.get_children():
		if inv_slot.id == item.item_id:
			var new_amount = int(inv_slot.get_node("amount").text)
			new_amount += 1
			inv_slot.get_node("amount").text = str(new_amount)
		elif inv_slot.id == 0 and empty == null:
			empty = inv_slot
	if not(empty == null):
		empty.get_node("sprite").texture = item.get_node("sprite").texture
		empty.get_node("amount").text = "1"
	return false
