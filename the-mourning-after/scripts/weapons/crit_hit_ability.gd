class_name CritHitAbility
extends WeaponAbility
## Deals bonus damage on top of the base hit, as a one-off extra chunk
## rather than a damage-over-time or status effect.

@export var bonus_damage := 2.0 # TUNE: extra damage added to this single hit

func apply(_attacker: Node3D, target: Node3D) -> void:
	if target.has_method("take_damage"):
		target.take_damage(bonus_damage, Vector2.ZERO)
