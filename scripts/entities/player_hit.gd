class_name HitReceiver
extends Area2D

enum HitType { NORMAL, WEAKSPOT, SHIELD }

@export var hit_type: HitType = HitType.NORMAL
@export var damage_multiplier: float = 1.0
@export var momentum_penalty: float = 0.25 # Percentual de perda de velocidade do jogador

signal hit_received(damage: float, direction: Vector2, hit_type: HitType)

func process_hit(incoming_damage: float, hit_direction: Vector2) -> Dictionary:
	var final_damage = incoming_damage * damage_multiplier
	hit_received.emit(final_damage, hit_direction, hit_type)
	
	return {
		"damage_dealt": final_damage,
		"hit_type": hit_type,
		"momentum_penalty": momentum_penalty
	}
