extends CanvasLayer

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if $upgrade_shop.visible:
			$upgrade_shop.visible = false
		$inventory.visible = not $inventory.visible
		if $inventory/store.visible:
			$inventory/store.visible = false

func add_item_inventory(new_item: Area2D) -> bool:
	var empty = null
	for inv_slot in $inventory/invent/Container.get_children():
		if inv_slot is not slot:
			continue
		if inv_slot.id == new_item.item_id:
			var new_amount = int(inv_slot.get_node("amount").text)
			new_amount += 1
			inv_slot.get_node("amount").text = str(new_amount)
			return true
		elif inv_slot.id == 0 and empty == null:
			empty = inv_slot
	if not(empty == null):
		empty.get_node("sprite").texture = new_item.get_node("sprite").texture
		empty.get_node("amount").text = "1"
		empty.id = new_item.item_id
		return true
	return false
