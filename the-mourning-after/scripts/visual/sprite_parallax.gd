class_name SpriteParallax
extends Node
## Characters in the world drift a touch against the cursor (like the dialogue portraits), so the
## flat cards read as standing in front of the room. Mild: a few centimetres.

@export var depth := 0.08 # TUNE: drift at the screen edge (m)
@export var smoothing := 5.0 # TUNE: how quickly cards follow the cursor

var _shift := Vector2.ZERO


func _process(delta: float) -> void:
	var view := get_viewport().get_visible_rect().size
	var cam := get_viewport().get_camera_3d()
	if cam == null or view.x <= 0.0:
		return
	var cursor := ((get_viewport().get_mouse_position() - view / 2.0) / (view / 2.0)).clamp(-Vector2.ONE, Vector2.ONE)
	_shift = _shift.lerp(-cursor * depth, 1.0 - exp(-smoothing * delta))
	var offset := cam.global_basis.x * _shift.x - cam.global_basis.y * _shift.y
	for body: Node in get_tree().get_nodes_in_group(&"player") + get_tree().get_nodes_in_group(&"enemies") + get_tree().get_nodes_in_group(&"parallax_character"):
		var card := body.get_node_or_null(^"Card") as Node3D
		if card == null:
			continue
		if not card.has_meta(&"parallax_home"):
			card.set_meta(&"parallax_home", card.position)
		card.position = card.get_meta(&"parallax_home") + (body as Node3D).global_basis.inverse() * offset
