class_name PerrinAsEnemy
extends Boss
## The AI-controlled Hero in the final fight. Uses the real HeroStats/WeaponData the player
## built up this run — no borrowed boss abilities; those belong to the Villain instead.

@export var weapon: WeaponData


func _think(to: Vector3) -> Vector3:
	if weapon == null:
		return chase(to)
	var dist := to.length()
	var attack_range := weapon.hitbox_height / 2.0 + 0.5

	if dist <= attack_range and is_ready(&"basic"):
		_basic_attack()
		return Vector3.ZERO
	return chase(to)


func _basic_attack() -> void:
	begin_attack()
	use(&"basic", weapon.attack_cooldown)
	await wait(weapon.active_delay)
	var side := Vector3(-_facing.y, 0.0, _facing.x)
	var offsets: Array[Vector3] = []
	for n in 3:
		offsets.append(forward() * (weapon.hitbox_height / 2.0) + side * ((n - 1) * 0.3))
	strike(offsets, weapon.damage, weapon.hitbox_radius, weapon.active_window)
	busy = false
