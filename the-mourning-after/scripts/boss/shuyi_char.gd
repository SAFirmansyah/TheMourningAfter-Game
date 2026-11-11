class_name BossShuyi
extends CharacterBody3D

signal defeated

enum State { CHASE, BASIC_ATTACK, DASH_ATTACK, CULLING }

@export var stats: BossStats
@export var target: Node3D

@export_group("Movement")
@export var base_move_speed := 4.0
@export var move_speed_multiplier := 1.5

@export_group("Basic Attack")
@export var basic_damage := 10
@export var basic_cooldown := 0.5
@export var basic_range := 4.0 # TUNE: "long-range"
@export var basic_hitbox_count := 5
@export var basic_hitbox_spacing := 0.6 # gap between stabs along the line
@export var basic_hitbox_radius := 0.25
@export var basic_hitbox_height := 0.8
@export var basic_hitbox_lifetime := 0.15

@export_group("Dash Attack")
@export var dash_damage := 20
@export var dash_cooldown := 7.0
@export var dash_speed := 16.0 # TUNE
@export var dash_hitbox_count := 3
@export var dash_hitbox_spacing := 0.3
@export var dash_hitbox_radius := 0.3
@export var dash_hitbox_height := 1.0
@export var dash_hitbox_lifetime := 0.15

@export_group("Healing Potion")
@export var heal_cooldown := 15.0

@export_group("Strength Potion")
@export var strength_duration := 10.0

@export_group("Culling")
@export var culling_health_fraction := 0.3
@export var culling_damage := 30
@export var culling_arc_degrees := 60.0
@export var culling_range := 5.0 # TUNE: reel-in range, not specified
@export var culling_stun_duration := 2.0
@export var culling_cooldown := 10.0

var _current_attack_damage := 0
var _state := State.CHASE
var _facing := Vector2.DOWN
var _basic_cd_left := 0.0
var _dash_cd_left := 0.0
var _heal_cd_left := 0.0
var _culling_cd_left := 0.0
var _culling_unlocked := false
var _strength_used := false
var _damage_multiplier := 1.0
var _health_at_last_heal := 0
var _is_dead := false


func _ready() -> void:
	if stats == null:
		stats = BossStats.new()
	else:
		stats = stats.duplicate()
	stats.health_depleted.connect(_on_health_depleted)
	stats.health_change.connect(_on_health_change)
	_health_at_last_heal = stats.health


func receive_hit(amount: int) -> void:
	stats.take_damage(amount)


func _on_health_change(cur: int, max_h: int) -> void:
	if not _culling_unlocked and float(cur) / float(max_h) <= culling_health_fraction:
		_culling_unlocked = true


func _on_health_depleted() -> void:
	if _is_dead:
		return
	_is_dead = true
	set_physics_process(false)
	visible = false
	collision_layer = 0
	collision_mask = 0
	defeated.emit()
	queue_free()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	_basic_cd_left = maxf(0.0, _basic_cd_left - delta)
	_dash_cd_left = maxf(0.0, _dash_cd_left - delta)
	_heal_cd_left = maxf(0.0, _heal_cd_left - delta)
	_culling_cd_left = maxf(0.0, _culling_cd_left - delta)

	if target == null or _state != State.CHASE:
		return

	var direction := (target.global_position - global_position).normalized()
	_facing = Vector2(direction.x, direction.z)
	var dist := global_position.distance_to(target.global_position)

	# Priority order is a TUNE decision: culling > heal (if hurt) > strength (once) > dash > basic > chase.
	if _culling_unlocked and _culling_cd_left <= 0.0 and _in_culling_arc():
		_start_culling()
	elif _heal_cd_left <= 0.0 and stats.health < _health_at_last_heal:
		_use_heal_potion()
	elif not _strength_used and randf() < 0.1: # TUNE: no trigger condition specified for strength potion timing
		_use_strength_potion()
	elif dist > basic_range and _dash_cd_left <= 0.0:
		_start_dash_attack()
	elif dist <= basic_range and _basic_cd_left <= 0.0:
		_start_basic_attack()
	elif dist > basic_range:
		velocity = direction * base_move_speed * move_speed_multiplier
		move_and_slide()
	else:
		velocity = Vector3.ZERO


func _in_culling_arc() -> bool:
	var to_target := (target.global_position - global_position)
	if to_target.length() > culling_range:
		return false
	var forward := Vector3(_facing.x, 0.0, _facing.y)
	var angle := rad_to_deg(forward.angle_to(to_target.normalized()))
	return angle <= culling_arc_degrees / 2.0


