extends slot
class_name sell_slot

#signal new_item_on_store(id, amount)
#signal item_removed_from_store(id, amount)

@onready var total_label = $"../../total"

var item_value = {
	2: 5,
	3: 8,
	4: 3,
	5: 6,
	6: 4,
	7: 10
}
var lvl_value_multiplier = 2
var slot_value = 0

func set_empty_slot() -> void:
	item_removed_from_store()
	#item_removed_from_store.emit(id, int($amout.text))
	$sprite.texture = null
	$amount.text = ""
	id = 0
	slot_value = 0

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is buy_slot:
		return false
	return super(_at_position, data)
	
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	super(_at_position, data)
	slot_value = int(((id%100) * item_value[id/100]) * 2.0/3.0)
	var quantity = int($amount.text)
	slot_value *= quantity
	#new_item_on_store.emit(id, quantity)
	new_item_on_store()

func new_item_on_store() -> void:
	var tot_tmp = int(total_label.text)
	tot_tmp += slot_value
	total_label.text = str(tot_tmp)
	
func item_removed_from_store() -> void:
	var tot_tmp = int(total_label.text)
	tot_tmp -= slot_value
	total_label.text = str(tot_tmp)
