extends Node2D

@export_group("Configurações da Rodada")
@export var round_duration: float = 5.0           # Duração total da rodada em segundos
@export var min_spawn_interval: float = 4.0        # Tempo mínimo entre spawns
@export var max_spawn_interval: float = 5.0        # Tempo máximo entre spawns
@export var min_distance_from_player: float = 380.0 # Distância mínima para não spawnar colado no player

@export_group("Limites da Arena para Spawn")
@export var arena_center: Vector2 = Vector2(895, 511)
@export var arena_spawn_radius: float = 1250.0

@export_group("Pool de Inimigos Padrão")
@export var enemy_scenes: Array[PackedScene] = []
# Pesos relativos (ex: [40, 30, 20, 10] -> o primeiro tem 40% de chance, etc.)
@export var enemy_weights: Array[float] = []

# Precarregamento das cenas dos 6 inimigos
const SCENE_SWORD = preload("res://scenes/entities/sword_enemy.tscn")
const SCENE_RANGED = preload("res://scenes/entities/ranged_enemy.tscn")
const SCENE_SHIELD = preload("res://scenes/entities/shield_enemy.tscn")
const SCENE_TAR = preload("res://scenes/entities/tar_enemy.tscn")
const SCENE_HEAVY = preload("res://scenes/entities/heavy_enemy.tscn")
const SCENE_DODGING = preload("res://scenes/entities/dodging_ranged_enemy.tscn")

@onready var timer_label: Label = get_node_or_null("CanvasLayer/UI/RoundTimerLabel")

var round_time_left: float = 0.0
var next_spawn_timer: float = 0.0
var is_round_active: bool = false
var player_ref: Node2D = null

var current_min_spawn: float = 4.0
var current_max_spawn: float = 5.0

@onready var announcement_container: VBoxContainer = get_node_or_null("CanvasLayer/AnnouncementContainer")
@onready var title_label: Label = get_node_or_null("CanvasLayer/AnnouncementContainer/TitleLabel")
@onready var subtitle_label: Label = get_node_or_null("CanvasLayer/AnnouncementContainer/SubtitleLabel")

@onready var charge_container: Control = get_node_or_null("CanvasLayer/UI/ChargeContainer")
@onready var charge_light: Node2D = get_node_or_null("CanvasLayer/UI/ChargeContainer/light")
@onready var charge_lance_progress: TextureProgressBar = get_node_or_null("CanvasLayer/UI/ChargeContainer/LanceProgress")
@onready var charge_label: Label = get_node_or_null("CanvasLayer/UI/ChargeContainer/Label")

# Nomes temáticos para cada uma das 9 fases
const PHASE_TITLES = {
	1: "The Awakening",
	2: "Scent of Gunpowder",
	3: "Reinforced Front",
	4: "Tainted Ground",
	5: "Heavy Footsteps",
	6: "Elusive Foes",
	7: "Rising Tension",
	8: "Relentless Pressure",
	9: "The Penultimate Confrontation",
	10: "The Final Reckoning"
}

var victory_panel: Panel = null
var victory_overlay: ColorRect = null

func _ready() -> void:
	if has_node("ForestRing"):
		arena_center = $ForestRing.global_position
		arena_spawn_radius = $ForestRing.radius - 200.0
	
	var current_phase: int = 1
	if "current_phase" in get_tree().current_scene:
		current_phase = maxi(1, get_tree().current_scene.current_phase)
	elif get_node_or_null("/root/GameManager"):
		current_phase = get_node("/root/GameManager").current_phase

	if current_phase >= 9:
		AudioManager.play_boss_theme()
	else:
		AudioManager.play_arena_theme()

	# 3. Inicialização dos Nós
	player_ref = get_tree().get_first_node_in_group("player") as Node2D
	
	# Conecta o sinal de carga do Player
	if player_ref and player_ref.has_signal("power_charge_changed"):
		if not player_ref.power_charge_changed.is_connected(_on_power_charge_changed):
			player_ref.power_charge_changed.connect(_on_power_charge_changed)
	
	_create_victory_panel()
	start_phase()

