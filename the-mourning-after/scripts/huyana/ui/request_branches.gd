class_name RequestBranches
extends CanvasLayer
## Constance's request and order branches, on screen during the day in the Sanctuary: containment requests hang
## top-left (two bulbs per containment, left to right), Gwenith's orders bottom-right and Shuyi's
## bottom-left. Each bulb has a small progress bar under it. They fade in and out.

@export var manager: SanctuaryManager
@export var world: World
@export var fade_time := 0.25 # TUNE: branches' fade in/out (s)

var _alpha := 0.0

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
	if not showing:
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
	requests_branch.set_entries(bulbs)
	gwenith_branch.set_entries(_order_entries(&"gwenith"))
	shuyi_branch.set_entries(_order_entries(&"shuyi"))


func _order_entries(worker: StringName) -> Array:
	var entries := []
	for order: Dictionary in manager.orders[worker]:
		entries.append({} if order.is_empty() else {"item": order.item, "ratio": order.progress, "sparkle": order.ready})
	return entries
