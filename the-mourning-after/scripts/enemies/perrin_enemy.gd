class_name PerrinAsEnemy
extends Boss
## The AI-controlled Hero in the final fight. Uses the real HeroStats/WeaponData the player built
## this run, plus whichever potion/shield move Perrin's own boss-kill didn't strip away.

@export var weapon: WeaponData

@export_group("Borrowed Abilities")
@export var has_self_heal := true    # stripped if Shuyi was the one defeated
@export var has_shield := true       # stripped if Rudrama was the one defeated
@export var has_pesticide := true    # stripped if Gwenith was the one defeated

@export_group("Heal Potion (borrowed from Shuyi)")
@export var heal_cooldown := 15.0
@export var heal_share := 0.5
@export var heal_min_damage := 20

@export_group("Shield (borrowed from Rudrama)")
@export var block_damage_reduction := 0.3
@export var block_duration := 5.0
@export var block_cooldown := 5.0
@export var block_absorb_cap := 50

@export_group("Pesticide (borrowed from Gwenith)")
const PESTICIDE_SCENE := preload("res://scenes/boss/pesticide_gwen.tscn")
@export var pesticide_cooldown := 8.0
@export var pesticide_range := 9.0
@export var pesticide_radius := 2.0
@export var pesticide_dps := 5
@export var pesticide_duration := 3.0
@export var pesticide_windup := 0.35

const HEAL_COLOR := Color(0.45, 1.0, 0.45)
const BLOCK_COLOR := Color(0.55, 0.7, 1.0)
const PESTICIDE_COLOR := Color(0.6, 0.95, 0.25)

var _damage_since_potion := 0
var _heal_rate := 0.0
var _heal_left := 0.0
var _heal_carry := 0.0
var _blocking := false
var _block_left := 0.0
var _block_absorbed := 0


func _ready() -> void:
	super()
	stats.damaged.connect(func(amount: int) -> void: _damage_since_potion += amount)
	if has_pesticide:
		use(&"pesticide", 4.0) # TUNE: delay before first use, matching Gwenith's pattern


func _modify_incoming(amount: int) -> int:
	if not _blocking:
		return amount
	var taken := roundi(amount * (1.0 - block_damage_reduction))
	_block_absorbed += amount - taken
	if _block_absorbed >= block_absorb_cap:
		_end_block()
	return taken


func _tick(delta: float) -> void:
	if _heal_left > 0.0:
		var step := minf(delta, _heal_left)
		_heal_left -= step
		_heal_carry += _heal_rate * step
		var whole := floori(_heal_carry)
		if whole > 0:
			_heal_carry -= whole
			stats.on_health_set(stats.health + whole)
		if _heal_left <= 0.0:
			set_aura(&"heal", HEAL_COLOR, false)
	if _blocking:
		_block_left -= delta
		if _block_left <= 0.0:
			_end_block()


func _think(to: Vector3) -> Vector3:
	if weapon == null:
		return chase(to)
	var dist := to.length()
	var attack_range := weapon.hitbox_height / 2.0 + 0.5

	if has_self_heal and is_ready(&"heal") and _damage_since_potion >= heal_min_damage:
		_drink_heal()
		return Vector3.ZERO
	if has_shield and not _blocking and is_ready(&"block") and dist <= attack_range:
		_raise_shield()
		return Vector3.ZERO
	if has_pesticide and is_ready(&"pesticide") and dist <= pesticide_range:
		_throw_pesticide()
		return Vector3.ZERO
	if dist <= attack_range and is_ready(&"basic"):
		_basic_attack()
		return Vector3.ZERO
	return chase(to)


func _basic_attack() -> void:
	busy = true
	use(&"basic", weapon.attack_cooldown)
	await wait(weapon.active_delay)
	var side := Vector3(-_facing.y, 0.0, _facing.x)
	var offsets: Array[Vector3] = []
	for n in 3:
		offsets.append(forward() * (weapon.hitbox_height / 2.0) + side * ((n - 1) * 0.3))
	strike(offsets, weapon.damage, weapon.hitbox_radius, weapon.active_window)
	busy = false


func _drink_heal() -> void:
	busy = true
	use(&"heal", heal_cooldown)
	var amount := _damage_since_potion * heal_share
	_damage_since_potion = 0
	announce("Healing", HEAL_COLOR)
	await wait(0.4)
	_heal_rate = amount / heal_cooldown
	_heal_left = heal_cooldown
	set_aura(&"heal", HEAL_COLOR, true)
	busy = false


func _raise_shield() -> void:
	_blocking = true
	_block_left = block_duration
	_block_absorbed = 0
	announce("Block", BLOCK_COLOR)
	set_aura(&"block", BLOCK_COLOR, true)


func _end_block() -> void:
	_blocking = false
	use(&"block", block_cooldown)
	set_aura(&"block", BLOCK_COLOR, false)


func _throw_pesticide() -> void:
	busy = true
	use(&"pesticide", pesticide_cooldown)
	announce("Pesticide", PESTICIDE_COLOR)
	var spot := target.global_position
	await wait(pesticide_windup)
	var puddle := PESTICIDE_SCENE.instantiate() as PesticideHazard
	get_parent().add_child(puddle)
	puddle.global_position = Vector3(spot.x, global_position.y, spot.z)
	puddle.configure(target, pesticide_radius, pesticide_dps, pesticide_duration)
	busy = false
