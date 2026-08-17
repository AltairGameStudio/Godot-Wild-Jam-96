class_name Enemy
extends CharacterBody2D

@export_group("Atributos")
@export var max_health: float = 60.0
@export var move_speed: float = 120.0
@export var turn_speed: float = 3.5
@export var contact_damage: float = 15.0

var current_health: float
var player_ref: Node2D = null

@onready var hit_receivers_node: Node2D = $HitReceivers
@onready var health_bar: ProgressBar = $HealthBar

func _ready() -> void:
	current_health = max_health
	player_ref = get_tree().get_first_node_in_group("player") as Node2D
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.top_level = true # Desacopla rotação e movimento do pai
	
	if hit_receivers_node:
		for child in hit_receivers_node.get_children():
			if child is HitReceiver:
				child.hit_received.connect(_on_hit_received)

func _physics_process(delta: float) -> void:
	_handle_ai_chase(delta)
	move_and_slide()
	_check_body_collisions()
	_update_healthbar_position()

func _handle_ai_chase(delta: float) -> void:
	if not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player") as Node2D
		return

	var to_player = player_ref.global_position - global_position
	var distance = to_player.length()
	
	# Rotaciona para o jogador alinhando a frente desenhada (DOWN)
	var target_angle = to_player.angle() - (PI / 2.0)
	rotation = rotate_toward(rotation, target_angle, turn_speed * delta)
	
	if distance > 20.0:
		var forward_dir = Vector2.DOWN.rotated(rotation)
		var desired_velocity = forward_dir * move_speed
		velocity = velocity.move_toward(desired_velocity, 500.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)

func _check_body_collisions() -> void:
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider is Player:
			var push_dir = (collider.global_position - global_position).normalized()
			collider.take_damage(contact_damage, push_dir * 250.0)

func _update_healthbar_position() -> void:
	if health_bar:
		health_bar.rotation = 0.0
		health_bar.global_position = global_position + Vector2(-health_bar.size.x / 2.0, 30.0)
	
func _on_hit_received(damage: float, direction: Vector2, hit_type: HitReceiver.HitType) -> void:
	match hit_type:
		HitReceiver.HitType.SHIELD:
			velocity += direction * 150.0
		HitReceiver.HitType.WEAKSPOT, HitReceiver.HitType.NORMAL:
			current_health = maxf(0.0, current_health - damage)
			if health_bar:
				health_bar.value = current_health
			velocity += direction * (damage * 8.0)
			
			if current_health <= 0.0:
				die()

func die() -> void:
	queue_free()
