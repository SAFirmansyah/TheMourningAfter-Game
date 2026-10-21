@tool
class_name Obstacle
extends StaticBody3D
## Environment object that blocks movement. Dashes pass through it.
## Collision box auto-fits the card's width while this object's own scene is open in the editor.

const BOX_HEIGHT := 2.0

@export var card: Sprite3D
@export var footprint_depth := 0.6 # TUNE: collision depth, front to back (m)
@export var footprint_width_scale := 1.0 # TUNE: collision width as a fraction of the card's width

@onready var _shape_node: CollisionShape3D = $CollisionShape3D


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and get_tree().edited_scene_root == self:
		_fit_collision()


func _fit_collision() -> void:
	if card == null or card.texture == null or _shape_node == null:
		return
	var box := _shape_node.shape as BoxShape3D
	if box == null:
		box = BoxShape3D.new()
		_shape_node.shape = box
	var frame_w: float = card.region_rect.size.x if card.region_enabled else card.texture.get_width() / float(card.hframes)
	var width := frame_w * card.pixel_size * absf(card.scale.x) * footprint_width_scale
	var size := Vector3(width, BOX_HEIGHT, footprint_depth)
	var pos := Vector3(card.position.x, BOX_HEIGHT / 2.0, card.position.z)
	if not box.size.is_equal_approx(size):
		box.size = size
	if not _shape_node.position.is_equal_approx(pos):
		_shape_node.position = pos
