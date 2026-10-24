extends Resource
class_name Stats

enum UnitType { HERO, ENEMY }

signal health_depleted
signal health_change(cur_health: int, max_health: int)

var rng = RandomNumberGenerator.new()

@export var unit_type: UnitType = UnitType.HERO

@export var max_health: int = 200

## Only used when unit_type == ENEMY. Hero damage comes from equipped_weapon instead.
@export var base_damage: int = 10

## Only relevant for HERO. Assign a weapon resource with a `damage` property.
@export var equipped_weapon: Resource

## Only relevant for HERO. Assign an Armor resource. Leave empty for no armor.
@export var equipped_armor: Armor

var current_max_health: int = 200

var health: int = 0


func _init():
	setup_stats.call_deferred()


func setup_stats():
	current_max_health = max_health

	if unit_type == UnitType.HERO:
		# Randomized once per run, only for the hero
		health = rng.randi_range(50, current_max_health)
	else:
		health = current_max_health


func on_health_set(new_value: int):
	health = clampi(new_value, 0, current_max_health)
	health_change.emit(health, current_max_health)
	if health <= 0:
		health_depleted.emit()


## Returns the current effective damage, whichever unit this is.
func get_damage() -> int:
	if unit_type == UnitType.HERO:
		if equipped_weapon and "damage" in equipped_weapon:
			return equipped_weapon.damage
		return 0 # no weapon equipped
	else:
		return base_damage


## Returns the current effective defense. Hero-only; enemies have no defense stat.
func get_defense() -> int:
	if unit_type != UnitType.HERO:
		return 0
	if equipped_armor:
		return equipped_armor.defense
	return 0 # no armor equipped


## Call this when this unit is hit by an attacker. Applies defense (hero only)
## before subtracting from health. Returns the actual damage dealt, in case
## you want to show a damage number in the UI.
func take_damage(incoming_damage: int) -> int:
	var mitigated := incoming_damage - get_defense()
	var actual_damage: int = max(mitigated, 0)
	on_health_set(health - actual_damage)
	return actual_damage


func equip_weapon(weapon: Resource) -> void:
	if unit_type != UnitType.HERO:
		push_warning("equip_weapon called on a non-hero Stats resource")
		return
	equipped_weapon = weapon


func equip_armor(armor: Armor) -> void:
	if unit_type != UnitType.HERO:
		push_warning("equip_armor called on a non-hero Stats resource")
		return
	equipped_armor = armor
