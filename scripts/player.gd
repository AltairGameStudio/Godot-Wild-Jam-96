extends CharacterBody2D

@export var acceleration := 300.0       # Quão rápido ele ganha velocidade
@export var max_speed := 1000.0         # Limite máximo de velocidade
@export var friction := 150.0           # Desaceleração quando solta o teclado
@export var steering_speed := 2.5       # Quão rápido ele consegue fazer curvas
@export var sharp_turn_penalty := 0.98  # Multiplicador que rouba inércia em curvas muito fechadass

# Variável para calcular o dano nos inimigos
var kinetic_energy: float = 0.0

func _physics_process(delta):
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	if input_dir.length() > 0:
		# Adiciona velocidade progressivamente na direção do input
		velocity += input_dir * acceleration * delta
		
		# Garante que a velocidade não ultrapasse a max_speed
		if velocity.length() > max_speed:
			velocity = velocity.normalized() * max_speed

		# Calculamos para onde ele quer ir, mantendo a velocidade atual
		var current_speed = velocity.length()
		var desired_velocity = input_dir * current_speed
		
		velocity = velocity.lerp(desired_velocity, steering_speed * delta)
		
		# Sistema de quebra de momento
		var movement_dir = velocity.normalized()
		var dot_product = movement_dir.dot(input_dir)
		
		# Se fizer curva brusca com alta velocidade, perde momento
		if dot_product < 0.5 and current_speed > 200:
			velocity *= sharp_turn_penalty
			
	else:
		# Reduz a velocidade a zero
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	# Aplica a física
	move_and_slide()

	# Guarda a energia para o combate
	kinetic_energy = velocity.length()
	
	# Rotaciona o personagem
	if velocity.length() > 50:
		rotation = velocity.angle()
