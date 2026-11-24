@tool
class_name Containment
extends Obstacle
## Mutant containment facade with a request slot at each end. Requests show on the request branch;
## E near an end hands over what that slot's request needs, once it's in stock. On the wall layer, so dashes can't pass through.

@export_range(1, 3) var number := 1 # which containment this is (1 = leftmost); also picks its food
@export var bubble_height := 4.4 # TUNE: height the tutorial's arrow points at above a slot (m)
@export var slot_offset := 2.2: # TUNE: distance of each request slot from the facade's centre (m)
	set(value):
		slot_offset = value
		_place_slots()

@onready var slots: Array[Interactable] = [$SlotLeft, $SlotRight]

var _manager: SanctuaryManager


func _ready() -> void:
	super()
	_place_slots()
	if Engine.is_editor_hint():
		return
	add_to_group(&"containment")
	_manager = get_tree().get_first_node_in_group(&"sanctuary_manager")
	for i in slots.size():
		slots[i].interacted.connect(func() -> void:
			if _manager:
				_manager.interact(number - 1, i))


func _process(delta: float) -> void:
	super(delta)
	if Engine.is_editor_hint() or _manager == null:
		return
	for i in slots.size():
		var request := _manager.request_at(number - 1, i)
		var hand_over: bool = not request.is_empty() and request.item != RequestCatalog.REPAIR and _manager.is_fulfillable(request)
		slots[i].enabled = hand_over
		slots[i].prompt_label = "Fulfill"


func slot_bubble_position(slot: int) -> Vector3:
	return global_position + Vector3((slot * 2 - 1) * slot_offset, bubble_height, 0.0)


func _place_slots() -> void:
	if not is_node_ready():
		return
	for i in slots.size():
		slots[i].position.x = (i * 2 - 1) * slot_offset
