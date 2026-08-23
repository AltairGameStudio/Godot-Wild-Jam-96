class_name NPC
extends Node2D

enum NPCType { DIALOGUE, SHOP, UPGRADE, QUEST, EXPEDITION_GATE }

@export_group("Identidade")
@export var npc_name: String = "Habitant"
@export var npc_type: NPCType = NPCType.DIALOGUE
@export var prompt_message: String = "[E] Speak"

@export_group("Conteúdo")
@export_multiline var dialogue_pages: Array[String] = ["Hello, knight!"]
@export var accent_color: Color = Color.CORNFLOWER_BLUE

signal interacted(npc_data: NPC)

@onready var interaction_area: Area2D = $InteractionArea
@onready var prompt_label: Label = $PromptLabel
@onready var visual: Node2D = $Visual

var player_in_range: bool = false

@onready var quest_marker: Label = $ExclamationMarker
var has_quest: bool = false

func _ready() -> void:
	# Garante que o NPC esteja no grupo para o TownUI conectar
	add_to_group("npcs")

	# Se for o portão de expedição, atualiza a mensagem com a fase atual
	if npc_type == NPCType.EXPEDITION_GATE:
		prompt_message = "[Space] Go to the arena (Phase %d)" % (get_tree().current_scene.current_phase)

	prompt_label.text = prompt_message
	prompt_label.visible = false

	if visual and "modulate" in visual:
		visual.modulate = accent_color

	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_in_range = true
		if npc_type == NPCType.EXPEDITION_GATE:
			prompt_label.text = "[Space] Go to the arena (level %d)" % (get_tree().current_scene.current_phase)
		prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_in_range = false
		prompt_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	# Aceita tanto a ação customizada 'interact' quanto 'ui_accept' ou a tecla E diretamente
	if player_in_range:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			if get_viewport():
				get_viewport().set_input_as_handled()
				
			interacted.emit(self)

func _process(_delta: float) -> void:
	if not has_quest or not is_instance_valid(quest_marker):
		if is_instance_valid(quest_marker):
			quest_marker.visible = false
		return

	# Verifica se a posição do NPC está dentro da tela visível
	var viewport_rect: Rect2 = get_viewport_rect()
	var screen_pos: Vector2 = get_global_transform_with_canvas().origin
	var is_on_screen: bool = viewport_rect.has_point(screen_pos)

	quest_marker.visible = is_on_screen

	if is_on_screen:
		# 1. Anula a rotação herdada do NPC para ficar sempre em pé
		quest_marker.rotation = -global_rotation
			
		# 2. Posiciona ela no topo do NPC com animação
		var bobbing = sin(Time.get_ticks_msec() * 0.005) * 4.0
		quest_marker.global_position = global_position + Vector2(-quest_marker.size.x / 2.0, -60.0 + bobbing)
