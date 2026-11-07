extends Stats
class_name HeroStats

@export var max_health: int = 200
@export var min_health: int = 100
@export var health_step: int = 25 # TUNE: rolled max HP lands on multiples of this
@export var min_move_speed := 1.0
@export var max_move_speed := 2.0
@export var move_speed_step := 0.25 # TUNE: rolled move speed lands on multiples of this
@export var equipped_weapon: WeaponData
@export var equipped_armor: Armor

var move_speed_multiplier := 1.0

var rng = RandomNumberGenerator.new()

func _init() -> void:
	unit_type = UnitType.HERO
	super._init()

func setup_stats() -> void:
	current_max_health = min_health + health_step * randi_range(0, (max_health - min_health) / health_step)
	health = current_max_health
	move_speed_multiplier = min_move_speed + move_speed_step * randi_range(0, roundi((max_move_speed - min_move_speed) / move_speed_step))
	health_change.emit(health, current_max_health)

func setup_fixed_stats(max_hp: int, speed: float) -> void:
	current_max_health = max_hp
	health = max_hp
	move_speed_multiplier = speed
	health_change.emit(health, current_max_health)


func setup_first_run_stats() -> void:
	current_max_health = 50
	health = 50
	move_speed_multiplier = 0.5
	health_change.emit(health, current_max_health)

func get_damage() -> int:
	if equipped_weapon and "damage" in equipped_weapon:
		return equipped_weapon.damage
	return 0


func get_defense() -> int:
	if equipped_armor:
		return equipped_armor.defense
	return 0


func equip_weapon(weapon: WeaponData) -> void:
	equipped_weapon = weapon


func equip_armor(armor: Armor) -> void:
	equipped_armor = armor
