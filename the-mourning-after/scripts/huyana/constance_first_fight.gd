class_name PerrinVsConstanceTrivial
extends Room
## Perrin's side of the final confrontation: a one-slash, no-real-fight Constance encounter
## that hands off into Act 2 once she falls.

@onready var constance_first: ConstanceAsEnemy = $ConstanceAsEnemy


func _ready() -> void:
	super._ready()
	constance_first.defeated.connect(_on_constance_defeated)


func _on_constance_defeated() -> void:
	var world := get_tree().get_first_node_in_group(&"world") as World
	if world:
		world.begin_act_two()
