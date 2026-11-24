class_name Hurtbox
extends Area3D

func _ready() -> void:
	monitorable = true
	monitoring = false
	refresh_layer()


func refresh_layer() -> void:
	if owner.stats == null:
		return
	collision_layer = 0
	collision_mask = 0
	match owner.stats.unit_type:
		Stats.UnitType.HERO:
			set_collision_layer_value(6, true) # player_hurtbox
		Stats.UnitType.ENEMY:
			set_collision_layer_value(7, true) # enemy_hurtbox


func receive_hit(damage: int) -> void:
	owner.stats.take_damage(damage)
