extends Node

# Sinais para atualização reativa de UI
signal gold_changed(new_amount: int)
signal upgrade_purchased(upgrade_id: String, new_level: int)

# Economia e Meta-Progressão (Persistente)
var gold: int = 0 # Ouro inicial para testes

# Níveis e valores dos upgrades permanentes
var upgrades: Dictionary = {
	"max_health": {"level": 1, "base_cost": 50, "cost_mult": 1.5, "val_step": 20.0, "current_val": 100.0},
	"engine_power": {"level": 1, "base_cost": 75, "cost_mult": 1.6, "val_step": 150.0, "current_val": 1400.0},
	"base_damage": {"level": 1, "base_cost": 60, "cost_mult": 1.5, "val_step": 10.0, "current_val": 30.0},
	"drift_traction": {"level": 1, "base_cost": 100, "cost_mult": 1.8, "val_step": 0.03, "current_val": 0.85}
}

# Dados da Expedição Atual (Transitórios)
var current_run_loot: Array[Dictionary] = []
var run_timer: float = 0.0
var is_in_run: bool = false

# Caminhos das Cenas
const ARENA_SCENE_PATH = "res://scenes/arena/arena.tscn"
const TOWN_SCENE_PATH = "res://scenes/town/town.tscn"
var player_scene = preload("res://scenes/entities/player.tscn")

var current_phase: int = 1

var current_scene: Node

func _ready() -> void:
	change_world(TOWN_SCENE_PATH)
	
func _process(delta: float) -> void:
	if is_in_run:
		run_timer += delta

func change_world(scene_path: String) -> void:
	if current_scene:
		current_scene.queue_free()
	
	current_scene = load(scene_path).instantiate()
	$World.add_child(current_scene)
	
	var spawn = current_scene.get_node("PlayerSpawn")
	$Player.global_position = spawn.global_position
	$Player.velocity = Vector2(0,0)

# Inicia a expedição limpando os dados da run anterior
func start_run() -> void:
	current_run_loot.clear()
	run_timer = 0.0
	is_in_run = true
	change_world(ARENA_SCENE_PATH)

# Retorno com sucesso (ex: passou pelo portal de extração)
func end_run_success() -> void:
	await get_tree().create_timer(5).timeout
	print("Passou de fase")
	is_in_run = false
	var total_earned = 0
	
	for item in current_run_loot:
		var freshness_mult = clampf(1.0 - (run_timer / 300.0), 0.2, 1.0)
		total_earned += int(item.get("base_value", 10) * freshness_mult)
	
	add_gold(total_earned)
	current_run_loot.clear.call_deferred()
	
	# Avança para a próxima fase
	current_phase += 1
	change_world(TOWN_SCENE_PATH)

# Retorno por morte (perde os itens da run atual)
func end_run_failure() -> void:
	await get_tree().create_timer(5).timeout
	is_in_run = false
	current_run_loot.clear.call_deferred()
	
	# Reseta a fase ao morrer
	current_phase = 1
	gold = 100
	var new_player = player_scene.instantiate()
	add_child(new_player)
	upgrades["max_health"]["current_val"] = new_player.max_health
	upgrades["engine_power"]["current_val"] = new_player.engine_power
	upgrades["base_damage"]["current_val"] = new_player.base_damage
	upgrades["drift_traction"]["current_val"] = new_player.drift_traction
	change_world(TOWN_SCENE_PATH)

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)

func get_upgrade_cost(upgrade_id: String) -> int:
	if not upgrades.has(upgrade_id):
		return 999999
	var data = upgrades[upgrade_id]
	return int(data["base_cost"] * pow(data["cost_mult"], data["level"] - 1))

func buy_upgrade(upgrade_id: String) -> bool:
	if not upgrades.has(upgrade_id):
		return false
		
	var cost = get_upgrade_cost(upgrade_id)
	if gold < cost:
		return false
		
	gold -= cost
	gold_changed.emit(gold)
	
	var data = upgrades[upgrade_id]
	data["level"] += 1
	data["current_val"] += data["val_step"]
	
	upgrade_purchased.emit(upgrade_id, data["level"])
	return true
