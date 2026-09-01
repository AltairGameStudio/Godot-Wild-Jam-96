class_name Player
extends CharacterBody2D

signal health_changed(current: float, max_h: float)
signal power_charge_changed(current_load: float, on_load: bool)

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

@export_group("Equipáveis")
@export var extra_damage = 0
@export var extra_health = 0
@export var defense = 0
@export var extra_speed = 0
@export var extra_steer_speed = 0
@export var extra_speed_multiplier = 0

@export_group("Habilidade Dash / Carga")
@export var charge_time_to_fill: float = 3.0   # Tempo em segundos para encher a barra de 0% a 100%
@export var dash_duration: float = 1.5         # Tempo em segundos que o Dash dura até a barra esvaziar
@export var power_charge_load: float = 0.0
@export var on_power_charge: bool = false

@onready var lance_pivot: Node2D = $LancePivot
@onready var lance_area: Area2D = $LancePivot/LanceArea
@onready var hurtbox_area: Area2D = $HurtboxArea

var heading_angle: float = 0.0

# Controle de efeitos de lentidão
var speed_multiplier: float = 1.0
var active_slow_sources: int = 0

var can_move: bool = true

# Efeito visual de velocidade
var ghost_intervals: float = 0.3
var last_ghost : float = 0.0

func _ready() -> void:
	add_to_group("player")
	current_health = max_health + extra_health
	heading_angle = rotation
	
	if lance_area:
		lance_area.area_entered.connect(_on_lance_hit)
	
	if hurtbox_area:
		hurtbox_area.area_entered.connect(_on_hurtbox_area_entered)
	update_info()

func create_ghost() -> void:
	var ghost = Sprite2D.new()
	ghost.texture = $Sprite2D.texture
	get_tree().current_scene.add_child(ghost)
	var tween = create_tween()
	tween.tween_property(ghost, "self_modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(ghost.queue_free)
	ghost.global_transform = $Sprite2D.global_transform

func update_info() -> void:
	$PlayerCanvas/inventory/info.update_labels(
		[max_health + extra_health,
		 current_health,
		 base_damage + extra_damage,
		 defense,
		 max_speed + extra_speed,
		 speed_multiplier + extra_speed_multiplier,
		 steer_speed + extra_steer_speed,
		 drift_traction,
		 engine_power])
	$PlayerCanvas/equipment/coin/quantity.text = "%d" % get_tree().current_scene.gold

func equipment_changed(item_id, item_equipped: bool):
	var lvl : float = item_id%100
	var controler = -1
	var mod_color = Color(1,1,1,0.5)
	var equip_txt = ""
	if item_equipped: 
		controler = 1
		mod_color = Color(1,1,1,1)
		equip_txt = "Lvl %d" % lvl
	if (item_id/100) == 2:
		extra_damage += controler * lvl*2
		$PlayerCanvas/equipment/lance.modulate = mod_color
		$PlayerCanvas/equipment/lance/lvl.text = equip_txt
	elif (item_id/100) == 3:
		defense += controler * lvl*3
		$PlayerCanvas/equipment/armor.modulate = mod_color
		$PlayerCanvas/equipment/armor/lvl.text = equip_txt
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
		$PlayerCanvas/equipment/cape.modulate = mod_color
		$PlayerCanvas/equipment/cape/lvl.text = equip_txt
	elif (item_id/100) == 5:
		extra_steer_speed += controler * lvl/5.0
		$PlayerCanvas/equipment/rein.modulate = mod_color
		$PlayerCanvas/equipment/rein/lvl.text = equip_txt
	elif (item_id/100) == 6:
		extra_speed_multiplier += controler * lvl/10.0
		$PlayerCanvas/equipment/horseshoe.modulate = mod_color
		$PlayerCanvas/equipment/horseshoe/lvl.text = equip_txt
	elif (item_id/100) == 7:
		extra_speed += controler * lvl*50
		$PlayerCanvas/equipment/saddle.modulate = mod_color
		$PlayerCanvas/equipment/saddle/lvl.text = equip_txt
	
	update_info()

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if is_invulnerable:
		return
	
	# Aceita tanto EnemyHitbox quanto classes genéricas de Hitbox
	if area is EnemyHitbox or area.has_method("get_damage_payload"):
		var payload: Dictionary = area.get_damage_payload(global_position)
		take_damage(payload["damage"], payload["knockback"])

func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO, ignore_charge: bool = false) -> void:
	if is_invulnerable:
		return
		
	# Se estiver em investida rápida frontal, a lança anula o dano de frente
	if not ignore_charge:
		var forward_vec = Vector2.UP.rotated(heading_angle)
		var is_charging = velocity.length() >= min_charge_speed and velocity.normalized().dot(forward_vec) > 0.5
		if is_charging:
			return
		
	current_health = maxf(0.0, current_health - (amount * (1 - defense/100)))
	velocity += knockback
	health_changed.emit(current_health, max_health+extra_health)
	AudioManager.play_sfx(AudioManager.SFX_HURT)
	_trigger_invulnerability()
	update_info()
	if current_health <= 0.0:
		die()
		