func start_phase() -> void:
	var current_phase: int = 1
	if "current_phase" in get_tree().current_scene:
		current_phase = maxi(1, get_tree().current_scene.current_phase)

	_setup_phase_pool(current_phase)
	
	var sub_title = PHASE_TITLES.get(current_phase, "Survive!")
	_show_announcement("LEVEL %d" % current_phase, sub_title, 2.5)

	round_time_left = round_duration
	
	# --- CONTROLE DE SPAWN: IGUAL ATÉ A FASE 10, DIMINUI NA 11 E ALÉM ---
	if current_phase >= 11:
		# Na fase 11 reduz ~15%. A cada fase além da 11, reduz mais 8% adicionais.
		# Com um limite mínimo de 1.0s para não saturar a tela/FPS.
		var endless_step = current_phase - 10 # Na fase 11 será 1, na fase 12 será 2, etc.
		var reduction_factor = 0.15 + (endless_step - 1) * 0.08
		var mult = maxf(0.25, 1.0 - reduction_factor)
		
		current_min_spawn = maxf(1.0, min_spawn_interval * mult)
		current_max_spawn = maxf(1.4, max_spawn_interval * mult)
	else:
		# Fases 1 a 10 mantêm os tempos 100% originais
		current_min_spawn = min_spawn_interval
		current_max_spawn = max_spawn_interval

	next_spawn_timer = randf_range(current_min_spawn, current_max_spawn)
	is_round_active = true
	_update_timer_label()

func _process(delta: float) -> void:
	if not is_round_active:
		return
	
	# Verifica se o player morreu
	if !player_ref:
		_end_phase_by_death()
		return
	
	# Atualiza a contagem regressiva
	round_time_left -= delta
	_update_timer_label()

	# Verifica se o tempo acabou
	if round_time_left <= 0.0:
		_end_phase_by_time()
		return

	# Controla o intervalo de spawn dos inimigos
	next_spawn_timer -= delta
	if next_spawn_timer <= 0.0:
		_spawn_random_enemy()
		next_spawn_timer = randf_range(current_min_spawn, current_max_spawn)

func _update_timer_label() -> void:
	if timer_label:
		var seconds_left = maxi(0, int(ceil(round_time_left)))
		# var minutes = seconds_left / 60
		# var remaining_seconds = seconds_left % 60
		timer_label.text = "%02d" % [seconds_left]

# --- SISTEMA DE SPAWN ALEATÓRIO E PONDERADO ---

func _spawn_random_enemy() -> void:
	var chosen_scene = _pick_enemy_from_pool()
	if chosen_scene == null:
		return

	var enemy_instance = chosen_scene.instantiate() as Node2D
	var spawn_pos = _get_safe_spawn_position()
	
	add_child(enemy_instance)
	enemy_instance.global_position = spawn_pos
	
	# Força a barra de vida a ir para a posição do inimigo imediatamente
	if enemy_instance.has_method("_update_healthbar_position"):
		enemy_instance._update_healthbar_position()

func _pick_enemy_from_pool() -> PackedScene:
	if enemy_scenes.is_empty():
		push_warning("Aviso: Nenhuma cena de inimigo configurada no enemy_scenes da Arena!")
		return null

	# Se não tiver pesos ou a contagem não bater, sorteia uniforme
	if enemy_weights.size() != enemy_scenes.size():
		return enemy_scenes.pick_random()

	var total_weight: float = 0.0
	for w in enemy_weights:
		total_weight += maxf(0.0, w)

	if total_weight <= 0.0:
		return enemy_scenes.pick_random()

	var roll = randf_range(0.0, total_weight)
	var accumulated_weight = 0.0
	for i in range(enemy_scenes.size()):
		accumulated_weight += maxf(0.0, enemy_weights[i])
		if roll <= accumulated_weight:
			return enemy_scenes[i]

	return enemy_scenes[0]

func _get_safe_spawn_position() -> Vector2:
	if not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player") as Node2D

	var attempts = 0
	var final_pos = arena_center

	# Tenta até 15 vezes sortear um ponto dentro do círculo seguro e afastado do jogador
	while attempts < 15:
		var angle = randf() * TAU
		var dist = sqrt(randf()) * arena_spawn_radius
		final_pos = arena_center + Vector2(cos(angle), sin(angle)) * dist
		
		if not is_instance_valid(player_ref):
			return final_pos
			
		if final_pos.distance_to(player_ref.global_position) >= min_distance_from_player:
			return final_pos
			
		attempts += 1

	return final_pos

# --- FINALIZAÇÃO DA FASE ---

func _end_phase_by_time() -> void:
	is_round_active = false
	if timer_label:
		timer_label.text = "00"

	# Remove todos os inimigos vivos restantes na arena
	get_tree().call_group("enemies", "queue_free")

	var current_phase: int = 1
	if "current_phase" in get_tree().current_scene:
		current_phase = maxi(1, get_tree().current_scene.current_phase)
	elif get_node_or_null("/root/GameManager"):
		current_phase = get_node("/root/GameManager").current_phase

	# Se completou a Fase 10, exibe o painel estilizado de vitória
	if current_phase == 10 and is_instance_valid(victory_overlay):
		victory_overlay.visible = true
		# Toca a música da tela inicial com transição suave
		if get_node_or_null("/root/AudioManager"):
			AudioManager.play_menu_theme()
	else:
		_show_announcement("TIME'S UP!", "Travelling to the town...", 3.5, Color("f2d9a6ff"))
		if get_tree().current_scene.has_method("end_run_success"):
			get_tree().current_scene.end_run_success()

