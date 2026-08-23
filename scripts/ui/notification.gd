extends VBoxContainer # Ou Control

@export var display_duration: float = 2.5
@export var fade_duration: float = 0.5

func activate_notification(message: String) -> void:
	visible = true
	
	# 1. Cria um novo Label para esta mensagem específica
	var item_label = Label.new()
	item_label.text = message
	item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	
	# 2. Configurações de estilo (contorno preto para leitura fácil)
	item_label.add_theme_constant_override("outline_size", 6)
	item_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	item_label.add_theme_font_size_override("font_size", 20)
	
	# 3. Adiciona na lista/pilha
	add_child(item_label)
	
	# 4. Animação: Fade in -> Espera -> Fade out -> Remove
	item_label.modulate.a = 0.0
	var tween = create_tween()
	
	# Aparece rapidamente
	tween.tween_property(item_label, "modulate:a", 1.0, 0.2)
	
	# Fica visível pelo tempo configurado
	tween.tween_interval(display_duration)
	
	# Desaparece suavemente
	tween.tween_property(item_label, "modulate:a", 0.0, fade_duration)
	
	# Libera a memória do label após terminar
	tween.tween_callback(item_label.queue_free)
