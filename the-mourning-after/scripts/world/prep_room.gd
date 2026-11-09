class_name NonCombatRoom
extends Room
## The non-combat room between the two gauntlets: its exit leads into the next gauntlet's first room.

@export var combat_entry_name: StringName = &"CombatEntry" # match this per-scene in the Inspector

func _ready() -> void:
	super._ready() # runs Room's tint + exit-wiring logic first
	if restoring:
		return # the run's room sequence and exit targets come from the save file
	CombatRunState.start_next_gauntlet()
	_configure_next_exit()


func _configure_next_exit() -> void:
	var exit := get_exit(combat_entry_name)
	if exit == null:
		push_warning("NonCombatRoom: exit named '", combat_entry_name, "' not found on this room")
		return
	exit.target_room = CombatRunState.pick_next_room_path()
