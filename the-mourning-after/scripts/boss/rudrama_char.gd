class_name BossRudrama
extends CharacterBody3D

signal defeated

enum State { CHASE, BASIC_ATTACK, WAVE_ATTACK, BLOCKING, BOOMERANG }

@export var stats: BossStats
@export var target: Node3D

@export_group("Movement")
@export var base_move_speed := 3.5
@export var move_speed_multiplier := 1.0

@export_group("Basic Attack")
@export var basic_damage := 15
@export var basic_cooldown := 0.7
@export var basic_range := 2.0
@export var basic_hitbox_count := 3
@export var basic_hitbox_spacing := 0.3
@export var basic_hitbox_radius := 0.35
@export var basic_hitbox_height := 1.0
@export var basic_hitbox_lifetime := 0.2

@export_group("Wave Attack")
@export var wave_damage := 25
@export var wave_cooldown := 10.0
@export var wave_hitbox_count := 6
@export var wave_hitbox_spacing := 0.3 # double arc → tighter spacing to cover 2x the angle
@export var wave_hitbox_radius := 0.35
@export var wave_hitbox_height := 1.0
@export var wave_hitbox_lifetime := 0.2

@export_group("Block")
@export var block_damage_reduction := 0.3
@export var block_duration := 5.0
@export var block_cooldown := 5.0
@export var block_absorb_cap := 50 # TUNE: "certain (TBD) amount" — placeholder

@export_group("Boomerang")
@export var boomerang_scene: PackedScene
@export var boomerang_damage := 30
@export var boomerang_cooldown := 10.0
@export var boomerang_speed := 12.0 # TUNE
@export var boomerang_bounce_count := 3

@export_group("Adrenaline")
@export var adrenaline_health_fraction := 0.25
@export var adrenaline_duration := 10.0
@export var adrenaline_speed_bonus := 0.5
@export var adrenaline_cooldown := 20.0

var _current_attack_damage := 0
var _state := State.CHASE
var _facing := Vector2.DOWN
var _basic_cd_left := 0.0
var _wave_cd_left := 0.0
var _block_cd_left := 0.0
var _boomerang_cd_left := 0.0
var _adrenaline_cd_left := 0.0
var _adrenaline_unlocked := false
var _is_blocking := false
var _block_absorbed := 0
var _is_invulnerable := false
var _speed_bonus := 0.0
var _is_dead := false


func _ready() -> void:
	if stats == null:
		stats = BossStats.new()
	else:
		stats = stats.duplicate()
	stats.health_depleted.connect(_on_health_depleted)
	stats.health_change.connect(_on_health_change)


func receive_hit(amount: int) -> void:
	if _is_invulnerable:
		return
	var incoming := amount
	if _is_blocking:
		incoming = int(incoming * (1.0 - block_damage_reduction))
		_block_absorbed += incoming
		if _block_absorbed >= block_absorb_cap:
			_is_blocking = false
	stats.take_damage(incoming)


func _on_health_change(cur: int, max_h: int) -> void:
	if not _adrenaline_unlocked and float(cur) / float(max_h) <= adrenaline_health_fraction:
		_adrenaline_unlocked = true


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
	_wave_cd_left = maxf(0.0, _wave_cd_left - delta)
	_block_cd_left = maxf(0.0, _block_cd_left - delta)
	_boomerang_cd_left = maxf(0.0, _boomerang_cd_left - delta)
	_adrenaline_cd_left = maxf(0.0, _adrenaline_cd_left - delta)

	if target == null or _state != State.CHASE:
		return

	var direction := (target.global_position - global_position).normalized()
	_facing = Vector2(direction.x, direction.z)
	var dist := global_position.distance_to(target.global_position)
	var speed := base_move_speed * move_speed_multiplier * (1.0 + _speed_bonus)

	# Priority: adrenaline (if unlocked, low HP pressure) > boomerang (ranged) > wave > block > basic > chase.
	if _adrenaline_unlocked and _adrenaline_cd_left <= 0.0:
		_start_adrenaline()
	elif dist > basic_range and _boomerang_cd_left <= 0.0:
		_start_boomerang()
	elif dist <= basic_range and _wave_cd_left <= 0.0:
		_start_wave_attack()
	elif not _is_blocking and _block_cd_left <= 0.0 and randf() < 0.05: # TUNE: no trigger condition specified for block timing
		_start_block()
	elif dist <= basic_range and _basic_cd_left <= 0.0:
		_start_basic_attack()
	elif dist > basic_range:
		velocity = direction * speed
		move_and_slide()
	else:
		velocity = Vector3.ZERO


func _spawn_swing_hitboxes(count: int, damage: int, spacing: float, radius: float, height: float, lifetime: float) -> void:
	var side := Vector3(-_facing.y, 0.0, _facing.x)
	var forward := Vector3(_facing.x, 0.0, _facing.y)
	for n in count:
		var hitbox := preload("res://scenes/weapon/weapon_hitbox.tscn").instantiate() as Hitbox
		hitbox.damage = damage
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
	_current_attack_damage = basic_damage
	_spawn_swing_hitboxes(basic_hitbox_count, basic_damage, basic_hitbox_spacing, basic_hitbox_radius, basic_hitbox_height, basic_hitbox_lifetime)
	_state = State.CHASE
	

func _start_wave_attack() -> void:
	_wave_cd_left = wave_cooldown
	_current_attack_damage = wave_damage # ← add this
	_spawn_swing_hitboxes(wave_hitbox_count, wave_damage, wave_hitbox_spacing, wave_hitbox_radius, wave_hitbox_height, wave_hitbox_lifetime)
	

func _start_block() -> void:
	_is_blocking = true
	_block_absorbed = 0
	_block_cd_left = block_cooldown
	await get_tree().create_timer(block_duration).timeout
	_is_blocking = false


func _start_boomerang() -> void:
	_state = State.BOOMERANG
	_boomerang_cd_left = boomerang_cooldown
	if boomerang_scene:
		var boomerang := boomerang_scene.instantiate()
		get_parent().add_child(boomerang)
		boomerang.global_position = global_position
		if boomerang.has_method("configure"):
			var direction := (target.global_position - global_position).normalized()
			boomerang.configure(direction, boomerang_speed, boomerang_damage, boomerang_bounce_count, self)
	_state = State.CHASE


func _start_adrenaline() -> void:
	_adrenaline_cd_left = adrenaline_cooldown
	_is_invulnerable = true
	_speed_bonus = adrenaline_speed_bonus
	await get_tree().create_timer(adrenaline_duration).timeout
	_is_invulnerable = false
	_speed_bonus = 0.0
