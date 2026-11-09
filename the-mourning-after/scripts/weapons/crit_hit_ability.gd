class_name CritHitAbility
extends WeaponAbility
## Deals bonus damage on top of the base hit, as a one-off extra chunk
## rather than a damage-over-time or status effect.

@export var min_bonus_percent := 33 # TUNE: lowest extra damage, as % of the hit's base damage
@export var max_bonus_percent := 50 # TUNE: highest extra damage, as % of the hit's base damage

func apply(attacker: Node3D, target: Node3D) -> void:
	if not target.has_method("receive_hit") or not attacker.has_method("hit_damage"):
		return
	var percent := randi_range(min_bonus_percent, max_bonus_percent)
	target.receive_hit(roundi(attacker.hit_damage() * percent / 100.0))
	if target.has_method("flash_crit"):
		target.flash_crit()
