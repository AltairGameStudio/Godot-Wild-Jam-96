@tool
class_name ForestRing
extends StaticBody2D

@export_group("Configurações do Anel")
@export var tree_texture: Texture2D:
	set(val):
		tree_texture = val
		_rebuild_arena()

@export var radius: float = 700.0:              # Raio da arena onde o player anda
	set(val):
		radius = val
		_rebuild_arena()

@export var tree_count: int = 36:                # Quantidade de árvores no círculo
	set(val):
		tree_count = val
		_rebuild_arena()

@export var ring_layers: int = 2:                # Quantas camadas de árvores (para parecer floresta densa)
	set(val):
		ring_layers = val
		_rebuild_arena()

@export var rebuild_button: bool = false:
	set(val):
		_rebuild_arena()

@onready var collision_poly: CollisionPolygon2D = $CollisionPolygon2D
@onready var trees_container: Node2D = $Trees

func _ready() -> void:
	_rebuild_arena()

func _rebuild_arena() -> void:
	# Garante que os nós filhos existam mesmo no editor
	if not has_node("Trees"):
		var t_node = Node2D.new()
		t_node.name = "Trees"
		t_node.y_sort_enabled = true
		add_child(t_node)
	if not has_node("CollisionPolygon2D"):
		var c_node = CollisionPolygon2D.new()
		c_node.name = "CollisionPolygon2D"
		add_child(c_node)

	var trees_node = $Trees
	var col_poly = $CollisionPolygon2D

	# 1. Limpa árvores antigas
	for child in trees_node.get_children():
		child.queue_free()

	if tree_texture == null:
		return

	# 2. Spawna as árvores em círculo
	for layer in range(ring_layers):
		var layer_radius = radius + (layer * 70.0) # Camadas exteriores
		var layer_count = int(tree_count * (1.0 + layer * 0.25))
		
		for i in range(layer_count):
			var angle = (float(i) / float(layer_count)) * TAU
			var pos = Vector2(cos(angle), sin(angle)) * layer_radius
			
			var spr = Sprite2D.new()
			spr.texture = tree_texture
			spr.position = pos
			spr.offset = Vector2(0, -tree_texture.get_height() * 0.35) # Pivô na raiz
			trees_node.add_child(spr)

	# 3. Cria a colisão oca (Player preso por dentro)
	var points: PackedVector2Array = []
	var segments = 48
	var outer_limit = radius + 400.0 # Margem externa grossa da parede

	# Contorno externo (sentido horário)
	for i in range(segments):
		var angle = (float(i) / float(segments)) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * outer_limit)

	# Contorno interno invertido (sentido anti-horário cria o "buraco" no meio)
	for i in range(segments, -1, -1):
		var angle = (float(i) / float(segments)) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * radius)

	col_poly.polygon = points
