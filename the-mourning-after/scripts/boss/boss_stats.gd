class_name BossStats
extends Stats

@export var max_health: int = 250
@export var base_damage: int = 5 # fallback, individual moves override this


func _init() -> void:
	unit_type = UnitType.ENEMY
	super._init()


func setup_stats() -> void:
	current_max_health = max_health
	health = max_health
	health_change.emit(health, current_max_health)


func get_damage() -> int:
	return base_damage