func _spawn_line_hitboxes(count: int, damage: int, spacing: float, radius: float, height: float, lifetime: float) -> void:
	var forward := Vector3(_facing.x, 0.0, _facing.y)
	for n in count:
		var hitbox := preload("res://scenes/weapon/weapon_hitbox.tscn").instantiate() as Hitbox
		hitbox.damage = int(damage * _damage_multiplier)
		hitbox.unit_type = Stats.UnitType.ENEMY
		hitbox.ignore_root = self
		hitbox.hitbox_lifetime = lifetime
		hitbox.hit_landed.connect(_on_hitbox_hit)
		add_child(hitbox)

		var shape_node: CollisionShape3D
		for child in hitbox.get_children():
			if child is CollisionShape3D:
				shape_node = child
				break
		var capsule := (shape_node.shape as CapsuleShape3D).duplicate()
		capsule.radius = radius
		capsule.height = height
		shape_node.shape = capsule

		hitbox.global_position = global_position + forward * (0.5 + height / 2.0 + n * spacing)


func _spawn_swing_hitboxes(count: int, damage: int, spacing: float, radius: float, height: float, lifetime: float) -> void:
	var side := Vector3(-_facing.y, 0.0, _facing.x)
	var forward := Vector3(_facing.x, 0.0, _facing.y)
	for n in count:
		var hitbox := preload("res://scenes/weapon/weapon_hitbox.tscn").instantiate() as Hitbox
		hitbox.damage = int(damage * _damage_multiplier)
		hitbox.unit_type = Stats.UnitType.ENEMY
		hitbox.ignore_root = self
		hitbox.hitbox_lifetime = lifetime
		hitbox.hit_landed.connect(_on_hitbox_hit)
		add_child(hitbox)

		var shape_node: CollisionShape3D
		for child in hitbox.get_children():
			if child is CollisionShape3D:
				shape_node = child
				break
		var capsule := (shape_node.shape as CapsuleShape3D).duplicate()
		capsule.radius = radius
		capsule.height = height
		shape_node.shape = capsule

		var lateral := (n - (count - 1) / 2.0) * spacing
		hitbox.global_position = global_position + forward * (0.5 + height / 2.0) + side * lateral


func _on_hitbox_hit(hit_target: Node3D) -> void:
	if hit_target.has_method("receive_hit"):
		hit_target.receive_hit(_current_attack_damage)

func _start_basic_attack() -> void:
	_state = State.BASIC_ATTACK
	_basic_cd_left = basic_cooldown
	_current_attack_damage = int(basic_damage * _damage_multiplier)
	_spawn_line_hitboxes(basic_hitbox_count, basic_damage, basic_hitbox_spacing, basic_hitbox_radius, basic_hitbox_height, basic_hitbox_lifetime)
	_state = State.CHASE


func _start_dash_attack() -> void:
	_state = State.DASH_ATTACK
	_dash_cd_left = dash_cooldown
	var direction := (target.global_position - global_position).normalized()
	velocity = direction * dash_speed
	await get_tree().create_timer(0.2).timeout # TUNE: dash travel time before swing
	_current_attack_damage = int(dash_damage * _damage_multiplier)
	_spawn_swing_hitboxes(dash_hitbox_count, dash_damage, dash_hitbox_spacing, dash_hitbox_radius, dash_hitbox_height, dash_hitbox_lifetime)
	_state = State.CHASE


func _use_heal_potion() -> void:
	_heal_cd_left = heal_cooldown
	var lost := _health_at_last_heal - stats.health
	var restore := int(lost * 0.5)
	stats.on_health_set(stats.health + restore)
	_health_at_last_heal = stats.health


func _use_strength_potion() -> void:
	_strength_used = true
	_damage_multiplier = 2.0
	await get_tree().create_timer(strength_duration).timeout
	_damage_multiplier = 1.0


func _start_culling() -> void:
	_state = State.CULLING
	_culling_cd_left = culling_cooldown
	target.global_position = global_position + Vector3(-_facing.x, 0.0, -_facing.y) * 1.0 # reel player in
	if target.has_method("receive_hit"):
		target.receive_hit(culling_damage)
	if target.has_method("apply_stun"):
		target.apply_stun(culling_stun_duration)
	await get_tree().create_timer(culling_stun_duration).timeout
	_state = State.CHASE
