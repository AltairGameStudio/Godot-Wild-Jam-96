class_name NPC
extends Node2D

enum NPCType { DIALOGUE, SHOP, UPGRADE, QUEST, EXPEDITION_GATE }

@export_group("Identidade")
@export var npc_name: String = "Habitante"
@export var npc_type: NPCType = NPCType.DIALOGUE
@export var prompt_message: String = "[E] Falar"

@export_group("Conteúdo")
@export_multiline var dialogue_pages: Array[String] = ["Olá, cavaleiro!"]
@export var accent_color: Color = Color.CORNFLOWER_BLUE

signal interacted(npc_data: NPC)

@onready var interaction_area: Area2D = $InteractionArea
@onready var prompt_label: Label = $PromptLabel
@onready var visual: Node2D = $Visual

var player_in_range: bool = false

func _ready() -> void:
	prompt_label.text = prompt_message
	prompt_label.visible = false
	
	if visual and "modulate" in visual:
		visual.modulate = accent_color
	
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_in_range = true
		prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_in_range = false
		prompt_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and event.is_action_pressed("ui_accept"): # Tecla Espaço / Enter / E
		interacted.emit(self)
		get_viewport().set_input_as_handled()
