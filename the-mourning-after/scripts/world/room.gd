class_name Room
extends Node3D
## One room. Forwards its path exits to the world.

signal exit_requested(target_room: String, target_entry: StringName, exit_direction: Vector3, cutscene: String)

@export var ground_tint := Color.WHITE


func _ready() -> void:
	var floor_mesh := find_child("Floor", true, false) as MeshInstance3D
	if floor_mesh:
		floor_mesh.set_instance_shader_parameter("tint", ground_tint)
	for exit in get_exits():
		exit.path_mesh.set_instance_shader_parameter("tint", ground_tint)
		exit.player_entered.connect(func() -> void:
			exit_requested.emit(exit.target_room, exit.target_entry, exit.outward_direction(), exit.cutscene))


func get_exits() -> Array[PathExit]:
	var exits: Array[PathExit] = []
	for node in find_children("*", "", true, false):
		if node is PathExit:
			exits.append(node)
	return exits


func get_exit(exit_name: StringName) -> PathExit:
	for exit in get_exits():
		if exit.name == exit_name:
			return exit
	return null


func get_start_position() -> Vector3:
	return $PlayerStart.global_position
