extends Node
## Tracks the overall run structure across multiple gauntlets and into the boss sequence.

signal boss_changed

@export var safe_room_path := "res://scenes/rooms/cooldown_nc.tscn"
@export var pre_boss_chamber_path := "res://scenes/rooms/pre_boss_chamber.tscn"
@export var boss_rooms: Dictionary[String, String] = {
	"GWENITH": "res://scenes/rooms/boss_sandbox.tscn",
	"SHUYI": "res://scenes/rooms/boss_sandbox_2.tscn",
	"RUDRAMA": "res://scenes/rooms/boss_sandbox.tscn", # TUNE: placeholder until Rudrama's chamber exists
}
@export var route_rest_rooms: Dictionary[String, String] = { # Huyana's non-combat room on each boss's route
	"GWENITH": "res://scenes/rooms/huyana/barn.tscn",
	"SHUYI": "res://scenes/rooms/huyana/medical_bay.tscn",
	"RUDRAMA": "res://scenes/rooms/huyana/forge.tscn",
}
@export var sanctuary_path := "res://scenes/rooms/huyana/sanctuary_gate.tscn" # stand-in for reaching the Sanctuary
@export var boss_bargain_cost := 2 # TUNE: Fate 2 re-roll of the boss (once per run)
@export var first_boss_shown := "RUDRAMA" # forced Fate 2: the boss first glimpsed on a fresh save
@export var first_boss_fought := "SHUYI" # ...and the one the forced bargain swaps in

var gauntlet_count := 0
var chosen_boss := ""
var has_boss_bargained := false
var boss_cleared := false

var _remaining_boss_pool: Array[String] = []

var chosen_boss_path: String:
	get:
		return boss_rooms.get(chosen_boss, "")


func reset_campaign() -> void:
	gauntlet_count = 0
	chosen_boss = ""
	has_boss_bargained = false
	boss_cleared = false
	_remaining_boss_pool.clear()


## Called by a CombatRoom when its gauntlet has no more rooms left.
func get_post_gauntlet_room_path() -> String:
	gauntlet_count += 1
	match gauntlet_count:
		1:
			return safe_room_path
		2:
			return pre_boss_chamber_path
		3:
			return route_rest_rooms.get(chosen_boss, safe_room_path)
	return sanctuary_path


func start_boss_selection() -> void:
	if chosen_boss != "":
		return # already chosen — don't reroll on repeat visits to the chamber
	_remaining_boss_pool.assign(boss_rooms.keys())
	_remaining_boss_pool.shuffle()
	if fate2_forced_pending():
		_remaining_boss_pool.erase(first_boss_shown)
		chosen_boss = first_boss_shown
	else:
		chosen_boss = _remaining_boss_pool.pop_back()
	boss_changed.emit()


## Fresh save only: the first time Perrin reaches the boss chamber, Fate 2 must be bargained with.
func fate2_forced_pending() -> bool:
	return not RunInventory.has_reached_boss and not has_boss_bargained


func can_bargain_boss() -> bool:
	return chosen_boss != "" and not has_boss_bargained and (RunInventory.magic_residue >= boss_bargain_cost or fate2_forced_pending())


func bargain_boss() -> bool:
	if not can_bargain_boss():
		return false
	var forced := fate2_forced_pending()
	RunInventory.magic_residue = maxi(RunInventory.magic_residue - boss_bargain_cost, 0) # the forced bargain never strands Perrin
	has_boss_bargained = true
	if forced:
		RunInventory.has_reached_boss = true
		chosen_boss = first_boss_fought
	else:
		_remaining_boss_pool.erase(chosen_boss) # elimination: won't re-pick the one just offered
		if _remaining_boss_pool.is_empty():
			_remaining_boss_pool.assign(boss_rooms.keys())
			_remaining_boss_pool.erase(chosen_boss)
		chosen_boss = _remaining_boss_pool.pick_random()
	RunInventory.effects_changed.emit()
	boss_changed.emit()
	RunInventory.bargained.emit()
	return true


func save_state() -> Dictionary:
	return {
		"gauntlet_count": gauntlet_count,
		"chosen_boss": chosen_boss,
		"has_boss_bargained": has_boss_bargained,
		"boss_cleared": boss_cleared,
		"remaining_boss_pool": _remaining_boss_pool,
	}


func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	gauntlet_count = int(state.get("gauntlet_count", 0))
	chosen_boss = state.get("chosen_boss", "")
	has_boss_bargained = state.get("has_boss_bargained", false)
	boss_cleared = state.get("boss_cleared", false)
	_remaining_boss_pool.assign(state.get("remaining_boss_pool", []))
