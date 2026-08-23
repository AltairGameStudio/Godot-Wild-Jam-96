extends NPC

func _ready() -> void:
	# Garante que o NPC esteja no grupo para o TownUI conectar
	add_to_group("npcs")
	npc_type = NPCType.SHOP
	npc_name = "Trainer"
	prompt_message = "[E] Improve attributes"
	prompt_label.position += Vector2(40, 30)
	prompt_label.set_rotation_degrees(-90)
	visual.modulate = Color(0.8,0.8,0.6)
	prompt_label.text = prompt_message
	prompt_label.visible = false
	# +40 no x e rodar -90
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
			if player.get_node("PlayerCanvas/inventory").visible:
				player.get_node("PlayerCanvas/inventory").visible = false
			player.get_node("PlayerCanvas/upgrade_shop").visible = !player.get_node("PlayerCanvas/upgrade_shop").visible
			interacted.emit(self)
