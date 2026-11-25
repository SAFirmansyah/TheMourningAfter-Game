class_name Enemy
extends CharacterBody3D

var target = null

@export var stats : MutantStats

@export_group("Movement")
@export var base_move_speed := 6.0 # TUNE: walk speed at 1x (m/s)
@export_range(0.5, 2.0, 0.05) var move_speed_multiplier := 1.0 # move speed stat (0.5x–2x)
@export_range(0.0, 1.0) var depth_speed_compensation := 0.0 # TUNE: 0 = raw world speed, 1 = equal on-screen speed in all directions

@export_group("Chase")
@export var sense_delay := 1.0 # TUNE: pause between spotting the player ("!") and starting to move (s)
@export var chase_bend := 0.6 # TUNE: largest sideways lean of the approach (0 = straight line, 1 = 45°)
@export var chase_bend_fade := 3.0 # TUNE: distance from the player over which the lean straightens out (m)
@export var chase_replan_time := Vector2(1.5, 3.5) # TUNE: seconds before picking a new lean (min, max)
@export var chase_acceleration := 4.0 # TUNE: speed-up / slow-down rate (m/s²)
@export var chase_ease_distance := 0.8 # TUNE: distance before attack range over which it slows down (m)
@export var chase_ease_min := 0.3 # TUNE: pace when right at attack range (fraction of full speed)
@export var chase_pace_variation := 0.12 # TUNE: random pace difference between mobs (fraction of full speed)

@export_group("Combat")
@export var attack_reach := 0.35 # TUNE: this enemy's own body radius
@export var attack_cooldown := 0.5 # TUNE: seconds between attacks
@export var attack_range := 1.2 # TUNE: distance at which this enemy can start an attack
@export var knockback_multiplier := 1.0 # TUNE: scales how far hits push this mob
@export var fall_limit := -3.0 # TUNE: below this height a mob is put back where it last stood

@export_group("Loot")
@export var loot_pickup_scene: PackedScene = preload("res://scenes/loot/loot_pickup.tscn")
@export var loot_drop_range := Vector2i(1, 1) # TUNE: drops per kill (min, max)
@export var loot_pool: Array[LootData] = [] # drag the relevant .tres files per mutant scene; equal odds
@export var loot_scatter_radius := 0.6

var _loot_rng := RandomNumberGenerator.new()

var _is_dead := false
var _stun_time_left := 0.0
var _poison_timer: Timer
var _poison_ticks_done := 0
var _attack_cooldown_left := 0.0
var _facing := Vector2.DOWN
var _knockback_velocity := Vector3.ZERO
var _knockback_time_left := 0.0
var _last_floor_position := Vector3.ZERO
var _sense_time_left := -1.0 # < 0: hasn't spotted the player yet
var _lean := 0.0
var _replan_left := 0.0
var _pace := 1.0

var _damage_flash: DamageFlash

@onready var _alert: Label3D = get_node_or_null(^"Alert")
@onready var _health_bar: MobHealthBar = get_node_or_null(^"HealthBar")
@onready var sprite: AnimatedSprite3D = $Card

## Per animation, how far (art pixels) to shift the card so its feet line up with the idle art, for
## animations drawn on a different canvas (e.g. {&"attack": Vector2(-58, 111)}). Mirrors with flip_h.
@export var animation_offsets := {}
var _base_offset := Vector2.ZERO

var _attacking := false


func _ready():
	if stats == null:
		stats = MutantStats.new()
	else:
		stats = stats.duplicate()
	call_deferred("_print_health")
	stats.health_depleted.connect(_on_health_depleted)
	_damage_flash = DamageFlash.new()
	add_child(_damage_flash)
	_damage_flash.watch(stats, $Card)
	_damage_flash.enable_effects()
	if _health_bar:
		_health_bar.watch(stats)
	if _alert:
		_alert.hide()
	_pace = 1.0 + randf_range(-chase_pace_variation, chase_pace_variation)
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	_base_offset = sprite.offset
	add_to_group(&"enemies")


func _on_sprite_animation_finished() -> void:
	if sprite.animation == &"attack":
		_attacking = false
		

func _print_health() -> void:
	print("health: ", stats.health)
	
