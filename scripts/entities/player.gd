class_name Player
extends CharacterBody2D

signal health_changed(current: float, max_h: float)

@export_group("Vida")
@export var max_health: float = 100.0
var current_health: float

@export_group("Movimento")
@export var engine_power: float = 200.0
@export var max_speed: float = 600.0
@export var steer_speed: float = 2.0
@export var forward_friction: float = 0.98
@export var drift_traction: float = 0.85

@export_group("Combate")
@export var min_charge_speed: float = 100.0
#@export var base_damage: float = 10.0
@export var base_damage: float = 1000.0
@export var damage_velocity_scale: float = 0.01
@export var bounce_ratio: float = 0.35

@export_group("Defesa e Invulnerabilidade")
@export var invulnerability_duration: float = 0.6
var is_invulnerable: bool = false

@onready var lance_pivot: Node2D = $LancePivot
@onready var lance_area: Area2D = $LancePivot/LanceArea
@onready var hurtbox_area: Area2D = $HurtboxArea

var heading_angle: float = 0.0

func _ready() -> void:
	add_to_group("player")
	current_health = max_health
	heading_angle = rotation
	
	if lance_area:
		lance_area.area_entered.connect(_on_lance_hit)
	
	if hurtbox_area:
		hurtbox_area.area_entered.connect(_on_hurtbox_area_entered)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if is_invulnerable:
		return
		
	# Aceita tanto EnemyHitbox quanto classes genéricas de Hitbox
	if area is EnemyHitbox or area.has_method("get_damage_payload"):
		var payload: Dictionary = area.get_damage_payload(global_position)
		take_damage(payload["damage"], payload["knockback"])

func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO) -> void:
	if is_invulnerable:
		return
		
	# Se estiver em investida rápida frontal, a lança anula o dano de frente
	var forward_vec = Vector2.UP.rotated(heading_angle)
	var is_charging = velocity.length() >= min_charge_speed and velocity.normalized().dot(forward_vec) > 0.5
	
	if is_charging:
		return
		
	current_health = maxf(0.0, current_health - amount)
	velocity += knockback
	health_changed.emit(current_health, max_health)
	
	_trigger_invulnerability()
	
	if current_health <= 0.0:
		die()

func _trigger_invulnerability() -> void:
	is_invulnerable = true
	var tween = create_tween().set_loops(int(invulnerability_duration / 0.1))
	tween.tween_property(self, "modulate:a", 0.2, 0.05)
	tween.tween_property(self, "modulate:a", 1.0, 0.05)
	
	await get_tree().create_timer(invulnerability_duration).timeout
	is_invulnerable = false
	modulate.a = 1.0
	
	_check_overlapping_hitboxes()

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_update_lance_state()
	move_and_slide()

func _handle_movement(delta: float) -> void:
	var turn_input = Input.get_axis("ui_left", "ui_right")
	var throttle_input = Input.get_axis("ui_down", "ui_up")
	
	heading_angle += turn_input * steer_speed * delta
	rotation = heading_angle
	
	var forward_vec = Vector2.UP.rotated(heading_angle)
	var right_vec = Vector2.RIGHT.rotated(heading_angle)
	
	if throttle_input > 0.0:
		velocity += forward_vec * engine_power * throttle_input * delta
	elif throttle_input < 0.0:
		velocity += forward_vec * (engine_power * 0.4) * throttle_input * delta
	
	var forward_velocity = forward_vec * velocity.dot(forward_vec)
	var lateral_velocity = right_vec * velocity.dot(right_vec)
	
	lateral_velocity *= pow(1.0 - drift_traction, delta)
	forward_velocity *= pow(forward_friction, delta)
	
	velocity = forward_velocity + lateral_velocity
	
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed

func _update_lance_state() -> void:
	if not lance_area:
		return
		
	var is_charging = velocity.length() >= min_charge_speed
	lance_area.monitoring = is_charging
	
	# Garante impacto mesmo se já estiver colidindo ao atingir a velocidade
	if is_charging:
		for area in lance_area.get_overlapping_areas():
			_on_lance_hit(area)

func _on_lance_hit(area: Area2D) -> void:
	if not area is HitReceiver:
		return
		
	var current_speed = velocity.length()
	if current_speed < min_charge_speed:
		return
		
	# Validação direcional
	var forward_vec = Vector2.UP.rotated(heading_angle)
	if velocity.normalized().dot(forward_vec) < 0.5:
		return
		
	var excess_speed = current_speed - min_charge_speed
	var raw_damage = base_damage + (excess_speed * damage_velocity_scale)
	
	var receiver = area as HitReceiver
	# Enviamos o dano, a direção e a velocidade atual do impacto
	var _hit_data = receiver.process_hit(raw_damage, velocity.normalized(), current_speed)
	
	# Empurra o jogador na direção oposta ao golpe
	var bounce_dir = -forward_vec
	velocity = bounce_dir * (current_speed * bounce_ratio)

func _on_hurtbox_entered(area: Area2D) -> void:
	if is_invulnerable:
		return
		
	# Verifica se é EnemyHitbox ou se tem a função de dano implementada
	if area is EnemyHitbox or area.has_method("get_damage_payload"):
		var payload: Dictionary = area.get_damage_payload(global_position)
		take_damage(payload["damage"], payload["knockback"])

func _check_overlapping_hitboxes() -> void:
	if is_invulnerable or not hurtbox_area:
		return
		
	for area in hurtbox_area.get_overlapping_areas():
		if area is EnemyHitbox or area.has_method("get_damage_payload"):
			var payload: Dictionary = area.get_damage_payload(global_position)
			take_damage(payload["damage"], payload["knockback"])
			break

func pickup_item(item: Area2D) -> void:
	var canvas = get_tree().get_first_node_in_group("canvas")
	if canvas:
		if canvas.add_item_inventory(item):
			item.queue_free()

func die() -> void:
	queue_free()
