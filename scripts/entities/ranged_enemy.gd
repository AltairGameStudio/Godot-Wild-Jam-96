class_name RangedEnemy
extends CharacterBody2D

signal enemy_died

@export_group("Atributos")
@export var max_health: float = 40.0
@export var move_speed: float = 90.0
@export var turn_speed: float = 4.0
@export var stop_distance: float = 250.0

@export_group("Combate")
@export var bullet_scene: PackedScene # Arraste a cena do seu EnemyBullet aqui!

var current_health: float
var player_ref: Node2D = null

@onready var health_bar: ProgressBar = $HealthBar
@onready var shoot_point: Marker2D = $ShootPoint
@onready var shoot_timer: Timer = $ShootTimer

var is_dead: bool = false

func _ready() -> void:
	current_health = max_health
	player_ref = get_tree().get_first_node_in_group("player") as Node2D
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.top_level = true
		
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)

func _physics_process(delta: float) -> void:
	_handle_ai_combat(delta)
	move_and_slide()
	_update_healthbar_position()

func _handle_ai_combat(delta: float) -> void:
	if not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player") as Node2D
		return

	var to_player = player_ref.global_position - global_position
	var distance = to_player.length()
	
	# Rotaciona para mirar no jogador
	var target_angle = to_player.angle() - (PI / 2.0)
	rotation = rotate_toward(rotation, target_angle, turn_speed * delta)
	
	# Só anda se estiver mais longe que a stop_distance
	if distance > stop_distance:
		var forward_dir = Vector2.DOWN.rotated(rotation)
		velocity = velocity.move_toward(forward_dir * move_speed, 500.0 * delta)
	else:
		# Se já está na distância de tiro, ele freia
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)

# --- SISTEMA DE TIRO ---

func _on_shoot_timer_timeout() -> void:
	# Só atira se o player existir e estiver dentro de uma distância razoável
	if is_instance_valid(player_ref) and (player_ref.global_position - global_position).length() < stop_distance + 100:
		shoot()

func shoot() -> void:
	if bullet_scene == null:
		return
		
	# Instancia o tiro
	var bullet = bullet_scene.instantiate() as Area2D
	
	# Calcula a direção exata da arma para o player
	var dir = (player_ref.global_position - shoot_point.global_position).normalized()
	bullet.direction = dir
	
	# Define a posição inicial do tiro para o nosso Marker2D
	bullet.global_position = shoot_point.global_position
	
	# Adiciona o tiro ao mundo
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
