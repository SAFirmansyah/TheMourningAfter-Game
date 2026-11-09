class_name BaseRoom
extends Room
## Perrin's starting room. Its run exit stays shut until he takes his starting loadout,
## then leads into the run's first combat room. He holds no weapon until then.
## On a fresh save it also stays shut until the forced Fate 1 bargain is made.

@export var run_exit_name: StringName = &"SouthExit"


func _ready() -> void:
	super._ready()
	RunInventory.effects_changed.connect(_refresh_exit)
	_refresh_exit()
	_unarm_if_no_loadout.call_deferred() # the player is bound (and any save restored) once the world is ready


func _unarm_if_no_loadout() -> void:
	if not RunInventory.loadout_taken:
		RunInventory.clear_weapon()


func _refresh_exit() -> void:
	var exit := get_exit(run_exit_name)
	if exit:
		var open := RunInventory.loadout_taken and not RunInventory.fate1_forced_pending()
		exit.target_room = CombatRunState.first_room_path if open else ""
