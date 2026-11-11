@tool
class_name ClockFace
extends Control
## Placeholder day/night dial: day sector, night sector, pointer. Starts at the top, runs clockwise.

@export_range(0.05, 0.5) var night_fraction := 0.15: # TUNE: share of the dial shown as night
	set(value):
		night_fraction = value
		queue_redraw()
@export_range(0.0, 1.0) var pointer_turn := 0.3: # pointer position, 0–1 around the dial from the top
	set(value):
		pointer_turn = value
		queue_redraw()
@export var day_color := Color(0.95, 0.78, 0.38)
@export var night_color := Color(0.2, 0.24, 0.48)
@export var rim_color := Color(0.08, 0.08, 0.09)
@export var pointer_color := Color(0.95, 0.95, 0.92)


func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - 6.0
	var top := -PI / 2.0
	var day_end := top + TAU * (1.0 - night_fraction)
	draw_circle(center, radius + 5.0, rim_color)
	_draw_sector(center, radius, top, day_end, day_color)
	_draw_sector(center, radius, day_end, top + TAU, night_color)
	var angle := top + TAU * pointer_turn
	var dir := Vector2(cos(angle), sin(angle))
	var tip := center + dir * (radius - 6.0)
	draw_line(center, tip - dir * 10.0, pointer_color, 4.0, true)
	var side := Vector2(-dir.y, dir.x) * 8.0
	draw_colored_polygon(PackedVector2Array([tip, tip - dir * 16.0 + side, tip - dir * 16.0 - side]), pointer_color)
	draw_circle(center, 6.0, pointer_color)


func _draw_sector(center: Vector2, radius: float, from: float, to: float, color: Color) -> void:
	var points := PackedVector2Array([center])
	var steps := maxi(4, int(48.0 * (to - from) / TAU))
	for i in steps + 1:
		var a := lerpf(from, to, float(i) / steps)
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(points, color)