func _on_health_depleted() -> void:
	if _is_dead:
		return
	_is_dead = true
	set_physics_process(false) # stop moving/attacking
	visible = false # hide the sprite/model
	collision_layer = 0 # no longer detectable as a body
	collision_mask = 0 # no longer collides with anything
	target = null # stop chasing (redundant with physics_process off, but explicit)
	# play death animation / drop loot below
	# await get_tree().create_timer(1.0).timeout # TUNE: match your death anim length
	_drop_loot()
	queue_free()
	
func _drop_loot() -> void:
	if loot_pickup_scene == null or loot_pool.is_empty():
		return

	var drop_count := _loot_rng.randi_range(loot_drop_range.x, loot_drop_range.y)
	var parent := get_parent()
	if parent == null:
		return

	for i in drop_count:
		var candidates := loot_pool.filter(_can_drop)
		if candidates.is_empty():
			continue
		var loot: LootData = candidates[_loot_rng.randi_range(0, candidates.size() - 1)]

		var pickup := loot_pickup_scene.instantiate() as LootPickup
		pickup.loot_id = loot.loot_id
		pickup.loot_data = loot
		pickup.tint = loot.tint
		pickup.auto_collect = loot.effect != LootData.EffectType.MAGIC_RESIDUE # residue: walk up and press E
		pickup.set_meta(&"dropped", true) # saved with the room if still on the floor

		var offset := Vector3(
			_loot_rng.randf_range(-loot_scatter_radius, loot_scatter_radius),
			0.0,
			_loot_rng.randf_range(-loot_scatter_radius, loot_scatter_radius)
		)

		parent.add_child(pickup)
		pickup.global_position = global_position + offset

## Capped loot stops dropping once the cap is held or already lying on the floor.
func _can_drop(loot: LootData) -> bool:
	var on_floor := get_tree().get_nodes_in_group(&"loot_pickups").filter(func(p: LootPickup) -> bool:
		return p.loot_data and p.loot_data.effect == loot.effect).size()
	match loot.effect:
		LootData.EffectType.DOUBLE_DASH:
			var player := RunInventory.get_player()
			return on_floor == 0 and (player == null or player.max_dashes < 2)
		LootData.EffectType.MAGIC_RESIDUE:
			return RunInventory.residue_gained_this_run + on_floor < RunInventory.MAX_RESIDUE_PER_RUN
	return true


func receive_hit(amount: int) -> void:
	stats.take_damage(amount)

func apply_knockback(push: Vector3, duration: float) -> void:
	_knockback_velocity = push * knockback_multiplier
	_knockback_time_left = duration


## True when a wall sits within `gap` metres of this mob in `direction`.
func is_pinned(direction: Vector3, gap: float) -> bool:
	var shape_node := get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	if shape_node == null or direction.is_zero_approx():
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape_node.shape
	query.transform = shape_node.global_transform
	query.motion = direction.normalized() * gap
	query.collision_mask = 131 # world_bounds + environment + mob_barrier
	query.exclude = [get_rid()]
	var result := get_world_3d().direct_space_state.cast_motion(query)
	return result[0] < 1.0

func apply_stun(duration: float) -> void:
	print(name, " stunned for ", duration, "s")
	_stun_time_left = maxf(_stun_time_left, duration)
	_damage_flash.set_greyed(true)


## Crit hits flash the card white.
func flash_crit() -> void:
	_damage_flash.flash_white()
	
func apply_poison(damage_per_tick: int, tick_count: int, tick_interval: float) -> void:
	if _poison_timer:
		_poison_timer.queue_free()

	_poison_ticks_done = 0
	_poison_timer = Timer.new()
	_poison_timer.wait_time = tick_interval
	add_child(_poison_timer)
	_poison_timer.timeout.connect(func():
		stats.take_damage(int(damage_per_tick))
		_poison_ticks_done += 1
		if _poison_ticks_done >= tick_count:
			_poison_timer.stop()
			_poison_timer.queue_free()
	)
	_poison_timer.start()

func _physics_process(delta: float) -> void:
	if _last_floor_position == Vector3.ZERO:
		_last_floor_position = global_position # spawn point: always on the floor
	if is_on_floor() and global_position.y > fall_limit + 2.0:
		_last_floor_position = global_position
	if not is_on_floor():
		velocity += get_gravity() * delta
		if global_position.y < fall_limit:
			_recover_from_fall()
		
	_attack_cooldown_left = maxf(0.0, _attack_cooldown_left - delta)
	if _stun_time_left > 0.0:
		_stun_time_left -= delta
		if _stun_time_left <= 0.0:
			_damage_flash.set_greyed(false)

	if _knockback_time_left > 0.0:
		_knockback_time_left -= delta
		velocity = _knockback_velocity
		move_and_slide()
		return # pushed back; no chasing or attacking this frame
		
	if _stun_time_left > 0.0:
		velocity = Vector3.ZERO
		return # skip movement/attack logic while stunned
	
	if target == null:
		_look_for_player()
	elif _sense_time_left > 0.0:
		_sense_time_left -= delta # "!" shown; waiting before moving
	else:
		_attack(delta)


