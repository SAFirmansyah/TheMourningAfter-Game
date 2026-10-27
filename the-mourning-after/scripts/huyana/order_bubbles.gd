class_name OrderBubbles
extends CanvasLayer
## Bubbles above Gwenith's and Shuyi's station slots: a filling ring while an order is prepared and a
## checkmark once it's ready to collect. Pops in when ordered, bursts when collected.
## Each worker has a tray (Gwenith bottom-right, Shuyi bottom-left) listing her current orders,
## shown whenever any of her station's slots isn't fully on screen (or Constance is out of the Sanctuary).

const VIEW_SCENE := preload("res://scenes/huyana/ui/request_view.tscn")
const WORKERS: Array[StringName] = [&"gwenith", &"shuyi"]

@export var manager: SanctuaryManager
@export var pop_in_time := 0.35 # TUNE: new bubble grow-in (s)
@export var pop_out_time := 0.25 # TUNE: collected bubble burst-out (s)
@export var pop_out_scale := 1.4 # TUNE: how big a collected bubble grows as it bursts
@export var screen_margin := 4.0 # TUNE: a slot's bubble must sit this far inside the screen edge to count as in view (px)
@export var tray_bubble_gap := 4 # TUNE: gap between bubbles in a tray (px)
@export var tray_edge_margin := 24.0 # TUNE: trays' distance from the screen corners (px)

@onready var trays := {&"gwenith": $GwenithTray, &"shuyi": $ShuyiTray}

var _views := {} # order id -> RequestView
var _leaving := {} # RequestView -> {worker, slot}, animating out
var _tray_signatures := {&"gwenith": "", &"shuyi": ""}


func _ready() -> void:
	manager.order_removed.connect(_on_order_removed)
	for worker in WORKERS:
		trays[worker].hide()
		trays[worker].get_node("Rows").add_theme_constant_override("separation", tray_bubble_gap)
		_size_tray(worker)


## Fixed at the size of a full tray (every one of her slots taken).
func _size_tray(worker: StringName) -> void:
	var tray: Control = trays[worker]
	var box := tray.get_theme_stylebox("panel")
	var slots: int = manager.order_slots[worker]
	var size := Vector2(
		slots * RequestView.COMPACT_SIZE.x + (slots - 1) * tray_bubble_gap + box.get_margin(SIDE_LEFT) + box.get_margin(SIDE_RIGHT),
		RequestView.COMPACT_SIZE.y + box.get_margin(SIDE_TOP) + box.get_margin(SIDE_BOTTOM))
	tray.custom_minimum_size = size
	tray.offset_top = -tray_edge_margin - size.y
	tray.offset_bottom = -tray_edge_margin
	if tray.anchor_left > 0.5:
		tray.offset_left = -tray_edge_margin - size.x
		tray.offset_right = -tray_edge_margin
	else:
		tray.offset_left = tray_edge_margin
		tray.offset_right = tray_edge_margin + size.x


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var stations := {}
	for station: WorkStation in get_tree().get_nodes_in_group(&"work_station"):
		stations[StringName(station.worker)] = station
	var screen := get_viewport().get_visible_rect().grow(-screen_margin)
	var is_day := manager.day_cycle.phase == DayCycle.Phase.DAY

	for worker in WORKERS:
		var station: WorkStation = stations.get(worker)
		var slots: Array = manager.orders[worker]
		var any_orders := false
		for slot in slots.size():
			var order: Dictionary = slots[slot]
			if order.is_empty():
				continue
			any_orders = true
			var view: RequestView = _views.get(order.id)
			if view == null:
				view = _spawn_view(order.id)
			_fill(view, order)
			view.set_meta(&"worker", worker)
			view.set_meta(&"slot", slot)
			_place(view, station, slot, cam)
		var tray: Control = trays[worker]
		tray.visible = is_day and any_orders and not _station_in_view(station, cam, screen)
		if tray.visible:
			_update_tray(worker)
	for view: RequestView in _leaving:
		_place(view, stations.get(_leaving[view].worker), _leaving[view].slot, cam)


## True only when every slot's bubble would sit fully on screen.
func _station_in_view(station: WorkStation, cam: Camera3D, screen: Rect2) -> bool:
	if station == null or cam == null:
		return false
	var size := RequestView.COMPACT_SIZE
	for slot in station.slots().size():
		var anchor := station.bubble_position(slot)
		if cam.is_position_behind(anchor):
			return false
		var tip := cam.unproject_position(anchor)
		if not screen.encloses(Rect2(tip - Vector2(size.x / 2.0, size.y), size)):
			return false
	return true


func _spawn_view(id: int) -> RequestView:
	var view: RequestView = VIEW_SCENE.instantiate()
	view.urgent_below = -1.0
	add_child(view)
	_views[id] = view
	view.scale = Vector2.ZERO
	create_tween().tween_property(view, "scale", Vector2.ONE, pop_in_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return view


func _fill(view: RequestView, order: Dictionary) -> void:
	view.item = order.item
	view.time_ratio = order.progress
	view.fulfillable = order.ready


func _place(view: RequestView, station: WorkStation, slot: int, cam: Camera3D) -> void:
	if station == null or cam == null:
		view.hide()
		return
	var anchor := station.bubble_position(slot)
	if cam.is_position_behind(anchor):
		view.hide()
		return
	view.show()
	view.position = cam.unproject_position(anchor) - view.pivot_offset


func _on_order_removed(id: int) -> void:
	var view: RequestView = _views.get(id)
	if view == null:
		return
	_views.erase(id)
	_leaving[view] = {"worker": view.get_meta(&"worker"), "slot": view.get_meta(&"slot")}
	var tween := create_tween().set_parallel()
	tween.tween_property(view, "scale", Vector2.ONE * pop_out_scale, pop_out_time).set_ease(Tween.EASE_OUT)
	tween.tween_property(view, "modulate:a", 0.0, pop_out_time).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void:
		_leaving.erase(view)
		view.queue_free())


func _update_tray(worker: StringName) -> void:
	var rows: HBoxContainer = trays[worker].get_node("Rows")
	var ids := []
	for order: Dictionary in manager.orders[worker]:
		if not order.is_empty():
			ids.append(str(order.id))
	var signature := ",".join(ids)
	if signature != _tray_signatures[worker]:
		_tray_signatures[worker] = signature
		for view in rows.get_children():
			view.queue_free()
		for order: Dictionary in manager.orders[worker]:
			if order.is_empty():
				continue
			var view: RequestView = VIEW_SCENE.instantiate()
			view.show_tip = false
			view.urgent_below = -1.0
			view.set_meta(&"order_id", order.id)
			rows.add_child(view)
	for view: RequestView in rows.get_children():
		if view.is_queued_for_deletion():
			continue
		for order: Dictionary in manager.orders[worker]:
			if not order.is_empty() and order.id == view.get_meta(&"order_id"):
				_fill(view, order)
