extends CanvasLayer

@onready var health_bar: ProgressBar = $UI/PlayerHealthBar

func _ready() -> void:
	var player = get_tree().get_first_node_in_group("player") as Player
	if player:
		health_bar.max_value = player.max_health
		health_bar.value = player.max_health
		player.health_changed.connect(_on_player_health_changed)

func _on_player_health_changed(current: float, max_h: float) -> void:
	health_bar.max_value = max_h
	health_bar.value = current
