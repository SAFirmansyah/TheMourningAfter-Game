class_name SelfHealAbility
extends WeaponAbility

@export var heal_amount := 2.0 # TUNE: HP restored to attacker per successful hit

func apply(attacker: Node3D, _target: Node3D) -> void:
	if attacker.has_method("heal"):
		attacker.heal(heal_amount)
