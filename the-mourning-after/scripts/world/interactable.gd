@tool
class_name Interactable
extends Area3D
## Shows the interact prompt when the player is in range.
## Lines set: narration text box. Conversation set: talk with overlay and portraits.
## Neither set: instant action (listen for `interacted`).

signal interacted
signal finished

@export var prompt_label := "Interact"
@export var enabled := true
@export var interact_radius := 2.2: # TUNE: distance at which the prompt appears (m)
	set(value):
		interact_radius = value
		_apply_radius()

@export_group("Narration")
@export var lines: PackedStringArray = []

@export_group("Conversation")
@export var character_name := ""
@export var character_portrait: Texture2D # placeholder until portraits exist
@export var character_portrait_tint := Color.WHITE
@export var conversation: Array[DialogueLine] = []

var player_in_range := false
var player: Player


func _ready() -> void:
	_apply_radius()
	if Engine.is_editor_hint():
		return
	add_to_group(&"interactable")
	body_entered.connect(func(body: Node3D) -> void:
		if body is Player:
			player_in_range = true
			player = body)
	body_exited.connect(func(body: Node3D) -> void:
		if body is Player:
			player_in_range = false)


func is_conversation() -> bool:
	return not conversation.is_empty()


func page_count() -> int:
	return conversation.size() if is_conversation() else lines.size()


func _apply_radius() -> void:
	var shape_node := get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	if shape_node == null:
		return
	var cylinder := shape_node.shape as CylinderShape3D
	if cylinder and not is_equal_approx(cylinder.radius, interact_radius):
		cylinder.radius = interact_radius
