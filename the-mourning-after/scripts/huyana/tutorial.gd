class_name Tutorial
extends Node
## First-run tutorial, per the GDD. The Sanctuary sits idle until Constance first leaves the Altar:
## - Night 0: paged instructions over the dark Sanctuary on what each station needs and makes, and how to order.
## - Day 1: a guided run through fixed requests (food, then a repair, then medicine), with a caption and an
##   arrow at each step. The clock waits and nothing expires until the guide is done; then the rest of a
##   shorter Day 1 plays normally. No Sanctuary Health is lost on Day 1.
## - Night 1: the night modal introduces Sanctuary Health (DayCycle.first_night_note).
## The Skip tutorial test button jumps straight to a normal day.

enum Stage { NIGHT_0, GUIDE, FREE_DAY, DONE, AT_ALTAR } # new stages go last: saves store the number

const PAGES := [
	["Night 0", "The Sanctuary keeps the mutants alive. Each day the three containments ask for food, medicine or repairs, and Gwenith, Shuyi and Rudrama make what they need. You carry the orders and the items between them.\n\nRead on to learn what each station does."],
	["Gwenith's planter boxes", "Gwenith grows everything from the harvest the human members bring in.\n\nFood: Infused Dew, Willow Bark and Graceroot. Each containment eats only one of them.\nIngredients: Bloodflower, Obsidian Grass and Pearls of Night, for Shuyi's medicines.\n\nTalk to Gwenith or use an empty planter to order. Once it has grown, collect it from its planter."],
	["Shuyi's medicine station", "Shuyi brews medicine from two ingredients you've collected from Gwenith:\n\nHaemoshear: Bloodflower + Obsidian Grass\nNacrescorch: Obsidian Grass + Pearls of Night\nCapillanyx: Pearls of Night + Bloodflower\n\nTalk to Shuyi or use an empty slot at her station to order, then collect the medicine once it's brewed."],
	["Rudrama's anvil", "Rudrama keeps the containments standing. When one needs repairs, talk to Rudrama or use the anvil and pick the containment. She walks over and fixes it herself, one repair at a time."],
	["Requests", "Each containment shows what it needs as bubbles above it. The ring is the time left, and a checkmark means you have what it needs.\n\nWalk up to a bubble and press E to hand the item over, or to see where it comes from. Gwenith and Shuyi only work at their stations, so they head back when you order."],
]
const FOOD_CONTAINMENT := 0
const REPAIR_CONTAINMENT := 1
const MEDICINE_CONTAINMENT := 2
const MEDICINE := &"haemoshear"

@export var world: World
@export var manager: SanctuaryManager
@export var day_cycle: DayCycle
@export var player: Player
@export var skip_button: Button
@export var hud: InteractionHUD
@export_file("*.tscn") var altar_room := "res://scenes/huyana/altar.tscn"
@export var day_1_length := 180.0 # TUNE: length of Day 1 (s at 1x); the clock only starts once the guide is done
@export var done_caption_time := 6.0 # TUNE: how long the closing caption stays up (s)
@export var character_arrow_height := 2.9 # TUNE: height of the arrow's tip over Gwenith, Shuyi or Rudrama (m)
@export var bubble_arrow_lift := 112.0 # TUNE: arrow's tip above a request bubble's tip (px)
@export var arrow_bob := 10.0 # TUNE: arrow bounce distance (px)
@export var arrow_bob_speed := 2.5 # TUNE: arrow bounces per second
@export var arrow_edge_margin := 56.0 # TUNE: distance of the off-screen arrow from the screen edge (px)

@onready var night_panel: Control = $Night0/Panel
@onready var page_title: Label = $Night0/Panel/Content/Title
@onready var page_body: Label = $Night0/Panel/Content/Body
@onready var page_number: Label = $Night0/Panel/Content/Buttons/Page
@onready var back_button: Button = $Night0/Panel/Content/Buttons/Back
@onready var next_button: Button = $Night0/Panel/Content/Buttons/Next
@onready var caption: Control = $Guide/Caption
@onready var caption_label: Label = $Guide/Caption/Label
@onready var arrow: GuideArrow = $Guide/Arrow

var stage := Stage.AT_ALTAR
var step := 0

