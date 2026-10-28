@tool
class_name BeatBubble
extends Control
## Speech bubble with an ellipsis, shown over the campfire when a narrative beat is waiting.
## The tip points down at the fire, and scaling pivots on it.

const SIZE := Vector2(84, 104)


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = Vector2(SIZE.x / 2.0, SIZE.y)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center := Vector2(SIZE.x / 2.0, 50.0)
	var radius := 30.0
	var tip := PackedVector2Array([center + Vector2(-10, radius - 2), center + Vector2(0, radius + 18), center + Vector2(10, radius - 2)])
	draw_circle(center, radius + 7.0, RequestView.OUTLINE)
	draw_colored_polygon(tip, RequestView.OUTLINE)
	draw_colored_polygon(PackedVector2Array([tip[0] + Vector2(3, -1), tip[1] + Vector2(0, -5), tip[2] + Vector2(-3, -1)]), RequestView.BACKGROUND)
	draw_circle(center, radius + 4.5, RequestView.BACKGROUND)
	for i in 3:
		draw_circle(center + Vector2((i - 1) * 14.0, 0.0), 5.0, RequestView.GOLD.darkened(0.2))
