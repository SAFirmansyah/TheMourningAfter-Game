@tool
class_name GuideArrow
extends Control
## Tutorial pointer: a gold arrow whose tip sits at the control's pivot. Points down by default;
## rotate it to point elsewhere.

const SIZE := Vector2(56, 72)
const FILL := Color(0.95, 0.78, 0.35)
const OUTLINE := Color(0.12, 0.11, 0.1)


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = Vector2(SIZE.x / 2.0, SIZE.y)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w := SIZE.x
	var h := SIZE.y
	var shape := PackedVector2Array([
		Vector2(w * 0.32, 0), Vector2(w * 0.68, 0), Vector2(w * 0.68, h * 0.45), Vector2(w, h * 0.45),
		Vector2(w / 2.0, h), Vector2(0, h * 0.45), Vector2(w * 0.32, h * 0.45)])
	draw_colored_polygon(shape, FILL)
	shape.append(shape[0])
	draw_polyline(shape, OUTLINE, 3.0, true)
