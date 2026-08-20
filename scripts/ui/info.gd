extends TextureRect

var labels = {
	0 : "Vida máx. :",
	1 : "Vida atual :" ,
	2 : "Dano : ",
	3 : "Vel. máx. : ",
	4 : "Mult. de vel. : "
}

func update_labels(values) -> void:
	for idx in range(5):
		get_child(idx).text = "%s%s" % [labels[idx], values[idx]]
