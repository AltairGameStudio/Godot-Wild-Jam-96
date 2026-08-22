extends Control

var click_delay = 0.4
var last_click = 0

func _process(delta: float) -> void:
	if last_click > 0:
		last_click -= delta
		
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and last_click <= 0:
		last_click = click_delay
		$"../../../".buy_upgrade(name)
