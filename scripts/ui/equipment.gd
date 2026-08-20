extends slot
class_name equipment

var id_accepted = 0
var equip_sprite = null

func set_empty_slot() -> void:
	$sprite.texture = null
	self.id = 0

func _get_drag_data(_at_position: Vector2) -> Variant:
	if self.id == 0:
		return null
	var preview = TextureRect.new()
	preview.texture = $sprite.texture
	preview.custom_minimum_size = Vector2(48, 48)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	$sprite.visible = false
	self.is_equipment = true
	return self

func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		$sprite.visible = true

func _return_data(data: Variant) -> void:
	$sprite.texture = data.sprite

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is slot:
		@warning_ignore("integer_division")
		if data.id/100 == id_accepted:
			return true
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data.id == 0 or data.id == self.id:
		return
	var quantity = int(data.get_node("amount").text)
	if self.id == 0:
		$sprite.texture = equip_sprite
		self.id = data.id
		if quantity == 1:
			data.set_empty_slot()
		else:
			data.get_node("amount").text = str(quantity-1)
	else:
		if quantity == 1:
			var n_id = data.id
			data.id = self.id
			self.id = n_id
		else:
			data.get_node("amount").text = str(quantity - 1)
			return_to_inventory(id)
			id = data.id
	data.get_node("sprite").visible = true
	data.get_node("amount").visible = true

func return_to_inventory(new_item_id) -> bool:
	var empty = null
	for inv_slot in  $"../../../invent/Container".get_children():
		if inv_slot is not slot:
			continue
		if inv_slot.id == new_item_id:
			var new_amount = int(inv_slot.get_node("amount").text)
			new_amount += 1
			inv_slot.get_node("amount").text = str(new_amount)
			return true 
		elif inv_slot.id == 0 and empty == null:
			empty = inv_slot
	if not(empty == null):
		empty.get_node("sprite").texture = equip_sprite
		empty.get_node("amount").text = "1"
		empty.id = new_item_id
		return true
	return false
