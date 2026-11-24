@tool
class_name BranchView
extends Control
## A hand-drawn branch with hanging bulbs. Each bulb shows one entry (an item icon, a sparkle when
## it's ready/fulfillable) with a small progress bar under it. Empty bulbs stay empty.
## Bulb positions are the bulbs' circles in the art, in the art's own pixels.
## A new item pops into its bulb, and the bars glide to their new values.

const BAR_BACK := Color(0.16, 0.11, 0.07, 0.85)
const BAR_EMPTY := Color(0.45, 0.38, 0.3)
const URGENT := Color(0.95, 0.3, 0.25)
const GOLD := Color(0.92, 0.72, 0.32)
const BACKING := Color(0.95, 0.9, 0.8, 0.92) # parchment behind a filled bulb's icon
const SPARKLE := preload("res://textures/ui/Sparkling.png")
const SPARKLE_SIZE := 1.1 # TUNE: ready sparkle's size, relative to the bulb's diameter

@export var art: Texture2D:
	set(value):
		art = value
		_resize()
@export var display_scale := 0.72: # TUNE: on-screen size of the art (1 = its pixel size)
	set(value):
		display_scale = value
		_resize()
@export var bulbs := PackedVector2Array() # centres of the bulbs' empty circles, in art pixels
@export var bulb_diameter := 74.0 # the empty circle's size, in art pixels
@export var bar_size := Vector2(67, 8) # TUNE: progress bar under each bulb (screen px)
@export var bar_gap := 36.0 # TUNE: bar's distance below the bulb's circle (screen px)
@export var urgent_below := 0.25 # TUNE: bar turns red below this share (requests' time left); -1 = never
@export var draw_backing := false # parchment behind icons, for art whose circles are still empty
@export var pop_time := 0.3 # TUNE: a new item's pop-in time (s)
@export var bar_glide := 8.0 # TUNE: how quickly bars catch up to their value (higher = snappier)

## One per bulb: {} = empty, or {item, ratio (0-1), sparkle (bool: ready to hand over / collect), repair (-1 or 0-1)}.
var entries: Array = []

var _items := [] # per bulb: the item it shows (to spot a new one)
var _pops := [] # per bulb: pop-in progress, 0-1
var _bars := [] # per bulb: the bar's shown value


func _ready() -> void:
	_resize()


func _resize() -> void:
	if art:
		custom_minimum_size = art.get_size() * display_scale
		size = custom_minimum_size
	queue_redraw()


func set_entries(new_entries: Array) -> void:
	entries = new_entries
	for i in entries.size():
		if i >= _items.size():
			_items.append(null)
			_pops.append(1.0)
			_bars.append(0.0)
		var item = null if entries[i].is_empty() else entries[i].item
		if item != _items[i]:
			_items[i] = item
			_pops[i] = 0.0
			_bars[i] = _bar_value(entries[i]) if item != null else 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_visible_in_tree():
		return
	for i in mini(entries.size(), _bars.size()):
		_pops[i] = minf(1.0, _pops[i] + delta / pop_time)
		if not entries[i].is_empty():
			_bars[i] = lerpf(_bars[i], _bar_value(entries[i]), 1.0 - exp(-bar_glide * delta))
	queue_redraw()


static func _bar_value(entry: Dictionary) -> float:
	var repair: float = entry.get("repair", -1.0)
	return repair if repair >= 0.0 else entry.get("ratio", 0.0)


## Screen-space (this control's) centre and radius of a bulb's circle.
func bulb_center(index: int) -> Vector2:
	return bulbs[index] * display_scale


func bulb_radius() -> float:
	return bulb_diameter * display_scale / 2.0


func _draw() -> void:
	if art:
		draw_texture_rect(art, Rect2(Vector2.ZERO, size), false)
	for i in mini(entries.size(), bulbs.size()):
		if not entries[i].is_empty():
			var entry: Dictionary = entries[i]
			var pop := 1.0
			if i < _bars.size():
				entry = entry.duplicate()
				entry.ratio = _bars[i]
				if entry.get("repair", -1.0) >= 0.0:
					entry.repair = _bars[i]
				pop = _ease_out_back(_pops[i])
			draw_entry(self, bulb_center(i), bulb_radius(), entry, bar_size, bar_gap, urgent_below, draw_backing, pop)


## 0 -> 1 with a slight overshoot.
static func _ease_out_back(t: float) -> float:
	var u := t - 1.0
	return 1.0 + 2.70158 * u * u * u + 1.70158 * u * u


## One entry in a circle of `radius` at `center`: optional parchment backing, icon, ready sparkle,
## and the progress bar `gap` below the circle.
## pop scales the icon (a new item popping in).
static func draw_entry(canvas: CanvasItem, center: Vector2, radius: float, entry: Dictionary, bar: Vector2, gap: float, urgent: float, backing := false, pop := 1.0) -> void:
	if backing:
		canvas.draw_circle(center, radius * 0.98, BACKING)
	RequestCatalog.draw_icon(canvas, entry.item, center, radius * pop * (0.85 if RequestCatalog.ICONS.has(entry.item) else 0.55))
	if entry.get("sparkle", false):
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 600.0) # same calm pulse as the stations' sparkles
		var side := radius * 2.0 * SPARKLE_SIZE * lerpf(0.9, 1.05, pulse)
		var sparkle_size := Vector2(side * SPARKLE.get_width() / SPARKLE.get_height(), side)
		canvas.draw_texture_rect(SPARKLE, Rect2(center - sparkle_size / 2.0, sparkle_size), false, Color(1, 1, 1, lerpf(0.75, 1.0, pulse)))
	var repair: float = entry.get("repair", -1.0)
	var ratio: float = repair if repair >= 0.0 else entry.get("ratio", 0.0)
	var color := GOLD # orders being prepared, and repairs under way
	if repair < 0.0 and urgent >= 0.0:
		color = URGENT if ratio < urgent else RequestCatalog.info(entry.item).color
	var rect := Rect2(center + Vector2(-bar.x / 2.0, radius + gap), bar)
	canvas.draw_rect(rect.grow(2.0), BAR_BACK)
	canvas.draw_rect(rect, BAR_EMPTY)
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y)), color)
