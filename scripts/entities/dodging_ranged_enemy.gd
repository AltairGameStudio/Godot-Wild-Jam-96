class_name DodgingRangedEnemy
extends CharacterBody2D

signal enemy_died

@export_group("Atributos")
@export var max_health: float = 35.0
@export var move_speed: float = 95.0
@export var turn_speed: float = 4.5
@export var stop_distance: float = 260.0
@export var knockback_multiplier: float = 1.2

@export_group("Esquiva / Dash Reativo")
@export var dodge_trigger_distance: float = 220.0     # Distância em que ele percebe o ataque
@export var min_player_speed_trigger: float = 250.0   # Velocidade mínima do player para assustar o inimigo
@export var dodge_speed: float = 580.0                # Força/velocidade do dash lateral
@export var dodge_duration: float = 0.25              # Duração do impulso em segundos
@export var dodge_cooldown_time: float = 3.0          # Tempo de recarga entre esquivas

@export_group("Combate")
@export var bullet_scene: PackedScene
@export var min_shoot_interval: float = 1.3
@export var max_shoot_interval: float = 2.5
@export var shoot_spread_degrees: float = 12.0

@export_group("Distâncias de Combate")
@export var retreat_distance: float = 160.0
@export var strafe_speed_ratio: float = 0.8
@export var separation_strength: float = 60.0

@onready var separation_area: Area2D = $SeparationArea
@onready var health_bar: ProgressBar = $HealthBar
@onready var shoot_point: Marker2D = $ShootPoint
@onready var shoot_timer: Timer = $ShootTimer
@onready var hit_receivers_node: Node2D = $HitReceivers

var current_health: float
var player_ref: Node2D = null
var is_dead: bool = false

# Variáveis de Strafe
var strafe_direction: float = 1.0
var strafe_change_timer: float = 0.0

# Variáveis de Controle da Esquiva
var is_dodging: bool = false
var dodge_timer: float = 0.0
var dodge_cooldown: float = 0.0
var dodge_direction_vec: Vector2 = Vector2.ZERO

var drop = preload("res://scenes/ui/item.tscn")

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
	shoot_timer.start(randf_range(min_shoot_interval, max_shoot_interval))
	
	if hit_receivers_node:
		for child in hit_receivers_node.get_children():
			if child is HitReceiver:
				child.hit_received.connect(_on_hit_received)
				
	strafe_direction = 1.0 if randf() > 0.5 else -1.0
	strafe_change_timer = randf_range(1.5, 3.0)

func _physics_process(delta: float) -> void:
	# Atualiza o tempo de recarga da esquiva
	if dodge_cooldown > 0.0:
		dodge_cooldown -= delta

	# Processa movimento ou esquiva
	if is_dodging:
		_process_dodge(delta)
	else:
		_check_dodge_trigger()
		_handle_ai_combat(delta)

	move_and_slide()
	_update_healthbar_position()

# --- VERIFICAÇÃO E EXECUÇÃO DA ESQUIVA ---

func _check_dodge_trigger() -> void:
	if dodge_cooldown > 0.0 or not is_instance_valid(player_ref):
		return
		
	var player_char = player_ref as CharacterBody2D
	if not player_char:
		return
		
	var to_enemy = global_position - player_ref.global_position
	var distance = to_enemy.length()
	
	# Checa se o player está próximo o suficiente para ativar o reflexo
	if distance > dodge_trigger_distance:
		return
		
	var player_speed = player_char.velocity.length()
	
	# Checa se o player está vindo em alta velocidade
	if player_speed < min_player_speed_trigger:
		return
		
	# Checa se o vetor de velocidade do player está apontado para a direção deste inimigo
	var player_move_dir = player_char.velocity.normalized()
	var dir_to_enemy = to_enemy.normalized()
	var alignment = player_move_dir.dot(dir_to_enemy)
	
	# Se alignment > 0.65, o player está vindo em rota de colisão frontal direta
	if alignment > 0.65:
		_trigger_dodge(dir_to_enemy)

func _trigger_dodge(dir_from_player: Vector2) -> void:
	is_dodging = true
	dodge_timer = dodge_duration
	dodge_cooldown = dodge_cooldown_time
	
	# Vetor lateral relativo à investida do player
	var lateral_dir = Vector2(-dir_from_player.y, dir_from_player.x).normalized()
	
	# Sorteia para qual dos dois lados vai esquivar (-1 ou 1)
	var side = 1.0 if randf() > 0.5 else -1.0
	dodge_direction_vec = lateral_dir * side
	
	# Aplica a velocidade instantânea do dash
	velocity = dodge_direction_vec * dodge_speed
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.4, 0.05)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

func _process_dodge(delta: float) -> void:
	dodge_timer -= delta
	
	# Mantém a velocidade do dash desacelerando suavemente até o fim da duração
	velocity = velocity.move_toward(dodge_direction_vec * (dodge_speed * 0.4), 800.0 * delta)
	
	if dodge_timer <= 0.0:
		is_dodging = false

# --- COMBATE PADRÃO ---

func _handle_ai_combat(delta: float) -> void:
	if not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player") as Node2D
		return

	var to_player = player_ref.global_position - global_position
	var distance = to_player.length()

	# Rotação em direção ao player
	var target_angle = to_player.angle() - (PI / 2.0)
	rotation = rotate_toward(rotation, target_angle, turn_speed * delta)

	# Atualiza timer do strafe normal
	strafe_change_timer -= delta
	if strafe_change_timer <= 0.0:
		strafe_direction *= -1.0
		strafe_change_timer = randf_range(2.0, 4.0)

	var forward_dir = to_player.normalized()
	var lateral_dir = Vector2(-forward_dir.y, forward_dir.x) * strafe_direction
	var desired_velocity = Vector2.ZERO

	if distance > stop_distance:
		var move_dir = (forward_dir + lateral_dir * 0.3).normalized()
		desired_velocity = move_dir * move_speed
	elif distance < retreat_distance:
		var retreat_dir = (-forward_dir + lateral_dir * 0.5).normalized()
		desired_velocity = retreat_dir * (move_speed * 1.1)
	else:
		desired_velocity = lateral_dir * (move_speed * strafe_speed_ratio)

	var separation = _get_separation_vector() * separation_strength
	desired_velocity += separation

	velocity = velocity.move_toward(desired_velocity, 450.0 * delta)

func _get_separation_vector() -> Vector2:
	if not separation_area:
		return Vector2.ZERO
		
	var push_vector = Vector2.ZERO
	for area in separation_area.get_overlapping_areas():
		if area != separation_area:
			var diff = global_position - area.global_position
			var distance = diff.length()
			if distance > 0.0:
				push_vector += diff.normalized() / maxf(distance, 1.0)
				
	return push_vector.normalized()

# --- SISTEMA DE TIRO ---

func _on_shoot_timer_timeout() -> void:
	# Não dispara no meio da esquiva
	if not is_dodging and is_instance_valid(player_ref) and (player_ref.global_position - global_position).length() < stop_distance + 500:
		shoot()
		
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

func create_item() -> void:
	for i in range(1, 6):
		var new_drop = drop.instantiate()
		new_drop.setup(i * 100, self.global_position)
		get_tree().current_scene.add_child(new_drop)

func die() -> void:
	if is_dead: return 
	call_deferred("create_item")
	is_dead = true
	enemy_died.emit()
	queue_free.call_deferred()

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
