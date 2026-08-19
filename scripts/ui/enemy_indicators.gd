class_name EnemyIndicators
extends Control

@export_group("Visual das Setas")
@export var indicator_color: Color = Color(0.95, 0.15, 0.15, 0.9)
@export var border_color: Color = Color(0.2, 0.0, 0.0, 1.0)
@export var border_margin: float = 40.0
@export var arrow_size: float = 1.0
@export var offscreen_padding: float = 20.0

# Formato poligonal da seta apontando para a direita
var arrow_polygon: PackedVector2Array = PackedVector2Array([
	Vector2(18, 0),
	Vector2(-12, -10),
	Vector2(-6, 0),
	Vector2(-12, 10),
	Vector2(18, 0)
])

func _process(_delta: float) -> void:
	# Solicita o redesenho a cada frame
	queue_redraw()

func _draw() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return

	var viewport_rect = get_viewport_rect()
	var center = viewport_rect.size / 2.0
	
	# Retângulo real da tela
	var screen_visible_rect = viewport_rect.grow(offscreen_padding)
	
	# Área visível com margem de segurança
	var half_w = (viewport_rect.size.x / 2.0) - border_margin
	var half_h = (viewport_rect.size.y / 2.0) - border_margin

	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.is_inside_tree():
			continue
		
		# Ignora inimigos que já morreram
		if "is_dead" in enemy and enemy.is_dead:
			continue

		# Converte a posição global 2D do inimigo diretamente para as coordenadas da telaa
		var screen_pos = enemy.get_global_transform_with_canvas().origin

		# Se o inimigo já está dentro da tela visível, não desenha a seta
		if screen_visible_rect.has_point(screen_pos):
			continue

		# Vetor de direção do centro da tela até a posição do inimigo
		var to_enemy = screen_pos - center
		if to_enemy.length_squared() < 0.001:
			continue

		var dir = to_enemy.normalized()

		# Calcula a interseção exata do raio com as bordas retangulares da tela
		var t_x = half_w / absf(dir.x) if absf(dir.x) > 0.0001 else 999999.0
		var t_y = half_h / absf(dir.y) if absf(dir.y) > 0.0001 else 999999.0
		var t = minf(t_x, t_y)

		# Posição final da seta na beirada da tela e o ângulo para onde ela aponta
		var arrow_position = center + (dir * t)
		var arrow_angle = dir.angle()

		# Desenha a seta estilizada rotacionada
		draw_set_transform(arrow_position, arrow_angle, Vector2.ONE * arrow_size)
		draw_colored_polygon(arrow_polygon, indicator_color)
		draw_polyline(arrow_polygon, border_color, 2.0, true)
