extends CanvasLayer

func _ready() -> void:
	$inventory.visible = false
	$inventory/store.visible = false
	$upgrade_shop.visible = false

func _process(_delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	
	# Tecla E para abrir/fechar inventário normal
	if Input.is_action_just_pressed("toggle_inventory"):
		if $upgrade_shop.visible:
			$upgrade_shop.visible = false
		var is_open = $inventory.visible
		if not is_open:
			$inventory.visible = true
			if is_instance_valid(player):
				player.can_move = false
				player.velocity = Vector2.ZERO
		else:
			$inventory.visible = false
			$inventory/store.visible = false
			$upgrade_shop.visible = false
			if is_instance_valid(player):
				player.can_move = true

	# Tecla ESC (ui_cancel) para fechar lojas e inventários
	if Input.is_action_just_pressed("ui_cancel"):
		var was_any_open = $inventory.visible or $upgrade_shop.visible or $inventory/store.visible
		$inventory.visible = false
		$inventory/store.visible = false
		$upgrade_shop.visible = false
		
		# Se alguma janela foi fechada pelo ESC, libera o movimento do player
		if was_any_open and is_instance_valid(player):
			player.can_move = true

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
