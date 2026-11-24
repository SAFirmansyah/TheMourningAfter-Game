class_name Player
extends CharacterBody3D
## Screen-relative movement on the floor plane, with dash charges and i-frames.
## Dashing passes through environment objects and mobs; walls still block. Walking into mobs is blocked.

signal dash_started
signal dash_ended
signal attack_started
signal attack_ended
signal died
signal weapon_changed(weapon: WeaponData)

@export var card: Sprite3D
@export var camera_rig: CameraRig
@export var display_name := "Player" # name shown in conversations
@export var portrait: Texture2D # conversation portrait; placeholder uses the card

@export_group("Movement")
@export var base_move_speed := 5.0 # TUNE: walk speed at 1x (m/s)
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
@export_flags_3d_physics var dash_phase_layers := 10 # layers passed through while dashing (environment, enemies)

@export_group("Combat")
@export var stats: HeroStats # the hero's Stats resource (health, armor, etc.)
@export var weapon: WeaponData:
	set(value):
		weapon = value
		charge_points = 0.0 # every new loadout starts uncharged
		if _sword:
			_sword.set_weapon(value)
		if stats:
			stats.equip_weapon(value)
		weapon_changed.emit(value)
@export var attack_reach := 0.5 # TUNE: player body radius — hitbox spawns this far forward before adding weapon reach
@export var attack_height := 0.8 # TUNE: vertical offset — roughly chest/sword height
@export var attack_hitbox_count := 3 # TUNE: how many hitboxes spawn per attack
@export var attack_hitbox_spacing := 0.3 # TUNE: lateral gap between hitboxes in the arc
@export var knockback_speed := 3.0 # TUNE: push speed given to enemies hit (m/s)
@export var knockback_time := 0.1 # TUNE: how long the push lasts (s)
@export var pinned_damage_multiplier := 1.5 # TUNE: damage vs a mob pressed against a wall
@export var pinned_gap := 0.1 # TUNE: wall distance that counts as pressed against it (m)
@export var aim_assist_range := 2.4 # TUNE: swings turn toward an enemy within this distance (m)
@export var attack_anim_min_time := 0.2
@export_range(0.0, 180.0) var aim_assist_angle := 60.0 # TUNE: ...if it's within this angle of where Perrin faces (degrees)

@export_group("Heal Effect")
@export var heal_plus_count := 4 # TUNE: "+" signs per heal
@export var heal_plus_color := Color(0.4, 1.0, 0.4) # TUNE
@export var heal_plus_height := 2.0 # TUNE: start height above feet (m)
@export var heal_plus_rise := 0.8 # TUNE: how far each "+" floats up (m)
@export var heal_plus_time := 0.7 # TUNE: rise time (s)
@export var heal_plus_stagger := 0.12 # TUNE: delay between signs (s)

var bonus_weapon_damage := 0.0
var bonus_cooldown_reduction := 0.0 # 0.0–1.0, fraction off attack_cooldown
var damage_reduction := 0.0 # 0.0–1.0, fraction off incoming damage
var bonus_move_speed := 0.0 # added to the move speed multiplier by loot

const MAX_CHARGE := 100.0

var is_invulnerable := false
var dashes_available := 0
var input_enabled := true
var animation_held := false # a cutscene is animating the card itself (e.g. walking her to a mark)
var forced_input := Vector2.ZERO # screen-space direction used while input is disabled
var charge_points := 0.0 # 0–MAX_CHARGE; fills from successful base hits, spent by the sword's ability (RMB/Q)

var _facing := Vector2.DOWN
var _dashing := false
var _dash_queued := false
var _dash_time_left := 0.0
var _iframe_time_left := 0.0
var _dash_velocity := Vector3.ZERO
var _recharge_progress := 0.0

var _attacking := false
var _attack_queued := false
var _attack_cooldown_left := 0.0
var _ability_queued := false
var _stun_time_left := 0.0
var _damage_flash: DamageFlash

