class_name BossRoom
extends Room
## A boss chamber. Its far exit stays shut until the boss falls, then leads onto that boss's Huyana route.
## Until boss fights exist, a stand-in interactable clears it.

signal boss_defeated

@export var route_exit_name: StringName = &"BossExit"


func _ready() -> void:
	super._ready()
	if restoring and CampaignState.boss_cleared:
		return # the world restores the route exit's target
	var exit := get_exit(route_exit_name)
	if exit:
		exit.target_room = ""


## Boss clear: the next gauntlet begins on the boss's route; the world autosaves (GDD).
func clear_boss() -> void:
	if CampaignState.boss_cleared:
		return
	CampaignState.boss_cleared = true
	CombatRunState.start_next_gauntlet()
	var exit := get_exit(route_exit_name)
	if exit:
		exit.target_room = CombatRunState.pick_next_room_path()
		exit.target_entry = &"WestExit"
	boss_defeated.emit()
