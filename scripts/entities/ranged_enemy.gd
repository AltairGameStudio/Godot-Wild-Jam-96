class_name RangedEnemy
extends CharacterBody2D

signal enemy_died

@export_group("Atributos")
@export var max_health: float = 40.0
@export var move_speed: float = 90.0
@export var turn_speed: float = 4.0
@export var stop_distance: float = 250.0
@export var knockback_multiplier: float = 1.3

@export_group("Combate")
@export var bullet_scene: PackedScene # Arraste a cena do seu EnemyBullet aqui!
@export var min_shoot_interval: float = 1.2 # Tempo mínimo de espera entre tiros
@export var max_shoot_interval: float = 2.6 # Tempo máximo de espera entre tiros
@export var shoot_spread_degrees: float = 12.0

@export_group("Distâncias de Combate")
@export var retreat_distance: float = 170.0 # Se o player chegar mais perto que isso, ele recua
@export var strafe_speed_ratio: float = 0.75 # Velocidade enquanto circula

@export var separation_strength: float = 60.0 # Força com que os inimigos se repelem
@onready var separation_area: Area2D = $SeparationArea

var strafe_direction: float = 1.0
var strafe_change_timer: float = 0.0

var current_health: float
var player_ref: Node2D = null

@onready var health_bar: ProgressBar = $HealthBar
@onready var shoot_point: Marker2D = $ShootPoint
@onready var shoot_timer: Timer = $ShootTimer
@onready var hit_receivers_node: Node2D = $HitReceivers

var is_dead: bool = false

func _ready() -> void:
	add_to_group("enemies")
	
	current_health = max_health
	player_ref = get_tree().get_first_node_in_group("player") as Node2D
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.top_level = true
		_update_healthbar_position()
		
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	# Inicia o primeiro tiro com tempo aleatório
	shoot_timer.start(randf_range(min_shoot_interval, max_shoot_interval))
	
	if hit_receivers_node:
		for child in hit_receivers_node.get_children():
			if child is HitReceiver:
				child.hit_received.connect(_on_hit_received)
				
	strafe_direction = 1.0 if randf() > 0.5 else -1.0
	strafe_change_timer = randf_range(1.5, 3.5)

func _physics_process(delta: float) -> void:
	_handle_ai_combat(delta)
	move_and_slide()
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

func _handle_ai_combat(delta: float) -> void:
	if not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player") as Node2D
		return

	var to_player = player_ref.global_position - global_position
	var distance = to_player.length()

	# Mira sempre no jogador
	var target_angle = to_player.angle() - (PI / 2.0)
	rotation = rotate_toward(rotation, target_angle, turn_speed * delta)

	# Atualiza timer de troca de direção do strafe
	strafe_change_timer -= delta
	if strafe_change_timer <= 0.0:
		strafe_direction *= -1.0 # Inverte o sentido (horário / anti-horário)
		strafe_change_timer = randf_range(2.0, 4.0)

	var forward_dir = to_player.normalized()
	var lateral_dir = Vector2(-forward_dir.y, forward_dir.x) * strafe_direction

	var desired_velocity = Vector2.ZERO

	if distance > stop_distance:
		# Longe demais: avança em direção ao player, com leve desvio lateral
		var move_dir = (forward_dir + lateral_dir * 0.3).normalized()
		desired_velocity = move_dir * move_speed

	elif distance < retreat_distance:
		# Perto demais: recua e esquiva para o lado
		var retreat_dir = (-forward_dir + lateral_dir * 0.5).normalized()
		desired_velocity = retreat_dir * (move_speed * 1.1)

	else:
		# Na distância ideal: circunda o jogador lateralmente
		desired_velocity = lateral_dir * (move_speed * strafe_speed_ratio)

	# Adiciona a repulsão para desviar e não colidir com outros inimigos
	var separation = _get_separation_vector() * separation_strength
	desired_velocity += separation

	velocity = velocity.move_toward(desired_velocity, 450.0 * delta)

# --- SISTEMA DE TIRO ---

func _on_shoot_timer_timeout() -> void:
	# Só atira se o player existir e estiver dentro de uma distância razoável
	if is_instance_valid(player_ref) and (player_ref.global_position - global_position).length() < stop_distance + 500:
		shoot()
		
	# Sorteia um novo intervalo aleatório para o próximo disparo
	shoot_timer.start(randf_range(min_shoot_interval, max_shoot_interval))

func shoot() -> void:
	if bullet_scene == null or not is_instance_valid(player_ref):
		return
		
	var bullet = bullet_scene.instantiate() as Area2D
	
	# Calcula a direção em linha reta para o player
	var base_dir = (player_ref.global_position - shoot_point.global_position).normalized()
	
	# Sorteia uma variação de ângulo em radianos entre [-spread, +spread]
	var spread_rad = deg_to_rad(shoot_spread_degrees)
	var random_offset = randf_range(-spread_rad, spread_rad)
	
	# Aplica a rotação no vetor de direção
	bullet.direction = base_dir.rotated(random_offset)
	bullet.global_position = shoot_point.global_position
	
	get_tree().current_scene.add_child(bullet)

func _update_healthbar_position() -> void:
	if health_bar:
		health_bar.global_position = global_position + Vector2(-health_bar.size.x / 2.0, -30.0)

func die() -> void:
	# Se já morreu neste frame, não faz nada
	if is_dead: return 
	
	is_dead = true
	enemy_died.emit()
	queue_free()
	
func _on_hit_received(damage: float, direction: Vector2, hit_type: HitReceiver.HitType, impact_speed: float = 0.0) -> void:
	match hit_type:
		HitReceiver.HitType.SHIELD:
			velocity += direction * (impact_speed * 0.4 + 100.0)
		HitReceiver.HitType.WEAKSPOT, HitReceiver.HitType.NORMAL:
			current_health = maxf(0.0, current_health - damage)
			if health_bar:
				health_bar.value = current_health
				
				var knockback_force = impact_speed * knockback_multiplier
				if hit_type == HitReceiver.HitType.WEAKSPOT:
					knockback_force *= 1.3
				
				velocity += direction * knockback_force
				
				if current_health <= 0.0:
					die()
