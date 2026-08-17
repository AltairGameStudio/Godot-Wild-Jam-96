extends Area2D

@export var speed: float = 400.0
@export var damage: float = 15.0

var direction: Vector2 = Vector2.ZERO

func _physics_process(delta: float) -> void:
	# Move o tiro na direção definida pelo inimigo
	global_position += direction * speed * delta

# --- SINAIS ---

func _on_body_entered(body: Node2D) -> void:
	# Se bateu no player, dá dano e deleta o tiro
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			# Empurra o player na direção do tiro
			var push_dir = direction
			body.take_damage(damage, push_dir * 150.0)
		queue_free()
		
	# Se bateu na parede, deleta o tiro também
	elif body is StaticBody2D:
		queue_free()

func _on_screen_exited() -> void:
	# Deleta o tiro se ele sair da tela do jogador
	queue_free()
