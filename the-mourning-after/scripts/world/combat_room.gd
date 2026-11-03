class_name CombatRoom
extends Room
## A Room that spawns mutants on entry and blocks its exits until they're all defeated.
## Spawn counts are set externally via configure_spawns() by whatever sequences the
## run (so room 1 can be low-mutant-only, room 3 can be big-mutant-heavy, etc.) —
## this room doesn't know its own position in the run.

signal all_enemies_defeated

# TUNE: sensible defaults if configure_spawns() is never called (e.g. testing this room standalone)
@export var low_mutant_count_range := Vector2i(2, 4)
@export var def_humans_count_range := Vector2i(0, 0)

@export_group("Spawn Area")
@export var spawn_area_min := Vector3(-5, 0, -5) # TUNE: per-room, covers the playable floor
@export var spawn_area_max := Vector3(5, 0, 5)
@export var spawn_raycast_height := 5.0 # TUNE: how far above the area to start the downward raycast
@export var spawn_max_attempts := 10 # TUNE: how many random tries before giving up on one spawn

var low_enemy_scn: PackedScene = load("res://scenes/enemies/low_mutant.tscn")
var big_enemy_scn: PackedScene = load("res://scenes/enemies/deformed_humans.tscn")

var _rng := RandomNumberGenerator.new()
var _alive_enemies: Array[Node] = []


func _ready() -> void:
	super._ready()
	spawn_enemies()
	_configure_next_exit()

	for exit in get_exits():
		exit.set_blocked(true)

	all_enemies_defeated.connect(func():
		for exit in get_exits():
			exit.set_blocked(false)
	)
	
func _configure_next_exit() -> void:
	var exit := get_exit(&"EastExit") # or whichever is this room's "forward" exit — match your actual node name
	if exit == null:
		push_warning("CombatRoom: no exit found to configure for next room")
		return

	if CombatRunState.has_more_rooms():
		exit.target_room = CombatRunState.pick_next_room_path()
	else:
		exit.target_room = CampaignState.get_post_gauntlet_room_path()	 # adjust to your actual cooldown room path


## Called by whatever sequences the run, right after instancing this room,
## before add_child()-ing it into the tree (since _ready() spawns immediately).
func configure_spawns(low_range: Vector2i, big_range: Vector2i) -> void:
	low_mutant_count_range = low_range
	def_humans_count_range = big_range


func spawn_enemies() -> void:
	var low_count := _rng.randi_range(low_mutant_count_range.x, low_mutant_count_range.y)
	var big_count := _rng.randi_range(def_humans_count_range.x, def_humans_count_range.y)

	for i in low_count:
		_spawn_one(low_enemy_scn)
	for i in big_count:
		_spawn_one(big_enemy_scn)

	if _alive_enemies.is_empty():
		call_deferred("emit_signal", "all_enemies_defeated")


func _spawn_one(scene: PackedScene) -> void:
	var pos: Variant = _find_valid_spawn_position()
	if pos == null:
		push_warning("CombatRoom: couldn't find a valid floor position after ", spawn_max_attempts, " attempts")
		return

	var enemy := scene.instantiate()
	$Enemies.add_child(enemy)

	var vertical_offset := 0.5 # fallback if stats isn't ready yet
	if "stats" in enemy and enemy.stats:
		vertical_offset = enemy.stats.get_spawn_vertical_offset()

	enemy.global_position = pos + Vector3(0.0, vertical_offset, 0.0)

	_alive_enemies.append(enemy)
	enemy.tree_exited.connect(_on_enemy_removed.bind(enemy))
	

func _find_valid_spawn_position() -> Variant:
	var space_state := get_world_3d().direct_space_state

	for attempt in spawn_max_attempts:
		var x := _rng.randf_range(spawn_area_min.x, spawn_area_max.x)
		var z := _rng.randf_range(spawn_area_min.z, spawn_area_max.z)
		var from := global_position + Vector3(x, spawn_raycast_height, z)
		var to := global_position + Vector3(x, -spawn_raycast_height, z)

		var query := PhysicsRayQueryParameters3D.create(from, to)
		# query.collision_mask = 1 << 1
		var result := space_state.intersect_ray(query)

		if result and result.has("position"):
			return result.position

	return null


func _get_spawn_points() -> Array[Node3D]:
	var points: Array[Node3D] = []
	var container := get_node_or_null("SpawnPoints")
	if container:
		for child in container.get_children():
			if child is Node3D:
				points.append(child)
	return points


func _on_enemy_removed(enemy: Node) -> void:
	_alive_enemies.erase(enemy)
	print("enemy removed, remaining: ", _alive_enemies.size())
	if _alive_enemies.is_empty():
		print("all enemies defeated, unblocking exits")
		all_enemies_defeated.emit()
