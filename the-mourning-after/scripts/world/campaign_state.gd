extends Node
## Tracks the overall run structure across multiple gauntlets and into the boss sequence.

signal boss_changed

@export var safe_room_path := "res://scenes/rooms/cooldown_nc.tscn"
@export var pre_boss_chamber_path := "res://scenes/rooms/pre_boss_chamber.tscn"
@export var boss_room_paths: Array[String] = [
	"res://scenes/rooms/boss_sandbox.tscn",
	"res://scenes/rooms/boss_sandbox_2.tscn",
]

var gauntlet_count := 0
var chosen_boss_path := ""
var has_boss_bargained := false

var _remaining_boss_pool: Array[String] = []


func reset_campaign() -> void:
	gauntlet_count = 0
	chosen_boss_path = ""
	has_boss_bargained = false
	_remaining_boss_pool.clear()


## Called by a CombatRoom when its gauntlet has no more rooms left.
func get_post_gauntlet_room_path() -> String:
	gauntlet_count += 1
	if gauntlet_count == 1:
		return safe_room_path
	return pre_boss_chamber_path


func start_boss_selection() -> void:
	if chosen_boss_path != "":
		return # already chosen — don't reroll on repeat visits to the chamber
	_remaining_boss_pool = boss_room_paths.duplicate()
	_remaining_boss_pool.shuffle()
	chosen_boss_path = _remaining_boss_pool.pop_back()
	boss_changed.emit()


func bargain_boss() -> bool:
	if has_boss_bargained or RunInventory.magic_residue <= 0:
		return false
	RunInventory.magic_residue -= 1
	has_boss_bargained = true
	if _remaining_boss_pool.is_empty():
		_remaining_boss_pool = boss_room_paths.duplicate()
		_remaining_boss_pool.erase(chosen_boss_path) # elimination: won't re-pick the one just offered
	chosen_boss_path = _remaining_boss_pool.pop_back()
	RunInventory.effects_changed.emit() # HUD residue count updates
	boss_changed.emit()
	return true
