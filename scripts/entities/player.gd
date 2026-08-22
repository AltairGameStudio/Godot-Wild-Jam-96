class_name Player
extends CharacterBody2D

signal health_changed(current: float, max_h: float)

# --- CONFIGURAÇÃO DE ANIMAÇÃO DO CAVALO ---
@export_group("Sprites / Animação")
@export var sprite_frame_0: Texture2D = preload("res://assets/sprites/entities/player_000.png")
@export var sprite_frame_1: Texture2D = preload("res://assets/sprites/entities/player_001.png")
@export var step_distance_threshold: float = 30.0 # Quantos pixels percorridos para trocar o frame

@onready var player_sprite: Sprite2D = $Sprite2D

var current_anim_frame: int = 0
var distance_traveled: float = 0.0
# ------------------------------------------

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
@export var base_damage: float = 1000.0
@export var damage_velocity_scale: float = 0.1
@export var bounce_ratio: float = 0.35

@export_group("Defesa e Invulnerabilidade")
@export var invulnerability_duration: float = 0.6
var is_invulnerable: bool = false

@export_group("Equipáveis")
@export var extra_damage = 0
@export var extra_health = 0
@export var defense = 0
@export var extra_speed = 0
@export var extra_steer_speed = 0
@export var extra_speed_multiplier = 0

@onready var lance_pivot: Node2D = $LancePivot
@onready var lance_area: Area2D = $LancePivot/LanceArea
@onready var hurtbox_area: Area2D = $HurtboxArea

var heading_angle: float = 0.0
var speed_multiplier: float = 1.0
var active_slow_sources: int = 0

func _ready() -> void:
	add_to_group("player")
	current_health = max_health + extra_health
	heading_angle = rotation
	
	if player_sprite and sprite_frame_0:
		player_sprite.texture = sprite_frame_0
	
	if lance_area:
		lance_area.area_entered.connect(_on_lance_hit)
	
	if hurtbox_area:
		hurtbox_area.area_entered.connect(_on_hurtbox_area_entered)
	update_info()

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_update_lance_state()
	_update_horse_animation(delta)
	move_and_slide()

func _update_horse_animation(delta: float) -> void:
	if not player_sprite:
		return
		
	var current_speed = velocity.length()
	
	# Se estiver praticamente parado, volta para o frame base
	if current_speed < 15.0:
		if current_anim_frame != 0:
			current_anim_frame = 0
			player_sprite.texture = sprite_frame_0
			distance_traveled = 0.0
		return
	
	# Acumula a distância percorrida no frame atual
	distance_traveled += current_speed * delta
	
	# Troca de sprite sempre que ultrapassa o limiar de passos
	if distance_traveled >= step_distance_threshold:
		distance_traveled = 0.0
		current_anim_frame = 1 if current_anim_frame == 0 else 0
		player_sprite.texture = sprite_frame_1 if current_anim_frame == 1 else sprite_frame_0

func update_info() -> void:
	if has_node("inventoryHUD/inventory/info"):
		$inventoryHUD/inventory/info.update_labels(
			[max_health + extra_health,
			 current_health,
			 base_damage + extra_damage,
			 defense,
			 max_speed + extra_speed,
			 speed_multiplier + extra_speed_multiplier,
			 steer_speed + extra_steer_speed])

func equipment_changed(item_id, item_equipped: bool):
	var lvl : float = item_id%100
	var controler = -1
	if item_equipped: 
		controler = 1
	if (item_id/100) == 2:
		extra_damage += controler * lvl*2
	elif (item_id/100) == 3:
		defense += controler * lvl*3
	elif (item_id/100) == 4:
		if item_equipped and (current_health == max_health + extra_health):
			current_health = max_health + lvl*10
		elif not item_equipped:
			if (current_health == max_health + extra_health):
				current_health = max_health
			elif (current_health != max_health + extra_health) and current_health >= max_health:
				var percent = current_health/max_health+extra_health
				current_health = max_health*percent
		extra_health += controler * lvl*10
	elif (item_id/100) == 5:
		extra_steer_speed += controler * lvl/5.0
	elif (item_id/100) == 6:
		extra_speed_multiplier += controler * lvl/10.0
	elif (item_id/100) == 7:
		extra_speed += controler * lvl*20
	
	update_info()

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if is_invulnerable:
		return
	
	if area is EnemyHitbox or area.has_method("get_damage_payload"):
		var payload: Dictionary = area.get_damage_payload(global_position)
		take_damage(payload["damage"], payload["knockback"])

