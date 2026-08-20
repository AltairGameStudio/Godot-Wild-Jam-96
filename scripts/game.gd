extends Node2D

var current_scene: Node

func _ready() -> void:
	change_world("res://scenes/town/town.tscn")

func change_world(scene_path: String) -> void:
	if current_scene:
		current_scene.queue_free()
	
	current_scene = load(scene_path).instantiate()
	$World.add_child(current_scene)