@onready var _body_shape: CollisionShape3D = $CollisionShape3D
@onready var _sword: SwordVisual = get_node_or_null(^"Sword")
@onready var _ready_sparkle: CPUParticles3D = get_node_or_null(^"ReadySparkle")
@onready var sprite: AnimatedSprite3D = $Card

func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	dashes_available = max_dashes
	if stats == null:
		stats = HeroStats.new()
	add_to_group(&"player")
	var damage_flash := DamageFlash.new()
	add_child(damage_flash)
	damage_flash.watch(stats, card)
	_damage_flash = damage_flash
	if _sword:
		_sword.set_weapon(weapon)
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	
	print("weapon at _ready start: ", weapon.weapon_name if weapon else "null")
	call_deferred("_print_health")
	
	stats.health_depleted.connect(_on_health_depleted)
		
func _print_health() -> void:
	print("player health: ", stats.health)
	

func _physics_process(delta: float) -> void:
	if _stun_time_left > 0.0:
		_stun_time_left -= delta
		if _stun_time_left <= 0.0:
			clear_stun()
	var stunned := is_stunned()
	var can_act := input_enabled and not stunned
	var input := Vector2.ZERO if stunned else (Input.get_vector("move_left", "move_right", "move_up", "move_down") if input_enabled else forced_input)
	if input != Vector2.ZERO:
		_facing = input.normalized()
		if input.x != 0:
			sprite.flip_h = input.x < 0
	if not _dashing and not _attacking and not animation_held:
		sprite.play("walk" if input != Vector2.ZERO else "idle")

	_recharge_dashes(delta)
	if _dash_queued:
		_dash_queued = false
		if can_act:
			_try_dash()

	_attack_cooldown_left = maxf(0.0, _attack_cooldown_left - delta)
	if _attack_queued:
		_attack_queued = false
		if can_act:
			_try_attack()

	if _ability_queued:
		_ability_queued = false
		if can_act:
			_try_activate_ability()

	if _dashing:
		velocity = _dash_velocity
		_dash_time_left -= delta
		var still_inside := _overlaps_phase_layers() and _dash_time_left > -dash_max_extension
		if _dash_time_left <= 0.0 and not still_inside:
			_end_dash()
	else:
		var target := _to_world(input) * base_move_speed * move_speed_multiplier()
		var rate := acceleration if input != Vector2.ZERO else deceleration
		velocity = velocity.move_toward(target, rate * delta)

	_iframe_time_left = maxf(0.0, _iframe_time_left - delta)
	is_invulnerable = _dashing or _iframe_time_left > 0.0

	velocity.y = 0.0
	move_and_slide()

	if card and input.x != 0.0:
		card.flip_h = input.x < 0.0
	if _sword:
		_sword.point(_facing)


func _unhandled_input(event: InputEvent) -> void:
	# Event-based so presses consumed by UI (e.g. Space advancing text) never dash/attack.
	if input_enabled and event.is_action_pressed(&"dash"):
		_dash_queued = true

	if input_enabled and weapon and event.is_action_pressed(&"attack"):
		_attack_queued = true
		
	if input_enabled and weapon and event.is_action_pressed(&"weapon_ability"):
		_ability_queued = true


func _process(_delta: float) -> void:
	if _ready_sparkle:
		_ready_sparkle.emitting = is_ability_ready()
	RenderingServer.global_shader_parameter_set(&"occlusion_target", get_global_transform_interpolated().origin)


## Rooted: can't move, dash, attack or use sword abilities, and the card greys out.
func apply_stun(duration: float) -> void:
	_stun_time_left = maxf(_stun_time_left, duration)
	if _dashing:
		_end_dash()
	_damage_flash.set_greyed(true)


func clear_stun() -> void:
	_stun_time_left = 0.0
	_damage_flash.set_greyed(false)


