@tool
class_name WorkStation
extends Node3D
## Gwenith's or Shuyi's station: a group of props (planters, med stations), each with an OrderPoint
## child as one order slot: empty -> "Order", ready -> "Collect", in progress -> no prompt.
## An occupied prop is dimmed; a ready one sparkles. Slots are numbered in tree order.

const SPARKLE := preload("res://textures/ui/Sparkling.png")

@export_enum("gwenith", "shuyi") var worker := "gwenith":
	set(value):
		worker = value
		_place_slots()
@export var spread_slots := false: # on: lines the slots up along the station (one long prop); off: slots stay where they're placed
	set(value):
		spread_slots = value
		_place_slots()
@export var slot_spacing := 2.2: # TUNE: distance between slots when spread (m)
	set(value):
		slot_spacing = value
		_place_slots()
@export var menu_height := 6.4 # TUNE: height of the order menu's tip above the floor (m)
@export var busy_tint := Color(0.45, 0.45, 0.45) # TUNE: a prop's tint while it holds an order
@export var tint_speed := 6.0 # TUNE: how fast a prop dims/brightens
@export var sparkle_size := 2.0 # TUNE: on-screen size of the ready sparkle (m)
@export var sparkle_height := 0.8 # TUNE: sparkle's height as a share of the prop's height
@export var sparkle_speed := 1.6 # TUNE: sparkle pulse speed (radians/s)

var _manager: SanctuaryManager
var _sparkles := {} # slot -> Sprite3D
var _sparkle_grow := {} # slot -> 0-1, grows in when an order becomes ready
var _time := 0.0


func _ready() -> void:
	_place_slots()
	if not Engine.is_editor_hint():
		add_to_group(&"work_station")
		_manager = get_tree().get_first_node_in_group(&"sanctuary_manager")


func slots() -> Array[OrderPoint]:
	var result: Array[OrderPoint] = []
	for point in find_children("*", "OrderPoint", true, false):
		result.append(point)
	return result


func menu_anchor() -> Vector3:
	return global_position + Vector3(0.0, menu_height, 0.0)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _manager == null:
		return
	_time += delta
	var points := slots()
	for i in points.size():
		var card := _card_of(points[i])
		if card == null:
			continue
		var state := _manager.slot_state(StringName(worker), i)
		var target := Color.WHITE if state == SanctuaryManager.SlotState.EMPTY else busy_tint
		if not card.modulate.is_equal_approx(target):
			card.set_tint(card.modulate.lerp(target, minf(1.0, tint_speed * delta)))
		_update_sparkle(i, card, state == SanctuaryManager.SlotState.READY)


## The prop a slot belongs to: its OrderPoint's parent obstacle.
func _card_of(point: OrderPoint) -> FacingCard:
	var prop := point.get_parent() as Obstacle
	return prop.card as FacingCard if prop else null


func _update_sparkle(slot: int, card: FacingCard, ready: bool) -> void:
	var sparkle: Sprite3D = _sparkles.get(slot)
	if sparkle == null:
		if not ready:
			return
		sparkle = Sprite3D.new()
		sparkle.texture = SPARKLE
		sparkle.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sparkle.no_depth_test = true
		sparkle.render_priority = 10
		sparkle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sparkle.pixel_size = sparkle_size / SPARKLE.get_height()
		card.get_parent().add_child(sparkle)
		_sparkles[slot] = sparkle
	_sparkle_grow[slot] = move_toward(_sparkle_grow.get(slot, 0.0), 1.0 if ready else 0.0, get_process_delta_time() / 0.35)
	sparkle.visible = _sparkle_grow[slot] > 0.0
	if sparkle.visible:
		var frame_h: float = card.region_rect.size.y if card.region_enabled else float(card.texture.get_height())
		sparkle.position = Vector3(0.0, frame_h * card.pixel_size * sparkle_height, 0.0)
		var pulse := 0.5 + 0.5 * sin(_time * sparkle_speed)
		var grow := ease(_sparkle_grow[slot], 0.4) # TUNE: grow-in curve
		sparkle.scale = Vector3.ONE * lerpf(0.85, 1.1, pulse) * grow
		sparkle.modulate.a = lerpf(0.7, 1.0, pulse) * grow


func _place_slots() -> void:
	if not is_node_ready():
		return
	var points := slots()
	for i in points.size():
		points[i].worker = worker
		points[i].slot = i
		points[i].station = self
		if spread_slots:
			points[i].position = Vector3((i - (points.size() - 1) / 2.0) * slot_spacing, 0.0, 0.0)
