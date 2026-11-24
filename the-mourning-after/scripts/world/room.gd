class_name Room
extends Node3D
## One room. Forwards its path exits to the world.

signal exit_requested(target_room: String, target_entry: StringName, exit_direction: Vector3, cutscene: String)

@export var ground_tint := Color.WHITE
@export_group("Mood")
@export var static_shadows := false # indoors: shadows hold one direction instead of following the sun
@export var shadow_dir := Vector2(-0.6, -0.8) # TUNE: static shadow direction (screen-ish x, z)
@export var shadow_length := 0.9 # TUNE: static shadow length
@export var shadow_alpha := 0.35 # TUNE: static shadow darkness
@export var mood_tint := Color.WHITE # TUNE: colour cast over the whole room (eerie rooms)
@export_range(0.3, 1.2) var mood_brightness := 1.0 # TUNE: overall brightness in this room
@export_range(0.0, 1.0) var mood_vignette := 0.3 # TUNE: edge darkening in this room
@export_group("")

var restoring := false # set by the world before adding a room loaded from the save file


func _ready() -> void:
	process_priority = 10 # after the day cycle
	for floor_mesh: MeshInstance3D in find_children("Floor*", "MeshInstance3D", true, false):
		floor_mesh.set_instance_shader_parameter("tint", ground_tint)
	_solidify_back_wall_props()
	var floor_material := _floor_material()
	for exit in get_exits():
		exit.path_mesh.set_instance_shader_parameter("tint", ground_tint)
		_match_path(exit, floor_material)
		exit.player_entered.connect(func() -> void:
			exit_requested.emit(exit.target_room, exit.target_entry, exit.outward_direction(), exit.cutscene))


## Props standing against the back (north) wall block dashes too, like walls: dashing through them
## would carry the player past the wall. Other props stay dash-through.
@export var back_wall_band := 1.6 # TUNE: how close to the back wall a prop counts as against it (m)

func _solidify_back_wall_props() -> void:
	var back := INF
	for floor_mesh: MeshInstance3D in find_children("Floor*", "MeshInstance3D", true, false):
		back = minf(back, (floor_mesh.global_transform * floor_mesh.get_aabb()).position.z)
	if back == INF:
		return
	for body in find_children("*", "StaticBody3D", true, false):
		var prop := body as StaticBody3D
		if prop is not NPC and prop.collision_layer & 2 and prop.global_position.z < back + back_wall_band:
			prop.collision_layer = 1 # the walls' layer: dashes don't pass it


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
	for param: StringName in [&"albedo_texture", &"world_uv_scale", &"stone_strength", &"carpet"]:
		var value: Variant = floor_material.get_shader_parameter(param)
		if value != null:
			path_material.set_shader_parameter(param, value)
	exit.path_mesh.material_override = path_material


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if static_shadows: # set after the day cycle's sun each frame
		RenderingServer.global_shader_parameter_set(&"sun_shadow_dir", shadow_dir.normalized())
		RenderingServer.global_shader_parameter_set(&"sun_shadow_length", shadow_length)
		RenderingServer.global_shader_parameter_set(&"sun_shadow_alpha", shadow_alpha)
	for shade in get_tree().get_nodes_in_group(&"atmosphere_shade"):
		var material := (shade as CanvasItem).material as ShaderMaterial
		material.set_shader_parameter("room_tint", Vector3(mood_tint.r, mood_tint.g, mood_tint.b))
		material.set_shader_parameter("room_brightness", mood_brightness)
		material.set_shader_parameter("vignette", mood_vignette)


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
