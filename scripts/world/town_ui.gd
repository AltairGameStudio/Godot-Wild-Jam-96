class_name TownUI
extends CanvasLayer

@onready var dialogue_box: Panel = $UI/DialogueWindow
@onready var dialogue_name: Label = $UI/DialogueWindow/NameLabel
@onready var dialogue_text: Label = $UI/DialogueWindow/TextLabel

@onready var shop_window: Panel = $UI/ShopWindow
@onready var upgrade_window: Panel = $UI/UpgradeWindow

var active_dialogue: Array[String] = []
var dialogue_index: int = 0

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

func _handle_npc_interaction(npc: NPC) -> void:
	match npc.npc_type:
		NPC.NPCType.DIALOGUE, NPC.NPCType.QUEST:
			_start_dialogue(npc.npc_name, npc.dialogue_pages)
		NPC.NPCType.SHOP:
			shop_window.visible = true
		NPC.NPCType.UPGRADE:
			upgrade_window.visible = true
		NPC.NPCType.EXPEDITION_GATE:
			#GameManager.start_run()
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
	# Avança o diálogo ao pressionar confirmar
	if dialogue_box.visible and event.is_action_pressed("ui_accept"):
		dialogue_index += 1
		_show_current_page()
		get_viewport().set_input_as_handled()
