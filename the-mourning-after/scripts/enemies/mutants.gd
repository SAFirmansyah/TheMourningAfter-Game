class_name Enemy
extends CharacterBody3D

var target = null

@export var stats : MutantStats

@export_group("Movement")
@export var base_move_speed := 6 # TUNE: walk speed at 1x (m/s)
@export_range(0.5, 2.0, 0.05) var move_speed_multiplier := 1.0 # move speed stat (0.5x–2x)
@export_range(0.0, 1.0) var depth_speed_compensation := 0.0 # TUNE: 0 = raw world speed, 1 = equal on-screen speed in all directions

@export_group("Combat")
@export var attack_reach := 0.35 # TUNE: this enemy's own body radius
@export var attack_cooldown := 0.5 # TUNE: seconds between attacks
@export var attack_range := 1.2 # TUNE: distance at which this enemy can start an attack

@export_group("Loot")
@export var loot_pickup_scene: PackedScene = preload("res://scenes/loot/loot_pickup.tscn")
@export var loot_drop_range := Vector2i(1, 3)
@export var loot_pool: Array[LootData] = [] # drag the relevant .tres files per mutant scene
@export var loot_scatter_radius := 0.6

var _loot_rng := RandomNumberGenerator.new()

var _is_dead := false
var _stunned := false
var _poison_timer: Timer
var _poison_ticks_done := 0
var _attack_cooldown_left := 0.0
var _facing := Vector2.DOWN

func _ready():
	if stats == null:
		stats = MutantStats.new()
	else:
		stats = stats.duplicate() # don't share the Inspector-assigned resource across instance
	call_deferred("_print_health")
	stats.health_depleted.connect(_on_health_depleted)

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
		var candidates := loot_pool.filter(func(l): return l.effect != LootData.EffectType.MAGIC_RESIDUE or RunInventory.can_drop_residue())
		if candidates.is_empty():
			continue
		var loot: LootData = candidates[_loot_rng.randi_range(0, candidates.size() - 1)]

		var pickup := loot_pickup_scene.instantiate() as LootPickup
		pickup.loot_id = loot.loot_id
		pickup.loot_data = loot

		var offset := Vector3(
			_loot_rng.randf_range(-loot_scatter_radius, loot_scatter_radius),
			0.0,
			_loot_rng.randf_range(-loot_scatter_radius, loot_scatter_radius)
		)

		parent.add_child(pickup)
		pickup.global_position = global_position + offset

func receive_hit(amount: int) -> void:
	stats.take_damage(amount)

func apply_stun(duration: float) -> void:
	print(name, " stunned for ", duration, "s")
	_stunned = true
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func(): _stunned = false)
	
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
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	_attack_cooldown_left = maxf(0.0, _attack_cooldown_left - delta)
		
	if _stunned:
		return # skip movement/attack logic while stunned
	
	if target:
		_attack(delta)

func _attack(delta: float) -> void:
	var direction = (target.global_position - global_position).normalized()
	_facing = Vector2(direction.x, direction.z)

	var dist_to_target := global_position.distance_to(target.global_position)

	if dist_to_target > attack_range:
		velocity = direction * base_move_speed
		move_and_slide()
	elif _attack_cooldown_left <= 0.0:
		velocity = Vector3.ZERO
		_spawn_hitbox()

	
func _spawn_hitbox() -> void:
	_attack_cooldown_left = attack_cooldown

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

func _on_detection_area_body_entered(body: Node3D) -> void:
	if body.name == "Player" :
		target = body

func _on_detection_area_body_exited(body: Node3D) -> void:
	if body.name == "Player" :
		target = null
