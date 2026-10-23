class_name Player
extends CharacterBody3D
## Screen-relative movement on the floor plane, with dash charges and i-frames.
## Dashing passes through environment objects; walls still block.

signal dash_started
signal dash_ended
signal attack_started
signal attack_ended

@export var card: Sprite3D
@export var camera_rig: CameraRig
@export var display_name := "Player" # name shown in conversations
@export var portrait: Texture2D # conversation portrait; placeholder uses the card

@export_group("Movement")
@export var base_move_speed := 5.0 # TUNE: walk speed at 1x (m/s)
@export_range(0.5, 2.0, 0.05) var move_speed_multiplier := 1.0 # move speed stat (0.5x–2x)
@export var acceleration := 60.0 # TUNE: speed-up rate (m/s²)
@export var deceleration := 80.0 # TUNE: slow-down rate (m/s²)
@export_range(0.0, 1.0) var depth_speed_compensation := 0.0 # TUNE: 0 = raw world speed, 1 = equal on-screen speed in all directions

@export_group("Dash")
@export var max_dashes := 1 # dash charges; buff raises to 2
@export var dash_distance := 3.5 # TUNE: dash length (m)
@export var dash_duration := 0.15 # TUNE: dash time (s)
@export var dash_recharge_time := 0.8 # TUNE: time to refill one charge (s)
@export var dash_iframe_extra := 0.05 # TUNE: i-frames after dash ends (s)
@export var dash_max_extension := 0.3 # TUNE: extra dash time allowed to finish exiting an object (s)
@export_range(0.0, 1.0) var dash_transparency := 0.45 # TUNE: card see-through amount while dashing (0 = opaque, 1 = invisible)
@export_flags_3d_physics var dash_phase_layers := 2 # layers passed through while dashing

@export_group("Combat")
@export var weapon: WeaponData
@export var attack_reach := 1 # TUNE: distance hitbox sits in front of player center

var is_invulnerable := false
var dashes_available := 0
var input_enabled := true
var forced_input := Vector2.ZERO # screen-space direction used while input is disabled

var _facing := Vector2.DOWN
var _dashing := false
var _dash_queued := false
var _dash_time_left := 0.0
var _iframe_time_left := 0.0
var _dash_velocity := Vector3.ZERO
var _recharge_progress := 0.0

var _attack_queued := false
var _attack_cooldown_left := 0.0
var _charging := false
var _charge_time := 0.0
var _current_attack_damage := 0.0
var _current_attack_abilities: Array[WeaponAbility] = []

@onready var _body_shape: CollisionShape3D = $CollisionShape3D
@onready var _hitbox: Hitbox = $Hitbox


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	dashes_available = max_dashes
	_hitbox.ignore_root = self
	_hitbox.hit_landed.connect(_on_hitbox_hit)


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down") if input_enabled else forced_input
	if input != Vector2.ZERO:
		_facing = input.normalized()

	_recharge_dashes(delta)
	if _dash_queued:
		_dash_queued = false
		if input_enabled:
			_try_dash()

	if _charging:
		_charge_time = minf(_charge_time + delta, weapon.max_charge_time)

	_attack_cooldown_left = maxf(0.0, _attack_cooldown_left - delta)
	if _attack_queued:
		_attack_queued = false
		if input_enabled:
			_try_attack()

	if _dashing:
		velocity = _dash_velocity
		_dash_time_left -= delta
		var still_inside := _overlaps_phase_layers() and _dash_time_left > -dash_max_extension
		if _dash_time_left <= 0.0 and not still_inside:
			_end_dash()
	else:
		var target := _to_world(input) * base_move_speed * move_speed_multiplier
		var rate := acceleration if input != Vector2.ZERO else deceleration
		velocity = velocity.move_toward(target, rate * delta)

	_iframe_time_left = maxf(0.0, _iframe_time_left - delta)
	is_invulnerable = _dashing or _iframe_time_left > 0.0

	velocity.y = 0.0
	move_and_slide()

	if card and input.x != 0.0:
		card.flip_h = input.x < 0.0


func _unhandled_input(event: InputEvent) -> void:
	# Event-based so presses consumed by UI (e.g. Space advancing text) never dash/attack.
	if input_enabled and event.is_action_pressed(&"dash"):
		_dash_queued = true

	if input_enabled and weapon and event.is_action_pressed(&"attack"):
		if weapon.is_chargeable:
			_charging = true
			_charge_time = 0.0
		else:
			_attack_queued = true

	if event.is_action_released(&"attack") and _charging:
		_charging = false
		_attack_queued = true


func _process(_delta: float) -> void:
	RenderingServer.global_shader_parameter_set(&"occlusion_target", get_global_transform_interpolated().origin)


func teleport(pos: Vector3) -> void:
	global_position = pos
	if _dashing:
		_end_dash()
	velocity = Vector3.ZERO
	reset_physics_interpolation()


func heal(amount: float) -> void:
	pass


func _try_dash() -> void:
	if dashes_available <= 0 or _dashing:
		return
	dashes_available -= 1
	_dashing = true
	_dash_time_left = dash_duration
	_dash_velocity = _to_world(_facing) * (dash_distance / dash_duration)
	collision_mask &= ~dash_phase_layers
	if card:
		card.transparency = dash_transparency
	dash_started.emit()


func _end_dash() -> void:
	_dashing = false
	_dash_time_left = 0.0
	collision_mask |= dash_phase_layers
	velocity = velocity.limit_length(base_move_speed * move_speed_multiplier)
	_iframe_time_left = dash_iframe_extra
	if card:
		card.transparency = 0.0
	dash_ended.emit()


func _try_attack() -> void:
	if weapon == null or _attack_cooldown_left > 0.0:
		return
	_attack_cooldown_left = weapon.attack_cooldown

	var charge_ratio := (_charge_time / weapon.max_charge_time) if weapon.is_chargeable else 0.0
	var is_full_charge := charge_ratio >= 1.0
	_current_attack_damage = weapon.damage * (weapon.charged_damage_multiplier if is_full_charge else 1.0)
	_current_attack_abilities = weapon.charged_abilities if is_full_charge else weapon.abilities
	_charge_time = 0.0

	_hitbox.position = Vector3(_facing.x, 0.0, _facing.y) * attack_reach
	attack_started.emit()

	await get_tree().create_timer(weapon.active_delay).timeout
	_hitbox.activate()
	await get_tree().create_timer(weapon.active_window).timeout
	_hitbox.deactivate()
	attack_ended.emit()


func _on_hitbox_hit(body: Node3D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(_current_attack_damage, _facing)
	for ability in _current_attack_abilities:
		ability.apply(self, body)


func _overlaps_phase_layers() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _body_shape.shape
	query.transform = _body_shape.global_transform
	query.collision_mask = dash_phase_layers
	query.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _recharge_dashes(delta: float) -> void:
	if dashes_available >= max_dashes:
		_recharge_progress = 0.0
		return
	_recharge_progress += delta
	if _recharge_progress >= dash_recharge_time:
		_recharge_progress = 0.0
		dashes_available += 1


func _to_world(screen_dir: Vector2) -> Vector3:
	return Vector3(screen_dir.x, 0.0, screen_dir.y * _depth_scale())


func _depth_scale() -> float:
	if camera_rig == null:
		return 1.0
	var full := 1.0 / sin(deg_to_rad(camera_rig.pitch_deg))
	return lerpf(1.0, full, depth_speed_compensation)
