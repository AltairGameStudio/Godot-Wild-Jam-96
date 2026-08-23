extends TextureRect

var labels = {
	0 : "Total coins : ",
	1 : "Max health : ",
	2 : "Current health : " ,
	3 : "Damage : ",
	4 : "Defense : ",
	5 : "Max speed : ",
	6 : "Speed multiplier : ",
	7 : "Steer speed : ",
	8 : "Drift traction : ",
	9 : "Horsepower : "
}

func update_labels(values) -> void:
	get_child(0).text = "%s%d" % [labels[0], get_tree().current_scene.gold]
	for idx in range(1,10):
		get_child(idx).text = "%s%s" % [labels[idx], values[idx-1]]
