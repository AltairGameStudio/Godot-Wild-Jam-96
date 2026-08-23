extends Container

@onready var game = get_tree().current_scene
@onready var player = get_tree().current_scene.get_node("Player")

@onready var max_health = $background/max_health_container
@onready var engine_power = $background/engine_power_container
@onready var base_damage = $background/base_damage_container
@onready var drift_traction = $background/drift_traction_container
var upgrade_names = ["max_health", "engine_power", "base_damage", "drift_traction"]

func _ready() -> void:
	update_upgrades()

func update_upgrades() -> void:
	$background/max_health_container/step_val.text = str(game.upgrades["max_health"]["val_step"])
	$background/max_health_container/cost.text = str(game.upgrades["max_health"]["base_cost"] * (game.upgrades["max_health"]["cost_mult"]**game.upgrades["max_health"]["level"]))
	$background/engine_power_container/step_val.text = str(game.upgrades["engine_power"]["val_step"])
	$background/engine_power_container/cost.text = str(game.upgrades["engine_power"]["base_cost"] * (game.upgrades["engine_power"]["cost_mult"]**game.upgrades["engine_power"]["level"]))
	$background/base_damage_container/step_val.text = str(game.upgrades["base_damage"]["val_step"])
	$background/base_damage_container/cost.text = str(game.upgrades["base_damage"]["base_cost"] * (game.upgrades["base_damage"]["cost_mult"]**game.upgrades["base_damage"]["level"]))
	$background/drift_traction_container/step_val.text = str(game.upgrades["drift_traction"]["val_step"])
	$background/drift_traction_container/cost.text = str(game.upgrades["drift_traction"]["base_cost"] * (game.upgrades["drift_traction"]["cost_mult"]**game.upgrades["drift_traction"]["level"]))

func apply_upgrade(upgrade_name: String, val_step: int) -> void:
	match upgrade_name:
		"max_health":
			player.max_health += val_step
			player.current_health += val_step
		"engine_power":
			player.engine_power += val_step
		"base_damage":
			player.base_damage += val_step
		"drift_traction":
			player.drift_traction += val_step
	player.update_info()

func buy_upgrade(upgrade_name: String) -> void:
	var upgrade_entry = game.upgrades[upgrade_name]
	var cost = upgrade_entry["base_cost"] * (upgrade_entry["cost_mult"] ** upgrade_entry["level"])
	var val_step = upgrade_entry["val_step"]
	if ((upgrade_entry["base_cost"] * (upgrade_entry["cost_mult"] ** upgrade_entry["level"])) <= game.gold):
		game.gold -= cost
		AudioManager.play_sfx(AudioManager.SFX_BUY)
		apply_upgrade(upgrade_name, val_step)
		$"../notification".activate_notification("Upgrade bought")
		game.upgrades[upgrade_name]["level"] += 1
		game.upgrades[upgrade_name]["current_val"] += game.upgrades[upgrade_name]["val_step"]
		update_upgrades()
	else:
		$"../notification".activate_notification("You don't have money for that")
