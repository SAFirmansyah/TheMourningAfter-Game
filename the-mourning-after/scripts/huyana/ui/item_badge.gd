@tool
class_name ItemBadge
extends Control
## Round badge for order menus: an item icon (or a short label like a containment number),
## an optional checkmark, stock count and caption.

const BACKGROUND := Color(0.97, 0.95, 0.9)
const OUTLINE := Color(0.12, 0.11, 0.1)
const CHECK := Color(0.3, 0.75, 0.35)

@export var item: StringName = &"infused_dew":
	set(value):
		item = value
		queue_redraw()
@export var label_text := "": # shown instead of the icon when set
	set(value):
		label_text = value
		queue_redraw()
@export var diameter := 56.0:
	set(value):
		diameter = value
		_resize()
@export var show_check := false:
	set(value):
		show_check = value
		queue_redraw()
@export var count := -1: # stock count shown as a small tag; -1 hides it
	set(value):
		count = value
		queue_redraw()
@export var caption := "":
	set(value):
		caption = value
		_resize()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resize()


func _resize() -> void:
	custom_minimum_size = Vector2(maxf(diameter + 12.0, 96.0 if caption != "" else 0.0), diameter + (24.0 if caption != "" else 6.0))
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var center := Vector2(size.x / 2.0, diameter / 2.0 + 3.0)
	var radius := diameter / 2.0
	draw_circle(center, radius, OUTLINE)
	draw_circle(center, radius - 3.0, BACKGROUND)
	if label_text != "":
		var font_size := int(diameter * 0.5)
		var width := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, center + Vector2(-width / 2.0, font_size * 0.35), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, OUTLINE)
	else:
		RequestCatalog.draw_icon(self, item, center, radius * 0.5)
	if show_check:
		var at := center + Vector2(radius * 0.72, -radius * 0.72)
		draw_circle(at, 11.0, CHECK)
		draw_polyline(PackedVector2Array([at + Vector2(-6, 0), at + Vector2(-2, 5), at + Vector2(6, -5)]), Color.WHITE, 3.0, true)
	if count >= 0:
		var tag := "x%d" % count
		var tag_width := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 10.0
		var tag_rect := Rect2(center + Vector2(radius * 0.45, radius * 0.35), Vector2(tag_width, 20))
		draw_rect(tag_rect, OUTLINE)
		draw_string(font, tag_rect.position + Vector2(5, 15), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, BACKGROUND)
	if caption != "":
		var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(font, Vector2((size.x - width) / 2.0, diameter + 22.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, OUTLINE)
