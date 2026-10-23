class_name Hitbox
extends Area3D
# Reusable melee hitbox.

signal hit_landed(body: Node3D)

@export var ignore_root: Node3D # so they can't hit themselves

var _active := false
var _already_hit: Array[Node3D] = []

@onready var _shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	monitoring = false
	monitorable = false
	_shape.disabled = true
	body_entered.connect(_on_body_entered)


func activate() -> void:
	_already_hit.clear()
	_active = true
	monitoring = true
	_shape.disabled = false


func deactivate() -> void:
	_active = false
	monitoring = false
	_shape.disabled = true


func _on_body_entered(body: Node3D) -> void:
	if not _active:
		return
	if body == ignore_root or body in _already_hit:
		return
	if ignore_root and body.is_ancestor_of(ignore_root):
		return
	_already_hit.append(body)
	hit_landed.emit(body)
