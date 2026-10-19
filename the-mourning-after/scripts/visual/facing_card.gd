@tool
class_name FacingCard
extends Sprite3D
## 2D card that turns to face the active camera's position, pivoting at its feet.

const OCCLUDER_MATERIAL := preload("res://materials/card_occluder.tres")

@export var pivot_at_feet := true
@export var see_through_over_player := false # environment props: turn see-through where they cover the player


func _ready() -> void:
	process_physics_priority = 20 # after camera rig
	billboard = BaseMaterial3D.BILLBOARD_DISABLED
	texture_changed.connect(_on_texture_changed)
	_apply_pivot()
	if see_through_over_player and not Engine.is_editor_hint():
		material_override = OCCLUDER_MATERIAL.duplicate()
		_sync_occluder_texture()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var cam := get_viewport().get_camera_3d()
	if cam:
		global_basis = _facing_basis(cam)


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	# Editor preview: visual only, saved rotation untouched.
	var cam := _editor_camera()
	if cam:
		RenderingServer.instance_set_transform(get_instance(), Transform3D(_facing_basis(cam), global_position))


func _facing_basis(cam: Camera3D) -> Basis:
	var away := global_position - cam.global_position
	if away.length_squared() < 0.0001:
		return global_basis
	return Basis.looking_at(away, cam.global_basis.y).scaled(global_basis.get_scale())


func _editor_camera() -> Camera3D:
	var game_cam := get_tree().get_first_node_in_group(&"game_camera") as Camera3D
	if game_cam:
		return game_cam
	var editor := Engine.get_singleton(&"EditorInterface")
	if editor == null:
		return null
	return editor.get_editor_viewport_3d(0).get_camera_3d()


func _on_texture_changed() -> void:
	_apply_pivot()
	_sync_occluder_texture()


func _sync_occluder_texture() -> void:
	if material_override is ShaderMaterial:
		material_override.set_shader_parameter("card_texture", texture)
		material_override.set_shader_parameter("card_modulate", modulate)


func _apply_pivot() -> void:
	if not pivot_at_feet or texture == null:
		return
	var frame_h: float = region_rect.size.y if region_enabled else texture.get_height() / float(vframes)
	centered = true
	offset.y = frame_h / 2.0
