class_name TownUI
extends CanvasLayer

@onready var dialogue_box: Panel = $UI/DialogueWindow
@onready var dialogue_name: Label = $UI/DialogueWindow/NameLabel
@onready var dialogue_text: Label = $UI/DialogueWindow/TextLabel

@onready var shop_window: Panel = $UI/ShopWindow
@onready var upgrade_window: Panel = $UI/UpgradeWindow

var active_dialogue: Array[String] = []
var dialogue_index: int = 0

enum TutorialState { CONTROLS, GO_TO_NPC, VISIT_SHOPS, COMPLETED }
var current_tutorial_state: TutorialState = TutorialState.COMPLETED

var arena_npc: Node2D = null
var shop_npcs: Array[Node2D] = []
var player: Node2D = null

@onready var controls_panel = $UI/ControlsBackground
@onready var objective_label: Label = $UI/ObjectiveLabel
@onready var target_indicator: Control = $UI/TargetIndicator

func _ready() -> void:
	dialogue_box.visible = false
	shop_window.visible = false
	upgrade_window.visible = false
	
	# Conecta todos os NPCs presentes no mapa
	var npcs = get_tree().get_nodes_in_group("npcs")
	for npc in npcs:
		if npc is NPC:
			npc.interacted.connect(_handle_npc_interaction)
			if npc.npc_type == NPC.NPCType.EXPEDITION_GATE:
				arena_npc = npc
			elif npc.npc_type == NPC.NPCType.SHOP or npc.npc_type == NPC.NPCType.UPGRADE:
				shop_npcs.append(npc)
			
	player = get_tree().get_first_node_in_group("player")

	# Busca a fase atual no nó principal do jogo
	var phase = 1
	var game_node = get_tree().root.get_node_or_null("Game")
	if not game_node:
		# Tenta pegar subindo na hierarquia (TownHUD -> Town -> World -> Game)
		game_node = get_node_or_null("/root/Game")
	
	if game_node and "current_phase" in game_node:
		phase = game_node.current_phase
	elif get_tree().current_scene and "current_phase" in get_tree().current_scene:
		phase = get_tree().current_scene.current_phase

	print(">>> [TownUI] Iniciando Cidade na Fase: ", phase)

	if phase == 1:
		_start_tutorial_controls()
	elif phase == 2:
		controls_panel.visible = false
		_start_tutorial_visit_shops()
	else:
		current_tutorial_state = TutorialState.COMPLETED
		controls_panel.visible = false
		objective_label.visible = false
		target_indicator.visible = false

func _handle_npc_interaction(npc: NPC) -> void:
	# Se interagiu com um NPC que tinha exclamação, remove daquele NPC
	if npc.has_quest:
		npc.has_quest = false
		target_indicator.custom_targets.erase(npc)
		
		# Se visitou todas as lojas, pode esconder o objetivo ou pedir para voltar para a arena
		if current_tutorial_state == TutorialState.VISIT_SHOPS:
			if target_indicator.custom_targets.is_empty():
				objective_label.text = "Ready? Go back to the Arena Guardian!"
				if is_instance_valid(arena_npc):
					target_indicator.custom_targets = [arena_npc]
					arena_npc.has_quest = true

	match npc.npc_type:
		NPC.NPCType.DIALOGUE, NPC.NPCType.QUEST:
			_start_dialogue(npc.npc_name, npc.dialogue_pages)
		#NPC.NPCType.SHOP:
			#shop_window.visible = true
		#NPC.NPCType.UPGRADE:
			#upgrade_window.visible = true
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
	controls_panel.visible = true
	objective_label.visible = false
	if is_instance_valid(player):
		player.can_move = false

func _start_tutorial_go_to_npc() -> void:
	current_tutorial_state = TutorialState.GO_TO_NPC
	controls_panel.visible = false
	objective_label.visible = true
	objective_label.text = "Go to the Arena Guardian to start an expedition."
	
	if is_instance_valid(player):
		player.can_move = true
	
	# Passa o NPC da arena como alvo da seta:
	if is_instance_valid(arena_npc):
		target_indicator.custom_targets = [arena_npc]
		target_indicator.visible = true
		arena_npc.has_quest = true

func _start_tutorial_visit_shops() -> void:
	current_tutorial_state = TutorialState.VISIT_SHOPS
	controls_panel.visible = false # <--- Garante que os controles estão fechados
	if is_instance_valid(player):
		player.can_move = true     # <--- Garante que o jogador pode andar
	objective_label.visible = true
	objective_label.text = "Visit the shops to upgrade your gear!"
	
	# Ativa a exclamação em todas as lojas
	for shop in shop_npcs:
		if is_instance_valid(shop):
			shop.has_quest = true
			
	# Passa todos os NPCs das lojas para o indicador de setas
	target_indicator.custom_targets = shop_npcs.duplicate()
	target_indicator.visible = true
