@tool
class_name BubbleTip
extends Control
## Downward speech-bubble tip drawn under a menu panel.

const BACKGROUND := Color(0.94, 0.92, 0.87, 0.97)
const OUTLINE := Color(0.12, 0.11, 0.1)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w / 2.0, h), Vector2(w, 0)]), OUTLINE)
	draw_colored_polygon(PackedVector2Array([Vector2(4, 0), Vector2(w / 2.0, h - 5), Vector2(w - 4, 0)]), BACKGROUND)
