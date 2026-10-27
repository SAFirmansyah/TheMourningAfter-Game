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
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	if hit_log == null:
		hit_log = HitLog.new()

	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(5, true) # this IS a hitbox
	match unit_type:
		Stats.UnitType.HERO:
			set_collision_mask_value(7, true) # hero hitbox looks for enemy_hurtbox
		Stats.UnitType.ENEMY:
			set_collision_mask_value(6, true) # enemy hitbox looks for player_hurtbox

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


func _on_area_entered(area: Area3D) -> void:
	if not _active:
		return
	if not area.has_method("receive_hit"):
		return

	var target: Node3D = area.owner if area.owner else area
	if target == ignore_root:
		return
	if ignore_root and target.is_ancestor_of(ignore_root):
		return
	if hit_log.has_hit(target):
		return

	hit_log.log_hit(target)
	hit_landed.emit(target)
