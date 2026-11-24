class_name ConstanceAsEnemy
extends CharacterBody3D
## Constance as she appears the very first time Perrin reaches her — not a real fight.
## She takes no actions and falls to a single hit, so the story can move straight into
## the villain-prequel sequence afterward.

signal defeated

@export var stats: BossStats # give her 1 HP in the Inspector, or override in _ready() below
@export var display_name := "Constance"

var _is_dead := false


func _ready() -> void:
	if stats == null:
		stats = BossStats.new()
	else:
		stats = stats.duplicate()
	stats.current_max_health = 1
	stats.health = 1
	stats.health_depleted.connect(_on_health_depleted)
	add_to_group(&"enemies")
	add_to_group(&"boss")


func receive_hit(_amount: int) -> void:
	stats.take_damage(stats.health) # any hit at all ends it — no real health pool to grind through


func _on_health_depleted() -> void:
	if _is_dead:
		return
	_is_dead = true
	set_physics_process(false)
	visible = false
	collision_layer = 0
	collision_mask = 0
	defeated.emit()
	queue_free()
