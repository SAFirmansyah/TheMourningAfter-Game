class_name VineHazard
extends Node3D
## Ensnared vine patch: shows on the ground, then erupts. Perrin standing in it takes damage,
## is rooted, and Gwenith comes for him. Dashing through it at the moment of eruption escapes.

@export var erupted_time := 0.5 # TUNE: how long the erupted vines stay visible (s)

@onready var warning: MeshInstance3D = $Warning
@onready var vines: MeshInstance3D = $Vines

var _boss: BossGwenith
var _player: Player
var _radius := 1.6
var _warning_left := 5.0
var _root_time := 5.0
var _damage := 5
var _erupted := false


func configure(boss: BossGwenith, player: Player, radius: float, warning_time: float, root_time: float, damage: int) -> void:
	_boss = boss
	_player = player
	_radius = radius
	_warning_left = warning_time
	_root_time = root_time
	_damage = damage
	warning.scale = Vector3(radius, 1.0, radius)
	vines.scale = Vector3(radius, 1.0, radius)
	vines.hide()


func _physics_process(delta: float) -> void:
	_warning_left -= delta
	if not _erupted:
		warning.transparency = 0.3 + 0.3 * sin(_warning_left * TAU) # pulses while waiting
		if _warning_left <= 0.0:
			_erupt()
	elif _warning_left <= -erupted_time:
		queue_free()


func _erupt() -> void:
	_erupted = true
	warning.hide()
	vines.show()
	if not is_instance_valid(_player) or _player.is_invulnerable or _player.is_stunned():
		return
	var offset := _player.global_position - global_position
	offset.y = 0.0
	if offset.length() > _radius:
		return
	_player.receive_hit(_damage)
	_player.apply_stun(_root_time)
	if is_instance_valid(_boss):
		_boss.on_player_ensnared()
