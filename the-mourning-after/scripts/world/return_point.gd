@tool
class_name ReturnPoint
extends Interactable
## Boss-room stand-in until boss fights exist: ends the run and returns Perrin to base, progress saved.


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	prompt_label = "Return to base"
	interacted.connect(_on_interacted)


func _on_interacted() -> void:
	var world := get_tree().current_scene as World
	if world:
		world.return_to_base()
