class_name RequestBranches
extends CanvasLayer
## Constance's request and order branches, on screen during the day in the Sanctuary: containment requests hang
## top-left (two bulbs per containment, left to right), Gwenith's orders bottom-right and Shuyi's
## bottom-left. Each bulb has a small progress bar under it. They fade in and out.
## Clicking a sparkling request bulb walks Constance to its containment to hand it over (any movement
## key cancels the walk).

@export var manager: SanctuaryManager
@export var world: World
@export var fade_time := 0.25 # TUNE: branches' fade in/out (s)

var _alpha := 0.0
var _showing := false
var _ready_bulbs := {} # bulb index -> true, for requests that can be handed over now

@onready var requests_branch: BranchView = $Requests
@onready var gwenith_branch: BranchView = $Gwenith
@onready var shuyi_branch: BranchView = $Shuyi


func _process(delta: float) -> void:
	var day_cycle := manager.day_cycle
	var in_sanctuary := world != null and world.current_room != null and world.current_room.scene_file_path.ends_with("sanctuary.tscn")
	var showing := in_sanctuary and day_cycle.clock_layer.visible and day_cycle.phase == DayCycle.Phase.DAY and not day_cycle.clock_paused and not world.is_story_playing() # daytime play only (the clock stands still for the tutorial pages)
	_alpha = move_toward(_alpha, 1.0 if showing else 0.0, delta / fade_time)
	visible = _alpha > 0.0
	for branch: Control in [requests_branch, gwenith_branch, shuyi_branch]:
		branch.modulate.a = _alpha
	_showing = showing
	if not showing:
		requests_branch.hovered = -1
		return
	var bulbs := []
	bulbs.resize(manager.containment_foods.size() * manager.max_requests)
	bulbs.fill({})
	for request in manager.requests:
		var index: int = request.containment * manager.max_requests + request.slot
		if index < bulbs.size():
			bulbs[index] = {
				"item": request.item,
				"ratio": request.time_left / request.duration,
				"sparkle": request.item != RequestCatalog.REPAIR and manager.is_fulfillable(request),
				"repair": manager.repair_progress(request),
			}
	_ready_bulbs.clear()
	for i in bulbs.size():
		if not bulbs[i].is_empty() and bulbs[i].sparkle:
			_ready_bulbs[i] = true
	requests_branch.set_entries(bulbs)
	requests_branch.hovered = _ready_bulb_under_mouse()
	gwenith_branch.set_entries(_order_entries(&"gwenith"))
	shuyi_branch.set_entries(_order_entries(&"shuyi"))


func _order_entries(worker: StringName) -> Array:
	var entries := []
	for order: Dictionary in manager.orders[worker]:
		entries.append({} if order.is_empty() else {"item": order.item, "ratio": order.progress, "sparkle": order.ready})
	return entries


func _ready_bulb_under_mouse() -> int:
	var player := _player()
	if player == null or not player.input_enabled:
		return -1
	var index := requests_branch.bulb_at(requests_branch.get_local_mouse_position())
	return index if _ready_bulbs.has(index) else -1


func _player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


func _input(event: InputEvent) -> void:
	if not _showing or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var index := _ready_bulb_under_mouse()
	if index < 0:
		return
	get_viewport().set_input_as_handled() # not a swing
	var containment := index / manager.max_requests
	var slot := index % manager.max_requests
	for node in get_tree().get_nodes_in_group(&"containment"):
		var facade := node as Containment
		if facade and facade.number == containment + 1:
			_player().auto_walk_to(facade.fulfill_point(slot), func() -> void:
				var request := manager.request_at(containment, slot)
				if not request.is_empty() and manager.is_fulfillable(request):
					get_tree().call_group(&"world", &"mark_unsaved")
					manager.interact(containment, slot))
			return
