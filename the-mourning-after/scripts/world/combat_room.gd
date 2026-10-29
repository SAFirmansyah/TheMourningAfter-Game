class_name CombatRoom
extends Room
## A Room that spawns mutants on entry and blocks its exits until they're all defeated.
## Spawn counts are set externally via configure_spawns() by whatever sequences the
## run (so room 1 can be low-mutant-only, room 3 can be big-mutant-heavy, etc.) —
## this room doesn't know its own position in the run.

signal all_enemies_defeated

# TUNE: sensible defaults if configure_spawns() is never called (e.g. testing this room standalone)
@export var low_mutant_count_range := Vector2i(2, 4)
@export var big_mutant_count_range := Vector2i(0, 0)

var low_enemy_scn: PackedScene = load("res://scenes/enemies/low_mutant.tscn")
var big_enemy_scn: PackedScene = load("res://scenes/enemies/big_mutant.tscn")

var _rng := RandomNumberGenerator.new()
var _alive_enemies: Array[Node] = []


func _ready() -> void:
	super._ready()
	spawn_enemies()

	for exit in get_exits():
		exit.set_blocked(true)

	all_enemies_defeated.connect(func():
		for exit in get_exits():
			exit.set_blocked(false)
	)


## Called by whatever sequences the run, right after instancing this room,
## before add_child()-ing it into the tree (since _ready() spawns immediately).
func configure_spawns(low_range: Vector2i, big_range: Vector2i) -> void:
	low_mutant_count_range = low_range
	big_mutant_count_range = big_range


func spawn_enemies() -> void:
	var spawn_points := _get_spawn_points()
	spawn_points.shuffle()

	var low_count := _rng.randi_range(low_mutant_count_range.x, low_mutant_count_range.y)
	var big_count := _rng.randi_range(big_mutant_count_range.x, big_mutant_count_range.y)

	var point_index := 0
	for i in low_count:
		_spawn_one(low_enemy_scn, spawn_points, point_index)
		point_index += 1
	for i in big_count:
		_spawn_one(big_enemy_scn, spawn_points, point_index)
		point_index += 1


func _spawn_one(scene: PackedScene, spawn_points: Array[Node3D], point_index: int) -> void:
	if spawn_points.is_empty():
		push_warning("CombatRoom has no spawn points — add Marker3D/Node3D children under a SpawnPoints node")
		return

	var enemy := scene.instantiate()
	$Enemies.add_child(enemy)

	var point := spawn_points[point_index % spawn_points.size()]
	var jitter := Vector3(_rng.randf_range(-0.5, 0.5), 0.0, _rng.randf_range(-0.5, 0.5))
	enemy.global_position = point.global_position + jitter

	_alive_enemies.append(enemy)
	enemy.tree_exited.connect(_on_enemy_removed.bind(enemy))


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
	if _alive_enemies.is_empty():
		all_enemies_defeated.emit()
