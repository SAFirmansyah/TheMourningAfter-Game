extends Resource
class_name Stats

enum UnitType { HERO, ENEMY }

signal health_depleted
signal health_change(cur_health: int, max_health: int)

@export var unit_type: UnitType = UnitType.HERO

var current_max_health: int = 0
var health: int = 0


func _init() -> void:
	setup_stats.call_deferred()


func setup_stats() -> void:
	pass

func on_health_set(new_value: int):
	health = clampi(new_value, 0, current_max_health)
	health_change.emit(health, current_max_health)
	if health <= 0:
		health_depleted.emit()


## Returns the current effective damage, whichever unit this is.
func get_damage() -> int:
	return 0 # subclass override


## Returns the current effective defense. Hero-only; enemies have no defense stat.
func get_defense() -> int:
	return 0 #subclass override


## Call this when this unit is hit by an attacker. Applies defense (hero only)
## before subtracting from health. Returns the actual damage dealt, in case
## you want to show a damage number in the UI.
func take_damage(incoming_damage: int) -> int:
	var mitigated := incoming_damage - get_defense()
	var actual_damage: int = max(mitigated, 0)
	var who := "HERO" if unit_type == UnitType.HERO else "ENEMY"
	on_health_set(health - actual_damage)
	return actual_damage
