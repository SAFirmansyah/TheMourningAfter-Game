class_name SanctuaryManager
extends Node
## Sanctuary state: health, containment requests, stock, worker orders and Rudrama's repair rounds.
## Lives on the world (not the room) so everything keeps running while Constance is in the Altar.
## Requests, orders and the workers' walking all run during the day at the day cycle's speed.
## When Gwenith and Shuyi have nothing in progress they sometimes wander over to the campfire, and
## each day starts with them heading there. Their orders only progress while they're at their station.
## Everyone walks along gently curving paths, easing in and out of each walk.
## Autosaves whenever a request is fulfilled or expires, and at every night.
## Health milestones (75/50/25/0) each unlock a story event: a day's losses stop at the next milestone,
## its event plays after that night's results, and missed requests cost more after each one.

signal health_changed(health: float)
signal request_added(request: Dictionary)
signal request_removed(id: int, fulfilled: bool)
signal order_removed(id: int)

enum SlotState { EMPTY, PREPARING, READY }

enum RudramaState { HOME, TO_JOB, WORKING, RETURNING }
enum WanderState { HOME, TO_FIRE, AT_FIRE, RETURNING }

const MILESTONES := [75.0, 50.0, 25.0, 0.0]
const STORY_EVENTS: Array[StringName] = [&"gwenith", &"shuyi", &"rudrama", &"fates"] # one per milestone

@export var world: World
@export var day_cycle: DayCycle
@export_range(0.0, 100.0) var health := 100.0
@export var containment_foods: Array[StringName] = [&"infused_dew", &"willow_bark", &"graceroot"] # food asked for by containment 1, 2, 3

@export_group("Requests")
@export var max_requests := 2 # per containment; one per slot (0 = left end, 1 = right end)
@export var spawn_interval_min := 12.0 # TUNE: shortest wait before a containment asks for something new (s)
@export var spawn_interval_max := 30.0 # TUNE: longest wait before a containment asks for something new (s)
@export var food_weight := 0.55 # TUNE: chance weight of a new request being food
@export var medicine_weight := 0.2 # TUNE: chance weight of a new request being medicine
@export var repair_weight := 0.25 # TUNE: chance weight of a new request being a repair
@export var food_duration := 60.0 # TUNE: seconds to fulfil a food request
@export var medicine_duration := 120.0 # TUNE: seconds to fulfil a medicine request
@export var repair_durations := PackedFloat32Array([20.0, 25.0, 30.0]) # TUNE: seconds to fix a repair request, by urgency
@export var expiry_penalties := PackedFloat32Array([0.4, 0.5, 0.9, 1.5]) # TUNE: sanctuary health lost per expired request (%), by story events reached (0, 1, 2, 3+)

@export_group("Orders")
@export var grow_times := { # TUNE: seconds Gwenith takes to grow each item
	&"infused_dew": 30.0,
	&"willow_bark": 15.0,
	&"graceroot": 45.0,
	&"bloodflower": 45.0,
	&"obsidian_grass": 30.0,
	&"pearls_of_night": 65.0,
}
@export var brew_time := 20.0 # TUNE: seconds Shuyi takes to make one medicine
@export var order_slots := {&"gwenith": 3, &"shuyi": 2} # TUNE: orders each worker can hold at once (one per station slot; Rudrama always takes one repair)
@export var repair_order_time := 10.0 # TUNE: seconds Rudrama spends repairing once she arrives
@export var rudrama_speed := 5.0 # TUNE: Rudrama's walking speed at 1x (m/s); matches the player
@export var rudrama_home := Vector3(8.25, 0.0, -6.667) # where Rudrama waits by the anvil
@export_group("Wandering")
@export var worker_homes := {&"gwenith": Vector3(6.0, 0.0, 7.333), &"shuyi": Vector3(-5.7, 0.0, 8.0)} # where Gwenith and Shuyi stand at their stations
@export var campfire_spot := Vector3(0.0, 0.0, -0.333) # centre of the campfire
@export var campfire_stand_radius := 3.2 # TUNE: how far from the campfire's centre wanderers stand (m)
@export var wander_check_min := 15.0 # TUNE: shortest wait at the station before maybe wandering off (s)
@export var wander_check_max := 35.0 # TUNE: longest wait at the station before maybe wandering off (s)
@export var wander_chance := 0.5 # TUNE: chance she heads to the campfire at each check
@export var fire_stay_min := 15.0 # TUNE: shortest stay at the campfire (s)
@export var fire_stay_max := 40.0 # TUNE: longest stay at the campfire (s)
@export var worker_speed := 5.0 # TUNE: Gwenith's and Shuyi's walking speed at 1x (m/s); matches the player
@export var day_start_wander_delay := 6.0 # TUNE: longest wait after dawn before each heads to the campfire (s)
@export_group("Walking")
@export var walk_curve := 0.35 # TUNE: largest sideways bend of a walk, as a fraction of its length
@export var walk_curve_max := 3.0 # TUNE: largest sideways bend of a walk (m)
@export var walk_ease_distance := 0.8 # TUNE: distance over which walkers speed up / slow down (m)
@export var walk_ease_min := 0.3 # TUNE: walking pace at the very start and end of a walk (fraction of full speed)
@export var walk_pace_variation := 0.12 # TUNE: random pace difference between walks (fraction of full speed)
@export var walk_bounds := Rect2(-14.0, -8.4, 28.0, 17.4) # TUNE: floor area (x, z) paths bend within; keeps them off the containments
@export_group("Orders")
@export var repair_spots := PackedVector3Array([Vector3(-11.583, 0.0, -8.333), Vector3(-5.333, 0.0, -8.333), Vector3(0.917, 0.0, -8.333)]) # where Rudrama stands to repair containment 1, 2, 3

