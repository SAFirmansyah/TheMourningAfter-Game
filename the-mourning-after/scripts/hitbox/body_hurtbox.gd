class_name Hurtbox
extends Area3D

@onready var owner_stats: Stats = owner.stats


func _ready() -> void:
	monitorable = true
	monitoring = false
	collision_layer = 0
	collision_mask = 0
	match owner_stats.unit_type:
		Stats.UnitType.HERO:
			set_collision_layer_value(6, true) # player_hurtbox
		Stats.UnitType.ENEMY:
			set_collision_layer_value(7, true) # enemy_hurtbox


func receive_hit(damage: int) -> void:
	owner_stats.take_damage(damage)
