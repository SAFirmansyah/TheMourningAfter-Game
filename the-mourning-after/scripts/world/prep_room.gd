class_name PrepRoom
extends Room

func _ready() -> void:
	super._ready() # runs Room's tint + exit-wiring logic first
	CombatRunState.start_new_run()
	_configure_next_exit()


func _configure_next_exit() -> void:
	var exit := get_exit(&"ToCombat") # match this to your actual exit node's name
	exit.target_room = CombatRunState.pick_next_room_path()
