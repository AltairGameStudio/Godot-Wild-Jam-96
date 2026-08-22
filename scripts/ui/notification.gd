extends Label

var notification_time = 1
var time_to_expire = 0

func activate_notification(message: String) -> void:
	time_to_expire = notification_time
	text = message
	visible = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if (time_to_expire > 0):
		time_to_expire -= delta
		global_position = get_global_mouse_position() + Vector2(10,10)
	elif visible:
		visible = false
