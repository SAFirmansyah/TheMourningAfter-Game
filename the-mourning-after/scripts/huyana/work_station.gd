@tool
class_name WorkStation
extends Node3D
## Gwenith's or Shuyi's station. Its child OrderPoints are the order slots, spread along the
## station: empty -> "Order", ready -> "Collect", in progress -> no prompt. Order bubbles sit above each slot.

@export_enum("gwenith", "shuyi") var worker := "gwenith":
	set(value):
		worker = value
		_place_slots()
@export var slot_spacing := 2.2: # TUNE: distance between slots along the station (m)
	set(value):
		slot_spacing = value
		_place_slots()
@export var slot_depth := 0.0: # TUNE: how far in front of the station's centre each slot's E range sits (m); 0 = reachable from front and back
	set(value):
		slot_depth = value
		_place_slots()
@export var bubble_height := 5.0 # TUNE: height of the order bubbles above the floor (m)
@export var menu_height := 6.4 # TUNE: height of the order menu's tip above the floor (m)


func _ready() -> void:
	_place_slots()
	if not Engine.is_editor_hint():
		add_to_group(&"work_station")


func slots() -> Array[OrderPoint]:
	var result: Array[OrderPoint] = []
	for child in get_children():
		if child is OrderPoint:
			result.append(child)
	return result


func bubble_position(slot: int) -> Vector3:
	return global_position + Vector3(_slot_x(slot), bubble_height, 0.0)


func menu_anchor() -> Vector3:
	return global_position + Vector3(0.0, menu_height, 0.0)


func _slot_x(slot: int) -> float:
	return (slot - (slots().size() - 1) / 2.0) * slot_spacing


func _place_slots() -> void:
	if not is_node_ready():
		return
	var points := slots()
	for i in points.size():
		points[i].worker = worker
		points[i].slot = i
		points[i].station = self
		points[i].position = Vector3(_slot_x(i), 0.0, slot_depth)
