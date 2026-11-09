@tool
class_name ActTwoPoint
extends Interactable
## Sanctuary stand-in until the final confrontation exists: ends Perrin's story and moves on to Constance.


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	prompt_label = "Confront Constance"
	interacted.connect(_on_interacted)


func _on_interacted() -> void:
	var world := get_tree().current_scene as World
	if world:
		world.begin_act_two()
