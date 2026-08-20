extends Node2D

@export_group("Inimigos")
@export var melee_enemy_scene: PackedScene
@export var ranged_enemy_scene: PackedScene

@onready var spawn_points: Node2D = $SpawnPoints

var enemies_alive: int = 0

func _ready() -> void:
	start_phase()

func start_phase() -> void:
	#var phase: int = GameManager.current_phase 
	var phase: int = get_tree().current_scene.current_phase 
	
	var total_enemies: int = 1 + (phase * 2) 
	var ranged_amount: int = int(phase / 2.0) 
	var melee_amount: int = total_enemies - ranged_amount
	
	spawn_enemies(melee_amount, ranged_amount)

func spawn_enemies(melee_amount: int, ranged_amount: int) -> void:
	# Pega todos os Marker2D dentro do nó SpawnPoints
	var available_spawns = spawn_points.get_children()
	
	# Embaralha a lista de posições para ser aleatório a cada vez
	available_spawns.shuffle() 
	
	# Cria uma lista com as cenas que devem ser instanciadas
	var scenes_to_spawn: Array[PackedScene] = []
	
	# Coloca as cenas Melee no saco
	for i in range(melee_amount):
		if melee_enemy_scene: scenes_to_spawn.append(melee_enemy_scene)
		
	# Coloca as cenas Ranged no saco
	for i in range(ranged_amount):
		if ranged_enemy_scene: scenes_to_spawn.append(ranged_enemy_scene)
		
	# Instancia cada cena do saco nos pontos disponíveis
	for scene in scenes_to_spawn:
		if available_spawns.is_empty():
			push_warning("Aviso: Não há SpawnPoints suficientes para todos os inimigos!")
			break 
			
		var enemy = scene.instantiate()
		
		# Pega o último ponto de spawn da lista embaralhada e remove ele da lista
		var spawn_point = available_spawns.pop_back()
		
		enemy.global_position = spawn_point.global_position
		enemy.enemy_died.connect(_on_enemy_died)
		
		add_child(enemy)
		enemies_alive += 1

func _on_enemy_died() -> void:
	enemies_alive -= 1
	
	if enemies_alive <= 0:
		#GameManager.end_run_success()
		get_tree().current_scene.end_run_success()
