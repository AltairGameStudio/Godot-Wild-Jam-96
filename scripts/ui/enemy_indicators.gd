class_name OffscreenIndicator
extends Control

@export_group("Visual das Setas")
@export var indicator_color: Color = Color(0.95, 0.15, 0.15, 0.9)
@export var border_color: Color = Color(0.2, 0.0, 0.0, 1.0)
@export var border_margin: float = 40.0
@export var arrow_size: float = 1.0
@export var offscreen_padding: float = 20.0

@export_group("Alvo")
@export var target_group: String = "enemies" # Grupo padrão
var custom_targets: Array = []       # Alvos manuais (ex: o NPC)

# Formato poligonal da seta apontando para a direita
var arrow_polygon: PackedVector2Array = PackedVector2Array([
	Vector2(18, 0),
	Vector2(-12, -10),
	Vector2(-6, 0),
	Vector2(-12, 10),
	Vector2(18, 0)
])

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	# Pega os alvos: se tiver custom_targets usa eles, senão busca pelo grupo
	var targets: Array = []
	if not custom_targets.is_empty():
		targets = custom_targets
	elif not target_group.is_empty():
		targets = get_tree().get_nodes_in_group(target_group)

	if targets.is_empty():
		return

	var viewport_rect = get_viewport_rect()
	var center = viewport_rect.size / 2.0
	var screen_visible_rect = viewport_rect.grow(offscreen_padding)
	var half_w = (viewport_rect.size.x / 2.0) - border_margin
	var half_h = (viewport_rect.size.y / 2.0) - border_margin

	for target in targets:
		if not is_instance_valid(target) or not target.is_inside_tree():
			continue
		
		# Se tiver propriedade de morte (inimigos)
		if "is_dead" in target and target.is_dead:
			continue

		var screen_pos = target.get_global_transform_with_canvas().origin

		# Se já estiver na tela, não desenha seta
		if screen_visible_rect.has_point(screen_pos):
			continue

		var to_target = screen_pos - center
		if to_target.length_squared() < 0.001:
			continue

		var dir = to_target.normalized()
		var t_x = half_w / absf(dir.x) if absf(dir.x) > 0.0001 else 999999.0
		var t_y = half_h / absf(dir.y) if absf(dir.y) > 0.0001 else 999999.0
		var t = minf(t_x, t_y)

		var arrow_position = center + (dir * t)
		var arrow_angle = dir.angle()

		# Desenha a seta
		draw_set_transform(arrow_position, arrow_angle, Vector2.ONE * arrow_size)
		draw_colored_polygon(arrow_polygon, indicator_color)
		draw_polyline(arrow_polygon, border_color, 2.0, true)