var _page := 0
var _normal_day_length := 0.0
var _steps: Array[Dictionary] = []
var _caption_timer := 0.0
var _caption_wanted := false
var _time := 0.0


func _enter_tree() -> void:
	add_to_group(&"save_state")


func _ready() -> void:
	_normal_day_length = day_cycle.day_length
	night_panel.hide()
	_caption_wanted = false
	arrow.hide()
	back_button.pressed.connect(func() -> void: _show_page(_page - 1))
	next_button.pressed.connect(_on_next)
	skip_button.pressed.connect(_skip)
	day_cycle.night_started.connect(_on_night_started)
	_build_steps()
	_begin.call_deferred() # after the world has loaded the save


func _begin() -> void:
	# Saves from before the tutorial existed are already past it.
	if stage in [Stage.NIGHT_0, Stage.AT_ALTAR] and (day_cycle.day > 1 or day_cycle.elapsed > 0.0 or day_cycle.phase == DayCycle.Phase.NIGHT):
		stage = Stage.DONE
	elif stage == Stage.AT_ALTAR and not _in_altar():
		stage = Stage.NIGHT_0
	_apply_stage()
	world.room_entered.connect(_on_room_entered)


func _process(delta: float) -> void:
	_time += delta
	if stage == Stage.NIGHT_0:
		player.input_enabled = false # the room change hands control back as it fades in
	if stage == Stage.GUIDE:
		_update_guide()
	elif _caption_timer > 0.0:
		_caption_timer -= delta
		if _caption_timer <= 0.0:
			_caption_wanted = false
	caption.visible = _caption_wanted and not hud.is_open() # the text box takes its place
	_place_arrow()


# --- Stages --------------------------------------------------------------------------------------

func _apply_stage() -> void:
	skip_button.visible = stage not in [Stage.DONE, Stage.AT_ALTAR]
	day_cycle.clock_layer.visible = stage != Stage.AT_ALTAR
	manager.frozen = stage in [Stage.NIGHT_0, Stage.AT_ALTAR]
	manager.spawning = stage != Stage.GUIDE
	manager.requests_paused = stage == Stage.GUIDE
	manager.health_locked = stage in [Stage.GUIDE, Stage.FREE_DAY]
	day_cycle.clock_paused = stage in [Stage.NIGHT_0, Stage.GUIDE, Stage.AT_ALTAR]
	day_cycle.day_length = _normal_day_length if stage == Stage.DONE else day_1_length
	night_panel.visible = stage == Stage.NIGHT_0
	match stage:
		Stage.NIGHT_0:
			day_cycle.set_darkness(1.0)
			player.input_enabled = false
			player.forced_input = Vector2.ZERO
			_show_page(0)
		Stage.GUIDE:
			_enter_step()
		_:
			if _caption_timer <= 0.0:
				_caption_wanted = false


func _in_altar() -> bool:
	return world.current_room != null and world.current_room.scene_file_path == altar_room


func _on_room_entered(_room: Room) -> void:
	if stage == Stage.AT_ALTAR and not _in_altar():
		stage = Stage.NIGHT_0
		_apply_stage()


func _on_next() -> void:
	if _page < PAGES.size() - 1:
		_show_page(_page + 1)
		return
	stage = Stage.GUIDE
	step = 0
	day_cycle.set_darkness(0.0, true)
	player.input_enabled = true
	_apply_stage()
	get_tree().call_group(&"world", &"mark_unsaved")


func _show_page(index: int) -> void:
	_page = clampi(index, 0, PAGES.size() - 1)
	page_title.text = PAGES[_page][0]
	page_body.text = PAGES[_page][1]
	page_number.text = "%d / %d" % [_page + 1, PAGES.size()]
	back_button.disabled = _page == 0
	back_button.modulate.a = 0.4 if _page == 0 else 1.0
	next_button.text = "Begin" if _page == PAGES.size() - 1 else "Next"
	next_button.grab_focus()


func _finish_guide() -> void:
	stage = Stage.FREE_DAY
	_apply_stage()
	_show_caption("That's the Sanctuary. Keep it running until nightfall.")
	_caption_timer = done_caption_time
	get_tree().call_group(&"world", &"save_game")