func is_stunned() -> bool:
	return _stun_time_left > 0.0


func _on_sprite_animation_finished() -> void:
	if sprite.animation == &"attack":
		_attacking = false
		sprite.speed_scale = 1.0


func teleport(pos: Vector3) -> void:
	global_position = pos
	if _dashing:
		_end_dash()
	velocity = Vector3.ZERO
	reset_physics_interpolation()


func heal(amount: int) -> void:
	stats.on_health_set(stats.health + amount)
	show_heal_effect()


## Green "+" signs drifting up over Perrin's head.
func show_heal_effect() -> void:
	for i in heal_plus_count:
		var plus := Label3D.new()
		plus.text = "+"
		plus.font_size = 96
		plus.outline_size = 18
		plus.modulate = heal_plus_color
		plus.outline_modulate = Color(0.05, 0.2, 0.05, 1.0)
		plus.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		plus.no_depth_test = true
		plus.pixel_size = 0.008
		add_child(plus)
		var start := Vector3(randf_range(-0.45, 0.45), heal_plus_height + randf_range(-0.2, 0.2), 0.0)
		plus.position = start
		plus.modulate.a = 0.0
		var tween := plus.create_tween()
		tween.tween_interval(i * heal_plus_stagger)
		tween.tween_property(plus, "modulate:a", 1.0, 0.1)
		tween.parallel().tween_property(plus, "position", start + Vector3.UP * heal_plus_rise, heal_plus_time)
		tween.tween_property(plus, "modulate:a", 0.0, 0.25)
		tween.tween_callback(plus.queue_free)

## Base damage of one swing, before abilities.
func hit_damage() -> float:
	return weapon.damage + bonus_weapon_damage if weapon else 0.0


func move_speed_multiplier() -> float:
	return stats.move_speed_multiplier + bonus_move_speed


func receive_hit(amount: int) -> void:
	if is_invulnerable or TestTools.no_health_loss:
		return # dash i-frames, or the No health loss test button
	var reduced := int(amount * (1.0 - damage_reduction))
	stats.take_damage(reduced)

func _try_dash() -> void:
	if dashes_available <= 0 or _dashing:
		return
	dashes_available -= 1
	_dashing = true
	sprite.play("dash")
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
	velocity = velocity.limit_length(base_move_speed * move_speed_multiplier())
	_iframe_time_left = dash_iframe_extra
	if card:
		card.transparency = 0.0
	dash_ended.emit()


## A base swing (LMB) charges the sword when it lands; an ability swing (RMB/Q) applies the
## sword's ability to whatever it hits instead.
func _try_attack(ability_swing := false) -> bool:
	if weapon == null or _attack_cooldown_left > 0.0:
		return false
	_attack_cooldown_left = weapon.attack_cooldown * (1.0 - bonus_cooldown_reduction)
	_aim_at_nearby_enemy()
	_attacking = true

	var frames := sprite.sprite_frames
	var natural_duration := frames.get_frame_count(&"attack") / frames.get_animation_speed(&"attack")
	var display_time := maxf(attack_anim_min_time, weapon.active_delay + weapon.active_window)
	sprite.speed_scale = natural_duration / display_time
	sprite.play("attack")
	
	var swing := {
		"damage": hit_damage(),
		"abilities": weapon.charged_abilities if ability_swing else [],
		"charges": not ability_swing,
		"landed": false,
		"facing": _facing,
	}
	if _sword:
		_sword.point(_facing)
		_sword.swing(weapon.active_delay + weapon.active_window)
	attack_started.emit()
	await get_tree().create_timer(weapon.active_delay).timeout
	_spawn_hitbox(swing)
	attack_ended.emit()
	return true