func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO, ignore_charge: bool = false) -> void:
	if is_invulnerable:
		return
		
	if not ignore_charge:
		var forward_vec = Vector2.UP.rotated(heading_angle)
		var is_charging = velocity.length() >= min_charge_speed and velocity.normalized().dot(forward_vec) > 0.5
		if is_charging:
			return
		
	current_health = maxf(0.0, current_health - (amount * (1.0 - float(defense)/100.0)))
	velocity += knockback
	health_changed.emit(current_health, max_health+extra_health)
	
	_trigger_invulnerability()
	update_info()
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

func _handle_movement(delta: float) -> void:
	var turn_input = Input.get_axis("ui_left", "ui_right")
	var throttle_input = Input.get_axis("ui_down", "ui_up")
	
	heading_angle += turn_input * (steer_speed + extra_steer_speed) * delta
	rotation = heading_angle
	
	var forward_vec = Vector2.UP.rotated(heading_angle)
	var right_vec = Vector2.RIGHT.rotated(heading_angle)
	
	var effective_max_speed = (max_speed + extra_speed) * (speed_multiplier + extra_speed_multiplier)
	
	if throttle_input > 0.0:
		velocity += forward_vec * engine_power * throttle_input * delta
	elif throttle_input < 0.0:
		velocity += forward_vec * (engine_power * 0.4) * throttle_input * delta
	
	var forward_velocity = forward_vec * velocity.dot(forward_vec)
	var lateral_velocity = right_vec * velocity.dot(right_vec)
	
	lateral_velocity *= pow(1.0 - drift_traction, delta)
	forward_velocity *= pow(forward_friction, delta)
	
	velocity = forward_velocity + lateral_velocity
	
	if velocity.length() > effective_max_speed:
		velocity = velocity.normalized() * effective_max_speed

func _update_lance_state() -> void:
	if not lance_area:
		return
		
	var is_charging = velocity.length() >= min_charge_speed
	lance_area.monitoring = is_charging
	
	if is_charging:
		for area in lance_area.get_overlapping_areas():
			_on_lance_hit(area)

func _on_lance_hit(area: Area2D) -> void:
	if not area is HitReceiver:
		return
		
	var current_speed = velocity.length()
	if current_speed < min_charge_speed:
		return
		
	var forward_vec = Vector2.UP.rotated(heading_angle)
	if velocity.normalized().dot(forward_vec) < 0.5:
		return
		
	var excess_speed = current_speed - min_charge_speed
	var raw_damage = base_damage + (excess_speed * damage_velocity_scale)
	
	var receiver = area as HitReceiver
	var _hit_data = receiver.process_hit(raw_damage + extra_damage, velocity.normalized(), current_speed)
	
	var bounce_dir = -forward_vec
	velocity = bounce_dir * (current_speed * bounce_ratio)

func _on_hurtbox_entered(area: Area2D) -> void:
	if is_invulnerable:
		return
		
	if area is EnemyHitbox or area.has_method("get_damage_payload"):
		var payload: Dictionary = area.get_damage_payload(global_position)
		take_damage(payload["damage"] * ((100.0 - float(defense)) / 100.0), payload["knockback"])

func _check_overlapping_hitboxes() -> void:
	if is_invulnerable or not hurtbox_area:
		return
		
	for area in hurtbox_area.get_overlapping_areas():
		if area is EnemyHitbox or area.has_method("get_damage_payload"):
			var payload: Dictionary = area.get_damage_payload(global_position)
			take_damage(payload["damage"], payload["knockback"])
			break

func pickup_item(item: Area2D) -> void:
	var item_id = item.item_id
	if int(item_id / 100) == 1:
		if get_tree().current_scene.has_method("add_gold"):
			get_tree().current_scene.add_gold(5 * (item_id % 100))
		item.queue_free()
		return
	var canvas = get_tree().get_first_node_in_group("inventCanvas")
	if canvas:
		if canvas.add_item_inventory(item):
			item.queue_free()
			
func apply_slow(factor: float = 0.5) -> void:
	active_slow_sources += 1
	speed_multiplier = factor

func remove_slow() -> void:
	active_slow_sources = maxi(0, active_slow_sources - 1)
	if active_slow_sources == 0:
		speed_multiplier = 1.0

func die() -> void:
	queue_free()

func _gold_changed(_new_amount: int) -> void:
	update_info()
