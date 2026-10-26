class_name Hitbox
extends Area3D
## Reusable melee hitbox. Collision side (hero vs enemy) comes from unit_type.
## hit_log is optional: pass a shared HitLog when multiple hitboxes from the
## same attack should treat a target as "already hit" across all of them.

signal hit_landed(body: Node3D)

@export var ignore_root: Node3D # so the wielder can't hit themselves

var damage: int = 0
var unit_type: Stats.UnitType = Stats.UnitType.HERO
var hit_log: HitLog
var hitbox_lifetime: float = 0.3 # TUNE: how long this hitbox exists before auto-freeing

var _active := false


func _ready() -> void:
	monitorable = false
	body_entered.connect(_on_body_entered)

	if hit_log == null:
		hit_log = HitLog.new()

	set_collision_layer_value(5, false)
	set_collision_mask_value(4, false)
	match unit_type:
		Stats.UnitType.HERO:
			set_collision_mask_value(4, true)
		Stats.UnitType.ENEMY:
			set_collision_mask_value(3, true)

	activate()
	
	var timer := Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(queue_free)
	timer.start(hitbox_lifetime)


func activate() -> void:
	_active = true
	monitoring = true


func deactivate() -> void:
	_active = false
	monitoring = false


func _on_body_entered(body: Node3D) -> void:
	if not _active:
		return
	if body == ignore_root:
		return
	if ignore_root and body.is_ancestor_of(ignore_root):
		return
	if hit_log.has_hit(body):
		return
	if not body.has_method("receive_hit"):
		return
		
	var hurtbox_owner = body.owner
	if hit_log:
		if hit_log.has_hit(hurtbox_owner):
			return
		else:
			hit_log.log_hit(hurtbox_owner)
	
	hit_log.log_hit(body)
	body.receive_hit(damage)
	hit_landed.emit(body)