func _end_phase_by_death() -> void:
	is_round_active = false
	if timer_label:
		timer_label.text = "00"
	
	_show_announcement("YOU DIED!", "Restarting on town...", 3.5, Color(0.3, 1.0, 0.4))

	# Remove todos os inimigos vivos restantes na arena
	get_tree().call_group("enemies", "queue_free")
	
	# Chama a finalização da run com sucesso para voltar à cidade
	if get_tree().current_scene.has_method("end_run_failure"):
		get_tree().current_scene.end_run_failure()

# --- CONFIGURAÇÃO DE POOL POR FASE (OPCIONAL) ---
func _setup_phase_pool(phase: int) -> void:
	match phase:
		0, 1:
			enemy_scenes = [SCENE_SWORD]
			enemy_weights = [100.0]
		2:
			enemy_scenes = [SCENE_SWORD, SCENE_RANGED]
			enemy_weights = [70.0, 30.0]
		3:
			enemy_scenes = [SCENE_SWORD, SCENE_RANGED, SCENE_SHIELD]
			enemy_weights = [50.0, 30.0, 20.0]
		4:
			enemy_scenes = [SCENE_SWORD, SCENE_RANGED, SCENE_SHIELD, SCENE_TAR]
			enemy_weights = [35.0, 25.0, 20.0, 20.0]
		5:
			enemy_scenes = [SCENE_SWORD, SCENE_RANGED, SCENE_SHIELD, SCENE_TAR, SCENE_HEAVY]
			enemy_weights = [25.0, 20.0, 20.0, 20.0, 15.0]
		6:
			enemy_scenes = [SCENE_SWORD, SCENE_RANGED, SCENE_SHIELD, SCENE_TAR, SCENE_HEAVY, SCENE_DODGING]
			enemy_weights = [15.0, 15.0, 20.0, 20.0, 15.0, 15.0]
		7:
			enemy_scenes = [SCENE_SWORD, SCENE_RANGED, SCENE_SHIELD, SCENE_TAR, SCENE_HEAVY, SCENE_DODGING]
			enemy_weights = [10.0, 15.0, 20.0, 15.0, 15.0, 25.0]
		8:
			enemy_scenes = [SCENE_SWORD, SCENE_RANGED, SCENE_SHIELD, SCENE_TAR, SCENE_HEAVY, SCENE_DODGING]
			enemy_weights = [10.0, 10.0, 15.0, 20.0, 20.0, 25.0]
		9:
			enemy_scenes = [SCENE_SWORD, SCENE_RANGED, SCENE_SHIELD, SCENE_TAR, SCENE_HEAVY, SCENE_DODGING]
			enemy_weights = [10.0, 10.0, 15.0, 20.0, 20.0, 25.0]
		_: # Fase 10 em diante (Modo Infinito / Dificuldade Máxima)
			enemy_scenes = [SCENE_SWORD, SCENE_RANGED, SCENE_SHIELD, SCENE_TAR, SCENE_HEAVY, SCENE_DODGING]
			enemy_weights = [5.0, 5.0, 15.0, 25.0, 25.0, 25.0]

