extends Control

var click_delay = 0.3
var last_click = 0

func _process(delta: float) -> void:
	if last_click > 0:
		last_click -= delta
	if $description.visible:
		$description.global_position = get_global_mouse_position() + Vector2(10,10)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and last_click <= 0:
		last_click = click_delay
		get_tree().call_group("buy_store", "on_lvl_down")
		var tween = create_tween().set_parallel(false)
		tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _on_mouse_entered() -> void:
	if get_viewport().gui_is_dragging(): return
	$description.visible = true

func _on_mouse_exited() -> void:
	$description.visible = false