func _on_night_started(_day: int) -> void:
	if stage != Stage.DONE:
		stage = Stage.DONE # the manager has already settled the day, so Day 1 cost no health
		_apply_stage()


## Test button: straight to a normal day, wherever the tutorial is.
func _skip() -> void:
	var was_night_0 := stage == Stage.NIGHT_0
	stage = Stage.DONE
	_caption_timer = 0.0
	_apply_stage()
	if was_night_0:
		day_cycle.set_darkness(0.0, true)
		player.input_enabled = true
	get_tree().call_group(&"world", &"save_game")


# --- Guide ---------------------------------------------------------------------------------------

func _build_steps() -> void:
	var food: StringName = manager.containment_foods[FOOD_CONTAINMENT]
	var food_name: String = RequestCatalog.info(food).name
	var recipe: Array = RequestCatalog.RECIPES[MEDICINE]
	var medicine_name: String = RequestCatalog.info(MEDICINE).name
	var first: String = RequestCatalog.info(recipe[0]).name
	var second: String = RequestCatalog.info(recipe[1]).name
	var food_request := [FOOD_CONTAINMENT, food]
	var repair_request := [REPAIR_CONTAINMENT, RequestCatalog.REPAIR]
	var medicine_request := [MEDICINE_CONTAINMENT, MEDICINE]
	_steps = [
		{"text": "Containment 1 is hungry. Talk to Gwenith and order %s." % food_name, "request": food_request,
			"target": _worker_target.bind(&"gwenith"),
			"done": func() -> bool: return _have(food) > 0 or _request_gone(food_request)},
		{"text": "Gwenith is growing the %s. Collect it from her planter once it's ready." % food_name, "request": food_request,
			"target": _station_target.bind(&"gwenith"),
			"done": func() -> bool: return manager.stock_of(food) > 0 or _request_gone(food_request)},
		{"text": "Walk up to containment 1's bubble and press E to hand over the %s." % food_name, "request": food_request,
			"target": _request_target.bind(food_request),
			"done": func() -> bool: return _request_gone(food_request)},
		{"text": "Containment 2 needs repairs. Talk to Rudrama and send her to fix it.", "request": repair_request,
			"target": _worker_target.bind(&"rudrama"),
			"done": func() -> bool: return not manager.repair_order.is_empty() or _request_gone(repair_request)},
		{"text": "Rudrama is on her way. Wait while she repairs containment 2.", "request": repair_request,
			"target": _request_target.bind(repair_request),
			"done": func() -> bool: return _request_gone(repair_request)},
		{"text": "Containment 3 is sick and needs %s, made from %s and %s. Order both from Gwenith." % [medicine_name, first, second], "request": medicine_request,
			"target": _worker_target.bind(&"gwenith"),
			"done": func() -> bool: return (_have(recipe[0]) > 0 and _have(recipe[1]) > 0) or _have(MEDICINE) > 0 or _request_gone(medicine_request)},
		{"text": "Collect the %s and the %s from Gwenith's planters." % [first, second], "request": medicine_request,
			"target": _station_target.bind(&"gwenith"),
			"done": func() -> bool: return manager.can_brew(MEDICINE) or _have(MEDICINE) > 0 or _request_gone(medicine_request)},
		{"text": "Bring them to Shuyi and order %s." % medicine_name, "request": medicine_request,
			"target": _worker_target.bind(&"shuyi"),
			"done": func() -> bool: return _have(MEDICINE) > 0 or _request_gone(medicine_request)},
		{"text": "Collect the %s from Shuyi's station once it's brewed." % medicine_name, "request": medicine_request,
			"target": _station_target.bind(&"shuyi"),
			"done": func() -> bool: return manager.stock_of(MEDICINE) > 0 or _request_gone(medicine_request)},
		{"text": "Hand the %s to containment 3." % medicine_name, "request": medicine_request,
			"target": _request_target.bind(medicine_request),
			"done": func() -> bool: return _request_gone(medicine_request)},
	]


func _update_guide() -> void:
	var advanced := false
	while step < _steps.size() and _steps[step].done.call():
		step += 1
		advanced = true
		if step < _steps.size():
			_enter_step()
	if step >= _steps.size():
		_finish_guide()
	elif advanced:
		get_tree().call_group(&"world", &"mark_unsaved")


