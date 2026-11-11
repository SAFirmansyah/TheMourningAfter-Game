class_name BossGwenith
extends CharacterBody3D

signal defeated

enum State { CHASE, BASIC_ATTACK, DASH_ATTACK, PESTICIDE, POLLEN_CLOUD, ENSNARED_GRAB }

@export var stats: BossStats
@export var target: Node3D

@export_group("Movement")
@export var base_move_speed := 4.0 # TUNE
@export var move_speed_multiplier := 2.0

@export_group("Basic Attack")
@export var basic_damage := 5
@export var basic_cooldown := 0.3
@export var basic_range := 1.6 # TUNE: distance to trigger
@export var basic_hitbox_spacing := 0.3
@export var basic_hitbox_radius := 0.3
@export var basic_hitbox_height := 1.0
@export var basic_hitbox_lifetime := 0.15

@export_group("Dash Attack")
@export var dash_damage := 15
@export var dash_cooldown := 5.0
@export var dash_speed := 18.0 # TUNE
@export var dash_duration := 0.2 # TUNE: how long the dash burst lasts

@export_group("Pesticide")
@export var pesticide_scene: PackedScene # AOE hazard scene, see PesticideHazard.gd
@export var pesticide_radius := 3.0
@export var pesticide_dps := 5
@export var pesticide_duration := 3.0
@export var pesticide_cooldown := 8.0 # TUNE — not specified in design

@export_group("Pollen Cloud")
@export var pollen_cloud_radius := 3.0
@export var pollen_cloud_count := 4
@export var pollen_cloud_duration := 5.0
@export var pollen_cloud_cooldown := 15.0 # TUNE — not specified

@export_group("Ensnared Phase")
@export var ensnared_health_fraction := 0.3
@export var vine_scene: PackedScene # see VineHazard.gd
@export var vine_duration := 5.0
@export var vine_cooldown := 10.0

var _current_attack_damage := 0
var _state := State.CHASE
var _facing := Vector2.DOWN
var _basic_cd_left := 0.0
var _dash_cd_left := 0.0
var _pesticide_cd_left := 0.0
var _pollen_cd_left := 0.0
var _vine_cd_left := 0.0
var _ensnared_unlocked := false
var _is_dead := false


func _ready() -> void:
	if stats == null:
		stats = BossStats.new()
	else:
		stats = stats.duplicate()
	stats.health_depleted.connect(_on_health_depleted)
	stats.health_change.connect(_on_health_change)


func receive_hit(amount: int) -> void:
	stats.take_damage(amount)


func _on_health_change(cur: int, max_h: int) -> void:
	if not _ensnared_unlocked and float(cur) / float(max_h) <= ensnared_health_fraction:
		_ensnared_unlocked = true


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
	_dash_cd_left = maxf(0.0, _dash_cd_left - delta)
	_pesticide_cd_left = maxf(0.0, _pesticide_cd_left - delta)
	_pollen_cd_left = maxf(0.0, _pollen_cd_left - delta)
	_vine_cd_left = maxf(0.0, _vine_cd_left - delta)

	if target == null or _state != State.CHASE:
		return

	var direction := (target.global_position - global_position).normalized()
	_facing = Vector2(direction.x, direction.z)
	var dist := global_position.distance_to(target.global_position)

	# Priority order is a TUNE decision — currently: vine > pollen > pesticide > dash > basic > chase.
	if _ensnared_unlocked and _vine_cd_left <= 0.0:
		_start_ensnared()
	elif _pollen_cd_left <= 0.0:
		_start_pollen_cloud()
	elif _pesticide_cd_left <= 0.0:
		_start_pesticide()
	elif dist > basic_range and _dash_cd_left <= 0.0:
		_start_dash_attack()
	elif dist <= basic_range and _basic_cd_left <= 0.0:
		_start_basic_attack()
	elif dist > basic_range:
		velocity = direction * base_move_speed * move_speed_multiplier
		move_and_slide()
	else:
		velocity = Vector3.ZERO


