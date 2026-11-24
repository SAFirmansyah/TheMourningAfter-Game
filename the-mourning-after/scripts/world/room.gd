class_name Room
extends Node3D
## One room. Forwards its path exits to the world.

signal exit_requested(target_room: String, target_entry: StringName, exit_direction: Vector3, cutscene: String)

@export var ground_tint := Color.WHITE

var restoring := false # set by the world before adding a room loaded from the save file


func _ready() -> void:
	for floor_mesh: MeshInstance3D in find_children("Floor*", "MeshInstance3D", true, false):
		floor_mesh.set_instance_shader_parameter("tint", ground_tint)
	var floor_material := _floor_material()
	for exit in get_exits():
		exit.path_mesh.set_instance_shader_parameter("tint", ground_tint)
		_match_path(exit, floor_material)
		exit.player_entered.connect(func() -> void:
			exit_requested.emit(exit.target_room, exit.target_entry, exit.outward_direction(), exit.cutscene))


## The room's ground material (its first Floor mesh), so paths can wear the same stone.
func _floor_material() -> ShaderMaterial:
	for floor_mesh: MeshInstance3D in find_children("Floor*", "MeshInstance3D", true, false):
		var material := floor_mesh.get_active_material(0) as ShaderMaterial
		if material:
			return material
	return null


## A path leaving this room shows the same stone, at the same strength, as this room's floor.
func _match_path(exit: PathExit, floor_material: ShaderMaterial) -> void:
	var path_material := exit.path_mesh.get_active_material(0) as ShaderMaterial
	if floor_material == null or path_material == null:
		return
	path_material = path_material.duplicate()
	for param: StringName in [&"albedo_texture", &"world_uv_scale", &"stone_strength"]:
		var value: Variant = floor_material.get_shader_parameter(param)
		if value != null:
			path_material.set_shader_parameter(param, value)
	exit.path_mesh.material_override = path_material


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


## Saving (manual or quit) is allowed here; combat rooms say no until cleared.
func allows_saving() -> bool:
	return true


func get_start_position() -> Vector3:
	return $PlayerStart.global_position
