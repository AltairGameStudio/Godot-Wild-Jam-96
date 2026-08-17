class_name EnemyHitbox
extends Area2D

@export var damage: float = 20.0
@export var knockback_force: float = 250.0

func get_damage_payload(target_position: Vector2) -> Dictionary:
	var push_direction = (target_position - global_position).normalized()
	return {
		"damage": damage,
		"knockback": push_direction * knockback_force
	}
