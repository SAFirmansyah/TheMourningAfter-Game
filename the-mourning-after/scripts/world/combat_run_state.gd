extends Node
## Tracks progress through the randomized combat-room sequence for the current run.
## Autoload this as a singleton so World.gd and CombatRoom.gd can both reach it.

var combat_room_scenes: Array[String] = [
	"res://scenes/rooms/combat_room_24x20.tscn",
	#"res://scenes/rooms/combat_room_small_2.tscn",
	#"res://scenes/rooms/combat_room_big_1.tscn",
	#"res://scenes/rooms/combat_room_big_2.tscn",
	#"res://scenes/rooms/combat_room_small_3.tscn",
	#"res://scenes/rooms/combat_room_big_3.tscn",
]

var _remaining_pool: Array[String] = []
var _room_index := 0 # 0 = first combat room this run, 1 = second, etc.

const TOTAL_ROOMS_RANGE := Vector2i(2, 3) # TUNE: 2 or 3 combat rooms per run
var _total_rooms := 2


func start_new_run() -> void:
	_remaining_pool = combat_room_scenes.duplicate()
	_remaining_pool.shuffle()
	_room_index = 0
	_total_rooms = randi_range(TOTAL_ROOMS_RANGE.x, TOTAL_ROOMS_RANGE.y)


func has_more_rooms() -> bool:
	return _room_index < _total_rooms


func pick_next_room_path() -> String:
	if _remaining_pool.is_empty():
		_remaining_pool = combat_room_scenes.duplicate()
		_remaining_pool.shuffle()
	var path: String = _remaining_pool.pop_back()
	_room_index += 1
	return path


## Returns (low_mutant_range, big_mutant_range) for whichever room position we're on.
func get_spawn_ranges_for_current_room() -> Array:
	match _room_index:
		1:
			return [Vector2i(3, 5), Vector2i(0, 0)] # room 1: low mutants only
		2:
			return [Vector2i(3, 5), Vector2i(1, 2)] # room 2: low + a couple big
		_:
			return [Vector2i(2, 4), Vector2i(2, 3)] # room 3+: heavier big mutant presence
			
