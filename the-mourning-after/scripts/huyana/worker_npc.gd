@tool
class_name WorkerNPC
extends NPC
## Rudrama, Gwenith or Shuyi: follows the position the Sanctuary manager walks her along
## (Rudrama: anvil <-> containments; Gwenith and Shuyi: station <-> campfire).

@export_enum("rudrama", "gwenith", "shuyi") var worker := "rudrama"

var _manager: SanctuaryManager


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	_manager = get_tree().get_first_node_in_group(&"sanctuary_manager")
	if _manager:
		global_position = _manager.worker_position(StringName(worker))
		reset_physics_interpolation()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or _manager == null:
		return
	global_position = _manager.worker_position(StringName(worker))
