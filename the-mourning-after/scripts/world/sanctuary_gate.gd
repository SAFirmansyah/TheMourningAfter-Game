class_name SanctuaryGate
extends Room
## Stand-in for reaching the Sanctuary at the end of Huyana's route. Takes the GDD snapshot of this
## run's Perrin on arrival; its interactable sends him home until Act 2 exists.


func _ready() -> void:
	super._ready()
	if not restoring:
		RunInventory.take_final_snapshot()
