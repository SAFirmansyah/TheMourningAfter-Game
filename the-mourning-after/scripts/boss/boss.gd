class_name Boss
extends CharacterBody3D
## Shared boss behaviour: stats, damage intake, the health bar, chasing, dashes, pausable waits and
## melee hitboxes. Each boss decides what to do in _think() whenever no move is playing (busy).
## Moves are coroutines that set busy while they run; waits use child Timers, so they pause with
## the game and simply stop if the boss is freed.
## Every move except the basic attack is announced: a name pop-up overhead (like the mobs' "!"),
## a colour flash on the card, and for buffs a sparkle aura for as long as they last.

signal defeated

const HITBOX_SCENE := preload("res://scenes/weapon/weapon_hitbox.tscn")
const WALL_MASK := 131 # world_bounds + environment + mob_barrier
const BODY_LAYER := 8 # enemies
const HIT_HEIGHT := 0.9 # Perrin's hurtbox centre (m)

@export var stats: BossStats
@export var display_name := "Boss"
@export var base_move_speed := 5.0 # TUNE: a boss's 1x speed (m/s), same as Perrin's 1x
@export var move_speed_multiplier := 1.0
@export var start_delay := 1.5 # TUNE: pause after the room loads before the fight starts (s)
@export var keep_distance := 1.2 # TUNE: stops closing in at this distance (m)

@onready var card: Sprite3D = $Card
@onready var hurtbox: Area3D = $HurtboxArea
@onready var health_bar: BossHealthBar = $BossHealthBar
@onready var status_label: Label3D = $StatusLabel
@onready var aura_template: CPUParticles3D = $Aura

@export_group("Move Indicators")
@export var callout_hold := 0.9 # TUNE: how long a move's name stays overhead (s)
@export var flash_strength := 0.75 # TUNE: card flash at the start of a move (0–1)
@export var flash_time := 0.45 # TUNE: card flash fade (s)

var target: Player
var busy := false # a move is playing
var hidden := false # gone from the arena (Gwenith's pollen)
var invulnerable := false
var speed_bonus := 0.0 # fraction added to move speed
var damage_multiplier := 1.0
var cooldowns := {} # move name -> seconds left

var _facing := Vector2.LEFT
var _dash_velocity := Vector3.ZERO
var _dash_time_left := 0.0
var _start_left := 0.0
var _started := false
var _dead := false
var _stats_ready := false
var _callout_tween: Tween
var _auras := {} # buff name -> CPUParticles3D
var _damage_flash: DamageFlash
var _poison_ticks_left := 0
var _poison_timer: Timer


func _enter_tree() -> void:
	# Before the children's _ready: the hurtbox reads owner.stats.
	if _stats_ready:
		return
	_stats_ready = true
	stats = stats.duplicate() if stats else BossStats.new()
	stats.setup_stats()


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	add_to_group(&"enemies")
	add_to_group(&"boss")
	_damage_flash = DamageFlash.new()
	add_child(_damage_flash)
	_damage_flash.watch(stats, card)
	_damage_flash.enable_effects()
	health_bar.bind(self)
	status_label.hide()
	aura_template.emitting = false
	stats.health_depleted.connect(_die)
	stats.health_change.connect(func(cur: int, max_h: int) -> void:
		if max_h > 0:
			_on_health_fraction(float(cur) / max_h))
	_start_left = start_delay


func _physics_process(delta: float) -> void:
	if _dead:
		return
	for move: StringName in cooldowns:
		cooldowns[move] = maxf(cooldowns[move] - delta, 0.0)
	if target == null:
		target = _find_player()
		if target == null:
			return
		_on_target_found()
	if not _started:
		_start_left -= delta
		if _start_left > 0.0:
			return
		_started = true
		health_bar.reveal()
	_tick(delta)

	var to := flat(target.global_position - global_position)
	var walk := Vector3.ZERO
	if _dash_time_left > 0.0:
		_dash_time_left -= delta
		velocity = _dash_velocity
	else:
		if not busy and not hidden:
			face(to)
			walk = _think(to)
		velocity = walk * move_speed()
	move_and_slide()
	if card and absf(_facing.x) > 0.1:
		card.flip_h = _facing.x < 0.0


func set_stats(new_stats: Stats) -> void:
	stats = new_stats
	stats.setup_stats()
	stats.health_depleted.connect(_die)
	stats.health_change.connect(func(cur: int, max_h: int) -> void:
		if max_h > 0:
			_on_health_fraction(float(cur) / max_h))
	_damage_flash.watch(stats, card)
	health_bar.bind(self)
	get_node("HurtboxArea").refresh_layer()
# --- Overridden by each boss ---------------------------------------------------------------------

## Picks the next move (start one as a coroutine, without awaiting) or returns a walk direction.
func _think(_to_target: Vector3) -> Vector3:
	return Vector3.ZERO


