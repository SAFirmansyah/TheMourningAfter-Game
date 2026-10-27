extends Stats
class_name HeroStats

@export var max_health: int = 200
@export var equipped_weapon: WeaponData
@export var equipped_armor: Armor

var rng = RandomNumberGenerator.new()

func _init() -> void:
	unit_type = UnitType.HERO
	super._init()

func setup_stats() -> void:
	current_max_health = max_health
	health = randi_range(50, max_health) # hero-only: random starting health

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
