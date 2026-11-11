@tool
class_name RequestView
extends Control
## One request. Compact: bubble with icon, countdown ring and checkmark when it can be fulfilled.
## Expanded: card with icon, item name and whose station it comes from.
## The tip points down at the containment, and scaling pivots on it.

const COMPACT_SIZE := Vector2(84, 104)
const EXPANDED_SIZE := Vector2(320, 104)
const BACKGROUND := Color(0.94, 0.92, 0.87, 0.96)
const OUTLINE := Color(0.12, 0.11, 0.1)
const RING_EMPTY := Color(0.78, 0.75, 0.69)
const GOLD := Color(0.78, 0.66, 0.38)
const URGENT := Color(0.95, 0.3, 0.25)

@export var item: StringName = &"infused_dew":
	set(value):
		item = value
		queue_redraw()
@export_range(0.0, 1.0) var time_ratio := 0.7: # time left as a share of the request's duration
	set(value):
		time_ratio = value
		queue_redraw()
@export var fulfillable := true: # shows the checkmark
	set(value):
		fulfillable = value
		queue_redraw()
@export var expanded := false:
	set(value):
		expanded = value
		_apply_size()
		queue_redraw()
@export_range(-1.0, 1.0) var repair_progress := -1.0: # -1 = no repair order on this request
	set(value):
		repair_progress = value
		queue_redraw()
@export var show_tip := true: # off for the off-screen tray
	set(value):
		show_tip = value
		queue_redraw()
@export var urgent_below := 0.25 # TUNE: ring turns red below this share of time left


func _ready() -> void:
	_apply_size()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _apply_size() -> void:
	custom_minimum_size = EXPANDED_SIZE if expanded else COMPACT_SIZE
	size = custom_minimum_size
	pivot_offset = Vector2(size.x / 2.0, size.y)


func _draw() -> void:
	if expanded:
		_draw_expanded()
	else:
		_draw_compact()


func _ring_color() -> Color:
	return URGENT if time_ratio < urgent_below else RequestCatalog.info(item).color


func _draw_compact() -> void:
	var center := Vector2(size.x / 2.0, 50.0)
	var radius := 30.0
	draw_circle(center, radius + 7.0, OUTLINE)
	if show_tip:
		var tip := PackedVector2Array([center + Vector2(-10, radius - 2), center + Vector2(0, radius + 18), center + Vector2(10, radius - 2)])
		draw_colored_polygon(tip, OUTLINE)
		draw_colored_polygon(PackedVector2Array([tip[0] + Vector2(3, -1), tip[1] + Vector2(0, -5), tip[2] + Vector2(-3, -1)]), BACKGROUND)
	draw_circle(center, radius + 4.5, BACKGROUND)
	draw_arc(center, radius, 0.0, TAU, 48, RING_EMPTY, 5.0, true)
	if time_ratio > 0.0:
		draw_arc(center, radius, -PI / 2.0, -PI / 2.0 + TAU * time_ratio, 48, _ring_color(), 5.0, true)
	RequestCatalog.draw_icon(self, item, center, 15.0)
	if fulfillable and repair_progress < 0.0:
		_draw_check(center + Vector2(radius - 2, -radius + 4))
	if repair_progress >= 0.0:
		var bar := Rect2(center.x - 34, 2, 68, 7)
		draw_rect(bar.grow(2.0), OUTLINE)
		draw_rect(bar, BACKGROUND)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * repair_progress, bar.size.y)), GOLD)


func _draw_expanded() -> void:
	var rect := Rect2(Vector2.ZERO, size - Vector2(0, 16))
	var box := StyleBoxFlat.new()
	box.bg_color = BACKGROUND
	box.border_color = OUTLINE
	box.set_border_width_all(3)
	box.set_corner_radius_all(6)
	if show_tip:
		draw_colored_polygon(PackedVector2Array([Vector2(size.x / 2.0 - 11, rect.end.y - 3), Vector2(size.x / 2.0, size.y - 1), Vector2(size.x / 2.0 + 11, rect.end.y - 3)]), OUTLINE)
	draw_style_box(box, rect)
	var data := RequestCatalog.info(item)
	var font := get_theme_default_font()
	RequestCatalog.draw_icon(self, item, Vector2(42, rect.size.y / 2.0 - 4), 18.0)
	draw_string(font, Vector2(76, 34), data.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, OUTLINE)
	draw_string(font, Vector2(76, 62), "From: %s" % data.source, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.35, 0.33, 0.3))
	var bar := Rect2(12, rect.end.y - 12, size.x - 24, 5)
	draw_rect(bar, RING_EMPTY)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * time_ratio, bar.size.y)), _ring_color())


func _draw_check(at: Vector2) -> void:
	draw_circle(at, 12.0, Color(0.3, 0.75, 0.35))
	draw_polyline(PackedVector2Array([at + Vector2(-6, 0), at + Vector2(-2, 5), at + Vector2(6, -5)]), Color.WHITE, 3.0, true)