## Each request: {id, containment (0-based), slot (0 left / 1 right), item, duration, time_left}
var requests: Array[Dictionary] = []
## Active repair: {request_id, containment, progress (0-1)}; empty when Rudrama is free.
## Progress only starts once she has walked to the containment.
var repair_order := {}
## Items Constance has collected and can hand over: item -> count.
var stock := {}
## Order slots per worker, all worked on at once. Each is {} (free) or {id, item, progress, ready};
## finished items wait in their slot until collected.
var orders := {&"gwenith": [], &"shuyi": []}
var rudrama_position := Vector3.ZERO
var rudrama_state := RudramaState.HOME
## Story events reached so far (milestones crossed), and the one waiting to play after tonight's results.
var story_events_reached := 0
var pending_story_event: StringName = &""
## Not saved: Gwenith's and Shuyi's walking, {position, state, target, timer, eager, route}; they start each load at home.
var wanderers := {}
## Not saved: a worker stops walking while her own order menu is open.
var paused_workers := {}
## UI only, not saved: ids of requests shown expanded.
var expanded := {}

var _spawn_timers := PackedFloat32Array()
var _next_id := 1
var _next_order_id := 1
var _rudrama_route := {}


func _enter_tree() -> void:
	add_to_group(&"sanctuary_manager")
	add_to_group(&"save_state")
	rudrama_position = rudrama_home
	for worker in worker_homes:
		wanderers[worker] = {"position": worker_homes[worker], "state": WanderState.HOME, "target": worker_homes[worker], "timer": randf_range(wander_check_min, wander_check_max), "eager": false, "route": {}}


func _ready() -> void:
	for worker in orders:
		orders[worker] = _empty_slots(worker)
	for i in containment_foods.size():
		_spawn_timers.append(randf_range(spawn_interval_min * 0.25, spawn_interval_max * 0.5))
	day_cycle.night_started.connect(_on_night_started)
	day_cycle.day_started.connect(_on_day_started)
	if day_cycle.phase == DayCycle.Phase.DAY and day_cycle.elapsed == 0.0:
		_on_day_started(day_cycle.day) # the day cycle announced the first day before this was ready


func _process(delta: float) -> void:
	if day_cycle.phase != DayCycle.Phase.DAY:
		return
	var dt := delta * day_cycle.speed
	var changed := false

	for i in _spawn_timers.size():
		_spawn_timers[i] -= dt
		if _spawn_timers[i] <= 0.0:
			_spawn_timers[i] = randf_range(spawn_interval_min, spawn_interval_max)
			_try_spawn(i)

	_work_orders(&"gwenith", dt)
	_work_orders(&"shuyi", dt)
	_update_wanderers(dt)
	if _update_rudrama(dt):
		changed = true

	for request in requests.duplicate():
		request.time_left -= dt
		if request.time_left <= 0.0:
			_expire(request)
			changed = true

	if changed:
		world.save_game()


