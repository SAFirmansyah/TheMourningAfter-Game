class_name PreBossChamber
extends Room

@export var boss_exit_name: StringName = &"BossEntry" # match your actual exit node's name

func _ready() -> void:
	super._ready()
	CampaignState.start_boss_selection()
	_configure_boss_exit()
	CampaignState.boss_changed.connect(_on_boss_changed)

func _on_boss_changed() -> void:
	_configure_boss_exit()


## Shut while the forced Fate 2 bargain is still owed.
func _configure_boss_exit() -> void:
	var exit := get_exit(boss_exit_name)
	if exit == null:
		push_warning("PreBossChamber: exit '", boss_exit_name, "' not found")
		return
	exit.target_room = "" if CampaignState.fate2_forced_pending() else CampaignState.chosen_boss_path