func _spawn_twin_hitbox(damage: int) -> void:
	var side := Vector3(-_facing.y, 0.0, _facing.x)
	var forward := Vector3(_facing.x, 0.0, _facing.y)
	for n in 2:
		var hitbox := preload("res://scenes/weapon/weapon_hitbox.tscn").instantiate() as Hitbox
		hitbox.damage = damage
		hitbox.unit_type = Stats.UnitType.ENEMY
		hitbox.ignore_root = self
		hitbox.hitbox_lifetime = basic_hitbox_lifetime
		hitbox.hit_landed.connect(_on_hitbox_hit)
		add_child(hitbox)

		var shape_node: CollisionShape3D
		for child in hitbox.get_children():
			if child is CollisionShape3D:
				shape_node = child
				break
		var capsule := (shape_node.shape as CapsuleShape3D).duplicate()
		capsule.radius = basic_hitbox_radius
		capsule.height = basic_hitbox_height
		shape_node.shape = capsule

		var lateral := (n - 0.5) * basic_hitbox_spacing
		hitbox.global_position = global_position + forward * (0.5 + basic_hitbox_height / 2.0) + side * lateral

func _start_basic_attack() -> void:
	_state = State.BASIC_ATTACK
	_basic_cd_left = basic_cooldown
	_current_attack_damage = basic_damage
	_spawn_twin_hitbox(basic_damage)
	_state = State.CHASE

func _on_hitbox_hit(hit_target: Node3D) -> void:
	if hit_target.has_method("receive_hit"):
		hit_target.receive_hit(_current_attack_damage) # damage already baked into the hitbox; see note below



func _start_dash_attack() -> void:
	_state = State.DASH_ATTACK
	_dash_cd_left = dash_cooldown
	var direction := (target.global_position - global_position).normalized()
	velocity = direction * dash_speed
	await get_tree().create_timer(dash_duration).timeout
	_current_attack_damage = dash_damage
	_spawn_twin_hitbox(dash_damage)
	_state = State.CHASE


func _start_pesticide() -> void:
	_state = State.PESTICIDE
	_pesticide_cd_left = pesticide_cooldown
	if pesticide_scene:
		var hazard := pesticide_scene.instantiate()
		get_parent().add_child(hazard)
		hazard.global_position = global_position
		if hazard.has_method("configure"):
			hazard.configure(pesticide_radius, pesticide_dps, pesticide_duration, self)
	_state = State.CHASE


func _start_pollen_cloud() -> void:
	_state = State.POLLEN_CLOUD
	_pollen_cd_left = pollen_cloud_cooldown
	visible = false
	collision_layer = 0

	var points: Array[Vector3] = []
	for i in pollen_cloud_count:
		var angle := randf_range(0.0, TAU)
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * pollen_cloud_radius
		points.append(target.global_position + offset)

	await get_tree().create_timer(pollen_cloud_duration).timeout

	global_position = points[randi_range(0, points.size() - 1)]
	visible = true
	collision_layer = 16 # TUNE: restore to whatever layer this boss uses

	_dash_cd_left = 0.0 # "immediately uses dash-ATK regardless of cooldown status"
	_start_dash_attack()


func _start_ensnared() -> void:
	_state = State.ENSNARED_GRAB
	_vine_cd_left = vine_cooldown
	if vine_scene:
		var vine := vine_scene.instantiate()
		get_parent().add_child(vine)
		vine.configure(self, target)
	else:
		_state = State.CHASE


## Called by VineHazard once it erupts, if the player was standing inside.
func begin_grab(player: Node3D) -> void:
	player.input_enabled = false
	global_position = player.global_position + Vector3(-_facing.x, 0, -_facing.y) * 1.0
	var grab_timer := get_tree().create_timer(vine_duration)
	var strike_interval := 0.4 # TUNE: time between repeated strikes during the grab
	_current_attack_damage = basic_damage 
	while grab_timer.time_left > 0.0:
		_spawn_twin_hitbox(basic_damage)
		await get_tree().create_timer(strike_interval).timeout
	player.input_enabled = true
	_state = State.CHASE
