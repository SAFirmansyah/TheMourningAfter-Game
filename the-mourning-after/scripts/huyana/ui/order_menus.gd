class_name OrderMenus
extends CanvasLayer
## Order menus: Gwenith grows food and ingredients, Shuyi brews medicine from two ingredients,
## Rudrama is sent to repair a containment. Each opens on its parchment above the worker (Gwenith's and Shuyi's over
## their station). Clicking an option places the order and closes the menu; holding Shift keeps it
## open to place more, until that worker's slots are full. E or Esc closes it.
## Menus pop open (fade + slight grow from the bottom) and fade out.

@export var manager: SanctuaryManager
@export var player: Player
@export var day_cycle: DayCycle
@export var screen_margin := 16.0 # TUNE: closest a menu gets to the screen edge (px)
@export var dimmed_alpha := 0.4 # TUNE: opacity of options that can't be ordered right now
@export var open_time := 0.16 # TUNE: pop-open time (s)
@export var close_time := 0.1 # TUNE: fade-out time (s)

@onready var menus := {&"gwenith": $Gwenith, &"shuyi": $Shuyi, &"rudrama": $Rudrama}

var _worker: StringName = &""
var _anchor: OrderPoint
var _pausing := false
var _slot := -1
var _tweens := {} # menu -> its open/close tween


func _enter_tree() -> void:
	add_to_group(&"order_menus")


func _ready() -> void:
	for menu: Control in menus.values():
		menu.hide()
	for item: StringName in RequestCatalog.FOODS + RequestCatalog.INGREDIENTS:
		_gwenith_cell(item).pressed.connect(_order.bind(&"gwenith", item))
		HoverArt.apply(_gwenith_cell(item), HoverArt.ITEM_SELECTION)
	for medicine: StringName in RequestCatalog.MEDICINES:
		_shuyi_row(medicine).pressed.connect(_order.bind(&"shuyi", medicine))
		HoverArt.apply(_shuyi_row(medicine), HoverArt.ITEM_SELECTION)
	for i in 3:
		HoverArt.apply(_rudrama_bubble(i), HoverArt.ITEM_SELECTION)
	for i in 3:
		_rudrama_bubble(i).pressed.connect(func() -> void:
			if _worker == &"rudrama" and manager.order_repair(i):
				get_tree().call_group(&"world", &"mark_unsaved")
				close())
	day_cycle.night_started.connect(func(_day: int) -> void: close())


func is_open() -> bool:
	return _worker != &""


## slot: the station slot to fill, or -1 for the first free one.
func open(worker: StringName, anchor: OrderPoint, pauses_worker: bool, slot := -1) -> void:
	close()
	_worker = worker
	_anchor = anchor
	_pausing = pauses_worker
	_slot = slot
	if _pausing:
		manager.set_worker_paused(worker, true)
	player.input_enabled = false
	player.forced_input = Vector2.ZERO
	var menu: Control = menus[worker]
	menu.show()
	_refresh()
	_place()
	menu.pivot_offset = Vector2(menu.size.x / 2.0, menu.size.y)
	menu.modulate.a = 0.0
	menu.scale = Vector2.ONE * 0.94
	var tween := _restart_tween(menu).set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(menu, "modulate:a", 1.0, open_time)
	tween.tween_property(menu, "scale", Vector2.ONE, open_time)


func close() -> void:
	if not is_open():
		return
	var menu: Control = menus[_worker]
	var tween := _restart_tween(menu)
	tween.tween_property(menu, "modulate:a", 0.0, close_time)
	tween.tween_callback(menu.hide)
	if _pausing:
		manager.set_worker_paused(_worker, false)
	_worker = &""
	_anchor = null
	_pausing = false
	_slot = -1
	if day_cycle.phase == DayCycle.Phase.DAY:
		player.input_enabled = true


func _restart_tween(menu: Control) -> Tween:
	if _tweens.has(menu) and _tweens[menu].is_valid():
		_tweens[menu].kill()
	_tweens[menu] = menu.create_tween()
	return _tweens[menu]


