class_name World
extends Node3D
## Holds the player and camera; swaps rooms when a path exit is entered.
## Starts in whichever room is placed under Rooms.

@export var fade_time := 0.35 # TUNE: fade to/from black per room change (s)

@onready var player: Player = $Player
@onready var camera_rig: CameraRig = $CameraRig
@onready var rooms: Node3D = $Rooms
@onready var fade: ColorRect = $Transition/Fade

var current_room: Room
var _transitioning := false


func _ready() -> void:
	for child in rooms.get_children():
		if child is Room:
			_enter_room(child, &"")
			return


func _on_exit_requested(target_room: String, target_entry: StringName, exit_direction: Vector3) -> void:
	if _transitioning:
		return
	_transitioning = true
	player.input_enabled = false
	player.forced_input = Vector2(exit_direction.x, exit_direction.z)
	await _fade_to(1.0)
	_load_room(target_room, target_entry)
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
	var tween := create_tween()
	tween.tween_property(fade, "color:a", alpha, fade_time)
	await tween.finished
