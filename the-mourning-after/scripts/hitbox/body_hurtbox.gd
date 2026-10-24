class_name Hurtbox
extends Area3D

@onready var owner_stats: Stats = owner.stats

func _ready():
	monitoring = false
	set_collision_layer_value(5, false)
	set_collision_mask_value(4, false)
	match owner_stats.unit_type:
		Stats.UnitType.HERO:
			set_collision_layer_value(4,true)
		Stats.UnitType.ENEMY:
			set_collision_layer_value(3,true)
			
func receive_hit(damage: int):
	owner_stats.take_damage(damage)
