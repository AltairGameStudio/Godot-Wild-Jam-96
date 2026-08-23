class_name TownUI
extends CanvasLayer

@onready var dialogue_box: Panel = $UI/DialogueWindow
@onready var dialogue_name: Label = $UI/DialogueWindow/NameLabel
@onready var dialogue_text: Label = $UI/DialogueWindow/TextLabel

@onready var shop_window: Panel = $UI/ShopWindow
@onready var upgrade_window: Panel = $UI/UpgradeWindow

var active_dialogue: Array[String] = []
var dialogue_index: int = 0

enum TutorialState { CONTROLS, GO_TO_NPC, COMPLETED }
var current_tutorial_state: TutorialState = TutorialState.CONTROLS

@onready var controls_label: Label = $UI/Label
@onready var objective_label: Label = $UI/ObjectiveLabel
@onready var target_indicator: Control = $UI/TargetIndicator

var arena_npc: Node2D = null
var player: Node2D = null

func _ready() -> void:
	# Esconde todas as janelas ao carregar a cidade
	dialogue_box.visible = false
	shop_window.visible = false
	upgrade_window.visible = false
	
	# Conecta todos os NPCs presentes no mapa
	var npcs = get_tree().get_nodes_in_group("npcs")
	for npc in npcs:
		if npc is NPC:
			npc.interacted.connect(_handle_npc_interaction)
			
	# Localizar o NPC da arena e o Player
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc is NPC and npc.npc_type == NPC.NPCType.EXPEDITION_GATE:
			arena_npc = npc
			break
			
	player = get_tree().get_first_node_in_group("player")

	# Iniciar tutorial
	_start_tutorial_controls()

func _handle_npc_interaction(npc: NPC) -> void:
	match npc.npc_type:
		NPC.NPCType.DIALOGUE, NPC.NPCType.QUEST:
			_start_dialogue(npc.npc_name, npc.dialogue_pages)
		NPC.NPCType.SHOP:
			shop_window.visible = true
		NPC.NPCType.UPGRADE:
			upgrade_window.visible = true
		NPC.NPCType.EXPEDITION_GATE:
			current_tutorial_state = TutorialState.COMPLETED
			objective_label.visible = false
			target_indicator.custom_targets.clear()
			target_indicator.visible = false
			if is_instance_valid(arena_npc):
				arena_npc.has_quest = false
			get_tree().current_scene.start_run()

func _start_dialogue(speaker: String, text_pages: Array[String]) -> void:
	dialogue_name.text = speaker
	active_dialogue = text_pages
	dialogue_index = 0
	dialogue_box.visible = true
	_show_current_page()

func _show_current_page() -> void:
	if dialogue_index < active_dialogue.size():
		dialogue_text.text = active_dialogue[dialogue_index]
	else:
		dialogue_box.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if current_tutorial_state == TutorialState.CONTROLS and event.is_action_pressed("ui_accept"):
		_start_tutorial_go_to_npc()
		get_viewport().set_input_as_handled()
		return

func _start_tutorial_controls() -> void:
	current_tutorial_state = TutorialState.CONTROLS
	controls_label.visible = true
	objective_label.visible = false

func _start_tutorial_go_to_npc() -> void:
	current_tutorial_state = TutorialState.GO_TO_NPC
	controls_label.visible = false
	objective_label.visible = true
	objective_label.text = "Go to the Arena Guardian to start an expedition."
	
	# Passa o NPC da arena como alvo da seta:
	if is_instance_valid(arena_npc):
		target_indicator.custom_targets = [arena_npc]
		target_indicator.visible = true
		arena_npc.has_quest = true
