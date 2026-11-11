class_name VineHazard
extends Area3D

@export var telegraph_duration := 3.0
@export var erupted_lifetime := 0.3 # TUNE: how long the erupted-but-missed vines linger visually before despawning
@onready var warning_decal: Node3D = $WarningDecal

var _boss: Node3D
var _player: Node3D
var _following := true


func configure(boss: Node3D, player: Node3D) -> void:
	_boss = boss
	_player = player

	monitoring = false
	if warning_decal:
		warning_decal.visible = true
	global_position = _player.global_position

	var telegraph_timer := get_tree().create_timer(telegraph_duration)
	telegraph_timer.timeout.connect(_erupt)


func _physics_process(_delta: float) -> void:
	if _following and is_instance_valid(_player):
		global_position = _player.global_position


func _erupt() -> void:
	_following = false
	if warning_decal:
		warning_decal.visible = false

	monitoring = true
	await get_tree().physics_frame # let the engine register the new overlap state for one frame
	var overlapping := get_overlapping_bodies()

	if _player in overlapping:
		_boss.begin_grab(_player)
		queue_free()
	else:
		get_tree().create_timer(erupted_lifetime).timeout.connect(queue_free)
