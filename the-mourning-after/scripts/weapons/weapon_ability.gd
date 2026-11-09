class_name WeaponAbility
extends Resource
## Base class for on-hit weapon abilities. Subclass this and override
## apply() to add a new effect (knockback, poison, self-heal, stun, etc.)
## without touching Hitbox.gd or Player.gd.

func apply(_attacker: Node3D, _target: Node3D) -> void:
	pass # override in subclass
