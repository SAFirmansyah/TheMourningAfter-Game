class_name PesticideHazard
extends Node3D
## Gwenith's spilled pesticide: hurts Perrin for every full second he spends standing in it.

@onready var puddle: MeshInstance3D = $Puddle

var _player: Player
var _radius := 2.0
var _dps := 5
var _time_left := 3.0
var _time_inside := 0.0


func configure(player: Player, radius: float, dps: int, duration: float) -> void:
	_player = player
	_radius = radius
	_dps = dps
	_time_left = duration
	puddle.scale = Vector3(radius, 1.0, radius)


func _physics_process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()
		return
	if not is_instance_valid(_player):
		return
	var offset := _player.global_position - global_position
	offset.y = 0.0
	if offset.length() > _radius:
		return
	_time_inside += delta
	if _time_inside >= 1.0:
		_time_inside -= 1.0
		_player.receive_hit(_dps)
