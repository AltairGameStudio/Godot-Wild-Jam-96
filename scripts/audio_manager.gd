extends Node

# Trilhas Pré-carregadas
const BGM_MAIN_MENU = preload("res://assets/audio/music/bgm_main_menu.mp3")
const BGM_TOWN = preload("res://assets/audio/music/bgm_town.mp3")
const BGM_ARENA = preload("res://assets/audio/music/bgm_arena.mp3")
const BGM_BOSS = preload("res://assets/audio/music/bgm_boss.mp3")

# SFX Pré-carregados
const SFX_COIN = preload("res://assets/audio/sfx/coin.mp3")
const SFX_HURT = preload("res://assets/audio/sfx/hurt.mp3")
const SFX_SHIELD = preload("res://assets/audio/sfx/shield.mp3")
const SFX_BUY = preload("res://assets/audio/sfx/buy.mp3")
const SFX_IMPACT = preload("res://assets/audio/sfx/impact.mp3")
const SFX_HIT = preload("res://assets/audio/sfx/hit.mp3")
const SFX_SHOOT = preload("res://assets/audio/sfx/shoot.mp3")

# Dois players para crossfade transparente
var bgm_player_a: AudioStreamPlayer
var bgm_player_b: AudioStreamPlayer
var current_player: AudioStreamPlayer = null
var current_stream: AudioStream = null

var crossfade_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # Áudio continua tocando mesmo se o jogo for pausado
	
	bgm_player_a = AudioStreamPlayer.new()
	bgm_player_a.bus = "Master"
	add_child(bgm_player_a)

	bgm_player_b = AudioStreamPlayer.new()
	bgm_player_b.bus = "Master"
	add_child(bgm_player_b)

# --- SISTEMA DE CROSSFADE DE MÚSICA ---
# Adicione esta verificação no play_music() antes de dar .play()
func play_music(stream: AudioStream, fade_duration: float = 1.2) -> void:
	if not stream:
		return
	if current_stream == stream:
		return
		
	# Força o loop nativo do arquivo de áudio
	_enable_loop(stream)
	
	current_stream = stream
	
	var active_player: AudioStreamPlayer = bgm_player_b if current_player == bgm_player_a else bgm_player_a
	var outgoing_player: AudioStreamPlayer = current_player

	active_player.stream = stream
	active_player.volume_db = -80.0
	active_player.play()
	
	if crossfade_tween and crossfade_tween.is_valid():
		crossfade_tween.kill()
		
	crossfade_tween = create_tween().set_parallel(true)
	crossfade_tween.tween_property(active_player, "volume_db", 0.0, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	if outgoing_player and outgoing_player.playing:
		crossfade_tween.tween_property(outgoing_player, "volume_db", -80.0, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		crossfade_tween.chain().tween_callback(outgoing_player.stop)
	
	current_player = active_player

func _enable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

# Atalhos rápidos
func play_menu_theme() -> void:
	play_music(BGM_MAIN_MENU, 1.0)

func play_town_theme() -> void:
	play_music(BGM_TOWN, 1.2)

func play_arena_theme() -> void:
	play_music(BGM_ARENA, 0.8)

func play_boss_theme() -> void:
	play_music(BGM_BOSS, 0.8)
	
# --- SISTEMA DE SFX COM RANDOMIZAÇÃO DE PITCH (ANTI-FADIGA AUDITIVA) ---

func play_sfx(stream: AudioStream, base_volume_db: float = 0.0, pitch_range: float = 0.08) -> void:
	if not stream:
		return
		
	var sfx_node = AudioStreamPlayer.new()
	sfx_node.stream = stream
	sfx_node.bus = "Master"
	sfx_node.volume_db = base_volume_db
	
	# Variação sutil de tom para evitar repetição artificial
	if pitch_range > 0.0:
		sfx_node.pitch_scale = randf_range(1.0 - pitch_range, 1.0 + pitch_range)
		
	add_child(sfx_node)
	sfx_node.play()
	sfx_node.finished.connect(sfx_node.queue_free)
