class_name BossGwenith
extends Boss
## Gwenith: rapid sickle slashes, dash strikes, thrown pesticide and the pollen-cloud vanish.
## From 30% HP she adds Ensnared: vine patches that root Perrin while she slashes him.

const PESTICIDE_SCENE := preload("res://scenes/boss/pesticide_gwen.tscn")
const VINE_SCENE := preload("res://scenes/boss/vine_trap_gwen.tscn")
const POLLEN_SCENE := preload("res://scenes/boss/pollen_cloud.tscn")

@export_group("Basic Attack")
@export var basic_damage := 5
@export var basic_cooldown := 0.3
@export var basic_range := 1.8 # TUNE: distance at which she slashes (m)
@export var basic_windup := 0.08 # TUNE: pause before each slash lands (s)
@export var basic_reach := 1.3 # TUNE: slash reach (m)
@export var basic_arc := 70.0 # TUNE: slash width (degrees)

@export_group("Dash Attack")
@export var dash_damage := 15
@export var dash_cooldown := 5.0
@export var dash_min_range := 3.5 # TUNE: only dashes at Perrin from at least this far (m)
@export var dash_speed := 20.0 # TUNE (m/s)
@export var dash_windup := 0.3 # TUNE: crouch before the dash (s)

@export_group("Pesticide")
@export var pesticide_cooldown := 8.0 # TUNE: not in the spec
@export var pesticide_first_delay := 4.0 # TUNE: first throw this long into the fight (s)
@export var pesticide_range := 9.0 # TUNE: throws at Perrin within this distance (m)
@export var pesticide_radius := 2.0 # TUNE (m)
@export var pesticide_dps := 5
@export var pesticide_duration := 3.0
@export var pesticide_windup := 0.35 # TUNE: throw time; lands where Perrin stood (s)

@export_group("Pollen Cloud")
@export var pollen_cooldown := 15.0 # TUNE: not in the spec
@export var pollen_first_delay := 9.0 # TUNE: first vanish this long into the fight (s)
@export var pollen_total_time := 5.0
@export var pollen_warning := 1.0 # TUNE: the second cloud shows this long before she steps out of it (s)
@export var pollen_reappear_distance := 3.5 # TUNE: reappears this far from Perrin (m)

@export_group("Ensnared")
@export var ensnared_health_fraction := 0.3
@export var ensnared_cooldown := 10.0
@export var ensnared_patches := 3 # TUNE: vine patches per cast; the first is under Perrin
@export var ensnared_radius := 1.6 # TUNE (m)
@export var ensnared_spread := 4.0 # TUNE: other patches land this far from Perrin (m)
@export var ensnared_warning := 5.0 # TUNE: patches show this long before erupting (s)
@export var ensnared_root_time := 5.0 # TUNE: how long a caught Perrin stays rooted (s)
@export var ensnared_damage := 5

const DASH_COLOR := Color(1.0, 0.9, 0.55) # TUNE: indicator colours per move
const POLLEN_PUFF := 0.4 # TUNE: she's seen inside the first cloud this long before vanishing (s)
const PESTICIDE_COLOR := Color(0.6, 0.95, 0.25)
const POLLEN_COLOR := Color(1.0, 0.85, 0.35)
const ENSNARED_COLOR := Color(0.3, 0.75, 0.3)
const ENSNARED_CAST := 0.5 # TUNE: she stands summoning the vines this long (s)

var _ensnared_unlocked := false
var _grab_pending := false


func _ready() -> void:
	super()
	use(&"pesticide", pesticide_first_delay)
	use(&"pollen", pollen_first_delay)


func _on_health_fraction(fraction: float) -> void:
	if fraction <= ensnared_health_fraction:
		_ensnared_unlocked = true


func _think(to: Vector3) -> Vector3:
	var dist := to.length()
	if _grab_pending:
		_grab_pending = false
		if target.is_stunned():
			_grab()
			return Vector3.ZERO
	if _ensnared_unlocked and is_ready(&"ensnared"):
		_ensnared()
		return Vector3.ZERO
	if is_ready(&"pollen"):
		_pollen()
		return Vector3.ZERO
	if is_ready(&"pesticide") and dist <= pesticide_range:
		_pesticide()
		return Vector3.ZERO
	if dist >= dash_min_range and is_ready(&"dash"):
		_dash_attack()
		return Vector3.ZERO
	if dist <= basic_range and is_ready(&"basic"):
		_basic()
		return Vector3.ZERO
	return chase(to)


func _basic() -> void:
	busy = true
	use(&"basic", basic_cooldown)
	await wait(basic_windup)
	_slash(basic_damage)
	busy = false


func _slash(damage: int) -> void:
	strike(arc_offsets(basic_arc, basic_reach, 3), damage, 0.45)


func _dash_attack() -> void:
	busy = true
	use(&"dash", dash_cooldown)
	announce("Dash!", DASH_COLOR)
	await wait(dash_windup)
	var to := flat(target.global_position - global_position)
	await dash_toward(to, to.length() - 1.0, dash_speed)
	face(target.global_position - global_position)
	_slash(dash_damage)
	await wait(0.2)
	busy = false


func _pesticide() -> void:
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


## Vanishes in one cloud, reappears near Perrin in another, then dash-strikes at once.
func _pollen() -> void:
	busy = true
	use(&"pollen", pollen_cooldown)
	announce("Pollen Cloud", POLLEN_COLOR)
	_cloud(global_position)
	await wait(POLLEN_PUFF)
	set_hidden(true)
	await wait(pollen_total_time - pollen_warning - POLLEN_PUFF)
	var spot := find_open_spot(target.global_position, pollen_reappear_distance)
	_cloud(spot)
	await wait(pollen_warning)
	global_position = spot
	set_hidden(false)
	face(target.global_position - global_position)
	busy = false
	cooldowns[&"dash"] = 0.0 # regardless of the dash cooldown
	_dash_attack()


func _cloud(at: Vector3) -> void:
	var cloud := POLLEN_SCENE.instantiate() as Node3D
	get_parent().add_child(cloud)
	cloud.global_position = Vector3(at.x, global_position.y, at.z)


func _ensnared() -> void:
	busy = true
	use(&"ensnared", ensnared_cooldown)
	announce("Ensnared!", ENSNARED_COLOR)
	var centres: Array[Vector3] = [target.global_position]
	for i in ensnared_patches - 1:
		centres.append(find_open_spot(target.global_position, ensnared_spread))
	for centre in centres:
		var vine := VINE_SCENE.instantiate() as VineHazard
		get_parent().add_child(vine)
		vine.global_position = Vector3(centre.x, global_position.y, centre.z)
		vine.configure(self, target, ensnared_radius, ensnared_warning, ensnared_root_time, ensnared_damage)
	await wait(ENSNARED_CAST)
	busy = false


## A vine patch caught Perrin: she closes in on her next free moment.
func on_player_ensnared() -> void:
	_grab_pending = true


## Dashes in and keeps slashing until Perrin breaks free.
func _grab() -> void:
	busy = true
	var to := flat(target.global_position - global_position)
	if to.length() > basic_range:
		await dash_toward(to, to.length() - 1.0, dash_speed)
	while target and target.is_stunned():
		face(target.global_position - global_position)
		await wait(basic_windup)
		_slash(basic_damage)
		await wait(maxf(basic_cooldown - basic_windup, 0.05))
	busy = false
