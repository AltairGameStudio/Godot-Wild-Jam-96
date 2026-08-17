extends Node2D

@export var enemy_scene: PackedScene
@onready var spawn_points: Node2D = $SpawnPoints

var enemies_alive: int = 0

func _ready() -> void:
	start_phase()

func start_phase() -> void:
	# Pega a fase atual do GameManager para definir a dificuldade
	var phase = GameManager.current_phase
	
	var enemies_to_spawn = 1 + (phase * 2) 
	
	spawn_enemies(enemies_to_spawn)

func spawn_enemies(amount: int) -> void:
	var available_spawns = spawn_points.get_children()
	
	for i in range(amount):
		if available_spawns.is_empty():
			break
			
		# Instancia o inimigo
		var enemy = enemy_scene.instantiate() as Enemy
		
		# Escolhe um ponto de spawn aleatório
		var spawn_point = available_spawns.pick_random()
		enemy.global_position = spawn_point.global_position
		
		# Conecta o sinal de morte do inimigo à função de checagem
		enemy.enemy_died.connect(_on_enemy_died)
		
		# Adiciona o inimigo à cena
		add_child(enemy)
		enemies_alive += 1

func _on_enemy_died() -> void:
	enemies_alive -= 1
	
	if enemies_alive <= 0:
		GameManager.end_run_success()