func _order(worker: StringName, item: StringName) -> void:
	if _worker != worker: # a click on a menu that's fading out
		return
	if manager.place_order(worker, item, _slot):
		get_tree().call_group(&"world", &"mark_unsaved")
		if not manager.has_free_slot(worker):
			close() # every slot is taken: nothing more to order
		elif Input.is_physical_key_pressed(KEY_SHIFT):
			_slot = -1 # further orders go to the next free slot
		else:
			close()


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and (event.is_action_pressed(&"interact") or event.is_action_pressed(&"pause")):
		get_viewport().set_input_as_handled()
		close()


func _process(_delta: float) -> void:
	if not is_open():
		return
	if not is_instance_valid(_anchor):
		close()
		return
	_refresh()
	_place()


## Speech bubble with its tip over the anchor, kept on screen.
func _place() -> void:
	var menu: Control = menus[_worker]
	var panel: Control = menu.get_node("Panel")
	var tip: Control = menu.get_node("Tip")
	panel.reset_size()
	menu.size = panel.size + Vector2(0.0, tip.size.y if tip.visible else 0.0)
	tip.position = Vector2((panel.size.x - tip.size.x) / 2.0, panel.size.y - 3.0)
	var screen := get_viewport().get_visible_rect()
	var cam := get_viewport().get_camera_3d()
	var target := cam.unproject_position(_anchor.menu_anchor()) if cam else screen.size / 2.0
	var area := screen.grow(-screen_margin)
	menu.position = (target - Vector2(menu.size.x / 2.0, menu.size.y)).clamp(area.position, area.end - menu.size)


func _refresh() -> void:
	match _worker:
		&"gwenith":
			for item: StringName in RequestCatalog.FOODS + RequestCatalog.INGREDIENTS:
				var cell := _gwenith_cell(item)
				cell.get_node("Center/Badge").count = manager.stock_of(item)
				_set_enabled(cell, _slot_open(&"gwenith"))
			$Gwenith/Panel/Content/Status.text = "Shift-click to stack orders"
		&"shuyi":
			for medicine: StringName in RequestCatalog.MEDICINES:
				var row := _shuyi_row(medicine)
				var recipe: Array = RequestCatalog.RECIPES[medicine]
				row.get_node("Line/Medicine").count = manager.stock_of(medicine)
				row.get_node("Line/First").show_check = manager.stock_of(recipe[0]) > 0
				row.get_node("Line/Second").show_check = manager.stock_of(recipe[1]) > 0
				_set_enabled(row, manager.can_brew(medicine) and _slot_open(&"shuyi"))
			$Shuyi/Panel/Content/Status.text = "Shift-click to stack orders"
		&"rudrama":
			for i in 3:
				_set_enabled(_rudrama_bubble(i), manager.repair_order.is_empty() and not manager.repair_request_for(i).is_empty())
			$Rudrama/Panel/Content/Status.text = _rudrama_status() + "    E to close"


func _slot_open(worker: StringName) -> bool:
	if _slot >= 0:
		return manager.slot_state(worker, _slot) == SanctuaryManager.SlotState.EMPTY
	return manager.has_free_slot(worker)


func _rudrama_status() -> String:
	var order := manager.repair_order
	match manager.rudrama_state:
		SanctuaryManager.RudramaState.TO_JOB:
			return "Heading to containment %d" % (order.containment + 1)
		SanctuaryManager.RudramaState.WORKING:
			return "Repairing containment %d" % (order.containment + 1)
		SanctuaryManager.RudramaState.RETURNING:
			return "Walking back to the anvil"
	return "Ready at the anvil"


func _set_enabled(button: Button, enabled: bool) -> void:
	button.disabled = not enabled
	button.modulate.a = 1.0 if enabled else dimmed_alpha


func _gwenith_cell(item: StringName) -> Button:
	var row := "FoodRow" if RequestCatalog.FOODS.has(item) else "IngredientRow"
	return get_node("Gwenith/Panel/Content/%s/%s" % [row, item])


func _shuyi_row(medicine: StringName) -> Button:
	return get_node("Shuyi/Panel/Content/Rows/%s" % medicine)


func _rudrama_bubble(index: int) -> Button:
	return get_node("Rudrama/Panel/Content/Bubbles/%d" % (index + 1))
