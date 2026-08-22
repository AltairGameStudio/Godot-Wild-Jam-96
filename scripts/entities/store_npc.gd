extends NPC

func _ready() -> void:
	# Garante que o NPC esteja no grupo para o TownUI conectar
	add_to_group("npcs")
	npc_type = NPCType.SHOP
	npc_name = "Vendedor"
	prompt_message = "[E] Abrir a loja"

	prompt_label.text = prompt_message
	prompt_label.visible = false

	if visual and "modulate" in visual:
		visual.modulate = accent_color

	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_in_range = true
		prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_in_range = false
		prompt_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	# Aceita tanto a ação customizada 'interact' quanto 'ui_accept' ou a tecla E diretamente
	if player_in_range:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			var player = get_tree().get_first_node_in_group("player")
			var is_open = player.get_node("inventoryHUD/inventory/store").visible
			player.get_node("inventoryHUD/inventory").visible = !is_open
			player.get_node("inventoryHUD/inventory/store").visible = !is_open
			interacted.emit(self)
