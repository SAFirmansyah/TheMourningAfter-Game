class_name Hitbox
extends Area3D
## Reusable melee hitbox. Spawned fresh per attack, lives for hitbox_lifetime,
## then frees itself. Collision side (hero vs enemy) comes from atk_stat.unit_type.

signal hit_landed(body: Node3D)

@export var ignore_root: Node3D # so the wielder can't hit themselves

var atk_stat: Stats
var hitbox_lifetime: float

var _active := false
var _already_hit: Array[Node3D] = []


func _init(_atk_stat: Stats = null, _shape: Shape3D = null, _hitbox_lifetime: float = 0.0) -> void:
	atk_stat = _atk_stat
	hitbox_lifetime = _hitbox_lifetime
	if _shape:
		var collision_shape := CollisionShape3D.new()
		collision_shape.shape = _shape
		add_child(collision_shape)


func _ready() -> void:
	monitorable = false
	body_entered.connect(_on_body_entered)

	set_collision_layer_value(5, false)
	set_collision_mask_value(4, false)
	match atk_stat.unit_type:
		Stats.UnitType.HERO:
			set_collision_mask_value(4, true)
		Stats.UnitType.ENEMY:
			set_collision_mask_value(3, true)

	if hitbox_lifetime > 0.0:
		var timer := Timer.new()
		timer.one_shot = true
		add_child(timer)
		timer.timeout.connect(queue_free)
		timer.start(hitbox_lifetime)

	activate()


func activate() -> void:
	_already_hit.clear()
	_active = true
	monitoring = true


func deactivate() -> void:
	_active = false
	monitoring = false


func _on_body_entered(body: Node3D) -> void:
	if not _active:
		return
	if body == ignore_root or body in _already_hit:
		return
	if ignore_root and body.is_ancestor_of(ignore_root):
		return
	if not body.has_method("receive_hit"):
		return
	_already_hit.append(body)
	body.receive_hit(atk_stat.damage)
	hit_landed.emit(body)
