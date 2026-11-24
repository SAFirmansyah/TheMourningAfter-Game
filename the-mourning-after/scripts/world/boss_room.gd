class_name BossRoom
extends Room
## A boss chamber. Its far exit stays shut until the boss (a Boss child) falls, then leads onto that
## boss's Huyana route. Like a combat room, it can't be saved in until it's cleared.

signal boss_defeated

@export var route_exit_name: StringName = &"BossExit"


func _ready() -> void:
	super._ready()
	var boss := _find_boss()
	if restoring and CampaignState.boss_cleared:
		if boss:
			boss.queue_free()
		return # the world restores the route exit's target
	if boss:
		boss.defeated.connect(clear_boss)
	var exit := get_exit(route_exit_name)
	if exit:
		exit.target_room = ""


func allows_saving() -> bool:
	return CampaignState.boss_cleared


func _find_boss() -> Boss:
	for node in find_children("*", "", true, false):
		if node is Boss:
			return node
	return null


## Boss clear: the next gauntlet begins on the boss's route; the world autosaves (GDD).
func clear_boss() -> void:
	if CampaignState.boss_cleared:
		return
	CampaignState.boss_cleared = true
	CampaignState.mark_boss_defeated(_boss_name())
	CombatRunState.start_next_gauntlet()
	var exit := get_exit(route_exit_name)
	if exit:
		exit.target_room = CombatRunState.pick_next_room_path()
		exit.target_entry = &"WestExit"
	boss_defeated.emit()


func _boss_name() -> String:
	var boss := _find_boss()
	if boss == null:
		return ""
	return boss.get_class() if boss.get_script() == null else boss.get_script().get_global_name()