## Puts up the step's caption; the first step for each scripted request adds that request.
func _enter_step() -> void:
	if step >= _steps.size():
		_finish_guide()
		return
	var current: Dictionary = _steps[step]
	var request: Array = current.request
	var first_of_request: bool = step == 0 or _steps[step - 1].request != request
	if first_of_request and _find_request(request).is_empty():
		var slot := manager.free_request_slot(request[0])
		if slot >= 0:
			var item: StringName = request[1]
			var duration: float = manager.food_duration
			match RequestCatalog.info(item).kind:
				RequestCatalog.Kind.MEDICINE:
					duration = manager.medicine_duration
				RequestCatalog.Kind.REPAIR:
					duration = manager.repair_durations[manager.repair_durations.size() - 1]
			manager.add_request(request[0], slot, item, duration)
	_show_caption(current.text)


func _show_caption(text: String) -> void:
	caption_label.text = text
	_caption_wanted = true


func _find_request(request: Array) -> Dictionary:
	for r in manager.requests_for(request[0]):
		if r.item == request[1]:
			return r
	return {}


func _request_gone(request: Array) -> bool:
	return _find_request(request).is_empty()


## In stock, or ordered from anyone.
func _have(item: StringName) -> int:
	var count := manager.stock_of(item)
	for worker: StringName in manager.orders:
		for order: Dictionary in manager.orders[worker]:
			if not order.is_empty() and order.item == item:
				count += 1
	return count


# --- Arrow ---------------------------------------------------------------------------------------

## {position, lift (px)} or {} when the target isn't in the current room.
func _worker_target(worker: StringName) -> Dictionary:
	if get_tree().get_first_node_in_group(&"containment") == null:
		return {} # not in the Sanctuary
	return {"position": manager.worker_position(worker) + Vector3(0.0, character_arrow_height, 0.0), "lift": 0.0}


func _station_target(worker: StringName) -> Dictionary:
	for station: WorkStation in get_tree().get_nodes_in_group(&"work_station"):
		if StringName(station.worker) == worker:
			return {"position": station.menu_anchor(), "lift": 0.0}
	return {}


func _request_target(request: Array) -> Dictionary:
	var found := _find_request(request)
	if found.is_empty():
		return {}
	for containment: Containment in get_tree().get_nodes_in_group(&"containment"):
		if containment.number - 1 == request[0]:
			return {"position": containment.slot_bubble_position(found.slot), "lift": bubble_arrow_lift}
	return {}


func _place_arrow() -> void:
	var cam := get_viewport().get_camera_3d()
	var target: Dictionary = _steps[step].target.call() if stage == Stage.GUIDE and step < _steps.size() else {}
	var menus := get_tree().get_first_node_in_group(&"order_menus") as OrderMenus
	if target.is_empty() or cam == null or (menus and menus.is_open()):
		arrow.hide()
		return
	arrow.show()
	var screen := get_viewport().get_visible_rect()
	var behind := cam.is_position_behind(target.position)
	var tip := cam.unproject_position(target.position) - Vector2(0.0, target.lift)
	var inner := screen.grow(-arrow_edge_margin)
	var direction := Vector2.DOWN
	if behind or not inner.has_point(tip):
		var center := screen.get_center()
		var toward := (tip - center) * (-1.0 if behind else 1.0)
		direction = toward.normalized() if toward.length() > 0.01 else Vector2.DOWN
		tip = tip.clamp(inner.position, inner.end) if not behind else center + direction * minf(inner.size.x, inner.size.y) / 2.0
	var bob := -direction * arrow_bob * (0.5 + 0.5 * sin(_time * TAU * arrow_bob_speed))
	arrow.rotation = direction.angle() - PI / 2.0
	arrow.position = tip + bob - arrow.pivot_offset


# --- Saving --------------------------------------------------------------------------------------

func get_save_data() -> Dictionary:
	return {"stage": stage, "step": step}


func load_save_data(data: Dictionary) -> void:
	stage = int(data.get("stage", stage)) as Stage
	step = int(data.get("step", step))
