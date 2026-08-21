class_name TarEnemy
extends CharacterBody2D

signal enemy_died

@export_group("Atributos")
@export var max_health: float = 50.0
@export var wander_speed: float = 80.0
@export var flee_speed: float = 140.0
@export var turn_speed: float = 4.0
@export var flee_distance: float = 260.0 # Distância na qual começa a fugir do player
@export var knockback_multiplier: float = 1.2

@export_group("Rastro de Piche")
@export var tar_puddle_scene: PackedScene
@export var puddle_drop_interval_flee: float = 0.25  # Solta mais rápido ao fugir
@export var puddle_drop_interval_wander: float = 0.8 # Solta mais espaçado ao vagar

@export_group("Comportamento")
@export var separation_strength: float = 50.0
@onready var separation_area: Area2D = $SeparationArea
@onready var hit_receivers_node: Node2D = $HitReceivers
@onready var health_bar: ProgressBar = $HealthBar

var current_health: float
var player_ref: Node2D = null
var is_dead: bool = false
var drop = preload("res://scenes/ui/item.tscn")

# Controle de movimentação aleatória
var wander_direction: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0

# Controle do rastro de piche
var drop_timer: float = 0.0
var is_fleeing: bool = false

func _ready() -> void:
	add_to_group("enemies")
	current_health = max_health
	player_ref = get_tree().get_first_node_in_group("player") as Node2D
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.top_level = true
		_update_healthbar_position()
	
	if hit_receivers_node:
		for child in hit_receivers_node.get_children():
			if child is HitReceiver:
				child.hit_received.connect(_on_hit_received)
				
	_pick_new_wander_direction()

func _physics_process(delta: float) -> void:
	_handle_ai(delta)
	_handle_tar_drop(delta)
	move_and_slide()
	_update_healthbar_position()

func _get_separation_vector() -> Vector2:
	if not separation_area:
		return Vector2.ZERO
		
	var push_vector = Vector2.ZERO
	var overlapping_areas = separation_area.get_overlapping_areas()
	
	for area in overlapping_areas:
		if area != separation_area:
			var diff = global_position - area.global_position
			var distance = diff.length()
			if distance > 0.0:
				push_vector += diff.normalized() / maxf(distance, 1.0)
				
	return push_vector.normalized()

func _handle_ai(delta: float) -> void:
	if not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player") as Node2D
		return

	var to_player = player_ref.global_position - global_position
	var distance_to_player = to_player.length()
	
	var desired_move_dir = Vector2.ZERO
	var current_move_speed = wander_speed

	if distance_to_player < flee_distance:
		# --- ESTADO: FUGINDO ---
		is_fleeing = true
		# Corre na direção contrária ao player
		desired_move_dir = -to_player.normalized()
		current_move_speed = flee_speed
	else:
		# --- ESTADO: VAGANDO ---
		is_fleeing = false
		wander_timer -= delta
		if wander_timer <= 0.0:
			_pick_new_wander_direction()
		desired_move_dir = wander_direction
		current_move_speed = wander_speed

	# Rotação suave na direção em que está correndo
	if desired_move_dir.length_squared() > 0.01:
		var target_angle = desired_move_dir.angle() - (PI / 2.0)
		rotation = rotate_toward(rotation, target_angle, turn_speed * delta)

	# Aplica velocidade e separação de outros inimigos
	var desired_velocity = desired_move_dir * current_move_speed
	var separation = _get_separation_vector() * separation_strength
	desired_velocity += separation

	velocity = velocity.move_toward(desired_velocity, 400.0 * delta)

func _pick_new_wander_direction() -> void:
	# Escolhe um ângulo aleatório para andar
	var random_angle = randf_range(0.0, TAU)
	wander_direction = Vector2(cos(random_angle), sin(random_angle)).normalized()
	wander_timer = randf_range(1.5, 3.5)

func _handle_tar_drop(delta: float) -> void:
	if tar_puddle_scene == null:
		return

	drop_timer -= delta
	if drop_timer <= 0.0:
		_spawn_puddle()
		var current_interval = puddle_drop_interval_flee if is_fleeing else puddle_drop_interval_wander
		drop_timer = current_interval

func _spawn_puddle() -> void:
	var puddle = tar_puddle_scene.instantiate() as Node2D
	# Posiciona ligeiramente atrás do inimigo de acordo com a rotação
	var backward_offset = -Vector2.DOWN.rotated(rotation) * 12.0
	puddle.global_position = global_position + backward_offset
	
	# Adiciona à cena principal para que a poça fique estática no mundo
	get_tree().current_scene.add_child(puddle)

func _update_healthbar_position() -> void:
	if health_bar:
		health_bar.global_position = global_position + Vector2(-health_bar.size.x / 2.0, -30.0)

func _on_hit_received(damage: float, direction: Vector2, hit_type: HitReceiver.HitType, impact_speed: float = 0.0) -> void:
	current_health = maxf(0.0, current_health - damage)
	if health_bar:
		health_bar.value = current_health
	
	var knockback_force = impact_speed * knockback_multiplier
	velocity += direction * knockback_force
	
	# Ao tomar dano, assusta e força fugir imediatamente
	is_fleeing = true
	drop_timer = 0.0
	
	if current_health <= 0.0:
		die()

func create_item() -> void:
	for i in range(1, 4):
		var new_drop = drop.instantiate()
		new_drop.setup(i * 100, self.global_position)
		get_tree().current_scene.add_child(new_drop)

func die() -> void:
	if is_dead: return
	call_deferred("create_item")
	is_dead = true
	enemy_died.emit()
	queue_free.call_deferred()
