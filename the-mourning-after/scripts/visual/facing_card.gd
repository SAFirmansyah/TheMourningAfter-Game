@tool
class_name FacingCard
extends Sprite3D
## 2D card that turns to face the active camera's position, pivoting at its feet.

const CARD_MATERIAL := preload("res://materials/card.tres")
const SHADOW_MATERIAL := preload("res://materials/card_shadow.tres")

@export var pivot_at_feet := true
@export var turn_sideways := true # off: only tilts toward the camera, never turns left/right (wall facades)
@export var see_through_over_player := false: # environment props: turn see-through where they cover the player
	set(value):
		see_through_over_player = value
		_setup_material()
@export var sway := false: # foliage-style wind sway
	set(value):
		sway = value
		_setup_material()
@export var casts_shadow := true: # sun shadow on the ground, driven by the day cycle
	set(value):
		casts_shadow = value
		_setup_shadow()

var visual_offset := Vector3.ZERO # editor preview only: extra offset for animated cards

var _card_material: ShaderMaterial
var _shadow: MeshInstance3D


func _ready() -> void:
	process_physics_priority = 20 # after camera rig
	billboard = BaseMaterial3D.BILLBOARD_DISABLED
	texture_changed.connect(_on_texture_changed)
	_apply_pivot()
	_setup_material()
	_setup_shadow()


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
		RenderingServer.instance_set_transform(get_instance(), Transform3D(_facing_basis(cam), global_position + visual_offset))


func _facing_basis(cam: Camera3D) -> Basis:
	var away := global_position - cam.global_position
	if not turn_sideways:
		var right := get_parent_node_3d().global_basis.x.normalized() if get_parent_node_3d() else Vector3.RIGHT
		away -= right * away.dot(right)
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
	_sync_card_material()
	_setup_shadow()


## Internal child (never saved into scenes), so it also previews in the editor.
func _setup_shadow() -> void:
	if not is_node_ready():
		return
	if not casts_shadow or texture == null:
		if _shadow:
			_shadow.queue_free()
			_shadow = null
		return
	if _shadow == null:
		_shadow = MeshInstance3D.new()
		_shadow.mesh = QuadMesh.new()
		_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_shadow.extra_cull_margin = 16.0
		_shadow.material_override = SHADOW_MATERIAL.duplicate()
		add_child(_shadow, false, Node.INTERNAL_MODE_FRONT)
	var frame := region_rect.size if region_enabled else Vector2(texture.get_width() / float(hframes), texture.get_height() / float(vframes))
	var material := _shadow.material_override as ShaderMaterial
	material.set_shader_parameter("card_texture", texture)
	material.set_shader_parameter("card_size", frame * pixel_size * Vector2(absf(scale.x), absf(scale.y)))


## Custom card material only when a feature needs it. In the editor it's applied through the
## renderer so previews never get saved into scenes; the player cutout is game-only.
func _setup_material() -> void:
	if not is_node_ready():
		return
	var editor := Engine.is_editor_hint()
	if not (see_through_over_player or sway):
		_card_material = null
		if editor:
			RenderingServer.instance_geometry_set_material_override(get_instance(), RID())
		else:
			material_override = null
		return
	if _card_material == null:
		_card_material = CARD_MATERIAL.duplicate()
	_card_material.set_shader_parameter("occlusion_enabled", see_through_over_player and not editor)
	_card_material.set_shader_parameter("sway_enabled", sway)
	_sync_card_material()
	if editor:
		RenderingServer.instance_geometry_set_material_override(get_instance(), _card_material.get_rid())
	else:
		material_override = _card_material


func _sync_card_material() -> void:
	if _card_material:
		_card_material.set_shader_parameter("card_texture", texture)
		_card_material.set_shader_parameter("card_texture_pixel", texture)
		_card_material.set_shader_parameter("pixel_art", texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST)
		_card_material.set_shader_parameter("card_modulate", modulate)


## Tint the card (e.g. dimmed while a station is busy); works with or without the card material.
func set_tint(color: Color) -> void:
	modulate = color
	_sync_card_material()


func _apply_pivot() -> void:
	if not pivot_at_feet or texture == null:
		return
	var frame_h: float = region_rect.size.y if region_enabled else texture.get_height() / float(vframes)
	centered = true
	offset.y = frame_h / 2.0
