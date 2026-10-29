class_name World
extends Node3D
## Holds the player and camera; swaps rooms when a path exit is entered; plays cutscenes.
## Starts from the save file if there is one, otherwise in whichever room is placed under Rooms.
## Autosaves on every room change. Room changes (e.g. collected loot) only persist for the current room.

@export var fade_time := 0.35 # TUNE: fade to/from black per room change (s)
@export var load_save_on_start := true # off: always start fresh in the placed room

@onready var player: Player = $Player
@onready var camera_rig: CameraRig = $CameraRig
@onready var rooms: Node3D = $Rooms
@onready var fade: ColorRect = $Transition/Fade
@onready var save_indicator: SaveIndicator = $SaveIndicator
@onready var skip_prompt: SkipPrompt = $SkipPrompt

var current_room: Room
var _transitioning := false
var _in_cutscene := false
var _cutscene: Cutscene
var _fade_tween: Tween
var _menu_paused := false
var _tree_was_paused := false
var _room_changes := {}


func _ready() -> void:
	skip_prompt.skip_requested.connect(func() -> void:
		if _cutscene:
			_cutscene.skip())
	var placed: Room
	for child in rooms.get_children():
		if child is Room:
			placed = child
			break
	var data := SaveSystem.load_data() if load_save_on_start else {}
	var saved_room: String = data.get("room", "")
	if saved_room != "" and ResourceLoader.exists(saved_room):
		if placed:
			rooms.remove_child(placed)
			placed.queue_free()
		_load_room(saved_room, &"", data.get("room_changes", {}))
		var pos: Variant = data.get("player_position")
		if pos is Array and pos.size() == 3:
			player.teleport(Vector3(pos[0], pos[1], pos[2]))
			camera_rig.snap_to_target()
	elif placed:
		_enter_room(placed, &"")


## Plays a cutscene scene (a Cutscene root) over everything, pausing gameplay.
## Callable from any trigger: story beats, room changes, first launch, etc.
func play_cutscene(path: String, fade_back_in := true) -> void:
	if _in_cutscene:
		return
	_in_cutscene = true
	var cutscene: Cutscene = (load(path) as PackedScene).instantiate()
	cutscene.process_mode = Node.PROCESS_MODE_ALWAYS
	if fade.color.a < 1.0:
		await _fade_to(1.0)
	get_tree().paused = true
	_cutscene = cutscene
	add_child(cutscene)
	skip_prompt.begin()
	await _fade_to(0.0)
	await cutscene.play()
	skip_prompt.end()
	await _fade_to(1.0)
	_cutscene = null
	cutscene.queue_free()
	get_tree().paused = false
	_in_cutscene = false
	if fade_back_in:
		await _fade_to(0.0)


## Pause menu freeze: stops gameplay, any running cutscene and any fade in progress.
func set_menu_paused(on: bool) -> void:
	if on == _menu_paused:
		return
	_menu_paused = on
	if on:
		_tree_was_paused = get_tree().paused
		get_tree().paused = true
		skip_prompt.frozen = true
		if _cutscene:
			_cutscene.process_mode = Node.PROCESS_MODE_DISABLED
		if _fade_tween and _fade_tween.is_running():
			_fade_tween.pause()
	else:
		skip_prompt.frozen = false
		if _cutscene:
			_cutscene.process_mode = Node.PROCESS_MODE_ALWAYS
		if _fade_tween and _fade_tween.is_valid():
			_fade_tween.play()
		get_tree().paused = _tree_was_paused


func can_save() -> bool:
	return not _transitioning and not _in_cutscene # hero side: also false inside combat rooms until cleared


func can_view_stats() -> bool:
	return false # per game half; false during cutscenes


func save_game(show_indicator := true) -> void:
	var pos := player.global_position
	SaveSystem.save_data({
		"version": 1,
		"room": current_room.scene_file_path,
		"player_position": [pos.x, pos.y, pos.z],
		"room_changes": _room_changes,
	})
	if show_indicator:
		save_indicator.flash()


func _on_exit_requested(target_room: String, target_entry: StringName, exit_direction: Vector3, cutscene: String) -> void:
	if _transitioning or _in_cutscene:
		return
	_transitioning = true
	player.input_enabled = false
	player.forced_input = Vector2(exit_direction.x, exit_direction.z)
	await _fade_to(1.0)
	_load_room(target_room, target_entry)
	save_game()
	if cutscene != "":
		await play_cutscene(cutscene, false)
	await _fade_to(0.0)
	player.forced_input = Vector2.ZERO
	player.input_enabled = true
	_transitioning = false


func _load_room(path: String, entry: StringName, changes := {}) -> void:
	if current_room:
		rooms.remove_child(current_room)
		current_room.queue_free()
	var room: Room = (load(path) as PackedScene).instantiate()

	if room is CombatRoom:
		var ranges: Array = CombatRunState.get_spawn_ranges_for_current_room()
		room.configure_spawns(ranges[0], ranges[1])

	rooms.add_child(room)
	_enter_room(room, entry, changes)


func _enter_room(room: Room, entry: StringName, changes := {}) -> void:
	current_room = room
	current_room.exit_requested.connect(_on_exit_requested)
	_apply_room_changes(changes)

	var exit := current_room.get_exit(entry)
	if exit:
		player.teleport(exit.spawn_point.global_position)
		var inward := -exit.outward_direction()
		player.forced_input = Vector2(inward.x, inward.z)
	else:
		player.teleport(current_room.get_start_position())
	camera_rig.snap_to_target()


func _apply_room_changes(changes: Dictionary) -> void:
	_room_changes = {"collected": []}
	var collected: Array = changes.get("collected", [])
	for path: String in collected:
		var node := current_room.get_node_or_null(NodePath(path))
		if node:
			node.queue_free()
			_room_changes.collected.append(path)
	for node in current_room.find_children("*", "", true, false):
		if node is LootPickup and not node.is_queued_for_deletion():
			var path := String(current_room.get_path_to(node))
			node.collected.connect(func(_id: StringName) -> void:
				_room_changes.collected.append(path))


func _fade_to(alpha: float) -> void:
	_fade_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.tween_property(fade, "color:a", alpha, fade_time)
	await _fade_tween.finished
