extends TextureRect

var labels = {
	0 : "Qtd. ouro : ",
	1 : "Vida máx. : ",
	2 : "Vida atual : " ,
	3 : "Dano : ",
	4 : "Defesa : ",
	5 : "Vel. máx. : ",
	6 : "Mult. de vel. : ",
	7 : "Vel. de manobra : ",
	8 : "Tração de drift : ",
	9 : "Força do cavalo : "
}

func update_labels(values) -> void:
	get_child(0).text = "%s%d" % [labels[0], get_tree().current_scene.gold]
	for idx in range(1,10):
		get_child(idx).text = "%s%s" % [labels[idx], values[idx-1]]
