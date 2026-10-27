extends Stats
class_name MutantStats

@export var min_damage: int = 5 # TUNE - Mutants minimum damage deal
@export var max_damage: int = 25 # TUNE - Mutants maximum damage deal
@export var min_mutant_health: int = 30 # TUNE - Mutants minimum health
@export var max_mutant_health: int = 80 # TUNE - Mutants maximum health
@export var hitbox_radius: float = 0.3 # TUNE - Enemy attack lateral range
@export var hitbox_height: float = 0.6 # TUNE - Enemy attack height range

var rng := RandomNumberGenerator.new()
var _damage: int = 0


func _init() -> void:
	unit_type = UnitType.ENEMY
	super._init()


func setup_stats() -> void:
	current_max_health = max_mutant_health
	health = rng.randi_range(min_mutant_health, max_mutant_health)
	_damage = rng.randi_range(min_damage, max_damage)


func get_damage() -> int:
	return _damage


func get_hitbox_radius() -> float:
	return hitbox_radius


func get_hitbox_height() -> float:
	return hitbox_height