func heal(amount: float) -> void:
	var total_max = max_health + extra_health
	current_health = minf(total_max, current_health + amount)
	health_changed.emit(current_health, total_max)
	update_info()

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
	if Input.is_key_pressed(KEY_SHIFT):
		if not on_power_charge and power_charge_load >= 1:
			on_power_charge = true
			power_charge_changed.emit(power_charge_load, power_charge_changed)
	_handle_movement(delta)
	var is_charging = lance_area.monitoring
	_update_lance_state()
	if !is_charging and lance_area.monitoring:
		var tween = create_tween()
		tween.tween_property(lance_area, "modulate", Color(1,0,0,0.6), 0.2)
	elif is_charging and !lance_area.monitoring:
		var tween = create_tween()
		tween.tween_property(lance_area, "modulate", Color(1,1,1,1), 0.2)
	move_and_slide()

func _handle_movement(delta: float) -> void:
	if not can_move:
		velocity = Vector2.ZERO
		return
	
	var turn_input = Input.get_axis("ui_left", "ui_right")
	var throttle_input = Input.get_axis("ui_down", "ui_up")
	
	heading_angle += turn_input * (steer_speed + extra_steer_speed) * delta
	rotation = heading_angle
	
	var forward_vec = Vector2.UP.rotated(heading_angle)
	var right_vec = Vector2.RIGHT.rotated(heading_angle)
	
	# Aplica o multiplicador de velocidade atual
	var effective_power = engine_power * (speed_multiplier + extra_speed_multiplier)
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
	
	 # Limita à velocidade máxima com lentidão
	if velocity.length() > effective_max_speed:
		velocity = velocity.normalized() * effective_max_speed
	
	if get_tree().current_scene.is_in_run:
		if ((velocity.length() >= effective_max_speed * 0.95) and not on_power_charge):
			# Enche proporcionalmente ao tempo definido em charge_time_to_fill
			var fill_rate = delta / maxf(0.01, charge_time_to_fill)
			power_charge_load = min(power_charge_load + fill_rate, 1.0)
			power_charge_changed.emit(power_charge_load, on_power_charge)

		elif on_power_charge:
			if last_ghost >= ghost_intervals:
				create_ghost()
				last_ghost = 0.0
			else:
				last_ghost += delta

			# Esvazia proporcionalmente ao tempo definido em dash_duration
			var drain_rate = delta / maxf(0.01, dash_duration)
			power_charge_load = max(power_charge_load - drain_rate, 0.0)
			power_charge_changed.emit(power_charge_load, on_power_charge)
			
			if power_charge_load <= 0.0:
				on_power_charge = false

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
	var _hit_data = receiver.process_hit(raw_damage + extra_damage, velocity.normalized(), current_speed)
	
	# Empurra o jogador na direção oposta ao golpe
	if not on_power_charge:
		var bounce_dir = -forward_vec
		velocity = bounce_dir * (current_speed * bounce_ratio)

func _on_hurtbox_entered(area: Area2D) -> void:
	if is_invulnerable:
		return
		
	# Verifica se é EnemyHitbox ou se tem a função de dano implementada
	if area is EnemyHitbox or area.has_method("get_damage_payload"):
		var payload: Dictionary = area.get_damage_payload(global_position)
		take_damage(payload["damage"]*((100-defense)/100), payload["knockback"])

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
	if item_id/100 == 1:
		get_tree().current_scene.add_gold(item_id%100)
		$PlayerCanvas/notification.activate_notification("Collected %d coins" % (item_id%100))
		item.queue_free()
		return
	var canvas = get_tree().get_first_node_in_group("PlayerCanvas")
	if canvas and canvas.add_item_inventory(item):
		item.queue_free()
		var items_available = {
			2: "Lance",
			3: "Armor",
			4: "Cape",
			5: "Rein",
			6: "Horseshoe",
			7: "Saddle"
		}
		$PlayerCanvas/notification.activate_notification("%s Lvl %d added to the inventory" % [items_available[item_id/100], item_id%100])

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