## Per-frame upkeep once the fight has started (buffs, heals...).
func _tick(_delta: float) -> void:
	pass


## Health thresholds (unlocks).
func _on_health_fraction(_fraction: float) -> void:
	pass


func _on_target_found() -> void:
	pass


## Damage after the boss's own defences (block).
func _modify_incoming(amount: int) -> int:
	return amount


# --- Helpers -------------------------------------------------------------------------------------

func move_speed() -> float:
	return base_move_speed * move_speed_multiplier * (1.0 + speed_bonus)


func is_ready(move: StringName) -> bool:
	return cooldowns.get(move, 0.0) <= 0.0


func use(move: StringName, cooldown: float) -> void:
	cooldowns[move] = cooldown


## Walks toward Perrin until keep_distance.
func chase(to_target: Vector3) -> Vector3:
	return to_target.normalized() if to_target.length() > keep_distance else Vector3.ZERO


func face(direction: Vector3) -> void:
	if flat(direction).length() > 0.01:
		var d := flat(direction).normalized()
		_facing = Vector2(d.x, d.z)


func forward() -> Vector3:
	return Vector3(_facing.x, 0.0, _facing.y)


static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Pauses with the game; never resumes if the boss is freed first.
func wait(seconds: float) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.start(maxf(seconds, 0.01))
	await timer.timeout
	timer.queue_free()


## Fast straight-line move; walls and Perrin's body stop it.
func dash_toward(direction: Vector3, distance: float, speed: float) -> void:
	face(direction)
	_dash_velocity = flat(direction).normalized() * speed
	_dash_time_left = maxf(distance, 0.0) / speed
	await wait(_dash_time_left)
	_dash_time_left = 0.0


