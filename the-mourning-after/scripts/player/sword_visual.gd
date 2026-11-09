@tool
class_name SwordVisual
extends Node3D
## Placeholder sword: points the way Perrin attacks and sweeps across the swing.

@export var rest_angle := 35.0 # TUNE: how far the sword rests off the facing direction (degrees)
@export var swing_arc := 120.0 # TUNE: total sweep of a swing (degrees)
@export var colors := { # TUNE: blade tint per weapon name
	"Wood Sword": Color(0.55, 0.38, 0.2),
	"Bone Sword": Color(0.9, 0.87, 0.78),
	"Bronze Sword": Color(0.8, 0.5, 0.2),
	"Iron Sword": Color(0.65, 0.67, 0.72),
}

var _facing_angle := 0.0
var _swing_offset := 0.0
var _swing: Tween
var _material: StandardMaterial3D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", false, false):
		if _material == null:
			_material = mesh.get_active_material(0).duplicate()
		mesh.material_override = _material


func set_weapon(weapon: WeaponData) -> void:
	visible = weapon != null
	if weapon and _material:
		_material.albedo_color = colors.get(weapon.weapon_name, Color.WHITE)


## facing: the attack direction on the floor (x, z).
func point(facing: Vector2) -> void:
	_facing_angle = -atan2(facing.y, facing.x)
	_apply()


func swing(duration: float) -> void:
	if _swing:
		_swing.kill()
	var half := deg_to_rad(swing_arc / 2.0)
	_swing = create_tween()
	_swing.tween_method(_set_swing_offset, half, -half, duration)
	_swing.tween_method(_set_swing_offset, -half, deg_to_rad(rest_angle), 0.15)


func _set_swing_offset(value: float) -> void:
	_swing_offset = value
	_apply()


func _apply() -> void:
	var offset := _swing_offset if _swing and _swing.is_running() else deg_to_rad(rest_angle)
	rotation.y = _facing_angle + offset
