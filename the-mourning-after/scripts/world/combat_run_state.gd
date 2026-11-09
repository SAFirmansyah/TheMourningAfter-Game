extends Node
## Tracks progress through the randomized combat-room sequence for the current run.
## Autoload this as a singleton so World.gd and CombatRoom.gd can both reach it.
## Four gauntlets of 2–3 combat rooms: two in the forest (split by the pond), then after the boss
## two on that boss's Huyana route (split by its non-combat room). One shuffled pool per half, so no
## combat room repeats within a half.

const HUYANA_ROOM_DIR := "res://scenes/rooms/huyana/"

var combat_room_scenes: Array[String] = [
	"res://scenes/rooms/combat_room_40x20.tscn",
	"res://scenes/rooms/combat_room_10x36t.tscn",
	"res://scenes/rooms/combat_room_14x35l.tscn",
	"res://scenes/rooms/combat_room_30x_60.tscn",
	"res://scenes/rooms/combat_room_54x_72_lt.tscn",
	"res://scenes/rooms/combat_room_50x70h.tscn"
]

const ROOMS_PER_GAUNTLET := Vector2i(2, 3) # TUNE: combat rooms before and after the non-combat room
const GAUNTLETS := 4
const FIRST_HUYANA_GAUNTLET := 2 # gauntlets from here on use the boss's route pool

const BASE_ROOM_WEIGHT := 2.0 # TUNE: enemy weight in the run's first combat room
const ROOM_WEIGHT_GROWTH := 0.1 # TUNE: weight added per combat room (fraction, compounding; up to 12 rooms a run)
const LOW_MUTANT_WEIGHT := 1.0 # TUNE: weight of one low mutant
const DEFORMED_HUMAN_WEIGHT := 0.2 # TUNE: weight of one deformed human

var first_room_path := "" # where the starting room's exit leads this run
var rests_used: Array[int] = [] # gauntlets whose non-combat heal spot has been used

var _remaining_pool: Array[String] = []
var _gauntlet_sizes: Array[int] = []
var _gauntlet := 0 # 0–1 forest (before / after the pond), 2–3 Huyana (before / after its non-combat room)
var _room_index := 0 # combat rooms entered in the current gauntlet (1 = first)


func _ready() -> void:
	start_new_run() # so a combat room played on its own still has a sequence


func start_new_run() -> void:
	_gauntlet = 0
	_remaining_pool = _half_pool()
	_gauntlet_sizes.clear()
	for i in GAUNTLETS:
		_gauntlet_sizes.append(randi_range(ROOMS_PER_GAUNTLET.x, ROOMS_PER_GAUNTLET.y))
	_room_index = 0
	rests_used.clear()
	first_room_path = pick_next_room_path()
	print("new run: gauntlets ", _gauntlet_sizes, ", first room ", first_room_path)


func save_state() -> Dictionary:
	return {
		"remaining_pool": _remaining_pool,
		"gauntlet_sizes": _gauntlet_sizes,
		"gauntlet": _gauntlet,
		"room_index": _room_index,
		"first_room_path": first_room_path,
		"rests_used": rests_used,
	}


func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_remaining_pool.assign(state.get("remaining_pool", []))
	_gauntlet_sizes.assign(state.get("gauntlet_sizes", []).map(func(n: float) -> int: return int(n)))
	_gauntlet = int(state.get("gauntlet", 0))
	_room_index = int(state.get("room_index", 0))
	first_room_path = state.get("first_room_path", "")
	rests_used.assign(state.get("rests_used", []).map(func(n: float) -> int: return int(n)))


## Called by non-combat rooms and the cleared boss room: the next combat room starts a new gauntlet.
## Crossing into Huyana swaps in the chosen boss's route pool.
func start_next_gauntlet() -> void:
	_gauntlet += 1
	_room_index = 0
	if _gauntlet == FIRST_HUYANA_GAUNTLET:
		_remaining_pool = _half_pool()


func in_huyana() -> bool:
	return _gauntlet >= FIRST_HUYANA_GAUNTLET


## A non-combat room's heal spot works once per visit to that gauntlet break.
func is_rest_used() -> bool:
	return _gauntlet in rests_used


func use_rest() -> void:
	if not is_rest_used():
		rests_used.append(_gauntlet)


## This half's combat rooms, shuffled: the forest, or the boss's route through Huyana.
func _half_pool() -> Array[String]:
	var pool: Array[String] = []
	if in_huyana():
		var dir := HUYANA_ROOM_DIR + CampaignState.chosen_boss.to_lower() + "/"
		for file in ResourceLoader.list_directory(dir):
			if file.ends_with(".tscn"):
				pool.append(dir + file)
	if pool.is_empty():
		pool = combat_room_scenes.duplicate()
	pool.shuffle()
	return pool


func has_more_rooms() -> bool:
	return _gauntlet < _gauntlet_sizes.size() and _room_index < _gauntlet_sizes[_gauntlet]


func pick_next_room_path() -> String:
	if _remaining_pool.is_empty():
		_remaining_pool = _half_pool()
	var path: String = _remaining_pool.pop_back()
	_room_index += 1
	print("picked room #", _room_index, " of gauntlet ", _gauntlet + 1, ": ", path)
	return path

## Combat rooms entered so far this run, counting this one (1 = first).
func combat_room_number() -> int:
	var number := _room_index
	for i in mini(_gauntlet, _gauntlet_sizes.size()):
		number += _gauntlet_sizes[i]
	return number


## This room's enemy weight budget; it grows by ROOM_WEIGHT_GROWTH each combat room.
func current_room_weight() -> float:
	return BASE_ROOM_WEIGHT * pow(1.0 + ROOM_WEIGHT_GROWTH, maxi(combat_room_number() - 1, 0))


## Rolls (low mutants, deformed humans) that exactly fill this room's weight, any mix.
func roll_room_mobs() -> Vector2i:
	var units := roundi(current_room_weight() / DEFORMED_HUMAN_WEIGHT)
	var units_per_low := roundi(LOW_MUTANT_WEIGHT / DEFORMED_HUMAN_WEIGHT)
	var low := randi_range(0, units / units_per_low)
	return Vector2i(low, units - low * units_per_low)