## Turns the swing toward the closest enemy roughly in front, so near-misses connect.
func _aim_at_nearby_enemy() -> void:
	var forward := Vector3(_facing.x, 0.0, _facing.y)
	var best: Vector3
	var best_dist := aim_assist_range
	for enemy: Node3D in get_tree().get_nodes_in_group(&"enemies"):
		var to_enemy := enemy.global_position - global_position
		to_enemy.y = 0.0
		var dist := to_enemy.length()
		if dist > best_dist or dist < 0.01:
			continue
		if rad_to_deg(forward.angle_to(to_enemy)) > aim_assist_angle:
			continue
		best = to_enemy
		best_dist = dist
	if best_dist < aim_assist_range:
		_facing = Vector2(best.x, best.z).normalized()


func _spawn_hitbox(swing: Dictionary) -> void:
	var shared_log := HitLog.new()

	var facing: Vector2 = swing.get("facing", _facing)
	var side: Vector3 = Vector3(-facing.y, 0.0, facing.x)
	var forward: Vector3 = Vector3(facing.x, 0.0, facing.y)
	var base_offset: Vector3 = forward * (attack_reach + weapon.hitbox_radius / 2.0)

	for n in attack_hitbox_count:
		var hitbox := preload("res://scenes/weapon/weapon_hitbox.tscn").instantiate() as Hitbox

		hitbox.damage = int(swing.damage)
		hitbox.unit_type = Stats.UnitType.HERO
		hitbox.hit_log = shared_log
		hitbox.ignore_root = self
		hitbox.hitbox_lifetime = weapon.active_window
		hitbox.hit_landed.connect(_on_hitbox_hit.bind(swing))

		var shape_node: CollisionShape3D
		for child in hitbox.get_children():
			if child is CollisionShape3D:
				shape_node = child
				break

		var capsule := (shape_node.shape as CapsuleShape3D).duplicate()
		capsule.height = maxf(weapon.hitbox_height, weapon.hitbox_radius * 2.0) # capsules clamp radius to height / 2
		capsule.radius = weapon.hitbox_radius
		shape_node.shape = capsule

		var lateral_spread := (n - (attack_hitbox_count - 1) / 2.0) * attack_hitbox_spacing
		hitbox.position = base_offset + side * lateral_spread + Vector3.UP * attack_height

		add_child(hitbox)


func _on_hitbox_hit(target: Node3D, swing: Dictionary) -> void:
	var away := target.global_position - global_position
	away.y = 0.0
	away = away.normalized()
	if target.has_method("receive_hit"):
		var damage := int(swing.damage)
		if target.has_method("is_pinned") and target.is_pinned(away, pinned_gap):
			damage = roundi(damage * pinned_damage_multiplier)
		target.receive_hit(damage)
		print("dealt ", damage, " damage to ", target.name)
	if target.has_method("apply_knockback"):
		target.apply_knockback(away * knockback_speed, knockback_time)
	for ability: WeaponAbility in swing.abilities:
		ability.apply(self, target)
	# One step of charge per base swing that lands, however many targets it hits.
	if swing.charges and not swing.landed and weapon:
		swing.landed = true
		charge_points = minf(charge_points + MAX_CHARGE / maxi(weapon.hits_to_charge, 1), MAX_CHARGE)


func is_ability_ready() -> bool:
	return weapon != null and charge_points >= MAX_CHARGE

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

func _on_health_depleted() -> void:
	died.emit()

func reset_run_modifiers() -> void:
	bonus_weapon_damage = 0.0
	bonus_cooldown_reduction = 0.0
	damage_reduction = 0.0
	bonus_move_speed = 0.0
	max_dashes = 1
	charge_points = 0.0


## RMB/Q with a full charge: self abilities (heal) apply at once; the rest swing an ability attack.
func _try_activate_ability() -> void:
	if not is_ability_ready():
		return
	if weapon.charge_instant_use:
		for ability in weapon.charged_abilities:
			ability.apply(self, self)
		charge_points = 0.0
	elif _attack_cooldown_left <= 0.0:
		charge_points = 0.0
		_try_attack(true)