## Spawns one attack's hitboxes at offsets from the boss (on the floor plane). Hits Perrin once at most.
func strike(offsets: Array[Vector3], damage: int, radius: float, lifetime := 0.15) -> void:
	var log := HitLog.new()
	var amount := roundi(damage * damage_multiplier)
	for offset in offsets:
		var hitbox := HITBOX_SCENE.instantiate() as Hitbox
		hitbox.damage = amount
		hitbox.unit_type = Stats.UnitType.ENEMY
		hitbox.hit_log = log
		hitbox.ignore_root = self
		hitbox.hitbox_lifetime = lifetime
		hitbox.hit_landed.connect(func(body: Node3D) -> void:
			if body.has_method("receive_hit"):
				body.receive_hit(amount))
		var shape_node := hitbox.get_node(^"WeaponColission") as CollisionShape3D
		var capsule := (shape_node.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
		capsule.radius = radius
		capsule.height = maxf(1.6, radius * 2.0)
		shape_node.shape = capsule
		add_child(hitbox)
		hitbox.global_position = global_position + offset + Vector3.UP * HIT_HEIGHT


## Points along a sweep in front of the boss: an arc of `arc_degrees` at `reach`, plus a closer ring.
func arc_offsets(arc_degrees: float, reach: float, count: int) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var base := atan2(_facing.y, _facing.x)
	for ring: float in [reach * 0.55, reach]:
		for i in count:
			var t := 0.5 if count == 1 else float(i) / (count - 1)
			var angle := base + deg_to_rad(lerpf(-arc_degrees / 2.0, arc_degrees / 2.0, t))
			points.append(Vector3(cos(angle), 0.0, sin(angle)) * ring)
	return points


## Points in a straight line in front of the boss, from `start` to `reach`.
func line_offsets(start: float, reach: float, count: int) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for i in count:
		points.append(forward() * lerpf(start, reach, 0.0 if count == 1 else float(i) / (count - 1)))
	return points


## True when Perrin is within `reach` and inside a cone of `arc_degrees` around the boss's facing.
func in_arc(arc_degrees: float, reach: float) -> bool:
	var to := flat(target.global_position - global_position)
	if to.length() > reach:
		return false
	return to.length() < 0.3 or rad_to_deg(forward().angle_to(to)) <= arc_degrees / 2.0


## A spot `distance` from `origin` in the open (clear line from origin, not inside a wall).
## Falls back to `origin` if nothing fits.
func find_open_spot(origin: Vector3, distance: float, attempts := 12) -> Vector3:
	var space := get_world_3d().direct_space_state
	var start := randf() * TAU
	for i in attempts:
		var angle := start + TAU * i / attempts
		var spot := origin + Vector3(cos(angle), 0.0, sin(angle)) * distance
		if is_open_spot(origin, spot, space):
			return Vector3(spot.x, global_position.y, spot.z)
	return Vector3(origin.x, global_position.y, origin.z)


func is_open_spot(origin: Vector3, spot: Vector3, space := get_world_3d().direct_space_state) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(origin + Vector3.UP, spot + Vector3.UP, WALL_MASK)
	if not space.intersect_ray(ray).is_empty():
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.7
	query.shape = sphere
	query.transform = Transform3D(Basis(), spot + Vector3.UP)
	query.collision_mask = WALL_MASK
	return space.intersect_shape(query, 1).is_empty()


# --- Move indicators -----------------------------------------------------------------------------

## A move starts: its name pops up overhead and the card flashes in the move's colour.
func announce(text: String, color: Color) -> void:
	status_label.text = text
	status_label.modulate = color
	status_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	status_label.scale = Vector3.ONE * 0.3
	status_label.show()
	if _callout_tween:
		_callout_tween.kill()
	_callout_tween = create_tween()
	_callout_tween.tween_property(status_label, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_callout_tween.tween_interval(callout_hold)
	_callout_tween.tween_property(status_label, "modulate:a", 0.0, 0.25)
	_callout_tween.tween_callback(status_label.hide)
	_damage_flash.flash_tint(color, flash_strength, flash_time)


## Sparkles around the boss in a buff's colour while it lasts.
func set_aura(buff: StringName, color: Color, on: bool) -> void:
	if on and not _auras.has(buff):
		var aura := aura_template.duplicate() as CPUParticles3D
		add_child(aura)
		aura.color = color
		aura.emitting = true
		_auras[buff] = aura
	elif not on and _auras.has(buff):
		var aura: CPUParticles3D = _auras[buff]
		_auras.erase(buff)
		aura.emitting = false
		get_tree().create_timer(aura.lifetime + 0.1, false).timeout.connect(aura.queue_free)


## A sign that drifts up from the boss's head and fades (healing "+").
func rise_text(text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 96
	label.outline_size = 18
	label.modulate = color
	label.outline_modulate = Color(0.05, 0.2, 0.05, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.008
	add_child(label)
	var start := Vector3(randf_range(-0.5, 0.5), 2.8, 0.0)
	label.position = start
	var tween := label.create_tween()
	tween.tween_property(label, "position", start + Vector3.UP * 0.9, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.tween_callback(label.queue_free)


## A flat coloured wedge on the floor showing where a sweep will land, for `seconds`.
func show_wedge(arc_degrees: float, reach: float, color: Color, seconds: float) -> MeshInstance3D:
	var mesh := ImmediateMesh.new()
	var base := atan2(_facing.y, _facing.x)
	var steps := 16
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in steps:
		var a0 := base + deg_to_rad(lerpf(-arc_degrees / 2.0, arc_degrees / 2.0, float(i) / steps))
		var a1 := base + deg_to_rad(lerpf(-arc_degrees / 2.0, arc_degrees / 2.0, float(i + 1) / steps))
		mesh.surface_add_vertex(Vector3.ZERO)
		mesh.surface_add_vertex(Vector3(cos(a0), 0.0, sin(a0)) * reach)
		mesh.surface_add_vertex(Vector3(cos(a1), 0.0, sin(a1)) * reach)
	mesh.surface_end()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(color, 0.4)
	var wedge := MeshInstance3D.new()
	wedge.mesh = mesh
	wedge.material_override = material
	wedge.position = Vector3.UP * 0.05
	add_child(wedge)
	get_tree().create_timer(seconds, false).timeout.connect(wedge.queue_free)
	return wedge


## Leaves the arena (no body, no hurtbox) or comes back.
func set_hidden(on: bool) -> void:
	hidden = on
	visible = not on
	collision_layer = 0 if on else BODY_LAYER
	hurtbox.set_deferred(&"monitorable", not on)


# --- Taking hits (called by Perrin's sword and its abilities) -------------------------------------

func receive_hit(amount: int) -> void:
	if _dead or invulnerable or hidden:
		return
	stats.take_damage(_modify_incoming(amount))


func flash_crit() -> void:
	_damage_flash.flash_white()


func apply_poison(damage_per_tick: int, tick_count: int, tick_interval: float) -> void:
	if _poison_timer:
		_poison_timer.queue_free()
	_poison_ticks_left = tick_count
	_poison_timer = Timer.new()
	_poison_timer.wait_time = tick_interval
	add_child(_poison_timer)
	_poison_timer.timeout.connect(func() -> void:
		receive_hit(damage_per_tick)
		_poison_ticks_left -= 1
		if _poison_ticks_left <= 0 and _poison_timer:
			_poison_timer.queue_free()
			_poison_timer = null)
	_poison_timer.start()


func _find_player() -> Player:
	var player := RunInventory.get_player()
	if player and player.is_inside_tree():
		return player
	return get_tree().get_first_node_in_group(&"player") as Player


func _die() -> void:
	if _dead:
		return
	_dead = true
	busy = true
	set_physics_process(false)
	visible = false
	collision_layer = 0
	collision_mask = 0
	health_bar.hide()
	if target and target.is_stunned():
		target.clear_stun() # nobody left to hold him
	defeated.emit()
	queue_free()
