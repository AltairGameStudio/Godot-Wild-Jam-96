class_name TarPuddle
extends Area2D

@export var lifetime: float = 5.0        # Tempo total antes de sumir
@export var fade_time: float = 1.0       # Tempo de esmaecimento final
@export var slow_factor: float = 0.45    # Reduz para 45% da velocidade normal

var overlapping_players: Array[Node2D] = []

func _ready() -> void:
	# Camadas de colisão: monitora a colisão do player
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Animação inicial de surgimento (escala crescendo)
	scale = Vector2(0.3, 0.3)
	var spawn_tween = create_tween()
	spawn_tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Agenda o desaparecimento
	_schedule_fade_out()

func _schedule_fade_out() -> void:
	var timer_delay = maxf(0.1, lifetime - fade_time)
	await get_tree().create_timer(timer_delay).timeout
	
	if not is_inside_tree():
		return
		
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, fade_time)
	fade_tween.finished.connect(queue_free)

func _on_body_entered(body: Node2D) -> void:
	if (body is Player or body.is_in_group("player")) and body.has_method("apply_slow"):
		overlapping_players.append(body)
		body.apply_slow(slow_factor)

func _on_body_exited(body: Node2D) -> void:
	if body in overlapping_players:
		overlapping_players.erase(body)
		if body.has_method("remove_slow"):
			body.remove_slow()

# Garante que, se a poça sumir enquanto o player estiver dentro, o efeito de lentidão é removido
func _exit_tree() -> void:
	for player in overlapping_players:
		if is_instance_valid(player) and player.has_method("remove_slow"):
			player.remove_slow()
	overlapping_players.clear()
