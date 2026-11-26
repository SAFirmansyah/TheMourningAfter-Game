class_name PathExit
extends Area3D
## Path out of a room. Local +X points out of the room.

signal player_entered

@export_file("*.tscn") var target_room := ""
@export var target_entry: StringName = &"" # PathExit node name in the target room
@export_file("*.txt") var cutscene := "" # optional scene script (dialogue/*.txt): plays between leaving and arriving

@onready var spawn_point: Marker3D = $Spawn
@onready var path_mesh: MeshInstance3D = $PathMesh

var _blocked := false # shut for now: walking in does nothing (target_room is left alone, so it can still be set meanwhile)


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func outward_direction() -> Vector3:
	var dir := global_basis.x
	dir.y = 0.0
	return dir.normalized()


func set_blocked(blocked: bool) -> void:
	_blocked = blocked


func is_blocked() -> bool:
	return _blocked


func _on_body_entered(body: Node3D) -> void:
	if body is Player and target_room != "" and not _blocked:
		player_entered.emit()
