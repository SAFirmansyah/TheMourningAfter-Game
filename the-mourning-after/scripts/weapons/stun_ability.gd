class_name StunAbility
extends WeaponAbility
## Stuns the target briefly. Does nothing to anything in the "boss" group.

@export var stun_duration := 1.5 # TUNE: seconds the target is stunned

func apply(_attacker: Node3D, target: Node3D) -> void:
	print("StunAbility.apply called on ", target.name)
	if target.is_in_group("boss"):
		return
	if target.has_method("apply_stun"):
		target.apply_stun(stun_duration)
