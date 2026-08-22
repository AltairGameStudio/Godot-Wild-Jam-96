extends slot
class_name buy_slot

var item_cost = 0
var item_lvl = 1
var item_value = {
	2: 5,
	3: 8,
	4: 3,
	5: 6,
	6: 4,
	7: 10
}
var item_type = 0

func _ready() -> void:
	item_type = int(name)
	item_cost = item_value[item_type]
	id = 100*item_type+item_lvl
	$cost.text = str(item_cost)

func _can_drop_data(_at_position: Vector2, _data: Variant) -> bool:
	return false

func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview = TextureRect.new()
	preview.texture = $sprite.texture
	preview.custom_minimum_size = Vector2(60, 60)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	return self

func set_empty_slot():
	get_tree().current_scene.gold -= item_cost

func _notification(_what):
	return
	
func can_buy() -> bool:
	if item_cost <= get_tree().current_scene.gold:
		return true
	return false

func on_lvl_up() -> void:
	if (item_lvl >= 10):
		return
	item_lvl += 1
	id += 1
	item_cost += item_value[item_type]
	$cost.text = str(item_cost)

func on_lvl_down() -> void:
	if (item_lvl <= 1):
		return
	item_lvl -= 1
	id -= 1
	item_cost -= item_value[item_type]
	$cost.text = str(item_cost)
