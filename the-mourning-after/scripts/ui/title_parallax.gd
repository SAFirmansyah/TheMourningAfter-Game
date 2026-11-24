@tool
class_name TitleParallax
extends Control
## Title screen backdrop: the paper background with the vines over its corners. Each child layer
## drifts against the cursor by its own depth, so the vines move more than the paper.
## A layer's depth is its "parallax_depth" metadata (px of drift at the screen edge; 0 = still).
## Layers are drawn slightly past the screen edges so drifting never shows a gap.

@export var smoothing := 6.0 # TUNE: how quickly the layers follow the cursor (higher = snappier)

var _shift := Vector2.ZERO # -1..1 per axis: where the cursor is relative to the centre
var _rest := {} # layer -> its laid-out position


func _ready() -> void:
	resized.connect(_remember_layout)
	_remember_layout.call_deferred()


func _remember_layout() -> void:
	for layer: Control in _layers():
		layer.position -= _offset_of(layer) # back to its rest spot before re-reading it
		_rest[layer] = layer.position
		layer.position += _offset_of(layer)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_visible_in_tree():
		return
	var half := size / 2.0
	var target := Vector2.ZERO
	if half.x > 0.0 and half.y > 0.0:
		target = ((get_local_mouse_position() - half) / half).clamp(-Vector2.ONE, Vector2.ONE)
	_shift = _shift.lerp(target, 1.0 - exp(-smoothing * delta))
	for layer: Control in _layers():
		if _rest.has(layer):
			layer.position = _rest[layer] + _offset_of(layer)


func _offset_of(layer: Control) -> Vector2:
	return -_shift * float(layer.get_meta(&"parallax_depth", 0.0))


func _layers() -> Array[Control]:
	var result: Array[Control] = []
	for child in get_children():
		if child is Control:
			result.append(child)
	return result
