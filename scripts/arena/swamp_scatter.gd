@tool
class_name SwampScatter
extends Node2D

@export_group("Texturas")
@export var tex_tree: Texture2D = preload("res://assets/sprites/swamp-tree.png")
@export var tex_tree_down: Texture2D = preload("res://assets/sprites/swamp-tree-down.png")
@export var tex_stump: Texture2D = preload("res://assets/sprites/swamp-stump.png")
@export var tex_bush: Texture2D = preload("res://assets/sprites/swamp-bush.png")
@export var tex_flower: Texture2D = preload("res://assets/sprites/swamp-flower.png")

@export_group("Área e Densidade")
@export var safe_zone_radius: float = 400.0  # Raio do centro 100% livre para o jogador
@export var max_arena_radius: float = 1400.0 # Limite interno da arena
@export_range(0.2, 2.0, 0.05) var outer_density_bias: float = 0.65 # < 1.0 empurra mais props para a borda externa

@export_group("Quantidades Desejadas")
@export var tree_count: int = 12
@export var tree_down_count: int = 12
@export var stump_count: int = 9
@export var bush_count: int = 28
@export var flower_count: int = 45

@export_group("Geração")
@export var seed_number: int = 0
@export var generate_now: bool = false:
	set(val):
		_generate_swamp()

# Registro em memória para verificação de distância entre objetos
var _spawned_points: Array[Dictionary] = []

func _ready() -> void:
	if not Engine.is_editor_hint() and get_child_count() == 0:
		_generate_swamp()

func _generate_swamp() -> void:
	# 1. Limpa nós antigos
	for child in get_children():
		child.queue_free()
	_spawned_points.clear()

	if seed_number != 0:
		seed(seed_number)
	else:
		randomize()

	# 2. Ordem de Prioridade de Spawn (Maiores primeiro para garantir espaço físico)
	
	# Árvores Grandes: Tronco robusto, colisão circular na base
	_spawn_prop_category(tex_tree, tree_count, "circle", 100.0, 20.0, Vector2(0, -6))
	
	# Troncos Caídos: Barreira horizontal
	_spawn_prop_category(tex_tree_down, tree_down_count, "box", 120.0, 20.0, Vector2(0, -8), Vector2(70, 18))
	
	# Tocos: Obstáculo baixo
	_spawn_prop_category(tex_stump, stump_count, "circle", 100.0, 20.0, Vector2(0, -5))
	
	# Arbustos: Obstáculo pequeno
	_spawn_prop_category(tex_bush, bush_count, "none", 100.0, 20.0, Vector2(0, -4))
	
	# Flores: Sem colisão física (Clearance baixo apenas para não nascer dentro do mesmo ponto)
	_spawn_prop_category(tex_flower, flower_count, "none", 22.0, 0.0, Vector2.ZERO)

func _spawn_prop_category(
	texture: Texture2D,
	count: int,
	col_type: String,
	clearance_radius: float,
	col_radius: float,
	col_offset: Vector2,
	box_size: Vector2 = Vector2.ZERO
) -> void:
	if texture == null:
		return

	var attempts_max = 60
	var spawned_in_category = 0

	for i in range(count):
		var found_spot = false
		var candidate_pos = Vector2.ZERO

		for attempt in range(attempts_max):
			candidate_pos = _get_biased_position()
			if _is_position_valid(candidate_pos, clearance_radius):
				found_spot = true
				break

		if not found_spot:
			continue # Se o mapa saturou de props nesta área, segue sem empilhar

		# Registra a posição ocupada e o raio de exclusão
		_spawned_points.append({
			"position": candidate_pos,
			"radius": clearance_radius
		})

		_instantiate_element(texture, candidate_pos, col_type, col_radius, col_offset, box_size)
		spawned_in_category += 1

func _instantiate_element(
	texture: Texture2D,
	pos: Vector2,
	col_type: String,
	col_radius: float,
	col_offset: Vector2,
	box_size: Vector2
) -> void:
	var spr_h = texture.get_height()
	var spr_w = texture.get_width()

	if col_type == "none":
		var spr = Sprite2D.new()
		spr.texture = texture
		spr.position = pos
		# Origem na base do pé da flor
		spr.offset = Vector2(0, -spr_h * 0.4)
		spr.modulate.a = 0.5
		add_child(spr)
	else:
		var body = StaticBody2D.new()
		body.position = pos
		body.collision_layer = 1 # Layer 1: World
		body.collision_mask = 0
		body.y_sort_enabled = true

		# Sprite configurado para ter o pivô no ponto de contato do chão
		var spr = Sprite2D.new()
		spr.texture = texture
		spr.offset = Vector2(0, -spr_h * 0.42)
		body.add_child(spr)

		# Colisão colocada exatamente sobre a base física
		var col = CollisionShape2D.new()
		col.position = col_offset

		if col_type == "circle":
			var circle = CircleShape2D.new()
			circle.radius = col_radius
			col.shape = circle
		elif col_type == "box":
			var box = RectangleShape2D.new()
			box.size = box_size if box_size != Vector2.ZERO else Vector2(spr_w * 0.75, 16.0)
			col.shape = box

		body.add_child(col)
		add_child(body)

func _get_biased_position() -> Vector2:
	var angle = randf() * TAU
	# Interpolação ponderada por potência: concentra candidatos mais perto de max_arena_radius
	var u = pow(randf(), outer_density_bias)
	var r = lerpf(safe_zone_radius, max_arena_radius, u)
	return Vector2(cos(angle), sin(angle)) * r

func _is_position_valid(candidate: Vector2, candidate_radius: float) -> bool:
	for occupied in _spawned_points:
		var min_allowed_dist = candidate_radius + occupied["radius"]
		if candidate.distance_to(occupied["position"]) < min_allowed_dist:
			return false
	return true