func _show_announcement(title: String, subtitle: String, duration: float = 3.0, title_color: Color = Color("f2d9a6ff")) -> void:
	if not announcement_container or not title_label or not subtitle_label:
		return

	title_label.text = title
	title_label.modulate = title_color
	subtitle_label.text = subtitle

	# Garante que o pivô de escala fique no centro para o efeito de zoom
	announcement_container.pivot_offset = announcement_container.size / 2.0

	var tween = create_tween()
	# Aparece com zoom e fade-in
	announcement_container.modulate.a = 0.0
	announcement_container.scale = Vector2(0.7, 0.7)
	tween.parallel().tween_property(announcement_container, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(announcement_container, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.
EASE_OUT)

	# Permanece visível na tela
	tween.tween_interval(duration)

	# Fade-out suave
	tween.tween_property(announcement_container, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _on_power_charge_changed(current_load: float, is_on_dash: bool) -> void:
	var is_fully_charged = current_load >= 1.0
	var is_ready_to_use = is_fully_charged and not is_on_dash
	
	if charge_light:
		charge_light.visible = is_ready_to_use
	
	if charge_label:
		charge_label.visible = is_ready_to_use
		
	# Preenche a barra da esquerda para a direita de 0.0 a 1.0
	if charge_lance_progress:
		charge_lance_progress.value = current_load

func _create_victory_panel() -> void:
	var canvas_layer = get_node_or_null("CanvasLayer")
	if not canvas_layer:
		return

	# 1. Overlay escuro de fundo (cobre a tela toda)
	victory_overlay = ColorRect.new()
	victory_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	victory_overlay.color = Color(0, 0, 0, 0.75)
	victory_overlay.visible = false
	canvas_layer.add_child(victory_overlay)

	# 2. Painel central com a mesma paleta dos modais
	victory_panel = Panel.new()
	victory_panel.custom_minimum_size = Vector2(560, 300)
	victory_panel.set_anchors_preset(Control.PRESET_CENTER)
	victory_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	victory_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# Estilo: Fundo verde-escuro + Borda Dourada + Sombra
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.10, 0.95)       # Verde-escuro pântano
	style.border_color = Color(0.83, 0.64, 0.45, 1.0)    # Dourado envelhecido
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 6)
	victory_panel.add_theme_stylebox_override("panel", style)
	victory_overlay.add_child(victory_panel)

	# 3. Faixa de Cabeçalho Dourada Translúcida
	var header_bar = ColorRect.new()
	header_bar.color = Color(0.83, 0.64, 0.45, 0.15)
	header_bar.custom_minimum_size = Vector2(0, 42)
	header_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header_bar.offset_bottom = 42.0
	header_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	victory_panel.add_child(header_bar)

	# 4. Título Principal
	var title = Label.new()
	title.text = "VICTORY ACHIEVED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.offset_top = 8.0
	title.offset_bottom = 36.0
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.modulate = Color(0.95, 0.85, 0.65) # Dourado claro
	victory_panel.add_child(title)

	# 5. Container de Conteúdo Interno
	var content_box = VBoxContainer.new()
	content_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_box.offset_top = 60.0
	content_box.offset_bottom = -20.0
	content_box.offset_left = 30.0
	content_box.offset_right = -30.0
	content_box.add_theme_constant_override("separation", 18)
	victory_panel.add_child(content_box)

	# Texto descritivo / mensagem
	var msg_label = Label.new()
	msg_label.text = "You conquered all 10 trials of the arena!\nWill you retire victorious or dare to push beyond in Endless Mode?"
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.modulate = Color("f2d9a6ff")
	content_box.add_child(msg_label)

	# Espaçador flexível
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_box.add_child(spacer)

	# 6. Container de Botões
	var btn_box = VBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 12)
	content_box.add_child(btn_box)

	# Botão 1: Endless Mode (Continuar)
	var btn_endless = _create_styled_button("ENTER ENDLESS MODE (CONTINUE)")
	btn_endless.pressed.connect(_on_endless_button_pressed)
	btn_box.add_child(btn_endless)

	# Botão 2: Main Menu (Resetar)
	var btn_menu = _create_styled_button("MAIN MENU (RESET PROGRESS)")
	btn_menu.pressed.connect(_on_menu_button_pressed)
	btn_box.add_child(btn_menu)

# Função auxiliar para padronizar os botões com o mesmo estilo do jogo
func _create_styled_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 42)
	
	# Estilo normal do botão
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.12, 0.18, 0.15, 0.9)
	btn_normal.border_color = Color(0.83, 0.64, 0.45, 0.8)
	btn_normal.set_border_width_all(2)
	btn_normal.set_corner_radius_all(6)
	
	# Estilo ao passar o mouse (Hover)
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.20, 0.30, 0.25, 0.95)
	btn_hover.border_color = Color(0.95, 0.85, 0.65, 1.0)
	btn_hover.set_border_width_all(2)
	btn_hover.set_corner_radius_all(6)
	
	# Estilo ao clicar (Pressed)
	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.06, 0.10, 0.08, 0.95)
	btn_pressed.border_color = Color(0.83, 0.64, 0.45, 1.0)
	btn_pressed.set_border_width_all(2)
	btn_pressed.set_corner_radius_all(6)

	btn.add_theme_stylebox_override("normal", btn_normal)
	btn.add_theme_stylebox_override("hover", btn_hover)
	btn.add_theme_stylebox_override("pressed", btn_pressed)
	btn.add_theme_color_override("font_color", Color("f2d9a6ff"))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	
	return btn
	
func _on_endless_button_pressed() -> void:
	if victory_overlay:
		victory_overlay.visible = false
	_show_announcement("ENDLESS MODE!", "Travelling to town...", 2.5, Color("f2d9a6ff"))
	if get_tree().current_scene.has_method("end_run_success"):
		get_tree().current_scene.end_run_success()

func _on_menu_button_pressed() -> void:
	if get_node_or_null("/root/GameManager"):
		get_node("/root/GameManager").reset_game_to_menu()
	else:
		get_tree().change_scene_to_file("res://weball/main_menu.tscn")
