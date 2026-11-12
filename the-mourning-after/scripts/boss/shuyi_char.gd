class_name BossShuyi
extends Boss
## Shuyi: long straight staff stabs and dash stabs, a healing potion and a once-per-fight strength
## potion. From 30% HP she adds Culling: a 60° sweep that reels Perrin in and stuns him.

@export_group("Basic Attack")
@export var basic_damage := 10
@export var basic_cooldown := 0.5
@export var basic_range := 3.6 # TUNE: distance at which she stabs (m)
@export var basic_windup := 0.2 # TUNE: medium-speed stab (s)
@export var basic_reach := 3.4 # TUNE: stab length (m)

@export_group("Dash Attack")
@export var dash_damage := 20
@export var dash_cooldown := 7.0
@export var dash_min_range := 5.0 # TUNE: only dashes at Perrin from at least this far (m)
@export var dash_speed := 16.0 # TUNE (m/s)
@export var dash_windup := 0.35 # TUNE (s)

@export_group("Healing Potion")
@export var heal_cooldown := 15.0
@export var heal_share := 0.5 # restores this share of the damage taken since the last potion
@export var heal_min_damage := 20 # TUNE: drinks once she has taken at least this much since the last potion

@export_group("Strength Potion")
@export var strength_health_fraction := 0.6 # TUNE: drinks it once at this health (spec: any time)
@export var strength_duration := 10.0
@export var strength_multiplier := 2.0

@export_group("Culling")
@export var culling_health_fraction := 0.3
@export var culling_damage := 30
@export var culling_arc := 60.0
@export var culling_range := 5.0 # TUNE: sweep reach (m)
@export var culling_windup := 0.45 # TUNE: telegraph before the sweep; facing is locked (s)
@export var culling_stun := 2.0
@export var culling_cooldown := 10.0

const DRINK_TIME := 0.4 # TUNE: how long drinking a potion takes (s)
const DASH_COLOR := Color(1.0, 0.9, 0.55) # TUNE: indicator colours per move
const HEAL_COLOR := Color(0.45, 1.0, 0.45)
const STRENGTH_COLOR := Color(1.0, 0.35, 0.3)
const CULLING_COLOR := Color(1.0, 0.65, 0.2)
const HEAL_SIGN_INTERVAL := 1.0 # TUNE: a "+" rises this often while the potion heals (s)

var _culling_unlocked := false
var _strength_due := false
var _strength_used := false
var _strength_left := 0.0
var _damage_since_potion := 0
var _heal_rate := 0.0 # HP per second still being restored
var _heal_left := 0.0
var _heal_carry := 0.0
var _heal_sign_left := 0.0


func _ready() -> void:
	super()
	stats.damaged.connect(func(amount: int) -> void: _damage_since_potion += amount)


func _on_health_fraction(fraction: float) -> void:
	if fraction <= culling_health_fraction:
		_culling_unlocked = true
	if fraction <= strength_health_fraction and not _strength_used:
		_strength_due = true


func _tick(delta: float) -> void:
	if _heal_left > 0.0:
		var step := minf(delta, _heal_left)
		_heal_left -= step
		_heal_carry += _heal_rate * step
		var whole := floori(_heal_carry)
		if whole > 0:
			_heal_carry -= whole
			stats.on_health_set(stats.health + whole)
		_heal_sign_left -= step
		if _heal_sign_left <= 0.0:
			_heal_sign_left = HEAL_SIGN_INTERVAL
			rise_text("+", HEAL_COLOR)
		if _heal_left <= 0.0:
			set_aura(&"heal", HEAL_COLOR, false)
	if _strength_left > 0.0:
		_strength_left -= delta
		if _strength_left <= 0.0:
			damage_multiplier = 1.0
			set_aura(&"strength", STRENGTH_COLOR, false)


func _think(to: Vector3) -> Vector3:
	var dist := to.length()
	if _culling_unlocked and is_ready(&"culling") and dist <= culling_range:
		_culling()
		return Vector3.ZERO
	if is_ready(&"heal") and _damage_since_potion >= heal_min_damage:
		_drink_heal()
		return Vector3.ZERO
	if _strength_due:
		_drink_strength()
		return Vector3.ZERO
	if dist >= dash_min_range and is_ready(&"dash"):
		_dash_attack()
		return Vector3.ZERO
	if dist <= basic_range and is_ready(&"basic"):
		_basic()
		return Vector3.ZERO
	return chase(to)


func _stab(damage: int) -> void:
	strike(line_offsets(0.8, basic_reach, 5), damage, 0.35)


func _basic() -> void:
	busy = true
	use(&"basic", basic_cooldown)
	await wait(basic_windup)
	_stab(basic_damage)
	busy = false


func _dash_attack() -> void:
	busy = true
	use(&"dash", dash_cooldown)
	announce("Dash!", DASH_COLOR)
	await wait(dash_windup)
	var to := flat(target.global_position - global_position)
	await dash_toward(to, to.length() - 2.0, dash_speed)
	face(target.global_position - global_position)
	_stab(dash_damage)
	await wait(0.25)
	busy = false


## Half of the damage taken since the last potion, restored gradually until the next one is ready.
func _drink_heal() -> void:
	busy = true
	use(&"heal", heal_cooldown)
	var amount := _damage_since_potion * heal_share
	_damage_since_potion = 0
	announce("Healing", HEAL_COLOR)
	await wait(DRINK_TIME)
	_heal_rate = amount / heal_cooldown
	_heal_left = heal_cooldown
	_heal_sign_left = 0.0
	set_aura(&"heal", HEAL_COLOR, true)
	busy = false


func _drink_strength() -> void:
	busy = true
	_strength_due = false
	_strength_used = true
	announce("Strength", STRENGTH_COLOR)
	await wait(DRINK_TIME)
	damage_multiplier = strength_multiplier
	_strength_left = strength_duration
	set_aura(&"strength", STRENGTH_COLOR, true)
	busy = false


## Winds up facing Perrin, then sweeps: if he's still in the arc he's pulled in, hurt and stunned.
func _culling() -> void:
	busy = true
	use(&"culling", culling_cooldown)
	face(target.global_position - global_position)
	announce("Culling!", CULLING_COLOR)
	show_wedge(culling_arc, culling_range, CULLING_COLOR, culling_windup + 0.15)
	await wait(culling_windup)
	if in_arc(culling_arc, culling_range) and not target.is_invulnerable:
		target.teleport(Vector3(global_position.x, target.global_position.y, global_position.z) + forward() * 1.1)
		target.receive_hit(roundi(culling_damage * damage_multiplier))
		target.apply_stun(culling_stun)
	await wait(0.3)
	busy = false
