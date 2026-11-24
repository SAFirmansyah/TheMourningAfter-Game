class_name BossRudrama
extends Boss
## Rudrama: slow heavy axe sweeps, a dash into a double-width sweep, a shield that blocks or is
## thrown to bounce around the room. From 20% HP she adds Adrenaline: untouchable and faster.

const SHIELD_SCENE := preload("res://scenes/boss/rudrama_shield.tscn")

@export_group("Basic Attack")
@export var basic_damage := 15
@export var basic_cooldown := 0.7
@export var basic_range := 2.4 # TUNE: distance at which she swings (m)
@export var basic_windup := 0.4 # TUNE: slow, heavy wind-up (s)
@export var basic_reach := 2.2 # TUNE (m)
@export var basic_arc := 100.0 # TUNE: sweep width (degrees)

@export_group("Dash Attack")
@export var dash_damage := 25
@export var dash_cooldown := 10.0
@export var dash_min_range := 3.5 # TUNE: only dashes at Perrin from at least this far (m)
@export var dash_speed := 14.0 # TUNE (m/s)
@export var dash_windup := 0.45 # TUNE (s)

@export_group("Block")
@export var block_damage_reduction := 0.3
@export var block_duration := 5.0
@export var block_cooldown := 5.0
@export var block_absorb_cap := 50 # TUNE: spec TBD; damage the shield prevents before it drops
@export var block_trigger_range := 3.5 # TUNE: raises the shield when Perrin swings within this distance (m)

@export_group("Boomerang")
@export var boomerang_damage := 30
@export var boomerang_cooldown := 10.0
@export var boomerang_min_range := 5.0 # TUNE: throws at Perrin from at least this far (m)
@export var boomerang_speed := 12.0 # TUNE (m/s)
@export var boomerang_bounces := 3
@export var boomerang_windup := 0.35 # TUNE (s)

@export_group("Adrenaline")
@export var adrenaline_health_fraction := 0.2
@export var adrenaline_duration := 10.0
@export var adrenaline_speed_bonus := 0.5
@export var adrenaline_cooldown := 20.0

@onready var shield_visual: MeshInstance3D = $ShieldVisual

const DASH_COLOR := Color(1.0, 0.9, 0.55) # TUNE: indicator colours per move
const BLOCK_COLOR := Color(0.55, 0.7, 1.0)
const SHIELD_DOWN_COLOR := Color(0.75, 0.75, 0.8)
const BOOMERANG_COLOR := Color(0.75, 0.85, 1.0)
const ADRENALINE_COLOR := Color(1.0, 0.8, 0.25)

var _adrenaline_unlocked := false
var _adrenaline_left := 0.0
var _blocking := false
var _block_left := 0.0
var _block_absorbed := 0
var _shield_out := false


func _on_health_fraction(fraction: float) -> void:
	if fraction <= adrenaline_health_fraction:
		_adrenaline_unlocked = true


func _on_target_found() -> void:
	target.attack_started.connect(_on_perrin_swing)


func _tick(delta: float) -> void:
	if _blocking:
		_block_left -= delta
		if _block_left <= 0.0:
			_end_block()
	if _adrenaline_left > 0.0:
		_adrenaline_left -= delta
		if _adrenaline_left <= 0.0:
			invulnerable = false
			speed_bonus = 0.0
			set_aura(&"adrenaline", ADRENALINE_COLOR, false)
	shield_visual.visible = not _shield_out
	shield_visual.position.z = 0.55 if _blocking else -0.3 # in front while blocking, slung on her back otherwise


func _think(to: Vector3) -> Vector3:
	var dist := to.length()
	if _adrenaline_unlocked and is_ready(&"adrenaline"):
		_start_adrenaline()
	if dist >= boomerang_min_range and is_ready(&"boomerang") and not _shield_out and not _blocking:
		_throw_shield()
		return Vector3.ZERO
	if dist >= dash_min_range and is_ready(&"dash"):
		_dash_attack()
		return Vector3.ZERO
	if dist <= basic_range and is_ready(&"basic"):
		_basic()
		return Vector3.ZERO
	return chase(to)


func _modify_incoming(amount: int) -> int:
	if not _blocking:
		return amount
	var taken := roundi(amount * (1.0 - block_damage_reduction))
	_block_absorbed += amount - taken
	if _block_absorbed >= block_absorb_cap:
		_end_block()
		announce("Shield broken", SHIELD_DOWN_COLOR)
	return taken


func _sweep(damage: int, arc: float) -> void:
	strike(arc_offsets(arc, basic_reach, 5), damage, 0.5, 0.2)


func _basic() -> void:
	begin_attack()
	use(&"basic", basic_cooldown)
	await wait(basic_windup)
	_sweep(basic_damage, basic_arc)
	await wait(0.15)
	busy = false


## Dash in, then a sweep twice as wide as the basic one.
func _dash_attack() -> void:
	begin_attack()
	use(&"dash", dash_cooldown)
	announce("Dash!", DASH_COLOR)
	await wait(dash_windup)
	var to := flat(target.global_position - global_position)
	await dash_toward(to, to.length() - 1.5, dash_speed)
	face(target.global_position - global_position)
	_sweep(dash_damage, basic_arc * 2.0)
	await wait(0.3)
	busy = false


func _on_perrin_swing() -> void:
	if _dead or _blocking or _shield_out or not _started or not is_ready(&"block"):
		return
	if flat(target.global_position - global_position).length() > block_trigger_range:
		return
	_blocking = true
	_block_left = block_duration
	_block_absorbed = 0
	announce("Block", BLOCK_COLOR)
	set_aura(&"block", BLOCK_COLOR, true)


func _end_block() -> void:
	if not _blocking:
		return
	_blocking = false
	use(&"block", block_cooldown)
	set_aura(&"block", BLOCK_COLOR, false)


func _throw_shield() -> void:
	busy = true
	use(&"boomerang", boomerang_cooldown)
	announce("Boomerang", BOOMERANG_COLOR)
	await wait(boomerang_windup)
	_shield_out = true
	var shield := SHIELD_SCENE.instantiate() as BoomerangShield
	get_parent().add_child(shield)
	shield.global_position = global_position + Vector3.UP * 1.0 + forward() * 0.8
	shield.configure(self, flat(target.global_position - global_position), boomerang_speed, boomerang_damage, boomerang_bounces)
	busy = false


## The thrown shield is back in her hand.
func catch_shield() -> void:
	_shield_out = false


func _start_adrenaline() -> void:
	use(&"adrenaline", adrenaline_cooldown)
	_adrenaline_left = adrenaline_duration
	invulnerable = true
	speed_bonus = adrenaline_speed_bonus
	announce("Adrenaline!", ADRENALINE_COLOR)
	set_aura(&"adrenaline", ADRENALINE_COLOR, true)
