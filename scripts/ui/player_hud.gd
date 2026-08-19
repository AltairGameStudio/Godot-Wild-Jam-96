extends CanvasLayer

@onready var health_bar: ProgressBar = $UI/PlayerHealthBar

func _ready() -> void:
	var player = get_tree().get_first_node_in_group("player") as Player
	if player:
		health_bar.max_value = player.max_health
		health_bar.value = player.max_health
		player.health_changed.connect(_on_player_health_changed)

func _on_player_health_changed(current: float, max_h: float) -> void:
	health_bar.max_value = max_h
	health_bar.value = current

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		$inventory.visible = not $inventory.visible

func add_item_inventory(new_item: Area2D) -> bool:
	var empty = null
	for inv_slot in $inventory/invent/Container.get_children():
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
