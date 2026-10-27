class_name RequestBubbles
extends CanvasLayer
## Request bubbles above each containment slot, with pop-in / pop-out / fade animations.
## Whenever any request bubble isn't fully on screen (or Constance is out of the Sanctuary), a tray in the
## top-left lists every current request.

const VIEW_SCENE := preload("res://scenes/huyana/ui/request_view.tscn")

@export var manager: SanctuaryManager
@export var pop_in_time := 0.35 # TUNE: new bubble grow-in (s)
@export var pop_out_time := 0.25 # TUNE: fulfilled bubble burst-out (s)
@export var pop_out_scale := 1.4 # TUNE: how big a fulfilled bubble grows as it bursts
@export var fade_out_time := 0.6 # TUNE: expired bubble fade-out (s)
@export var screen_margin := 4.0 # TUNE: a bubble must sit this far inside the screen edge to count as in view (px)
@export var tray_bubble_gap := 4 # TUNE: gap between a containment's bubbles in the tray (px)
@export var tray_group_gap := 22 # TUNE: gap between containments in the tray (px)

@onready var tray: Control = $Tray
@onready var tray_rows: HBoxContainer = $Tray/Rows

var _views := {} # request id -> RequestView
var _leaving := {} # RequestView -> {containment, slot}, animating out
var _tray_signature := ""


func _ready() -> void:
	tray.hide()
	manager.request_removed.connect(_on_request_removed)
	tray_rows.add_theme_constant_override("separation", tray_group_gap)
	_size_tray()


## Fixed at the size of a full tray (every containment with every slot taken); fills from the left.
func _size_tray() -> void:
	var box := tray.get_theme_stylebox("panel")
	var per_containment := manager.max_requests * RequestView.COMPACT_SIZE.x + (manager.max_requests - 1) * tray_bubble_gap
	var containments := manager.containment_foods.size()
	tray.custom_minimum_size = Vector2(
		containments * per_containment + (containments - 1) * tray_group_gap + box.get_margin(SIDE_LEFT) + box.get_margin(SIDE_RIGHT),
		RequestView.COMPACT_SIZE.y + box.get_margin(SIDE_TOP) + box.get_margin(SIDE_BOTTOM))


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var containments := {}
	for containment: Containment in get_tree().get_nodes_in_group(&"containment"):
		containments[containment.number - 1] = containment
	var screen := get_viewport().get_visible_rect().grow(-screen_margin)
	var any_off_screen := false

	for request in manager.requests:
		var view: RequestView = _views.get(request.id)
		if view == null:
			view = _spawn_view(request)
		_fill(view, request)
		var on_screen := _place(view, containments.get(request.containment), request.slot, cam)
		if not on_screen or not screen.encloses(Rect2(view.position, view.size)):
			any_off_screen = true
	for view: RequestView in _leaving:
		_place(view, containments.get(_leaving[view].containment), _leaving[view].slot, cam)

	tray.visible = any_off_screen and not manager.requests.is_empty() and manager.day_cycle.phase == DayCycle.Phase.DAY
	if tray.visible:
		_update_tray()


func _spawn_view(request: Dictionary) -> RequestView:
	var view: RequestView = VIEW_SCENE.instantiate()
	add_child(view)
	_views[request.id] = view
	view.scale = Vector2.ZERO
	create_tween().tween_property(view, "scale", Vector2.ONE, pop_in_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return view


func _fill(view: RequestView, request: Dictionary) -> void:
	view.set_meta(&"containment", request.containment)
	view.set_meta(&"slot", request.slot)
	view.item = request.item
	view.time_ratio = request.time_left / request.duration
	view.fulfillable = request.item != RequestCatalog.REPAIR and manager.is_fulfillable(request)
	view.expanded = manager.expanded.has(request.id)
	view.repair_progress = manager.repair_progress(request)


## Puts the view's tip on its slot. Returns false when that slot isn't in view at all.
func _place(view: RequestView, containment: Containment, slot: int, cam: Camera3D) -> bool:
	if containment == null or cam == null:
		view.hide()
		return false
	var anchor := containment.slot_bubble_position(slot)
	if cam.is_position_behind(anchor):
		view.hide()
		return false
	view.show()
	view.position = cam.unproject_position(anchor) - view.pivot_offset
	return true


func _on_request_removed(id: int, fulfilled: bool) -> void:
	var view: RequestView = _views.get(id)
	if view == null:
		return
	_views.erase(id)
	_leaving[view] = {"containment": view.get_meta(&"containment"), "slot": view.get_meta(&"slot")}
	var tween := create_tween().set_parallel()
	if fulfilled:
		tween.tween_property(view, "scale", Vector2.ONE * pop_out_scale, pop_out_time).set_ease(Tween.EASE_OUT)
		tween.tween_property(view, "modulate:a", 0.0, pop_out_time).set_ease(Tween.EASE_IN)
	else:
		tween.tween_property(view, "modulate:a", 0.0, fade_out_time)
	tween.chain().tween_callback(func() -> void:
		_leaving.erase(view)
		view.queue_free())


func _update_tray() -> void:
	var signature := ",".join(manager.requests.map(func(r: Dictionary) -> String: return "%d:%d" % [r.containment, r.id]))
	if signature != _tray_signature:
		_tray_signature = signature
		_rebuild_tray()
	for group in tray_rows.get_children():
		for view: RequestView in group.get_children():
			var request := _find(view.get_meta(&"request_id"))
			if not request.is_empty():
				_fill(view, request)
				view.expanded = false


func _rebuild_tray() -> void:
	for group in tray_rows.get_children():
		group.queue_free()
	for containment in 3:
		var requests := manager.requests_for(containment)
		if requests.is_empty():
			continue
		requests.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.slot < b.slot)
		var group := HBoxContainer.new()
		group.add_theme_constant_override("separation", tray_bubble_gap)
		for request in requests:
			var view: RequestView = VIEW_SCENE.instantiate()
			view.show_tip = false
			view.set_meta(&"request_id", request.id)
			group.add_child(view)
		tray_rows.add_child(group)


func _find(id: int) -> Dictionary:
	for request in manager.requests:
		if request.id == id:
			return request
	return {}
