@tool
class_name ClockFace
extends Control
## The pocket-watch clock: the face art, with the hand art turning on top. The night wedge is painted
## on the face; the day runs clockwise from the wedge's right edge round to its left edge.
## Angles are degrees clockwise from straight up. In game the hand eases to its time (so nightfall
## and dawn sweep rather than jump).

@export var face: Texture2D:
	set(value):
		face = value
		queue_redraw()
@export var hand: Texture2D:
	set(value):
		hand = value
		queue_redraw()
@export var face_pivot := Vector2(105, 160) # where the hand turns, in the face art's pixels
@export var hand_pivot := Vector2(15, 78) # the hand's turning point, in the hand art's pixels
@export var night_start := -27.0 # left edge of the face's night wedge (degrees)
@export var night_end := 37.0 # right edge of the face's night wedge (degrees)
@export_range(0.0, 1.0) var day_progress := 0.3: # editor preview / current time of day
	set(value):
		day_progress = value
		queue_redraw()
@export var is_night := false:
	set(value):
		is_night = value
		queue_redraw()
@export var hand_ease := 3.0 # TUNE: how quickly the hand catches up to the time (higher = snappier)

var _shown := NAN # the hand's drawn angle in game (radians)


## Day: 0 at dawn (the wedge's right edge) to 1 at dusk (its left edge). Night: the middle of the wedge.
func set_time(night: bool, progress: float) -> void:
	is_night = night
	day_progress = progress


func hand_angle() -> float:
	if is_night:
		return (night_start + night_end) / 2.0
	return lerpf(night_end, night_start + 360.0, clampf(day_progress, 0.0, 1.0))


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var target := deg_to_rad(hand_angle())
	_shown = target if is_nan(_shown) else lerp_angle(_shown, target, 1.0 - exp(-hand_ease * delta))
	queue_redraw()


func _draw() -> void:
	if not face:
		return
	var scale := size.x / face.get_width() # the node keeps the face's shape
	draw_texture_rect(face, Rect2(Vector2.ZERO, face.get_size() * scale), false)
	if hand:
		var angle := deg_to_rad(hand_angle()) if Engine.is_editor_hint() or is_nan(_shown) else _shown
		draw_set_transform(face_pivot * scale, angle, Vector2.ONE * scale)
		draw_texture(hand, -hand_pivot)
		draw_set_transform(Vector2.ZERO)