## Safety net: a mob that dropped off the floor goes back where it last stood.
func _recover_from_fall() -> void:
	push_warning(name, " fell out of the room; putting it back")
	global_position = _last_floor_position
	velocity = Vector3.ZERO
	_knockback_time_left = 0.0


## Spots the player as soon as this mob is on screen, however far away.
func _look_for_player() -> void:
	var player := RunInventory.get_player()
	var camera := get_viewport().get_camera_3d()
	if player == null or camera == null or not camera.is_position_in_frustum(global_position):
		return
	target = player
	_sense_time_left = sense_delay
	if _alert:
		_alert.show()
		_alert.scale = Vector3.ONE * 0.3
		var pop := create_tween()
		pop.tween_property(_alert, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.tween_interval(maxf(sense_delay - 0.15, 0.0))
		pop.tween_callback(_alert.hide)


func _attack(delta: float) -> void:
	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0.0
	var dist_to_target := to_target.length()
	var direction := to_target.normalized()
	_facing = Vector2(direction.x, direction.z)
	if direction.x != 0.0:
		sprite.flip_h = direction.x < 0.0

	var desired := Vector3.ZERO
	if dist_to_target > attack_range:
		_replan_left -= delta
		if _replan_left <= 0.0:
			_replan_left = randf_range(chase_replan_time.x, chase_replan_time.y)
			_lean = randf_range(-chase_bend, chase_bend)
		var lean := _lean * clampf((dist_to_target - attack_range) / chase_bend_fade, 0.0, 1.0)
		var heading := (direction + direction.cross(Vector3.UP) * lean).normalized()
		var slow := lerpf(chase_ease_min, 1.0, clampf((dist_to_target - attack_range) / chase_ease_distance, 0.0, 1.0))
		desired = heading * base_move_speed * move_speed_multiplier * _pace * slow
		if not _attacking:
			sprite.play("walk")
	elif _attack_cooldown_left <= 0.0:
		_spawn_hitbox()

	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(desired, chase_acceleration * delta)
	velocity = Vector3(flat.x, velocity.y if motion_mode == MOTION_MODE_GROUNDED else 0.0, flat.z)
	move_and_slide()
	
	
func _spawn_hitbox() -> void:
	_attack_cooldown_left = attack_cooldown
	_attacking = true
	sprite.play("attack")

	var hitbox := preload("res://scenes/weapon/weapon_hitbox.tscn").instantiate() as Hitbox

	hitbox.damage = stats.get_damage()
	hitbox.unit_type = Stats.UnitType.ENEMY
	hitbox.ignore_root = self
	hitbox.hitbox_lifetime = 0.2 # TUNE: how long the hitbox lingers
	hitbox.hit_landed.connect(_on_hitbox_hit)

	var shape_node: CollisionShape3D
	for child in hitbox.get_children():
		if child is CollisionShape3D:
			shape_node = child
			break

	var capsule := (shape_node.shape as CapsuleShape3D).duplicate()
	capsule.radius = stats.get_hitbox_radius()
	capsule.height = stats.get_hitbox_height()
	shape_node.shape = capsule

	var forward := Vector3(_facing.x, 0.0, _facing.y)
	hitbox.position = forward * (attack_reach + stats.get_hitbox_height() / 2.0)

	add_child(hitbox)
	hitbox.global_position = global_position + forward * (attack_reach + stats.get_hitbox_height() / 2.0)

func _on_hitbox_hit(target_body: Node3D) -> void:
	if target_body.has_method("receive_hit"):
		target_body.receive_hit(stats.get_damage())


## Keeps the body still when an animation's frames sit differently in their canvas.
func _process(_delta: float) -> void:
	var shift: Vector2 = animation_offsets.get(sprite.animation, Vector2.ZERO)
	if sprite.flip_h:
		shift.x = -shift.x
	sprite.offset = _base_offset + shift
