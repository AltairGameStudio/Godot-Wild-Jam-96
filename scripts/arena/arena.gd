extends Node2D

@export_group("Configurações da Rodada")
@export var round_duration: float = 5.0           # Duração total da rodada em segundos
@export var min_spawn_interval: float = 4.0        # Tempo mínimo entre spawns
@export var max_spawn_interval: float = 5.0        # Tempo máximo entre spawns
@export var min_distance_from_player: float = 380.0 # Distância mínima para não spawnar colado no player

@export_group("Limites da Arena para Spawn")
@export var arena_min_bounds: Vector2 = Vector2(-600, -300)
@export var arena_max_bounds: Vector2 = Vector2(2300, 1350)

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

@onready var announcement_container: VBoxContainer = get_node_or_null("CanvasLayer/AnnouncementContainer")
@onready var title_label: Label = get_node_or_null("CanvasLayer/AnnouncementContainer/TitleLabel")
@onready var subtitle_label: Label = get_node_or_null("CanvasLayer/AnnouncementContainer/SubtitleLabel")

# Nomes temáticos para cada uma das 9 fases
const PHASE_TITLES = {
	1: "The Awakening of the Spear",
	2: "Rain of Arrows",
	3: "Iron Wall",
	4: "Sticky Ground",
	5: "Armored Colossus",
	6: "Dance of Shadows",
	7: "Crossfire",
	8: "Relentless Chaos",
	9: "The Penultimate Confrontation"
}

func _ready() -> void:
	AudioManager.play_arena_theme()
	player_ref = get_tree().get_first_node_in_group("player") as Node2D
	start_phase()

func start_phase() -> void:
	var current_phase: int = 1
	if "current_phase" in get_tree().current_scene:
		current_phase = maxi(1, get_tree().current_scene.current_phase)

	_setup_phase_pool(current_phase)
	
	var sub_title = PHASE_TITLES.get(current_phase, "Survive!")
	_show_announcement("LEVEL %d" % current_phase, sub_title, 2.5)

	round_time_left = round_duration
	next_spawn_timer = randf_range(min_spawn_interval, max_spawn_interval)
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
		next_spawn_timer = randf_range(min_spawn_interval, max_spawn_interval)

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
	var final_pos = Vector2.ZERO

	# Tenta até 12 vezes sortear um ponto afastado do jogador
	while attempts < 12:
		final_pos = Vector2(
			randf_range(arena_min_bounds.x, arena_max_bounds.x),
			randf_range(arena_min_bounds.y, arena_max_bounds.y)
		)
		
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
		
	_show_announcement("TIME'S UP!", "Travelling to the town...", 3.5, Color(0.3, 1.0, 0.4))

	# Remove todos os inimigos vivos restantes na arena
	get_tree().call_group("enemies", "queue_free")

	# Chama a finalização da run com sucesso para voltar à cidade
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
		_: # Fase 9 em diante
			enemy_scenes = [SCENE_SWORD, SCENE_RANGED, SCENE_SHIELD, SCENE_TAR, SCENE_HEAVY, SCENE_DODGING]
			enemy_weights = [5.0, 10.0, 15.0, 20.0, 25.0, 25.0]

func _show_announcement(title: String, subtitle: String, duration: float = 3.0, title_color: Color = Color(1.0, 0.85, 0.2)) -> void:
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
