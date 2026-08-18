class_name slot
extends Control

func _ready() -> void:
	pass

func set_empty_slot() -> void:
	$sprite.texture = null
	$amount.text = ""

func _get_drag_data(_at_position: Vector2) -> Variant:
	if $sprite.texture == null:
		return null
	var data = {
		"sprite": $sprite.texture,
		"amount": $amount.text,
		"backup": self
	}
	set_empty_slot()
	set_drag_preview(data.sprite)
	return data

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is slot:
		return true
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if $sprite.texture == null:
		return
	if $sprite.texture == data.sprite: # Se o sprite for o mesmo soma as quantidades
		var quantity = int($amount.text)
		quantity += int(data.amount)
		$amount.text = str(quantity)
	else: # Se o sprite for diferente troca os dados de lugar
		data.backup.get_node("sprite").texture = $sprite.texture
		data.backup.get_node("amount").text = $amount.text
		$sprite.texture = data.sprite
		$amount.text = data.amount
