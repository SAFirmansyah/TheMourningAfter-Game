class_name BoomerangShield
extends Node3D
## Rudrama's thrown shield: flies straight, bounces off walls and Perrin a set number of times
## (hurting him on each hit), then flies back to her. A dashing Perrin passes through it.

const HIT_MASK := 135 # world_bounds + environment + player + mob_barrier

@export var radius := 0.45 # TUNE (m)
@export var max_flight_time := 6.0 # TUNE: heads home after this long regardless (s)
@export var spin_speed := 12.0 # TUNE: visual spin (rad/s)

@onready var disc: MeshInstance3D = $Disc

var _boss: BossRudrama
var _direction := Vector3.FORWARD
var _speed := 12.0
var _damage := 30
var _bounces_left := 3
var _returning := false
var _flight_time := 0.0


func configure(boss: BossRudrama, direction: Vector3, speed: float, damage: int, bounces: int) -> void:
	_boss = boss
	_direction = Vector3(direction.x, 0.0, direction.z).normalized()
	_speed = speed
	_damage = damage
	_bounces_left = bounces


func _physics_process(delta: float) -> void:
	disc.rotate_y(spin_speed * delta)
	if not is_instance_valid(_boss):
		queue_free()
		return
	_flight_time += delta
	if _flight_time >= max_flight_time:
		_returning = true
	if _returning:
		var home := _boss.global_position + Vector3.UP * 1.0 - global_position
		if home.length() < 0.8:
			_boss.catch_shield()
			queue_free()
			return
		global_position += home.normalized() * minf(_speed * delta, home.length())
		return
	_fly(_speed * delta)


func _fly(distance: float) -> void:
	var space := get_world_3d().direct_space_state
	var excluded: Array[RID] = [_boss.get_rid()]
	for attempt in 3:
		var ray := PhysicsRayQueryParameters3D.create(global_position, global_position + _direction * (distance + radius), HIT_MASK, excluded)
		var hit := space.intersect_ray(ray)
		if hit.is_empty():
			global_position += _direction * distance
			return
		var body := hit.collider as Node3D
		if body is Player and (body as Player).is_invulnerable:
			excluded.append(hit.rid) # dashing through it
			continue
		if body is Player:
			(body as Player).receive_hit(_damage)
		var normal: Vector3 = hit.normal
		normal.y = 0.0
		if normal.length() < 0.01:
			normal = -_direction
		global_position = hit.position - _direction * radius
		_direction = _direction.bounce(normal.normalized()).normalized()
		_bounces_left -= 1
		if _bounces_left <= 0:
			_returning = true
		return
