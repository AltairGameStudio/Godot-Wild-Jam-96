class_name slot
extends Control

var id = 0

func _ready() -> void:
	var _stackable = true
	pass

func set_empty_slot() -> void:
	$sprite.texture = null
	$amount.text = ""
	self.id = 0

func _get_drag_data(_at_position: Vector2) -> Variant:
	if self.id == 0:
		return null
	#var data = {
		#"sprite": $sprite.texture,
		#"amount": $amount.text,
		#"backup": self
	#}
	var preview = TextureRect.new()
	preview.texture = $sprite.texture
	preview.custom_minimum_size = Vector2(48, 48)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	$sprite.visible = false
	$amount.visible = false
	return self

func _return_data(data: Variant) -> void:
	$sprite.texture = data.sprite
	$amount.text = data.amount

func _can_drop_data(_at_position: Vector2, _data: Variant) -> bool:
	return true
	
func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		# The drag ended without _drop_data() successfully
		$sprite.visible = true
		$amount.visible = true

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data.id == 0:
		return
	if self.id == data.id and self.stackable: # Se o id for o mesmo soma as quantidades
		var quantity = int($amount.text)
		quantity += int(data.amount.text)
		$amount.text = str(quantity)
		data.set_empty_slot()
	else: # Se o sprite for diferente troca os dados de lugar
		var sprite = data.get_node("sprite").texture
		var text = data.get_node("amount").text
		var n_id = data.id
		data.get_node("sprite").texture = $sprite.texture
		data.get_node("amount").text = $amount.text
		data.id = self.id
		$sprite.texture = sprite
		$amount.text = text
		self.id = n_id
