extends Area2D

# Item_id list:
# @@ -> Identificador do item
# $$ -> Level do item
# Id -> @@$$
# Identificadores:
# 00 -> Null
# 01 -> Moeda
# 02 -> Lança
# 03 -> Armadura
# 04 -> Rédea
# 05 -> Ferradura
# 06 -> Sela
var items = {
	1: "coin",
	2: "lance",
	3: "armor",
	4: "rein",
	5: "horseshoe",
	6: "saddle"
}
var item_id = 0

func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func setup(id: int, pos: Vector2) -> void:
	item_id = id
	self.global_position = pos
	@warning_ignore("integer_division")
	$sprite.texture = load("res://assets/sprites/items/%s.png" % items[item_id/100])
	scale = Vector2(0.75, 0.75)
	
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.pickup_item(self)
		queue_free.call_deferred()
