class_name SanctuaryGate
extends Room
## Stand-in for reaching the Sanctuary at the end of Huyana's route. Takes the GDD snapshot of this
## run's Perrin on arrival. One interactable sends him home, the other hands the story over to Constance.


func _ready() -> void:
	super._ready()
	if not restoring:
		RunInventory.take_final_snapshot()
