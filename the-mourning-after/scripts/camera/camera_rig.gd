@tool
class_name CameraRig
extends Node3D
## Locked perspective follow camera.

@export var follow_target: Node3D

@export var pitch_deg := 25.0: # TUNE: camera tilt, degrees down from horizontal
	set(value):
		pitch_deg = value
		_apply_view()
@export var fov_deg := 30.0: # TUNE: vertical field of view; lower = flatter perspective
	set(value):
		fov_deg = value
		_apply_view()
@export var distance := 26.0: # TUNE: zoom, camera distance from focus point (m)
	set(value):
		distance = value
		_apply_view()
@export var focus_offset := Vector3(0.0, 0.8, 0.0) # TUNE: focus point relative to target's feet
@export var follow_smoothing := 8.0 # TUNE: follow tightness; 0 = rigid

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	process_physics_priority = 10 # after player movement
	process_priority = -10 # editor preview: before cards
	_apply_view()
	if not Engine.is_editor_hint():
		snap_to_target()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or follow_target == null:
		return
	var goal := _focus_point()
	if follow_smoothing > 0.0:
		global_position = global_position.lerp(goal, 1.0 - exp(-follow_smoothing * delta))
	else:
		global_position = goal


func _process(_delta: float) -> void:
	# Editor preview: stay framed on the target.
	if Engine.is_editor_hint() and follow_target and not global_position.is_equal_approx(_focus_point()):
		global_position = _focus_point()


func snap_to_target() -> void:
	if follow_target == null:
		return
	global_position = _focus_point()
	reset_physics_interpolation()


func _focus_point() -> Vector3:
	return follow_target.global_position + focus_offset


func _apply_view() -> void:
	if camera == null:
		return
	rotation_degrees = Vector3(-pitch_deg, 0.0, 0.0)
	camera.position = Vector3(0.0, 0.0, distance)
	camera.rotation = Vector3.ZERO
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = fov_deg
