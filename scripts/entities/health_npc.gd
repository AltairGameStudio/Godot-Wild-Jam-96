extends NPC

var cost : int = 0
var coin_per_health = 1
var life_to_heal = 0
var player_ref = null

func _ready() -> void:
	# Garante que o NPC esteja no grupo para o TownUI conectar
	add_to_group("npcs")
	npc_type = NPCType.SHOP
	npc_name = "Doctor"
	prompt_message = "[Space] Pay %d to cure"
	prompt_label.position += Vector2(350, -50)
	prompt_label.set_rotation_degrees(-180)
	visual.modulate = Color(0.7,0,0)
	prompt_label.text = prompt_message
	prompt_label.visible = false
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_ref = body
		if player_ref.current_health == player_ref.max_health:
			prompt_label.text = "Your life is full"
		else:
			var total_gold = get_tree().current_scene.gold
			var life_missing = (body.max_health + body.extra_health) - body.current_health
			life_to_heal = min(min(total_gold/coin_per_health, life_missing), 10)
			cost = life_to_heal*coin_per_health
			player_in_range = true
			prompt_label.text = prompt_message % cost
		prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_in_range = false
		prompt_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			if (player_ref.current_health < player_ref.max_health + player_ref.extra_health):
				player_ref.current_health += life_to_heal * 2
				get_tree().current_scene.gold -= cost
				player_ref.update_info()
				_on_body_entered(player_ref)
				interacted.emit(self)