# --- Requests ------------------------------------------------------------------------------------

func request_at(containment: int, slot: int) -> Dictionary:
	for request in requests:
		if request.containment == containment and request.slot == slot:
			return request
	return {}


func requests_for(containment: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for request in requests:
		if request.containment == containment:
			result.append(request)
	return result


## Checkmark condition. Repairs: Rudrama is free to take the order. Food/medicine: it's in stock.
func is_fulfillable(request: Dictionary) -> bool:
	if request.item == RequestCatalog.REPAIR:
		return repair_order.is_empty()
	return stock_of(request.item) > 0


func repair_progress(request: Dictionary) -> float:
	return repair_order.progress if repair_order.get("request_id", -1) == request.id else -1.0


## Constance presses E at one end of a containment: hand over the item if it's in stock,
## otherwise expand/collapse the request to show where it comes from. Repairs are ordered from Rudrama.
func interact(containment: int, slot: int) -> void:
	var request := request_at(containment, slot)
	if request.is_empty():
		return
	if request.item != RequestCatalog.REPAIR and stock_of(request.item) > 0:
		stock[request.item] -= 1
		_remove(request, true)
		world.save_game()
	elif expanded.has(request.id):
		expanded.erase(request.id)
	else:
		expanded[request.id] = true


func collapse(containment: int, slot: int) -> void:
	expanded.erase(request_at(containment, slot).get("id", -1))


func set_health(value: float) -> void:
	health = clampf(value, 0.0, 100.0)
	health_changed.emit(health)


# --- Stock and orders ----------------------------------------------------------------------------

func stock_of(item: StringName) -> int:
	return stock.get(item, 0)


func slot_state(worker: StringName, slot: int) -> SlotState:
	var order: Dictionary = orders[worker][slot]
	if order.is_empty():
		return SlotState.EMPTY
	return SlotState.READY if order.ready else SlotState.PREPARING


func free_slot(worker: StringName) -> int:
	return orders[worker].find({})


func has_free_slot(worker: StringName) -> bool:
	return free_slot(worker) >= 0


func can_brew(medicine: StringName) -> bool:
	return RequestCatalog.RECIPES[medicine].all(func(ingredient: StringName) -> bool: return stock_of(ingredient) > 0)


## Places an order in the given station slot (or the first free one). Shuyi uses up the two
## ingredients straight away.
func place_order(worker: StringName, item: StringName, slot := -1) -> bool:
	if slot < 0:
		slot = free_slot(worker)
	if slot < 0 or slot_state(worker, slot) != SlotState.EMPTY:
		return false
	if worker == &"shuyi":
		if not can_brew(item):
			return false
		for ingredient: StringName in RequestCatalog.RECIPES[item]:
			stock[ingredient] -= 1
	orders[worker][slot] = {"id": _next_order_id, "item": item, "progress": 0.0, "ready": false}
	_next_order_id += 1
	return true


## Picks up a finished order into Constance's stock.
func collect(worker: StringName, slot: int) -> bool:
	if slot_state(worker, slot) != SlotState.READY:
		return false
	var order: Dictionary = orders[worker][slot]
	stock[order.item] = stock_of(order.item) + 1
	orders[worker][slot] = {}
	order_removed.emit(order.id)
	return true


## The repair request at a containment that Rudrama could be sent to, if any.
func repair_request_for(containment: int) -> Dictionary:
	for request in requests_for(containment):
		if request.item == RequestCatalog.REPAIR:
			return request
	return {}


func order_repair(containment: int) -> bool:
	var request := repair_request_for(containment)
	if request.is_empty() or not repair_order.is_empty():
		return false
	repair_order = {"request_id": request.id, "containment": containment, "progress": 0.0}
	rudrama_state = RudramaState.TO_JOB
	return true


func order_time(worker: StringName, item: StringName) -> float:
	return grow_times.get(item, 30.0) if worker == &"gwenith" else brew_time


func _work_orders(worker: StringName, dt: float) -> void:
	if wanderers[worker].state != WanderState.HOME:
		return
	for order: Dictionary in orders[worker]:
		if order.is_empty() or order.ready:
			continue
		order.progress = minf(order.progress + dt / order_time(worker, order.item), 1.0)
		order.ready = order.progress >= 1.0


# --- Rudrama -------------------------------------------------------------------------------------

## Returns true when a repair finished this frame.
func _update_rudrama(dt: float) -> bool:
	match rudrama_state:
		RudramaState.TO_JOB:
			if _walk_rudrama(repair_spots[repair_order.containment], dt):
				rudrama_state = RudramaState.WORKING
		RudramaState.WORKING:
			repair_order.progress += dt / repair_order_time
			if repair_order.progress >= 1.0:
				var done := _find(repair_order.request_id)
				repair_order = {}
				rudrama_state = RudramaState.RETURNING
				if not done.is_empty():
					_remove(done, true)
					return true
		RudramaState.RETURNING:
			if _walk_rudrama(rudrama_home, dt):
				rudrama_state = RudramaState.HOME
	return false


## Moves Rudrama toward a point; returns true once she's there.
func _walk_rudrama(target: Vector3, dt: float) -> bool:
	if paused_workers.has(&"rudrama"):
		return false
	var walker := {"position": rudrama_position, "route": _rudrama_route}
	var arrived := _step_along(walker, target, rudrama_speed, dt)
	rudrama_position = walker.position
	_rudrama_route = walker.route
	return arrived


# --- Gwenith and Shuyi -----------------------------------------------------------------------------

func worker_position(worker: StringName) -> Vector3:
	return rudrama_position if worker == &"rudrama" else wanderers[worker].position


func set_worker_paused(worker: StringName, paused: bool) -> void:
	if paused:
		paused_workers[worker] = true
	else:
		paused_workers.erase(worker)


func _update_wanderers(dt: float) -> void:
	for worker: StringName in wanderers:
		var w: Dictionary = wanderers[worker]
		var busy: bool = orders[worker].any(func(o: Dictionary) -> bool: return not o.is_empty() and not o.ready)
		match w.state:
			WanderState.HOME:
				w.timer -= dt
				if w.timer <= 0.0:
					w.timer = randf_range(wander_check_min, wander_check_max)
					var eager: bool = w.eager
					w.eager = false
					if not busy and (eager or randf() < wander_chance):
						w.target = _fire_spot(worker)
						w.state = WanderState.TO_FIRE
			WanderState.TO_FIRE:
				if busy:
					w.state = WanderState.RETURNING
				elif _walk_worker(worker, w.target, dt):
					w.state = WanderState.AT_FIRE
					w.timer = randf_range(fire_stay_min, fire_stay_max)
			WanderState.AT_FIRE:
				w.timer -= dt
				if busy or w.timer <= 0.0:
					w.state = WanderState.RETURNING
			WanderState.RETURNING:
				if _walk_worker(worker, worker_homes[worker], dt):
					w.state = WanderState.HOME
					w.timer = randf_range(wander_check_min, wander_check_max)


## A spot on the campfire's near side (relative to her station), clear of the other wanderer.
func _fire_spot(worker: StringName) -> Vector3:
	var home: Vector3 = worker_homes[worker]
	var base := atan2(home.z - campfire_spot.z, home.x - campfire_spot.x)
	var spot := campfire_spot
	for attempt in 6:
		var angle := base + randf_range(-1.0, 1.0)
		spot = campfire_spot + Vector3(cos(angle), 0.0, sin(angle)) * campfire_stand_radius
		var clear := true
		for other: StringName in wanderers:
			if other != worker and wanderers[other].target.distance_to(spot) < 1.4:
				clear = false
		if clear:
			break
	return spot


func _walk_worker(worker: StringName, target: Vector3, dt: float) -> bool:
	if paused_workers.has(worker):
		return false
	return _step_along(wanderers[worker], target, worker_speed, dt)


## Moves a walker ({position, route}) toward a point along a gently curved path, easing in and out;
## returns true once it's there. A new target starts a new path from wherever the walker is.
func _step_along(walker: Dictionary, target: Vector3, speed: float, dt: float) -> bool:
	var route: Dictionary = walker.route
	if route.is_empty() or not route.to.is_equal_approx(target):
		route = _plan_route(walker.position, target)
		walker.route = route
	if route.travelled >= route.length:
		walker.position = target
		walker.route = {}
		return true
	var edge: float = minf(route.travelled, route.length - route.travelled)
	var pace: float = lerpf(walk_ease_min, 1.0, clampf(edge / walk_ease_distance, 0.0, 1.0)) * route.pace
	route.travelled = minf(route.travelled + speed * pace * dt, route.length)
	var t: float = route.travelled / route.length
	var from: Vector3 = route.from
	var bend: Vector3 = route.bend
	walker.position = from.lerp(bend, t).lerp(bend.lerp(target, t), t)
	return false


func _plan_route(from: Vector3, to: Vector3) -> Dictionary:
	var length := from.distance_to(to)
	var bend := from.lerp(to, 0.5)
	if length > 0.01:
		var side := (to - from).normalized().cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
		bend += side * minf(randf_range(0.2, 1.0) * walk_curve * length, walk_curve_max)
		bend.x = clampf(bend.x, walk_bounds.position.x, walk_bounds.end.x)
		bend.z = clampf(bend.z, walk_bounds.position.y, walk_bounds.end.y)
		length = (from.distance_to(bend) + bend.distance_to(to) + length) / 2.0 # close to the curve's length
	return {"from": from, "to": to, "bend": bend, "length": length, "travelled": 0.0, "pace": 1.0 + randf_range(-walk_pace_variation, walk_pace_variation)}


func _cancel_repair() -> void:
	repair_order = {}
	if rudrama_state != RudramaState.HOME:
		rudrama_state = RudramaState.RETURNING


# --- Night, saving -------------------------------------------------------------------------------

## Requests don't carry over: anything still open at nightfall counts as missed.
## Orders do: whatever is still on Gwenith's or Shuyi's station is finished and goes into stock.
## Sanctuary Health is rounded up to a whole number for the night, then raised back to the next
## milestone if the day crossed it, which queues that milestone's story event.
func _on_night_started(_day: int) -> void:
	for request in requests.duplicate():
		_expire(request)
	set_health(ceilf(health))
	if story_events_reached < MILESTONES.size() and health <= MILESTONES[story_events_reached]:
		set_health(MILESTONES[story_events_reached])
		pending_story_event = STORY_EVENTS[story_events_reached]
		story_events_reached += 1
	for worker in orders:
		var slots: Array = orders[worker]
		for slot in slots.size():
			var order: Dictionary = slots[slot]
			if order.is_empty():
				continue
			stock[order.item] = stock_of(order.item) + 1
			slots[slot] = {}
			order_removed.emit(order.id)
	repair_order = {}
	rudrama_state = RudramaState.HOME
	rudrama_position = rudrama_home
	_rudrama_route = {}
	for worker: StringName in wanderers:
		wanderers[worker].position = worker_homes[worker]
		wanderers[worker].state = WanderState.HOME
		wanderers[worker].route = {}
	world.save_game()


## Each day starts with Gwenith and Shuyi drifting over to the campfire unless they're given work first.
func _on_day_started(_day: int) -> void:
	for worker: StringName in wanderers:
		var w: Dictionary = wanderers[worker]
		if w.state == WanderState.HOME:
			w.eager = true
			w.timer = randf_range(0.5, day_start_wander_delay)


func get_save_data() -> Dictionary:
	return {
		"health": health,
		"requests": requests,
		"repair_order": repair_order,
		"stock": stock,
		"orders": orders,
		"next_order_id": _next_order_id,
		"rudrama_position": [rudrama_position.x, rudrama_position.y, rudrama_position.z],
		"rudrama_state": rudrama_state,
		"spawn_timers": Array(_spawn_timers),
		"next_id": _next_id,
		"story_events_reached": story_events_reached,
		"pending_story_event": pending_story_event,
	}


func load_save_data(data: Dictionary) -> void:
	set_health(data.get("health", health))
	requests.clear()
	for request: Dictionary in data.get("requests", []):
		request.id = int(request.id)
		request.containment = int(request.containment)
		request.item = StringName(request.item)
		request.slot = int(request.get("slot", -1))
		if request.slot < 0 or not request_at(request.containment, request.slot).is_empty():
			request.slot = _free_slot(request.containment)
		requests.append(request)
	repair_order = data.get("repair_order", {})
	if not repair_order.is_empty():
		repair_order.request_id = int(repair_order.request_id)
		repair_order.containment = int(repair_order.get("containment", _find(repair_order.request_id).get("containment", 0)))
	stock.clear()
	var saved_stock: Dictionary = data.get("stock", {})
	for item: String in saved_stock:
		stock[StringName(item)] = int(saved_stock[item])
	_next_order_id = int(data.get("next_order_id", _next_order_id))
	var saved_orders: Dictionary = data.get("orders", {})
	for worker: String in saved_orders:
		var slots := _empty_slots(StringName(worker))
		var i := 0
		for order: Dictionary in saved_orders[worker]:
			if i >= slots.size():
				break
			if not order.is_empty():
				slots[i] = {"id": int(order.get("id", _next_order_id)), "item": StringName(order.item), "progress": float(order.progress), "ready": bool(order.get("ready", false))}
				_next_order_id = maxi(_next_order_id, slots[i].id + 1)
			i += 1
		orders[StringName(worker)] = slots
	var pos: Array = data.get("rudrama_position", [])
	if pos.size() == 3:
		rudrama_position = Vector3(pos[0], pos[1], pos[2])
	rudrama_state = int(data.get("rudrama_state", RudramaState.HOME)) as RudramaState
	if repair_order.is_empty() and rudrama_state in [RudramaState.TO_JOB, RudramaState.WORKING]:
		rudrama_state = RudramaState.RETURNING
	var timers: Array = data.get("spawn_timers", [])
	for i in mini(timers.size(), _spawn_timers.size()):
		_spawn_timers[i] = timers[i]
	_next_id = int(data.get("next_id", _next_id))
	story_events_reached = int(data.get("story_events_reached", story_events_reached))
	pending_story_event = StringName(data.get("pending_story_event", pending_story_event))


# --- Internals -----------------------------------------------------------------------------------

func _try_spawn(containment: int) -> void:
	var current := requests_for(containment)
	var slot := _free_slot(containment)
	if current.size() >= max_requests or slot < 0:
		return
	var taken := current.map(func(r: Dictionary) -> int: return RequestCatalog.info(r.item).kind)
	# Only requests that can run their full time before nightfall.
	var daylight_left := day_cycle.day_length - day_cycle.elapsed
	var repair_fits := Array(repair_durations).filter(func(d: float) -> bool: return d <= daylight_left)
	var options := {}
	if not taken.has(RequestCatalog.Kind.FOOD) and food_duration <= daylight_left:
		options[RequestCatalog.Kind.FOOD] = food_weight
	if not taken.has(RequestCatalog.Kind.MEDICINE) and medicine_duration <= daylight_left:
		options[RequestCatalog.Kind.MEDICINE] = medicine_weight
	if not taken.has(RequestCatalog.Kind.REPAIR) and not repair_fits.is_empty():
		options[RequestCatalog.Kind.REPAIR] = repair_weight
	if options.is_empty():
		return
	var kind: int = _weighted_pick(options)
	var item: StringName
	var duration: float
	match kind:
		RequestCatalog.Kind.FOOD:
			item = containment_foods[containment]
			duration = food_duration
		RequestCatalog.Kind.MEDICINE:
			item = RequestCatalog.MEDICINES.pick_random()
			duration = medicine_duration
		_:
			item = RequestCatalog.REPAIR
			duration = repair_fits.pick_random()
	var request := {
		"id": _next_id,
		"containment": containment,
		"slot": slot,
		"item": item,
		"duration": duration,
		"time_left": duration,
	}
	requests.append(request)
	_next_id += 1
	request_added.emit(request)


func _empty_slots(worker: StringName) -> Array:
	var slots := []
	for i in order_slots[worker]:
		slots.append({})
	return slots


func _expire(request: Dictionary) -> void:
	if repair_order.get("request_id", -1) == request.id:
		_cancel_repair()
	_remove(request, false)
	set_health(health - expiry_penalty())


func expiry_penalty() -> float:
	return expiry_penalties[mini(story_events_reached, expiry_penalties.size() - 1)]


func _free_slot(containment: int) -> int:
	for slot in max_requests:
		if request_at(containment, slot).is_empty():
			return slot
	return -1


func _weighted_pick(options: Dictionary) -> int:
	var total := 0.0
	for weight: float in options.values():
		total += weight
	var roll := randf() * total
	for kind: int in options:
		roll -= options[kind]
		if roll <= 0.0:
			return kind
	return options.keys().back()


func _find(id: int) -> Dictionary:
	for request in requests:
		if request.id == id:
			return request
	return {}


func _remove(request: Dictionary, fulfilled: bool) -> void:
	requests.erase(request)
	expanded.erase(request.id)
	request_removed.emit(request.id, fulfilled)
