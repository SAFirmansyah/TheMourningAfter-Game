class_name PoisonDamageAbility
extends WeaponAbility

@export var damage_per_tick := 5 # TUNE
@export var tick_count := 3 # TUNE: number of ticks
@export var tick_interval := 1 # TUNE: seconds between ticks

func apply(_attacker: Node3D, target: Node3D) -> void:
	if target.has_method("apply_poison"):
		target.apply_poison(damage_per_tick, tick_count, tick_interval)
