extends CanvasLayer

@onready var damage_mask: Panel = $UI/HealthBarContainer/DamageMask

var mask_start_x: float = 0.0
var max_mask_width: float = 0.0

func _ready() -> void:
	# Guarda a posição X inicial (ex: 32.0) e a largura total (ex: 284.0)
	mask_start_x = damage_mask.position.x
	max_mask_width = damage_mask.size.x
	
	var player = get_tree().get_first_node_in_group("player") as Player
	if player:
		_on_player_health_changed(player.current_health, player.max_health + player.extra_health)
		player.health_changed.connect(_on_player_health_changed)

func _on_player_health_changed(current: float, max_h: float) -> void:
	var health_percent: float = clampf(current / maxf(1.0, max_h), 0.0, 1.0)
	var missing_percent: float = 1.0 - health_percent
	
	# Largura atual que deve ser coberta
	var current_mask_width: float = max_mask_width * missing_percent
	
	# Ajusta o tamanho e posiciona colado na extremidade direita da barra
	damage_mask.size.x = current_mask_width
	damage_mask.position.x = mask_start_x + (max_mask_width - current_mask_width)
