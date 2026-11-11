class_name PesticideHazard
extends Area3D

var _dps := 5
var _ticks_left := 0
var _owner_boss: Node3D


func configure(radius: float, dps: int, duration: float, boss: Node3D) -> void:
	_dps = dps
	_owner_boss = boss
	(get_node("CollisionShape3D").shape as SphereShape3D).radius = radius

	var tick_timer := Timer.new()
	tick_timer.wait_time = 1.0
	add_child(tick_timer)
	tick_timer.timeout.connect(_tick)
	tick_timer.start()

	var life_timer := get_tree().create_timer(duration)
	life_timer.timeout.connect(queue_free)


func _tick() -> void:
	for body in get_overlapping_bodies():
		if body.has_method("receive_hit") and body != _owner_boss:
			body.receive_hit(_dps)
