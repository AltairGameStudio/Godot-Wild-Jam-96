extends Area2D

@export var speed: float = 400.0
@export var damage: float = 5.0

var direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	# Checa se bateu no player
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			# Passa o dano e a direção para empurrar o player
			body.take_damage(damage, direction * 150.0, true)
		queue_free()
		
	# Se bateu em paredes ou barreiras, a bala some
	elif body is StaticBody2D:
		queue_free()

func _on_screen_exited() -> void:
	queue_free()
