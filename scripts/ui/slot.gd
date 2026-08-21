class_name slot
extends Control

var id = 0
var description = null
var item = {
		1: "Moeda",
		2: "Lança",
		3: "Armadura",
		4: "Capa",
		5: "Rédea",
		6: "Ferradura",
		7: "Sela"
	}
var item_description = {
	1: "%d dinheiros pae",
	2: "Aumenta o dano em (%d).",
	3: "Diminui em (%d) porcento o dano recebido.",
	4: "Aumenta a vida máxima em (%d)",
	5: "Aumenta a velocidade de condução (giro) em (%.1f).",
	6: "Aumenta o multiplicador de velocidade em (%.1f).",
	7: "Aumenta a velocidade máxima em (%d)."
}

func _ready() -> void:
	pass

func set_empty_slot() -> void:
	$sprite.texture = null
	$amount.text = ""
	self.id = 0

func _process(_delta: float) -> void:
	if $description.visible:
		$description.global_position = get_global_mouse_position() + Vector2(10,10)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if self.id == 0:
		return null
	var preview = TextureRect.new()
	preview.texture = $sprite.texture
	preview.custom_minimum_size = Vector2(60, 60)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	$sprite.visible = false
	$amount.visible = false
	$description.visible = false
	return self

func _return_data(data: Variant) -> void:
	$sprite.texture = data.sprite
	$amount.text = data.amount

func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		$sprite.visible = true
		if !(self is equipment) and $amount:
			$amount.visible = true

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is equipment:
		if self.id == 0:
			return true
		elif data.id != self.id:
			return false
	return true

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data.id == 0:
		return
	if data == self: 
		$sprite.visible = true
		if !(self is equipment):
			$amount.visible = true
		return
	if data is equipment and self.id == 0:
		get_tree().call_group("player", "equipment_changed", data.id, false)
		$amount.text = "1"
		$sprite.texture = data.equip_sprite
		id = data.id
		data.set_empty_slot()
		return
	if self.id == data.id: # Se o id for o mesmo soma as quantidades
		var quantity = int($amount.text)
		if data is equipment:
			quantity += 1
			get_tree().call_group("player", "equipment_changed", data.id, false)
		else:
			quantity += int(data.get_node("amount").text)
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
	

func _on_mouse_entered() -> void:
	if id == 0 or get_viewport().gui_is_dragging(): return
	var it = id/100
	var lvl = id%100 
	var buff = {
		1: lvl*5,
		2: lvl*2,
		3: lvl*3,
		4: lvl*10,
		5: lvl/5.0,
		6: lvl/10.0,
		7: lvl*20
	}
	$description.text = "Item: %s\nLevel: %d\n%s" % [item[it], lvl, item_description[it] % buff[it]]
	$description.visible = true

func _on_mouse_exited() -> void:
	$description.visible = false
