class_name BoomerangProjectile
extends Area3D

@onready var shape_cast: ShapeCast3D = $ShapeCast3D

var _direction: Vector3
var _speed: float
var _damage: int
var _bounces_left: int
var _owner_boss: Node3D
var _returning := false
var _already_hit: Array[Node3D] = []


func configure(direction: Vector3, speed: float, damage: int, bounces: int, boss: Node3D) -> void:
	_direction = direction.normalized()
	_speed = speed
	_damage = damage
	_bounces_left = bounces
	_owner_boss = boss
	body_entered.connect(_on_body_entered)

	# environment layer for wall detection — adjust bit to match your actual "environment" layer
	shape_cast.collision_mask = 1 << 1
	shape_cast.target_position = Vector3.ZERO # updated each frame to match travel direction


func _physics_process(delta: float) -> void:
	if _returning:
		var to_boss := _owner_boss.global_position - global_position
		if to_boss.length() < 0.5:
			queue_free()
			return
		_direction = to_boss.normalized()
		global_position += _direction * _speed * delta
		return

	# point the shapecast along current travel direction, scaled to this frame's travel distance
	var step := _direction * _speed * delta
	shape_cast.target_position = (global_transform.affine_inverse() * (global_position + step)) - (global_transform.affine_inverse() * global_position)
	shape_cast.force_shapecast_update()

	if shape_cast.is_colliding():
		var normal := shape_cast.get_collision_normal(0)
		_direction = _direction.bounce(normal)
		_register_bounce()
		# move the remaining distance along the new direction, so it doesn't clip into the wall
		global_position += _direction * _speed * delta
	else:
		global_position += step


func _on_body_entered(body: Node3D) -> void:
	if body == _owner_boss or body in _already_hit:
		return
	if body.has_method("receive_hit"):
		body.receive_hit(_damage)
	_already_hit.append(body)

	# reflect off the body using the direction from the body to this projectile as an approximate normal
	var normal := (global_position - body.global_position).normalized()
	_direction = _direction.bounce(normal)
	_register_bounce()


func _register_bounce() -> void:
	_bounces_left -= 1
	if _bounces_left <= 0:
		_returning = true
