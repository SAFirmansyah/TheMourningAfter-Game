class_name PrepRoom
extends Room

@export var combat_entry_name: StringName = &"CombatEntry" # match this per-scene in the Inspector

func _ready() -> void:
	super._ready() # runs Room's tint + exit-wiring logic first
	CombatRunState.start_new_run()
	_configure_next_exit()


func _configure_next_exit() -> void:
	var exit := get_exit(combat_entry_name)
	if exit == null:
		push_warning("PrepRoom: exit named '", combat_entry_name, "' not found on this room")
		return
	exit.target_room = CombatRunState.pick_next_room_path()
