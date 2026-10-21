class_name World
extends Node3D
## Holds the player and camera; swaps rooms when a path exit is entered; plays cutscenes.
## Starts in whichever room is placed under Rooms.

@export var fade_time := 0.35 # TUNE: fade to/from black per room change (s)

@onready var player: Player = $Player
@onready var camera_rig: CameraRig = $CameraRig
@onready var rooms: Node3D = $Rooms
@onready var fade: ColorRect = $Transition/Fade

var current_room: Room
var _transitioning := false
var _in_cutscene := false


func _ready() -> void:
	for child in rooms.get_children():
		if child is Room:
			_enter_room(child, &"")
			return


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
	add_child(cutscene)
	await _fade_to(0.0)
	await cutscene.play()
	await _fade_to(1.0)
	cutscene.queue_free()
	get_tree().paused = false
	_in_cutscene = false
	if fade_back_in:
		await _fade_to(0.0)


func _on_exit_requested(target_room: String, target_entry: StringName, exit_direction: Vector3, cutscene: String) -> void:
	if _transitioning or _in_cutscene:
		return
	_transitioning = true
	player.input_enabled = false
	player.forced_input = Vector2(exit_direction.x, exit_direction.z)
	await _fade_to(1.0)
	_load_room(target_room, target_entry)
	if cutscene != "":
		await play_cutscene(cutscene, false)
	await _fade_to(0.0)
	player.forced_input = Vector2.ZERO
	player.input_enabled = true
	_transitioning = false


func _load_room(path: String, entry: StringName) -> void:
	if current_room:
		rooms.remove_child(current_room)
		current_room.queue_free()
	var room: Room = (load(path) as PackedScene).instantiate()
	rooms.add_child(room)
	_enter_room(room, entry)


func _enter_room(room: Room, entry: StringName) -> void:
	current_room = room
	current_room.exit_requested.connect(_on_exit_requested)

	var exit := current_room.get_exit(entry)
	if exit:
		player.teleport(exit.spawn_point.global_position)
		var inward := -exit.outward_direction()
		player.forced_input = Vector2(inward.x, inward.z)
	else:
		player.teleport(current_room.get_start_position())
	camera_rig.snap_to_target()


func _fade_to(alpha: float) -> void:
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(fade, "color:a", alpha, fade_time)
	await tween.finished
