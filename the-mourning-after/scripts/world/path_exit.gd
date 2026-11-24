class_name PathExit
extends Area3D
## Path out of a room. Local +X points out of the room.

signal player_entered

@export_file("*.tscn") var target_room := ""
@export var target_entry: StringName = &"" # PathExit node name in the target room
@export_file("*.txt") var cutscene := "" # optional scene script (dialogue/*.txt): plays between leaving and arriving

@onready var spawn_point: Marker3D = $Spawn
@onready var path_mesh: MeshInstance3D = $PathMesh

var _real_target_room := "" # stored while blocked, restored on unblock
var _blocked := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func outward_direction() -> Vector3:
	var dir := global_basis.x
	dir.y = 0.0
	return dir.normalized()
	
func set_blocked(blocked: bool) -> void:
	if blocked == _blocked:
		return
	_blocked = blocked
	if blocked:
		_real_target_room = target_room
		print("blocking exit, stored target_room=", _real_target_room)
		target_room = ""
	else:
		target_room = _real_target_room
		print("unblocking exit, restored target_room=", target_room)


func _on_body_entered(body: Node3D) -> void:
	if body is Player and target_room != "":
		player_entered.emit()
