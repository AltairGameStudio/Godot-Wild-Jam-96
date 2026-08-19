class_name Enemy
extends CharacterBody2D

signal enemy_died

@export_group("Atributos")
@export var max_health: float = 60.0
@export var move_speed: float = 120.0
@export var turn_speed: float = 3.5
@export var contact_damage: float = 15.0
@export var knockback_multiplier: float = 1.2

@export_group("Comportamento Orgânico")
@export var wobble_frequency: float = 3.0    # Velocidade da oscilação
@export var wobble_amplitude: float = 0.5    # Intensidade do desvio lateral (0.0 a 1.0)

@export var separation_strength: float = 60.0 # Força com que os inimigos se repelem
@onready var separation_area: Area2D = $SeparationArea

var time_offset: float = 0.0

var current_health: float
var player_ref: Node2D = null

@onready var hit_receivers_node: Node2D = $HitReceivers
@onready var health_bar: ProgressBar = $HealthBar

var is_dead: bool = false

func _ready() -> void:
	add_to_group("enemies")
	
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
				
	time_offset = randf_range(0.0, 100.0)
	move_speed *= randf_range(0.9, 1.1)

func _physics_process(delta: float) -> void:
	_handle_ai_chase(delta)
	move_and_slide()
	_check_body_collisions()
	_update_healthbar_position()
	
func _get_separation_vector() -> Vector2:
	if not separation_area:
		return Vector2.ZERO
		
	var push_vector = Vector2.ZERO
	var overlapping_areas = separation_area.get_overlapping_areas()
	
	for area in overlapping_areas:
		# Ignora a própria área
		if area != separation_area:
			var diff = global_position - area.global_position
			var distance = diff.length()
			if distance > 0.0:
				# Quanto mais perto estiverem, mais forte é o empurrão
				push_vector += diff.normalized() / maxf(distance, 1.0)
				
	return push_vector.normalized()

func _handle_ai_chase(delta: float) -> void:
	if not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player") as Node2D
		return

	var to_player = player_ref.global_position - global_position
	var distance = to_player.length()

	# Direção frontal e direção lateral
	var forward_dir = to_player.normalized()
	var lateral_dir = Vector2(-forward_dir.y, forward_dir.x)

	# Calcula desvio senoidal
	var current_time = (Time.get_ticks_msec() / 1000.0) + time_offset
	var lateral_wobble = sin(current_time * wobble_frequency) * wobble_amplitude

	# Quando estiver muito perto do player, reduz o zigue-zague para focar no ataque
	if distance < 60.0:
		lateral_wobble *= (distance / 60.0)

	var final_move_dir = (forward_dir + lateral_dir * lateral_wobble).normalized()

	# Rotação alinhada à direção do movimento
	var target_angle = to_player.angle() - (PI / 2.0)
	rotation = rotate_toward(rotation, target_angle, turn_speed * delta)

	# Aplica a velocidade
	if distance > 20.0:
		# Direção desejada para ir até o player
		var desired_velocity = final_move_dir * move_speed
		
		# Adiciona a repulsão para desviar de outros inimigos
		var separation = _get_separation_vector() * separation_strength
		desired_velocity += separation
		
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
		health_bar.global_position = global_position + Vector2(-health_bar.size.x / 2.0, 30.0)
	
func _on_hit_received(damage: float, direction: Vector2, hit_type: HitReceiver.HitType, impact_speed: float = 0.0) -> void:
	match hit_type:
		HitReceiver.HitType.SHIELD:
			# Se acertar o escudo, empurra menos
			velocity += direction * (impact_speed * 0.4 + 100.0)
		HitReceiver.HitType.WEAKSPOT, HitReceiver.HitType.NORMAL:
			current_health = maxf(0.0, current_health - damage)
			if health_bar:
				health_bar.value = current_health
			
			# Força proporcional à velocidade do impacto
			var knockback_force = impact_speed * knockback_multiplier
			if hit_type == HitReceiver.HitType.WEAKSPOT:
				# Ponto fraco recebe 30% a mais de empurrão
				knockback_force *= 1.3
			
			velocity += direction * knockback_force
			
			if current_health <= 0.0:
				die()

func die() -> void:
	# Se já morreu neste frame, não faz nada
	if is_dead: return 
	
	is_dead = true
	enemy_died.emit()
	queue_free()
