class_name FinalBossRoom
extends Room

@export var villain_staff: WeaponData

@onready var villain: Player = $Villain
@onready var hero_opponent: PerrinAsEnemy = $PerrinEnemy


func _ready() -> void:
	super._ready()
	hero_opponent.stats = RunInventory.get_player().stats.duplicate()
	hero_opponent.weapon = RunInventory.get_player().weapon
	hero_opponent.target = villain
	# villain's has_self_heal/has_shield/has_pesticide are now set inside Villain._ready() itself

	hero_opponent.defeated.connect(func(): get_tree().change_scene_to_file("res://scenes/endings/victory_time_thief.tscn"))
	villain.died.connect(func(): get_tree().change_scene_to_file("res://scenes/endings/lost_cause.tscn"))
	
