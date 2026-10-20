@tool
class_name Interactable
extends Area3D
## Shows the interact prompt when the player is in range; pressing interact reads out its lines.
## One line = single text box. More lines = pages advanced with LMB.

signal interacted
signal finished

@export var prompt_label := "Interact"
@export var lines: PackedStringArray = ["Sample text."]
@export var interact_radius := 2.2: # TUNE: distance at which the prompt appears (m)
	set(value):
		interact_radius = value
		_apply_radius()

var player_in_range := false


func _ready() -> void:
	_apply_radius()
	if Engine.is_editor_hint():
		return
	add_to_group(&"interactable")
	body_entered.connect(func(body: Node3D) -> void:
		if body is Player:
			player_in_range = true)
	body_exited.connect(func(body: Node3D) -> void:
		if body is Player:
			player_in_range = false)


func _apply_radius() -> void:
	var shape_node := get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	if shape_node == null:
		return
	var cylinder := shape_node.shape as CylinderShape3D
	if cylinder and not is_equal_approx(cylinder.radius, interact_radius):
		cylinder.radius = interact_radius
