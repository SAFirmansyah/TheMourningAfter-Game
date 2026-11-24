class_name CombatRoom
extends Room
## A Room that spawns mutants on entry and blocks its exits until they're all defeated.
## Mob counts come from CombatRunState's weight budget for this point in the run.

signal all_enemies_defeated

@export_group("Spawning")
@export var entry_clear_radius := 6.0 # TUNE: no mob spawns within this distance of any exit (m)
@export var solo_chance := 0.25 # TUNE: chance each group is a single mob
@export var cluster_size := Vector2i(2, 4) # TUNE: mobs per cluster (min, max)
@export var cluster_radius := 1.6 # TUNE: how far clustermates spawn from their cluster's centre (m)
@export var cluster_separation := 5.0 # TUNE: minimum distance between cluster centres (m)
@export var mob_spacing := 1.2 # TUNE: minimum distance between any two mobs (m)
@export var wall_clearance := 0.6 # TUNE: minimum distance from walls (m)
@export var spawn_max_attempts := 40 # TUNE: random tries per position before giving up

@export_group("Grass")
@export var grass_scn: PackedScene = load("res://scenes/world/grass.tscn")
@export var grass_textures: Array[Texture2D] = [] # fill with all 20 variants in the inspector
@export var grass_count := Vector2i(10000, 10000)
@export var grass_wall_clearance := 0.3

var big_enemy_scn: PackedScene = load("res://scenes/enemies/low_mutant.tscn")
var low_enemy_scn2: PackedScene = load("res://scenes/enemies/deformed_humans_2.tscn")
var low_enemy_scn: PackedScene = load("res://scenes/enemies/deformed_humans.tscn")

var is_cleared := false

var _rng := RandomNumberGenerator.new()
var _alive_enemies: Array[Node] = []


func _ready() -> void:
	super._ready()
	all_enemies_defeated.connect(func():
		is_cleared = true
		for exit in get_exits():
			exit.set_blocked(false)
	)
	if restoring:
		is_cleared = true
		return
	spawn_enemies()
	spawn_grass()
	_configure_next_exit()
	for exit in get_exits():
		exit.set_blocked(true)


func allows_saving() -> bool:
	return is_cleared


func _configure_next_exit() -> void:
	var exit := get_exit(&"EastExit") # or whichever is this room's "forward" exit — match your actual node name
	if exit == null:
		push_warning("CombatRoom: no exit found to configure for next room")
		return

	if CombatRunState.has_more_rooms():
		exit.target_room = CombatRunState.pick_next_room_path()
	else:
		exit.target_room = CampaignState.get_post_gauntlet_room_path()	 # adjust to your actual cooldown room path


## Scatters decorative grass sprites across the room's floor. Purely visual —
## no collision, so these can overlap each other and sit near walls/exits freely.
func spawn_grass() -> void:
	if grass_scn == null or grass_textures.is_empty():
		print("spawn_grass bailed: grass_scn=", grass_scn, " textures=", grass_textures.size())
		return
	var count := _rng.randi_range(grass_count.x, grass_count.y)
	for i in count:
		var pos: Variant = _random_grass_point(_floor_bounds)
		if pos == null:
			continue
		var grass := grass_scn.instantiate() as Grass
		add_child(grass)
		grass.global_position = pos
		grass.set_texture(grass_textures[_rng.randi() % grass_textures.size()])
		

## Like _random_floor_point, but skips the exit-clearance check (grass can grow near exits)
## and uses a looser wall clearance.
func _random_grass_point(area: AABB) -> Variant:
	var space_state := get_world_3d().direct_space_state
	var x := _rng.randf_range(area.position.x, area.end.x)
	var z := _rng.randf_range(area.position.z, area.end.z)
	var from := Vector3(x, area.position.y + 5.0, z)
	var hit := space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, Vector3(x, area.position.y - 5.0, z)))
	if hit.is_empty() or absf(hit.position.y - area.position.y) > 0.3:
		return null
	var pos: Vector3 = hit.position
	var probe := SphereShape3D.new()
	probe.radius = grass_wall_clearance
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.transform = Transform3D(Basis(), pos + Vector3.UP * (grass_wall_clearance + 0.3))
	if not space_state.intersect_shape(query, 1).is_empty():
		return null
	return pos


## Mobs spawn in clusters (plus the odd loner) at random spots away from the exits,
## so every visit to a room lays them out differently.
func spawn_enemies() -> void:
	var mobs := CombatRunState.roll_room_mobs()
	print("room weight ", snappedf(CombatRunState.current_room_weight(), 0.01), ": ", mobs.x, " deformed humans, ", mobs.y, " deformed humans 2, ", mobs.z, " low mutants")
	var queue: Array[PackedScene] = []
	for i in mobs.x:
		queue.append(low_enemy_scn)
	for i in mobs.y:
		queue.append(low_enemy_scn2)
	for i in mobs.z:
		queue.append(big_enemy_scn)
	queue.shuffle()

	_floor_bounds = _compute_floor_bounds()
	var centres: Array[Vector3] = []
	var taken: Array[Vector3] = []
	while not queue.is_empty():
		var size := 1 if _rng.randf() < solo_chance else _rng.randi_range(cluster_size.x, cluster_size.y)
		size = mini(size, queue.size())
		var centre: Variant = _find_cluster_centre(centres)
		if centre == null:
			push_warning("CombatRoom: no room left for another cluster")
			break
		centres.append(centre)
		for i in size:
			var pos: Variant = centre if i == 0 else _find_spot_near(centre, taken)
			if pos == null or (i == 0 and _too_close(pos, taken)):
				pos = _find_spot_near(centre, taken)
			if pos == null:
				continue
			taken.append(pos)
			_spawn_at(queue.pop_back(), pos)
		# anything that didn't fit stays queued for the next cluster

	if _alive_enemies.is_empty():
		call_deferred("emit_signal", "all_enemies_defeated")


func _spawn_at(scene: PackedScene, pos: Vector3) -> void:
	var enemy := scene.instantiate()
	$Enemies.add_child(enemy)

	var vertical_offset := 0.5 # fallback if stats isn't ready yet
	if "stats" in enemy and enemy.stats:
		vertical_offset = enemy.stats.get_spawn_vertical_offset()

	enemy.global_position = pos + Vector3(0.0, vertical_offset, 0.0)

	_alive_enemies.append(enemy)
	enemy.tree_exited.connect(_on_enemy_removed.bind(enemy))


var _floor_bounds := AABB()


func _find_cluster_centre(centres: Array[Vector3]) -> Variant:
	# Prefer well-separated clusters; relax if the room is too cramped.
	for separation in [cluster_separation, cluster_separation * 0.5, 0.0]:
		for attempt in spawn_max_attempts:
			var pos: Variant = _random_floor_point(_floor_bounds)
			if pos == null:
				continue
			if centres.all(func(c: Vector3) -> bool: return c.distance_to(pos) >= separation):
				return pos
	return null


func _find_spot_near(centre: Vector3, taken: Array[Vector3]) -> Variant:
	var area := AABB(centre - Vector3(cluster_radius, 0, cluster_radius), Vector3(cluster_radius * 2.0, 0, cluster_radius * 2.0))
	for attempt in spawn_max_attempts:
		var pos: Variant = _random_floor_point(area)
		if pos != null and pos.distance_to(centre) <= cluster_radius and not _too_close(pos, taken):
			return pos
	return null


func _too_close(pos: Vector3, taken: Array[Vector3]) -> bool:
	return taken.any(func(t: Vector3) -> bool: return t.distance_to(pos) < mob_spacing)


## A random point on this room's walkable floor, clear of walls and away from every exit.
func _random_floor_point(area: AABB) -> Variant:
	var space_state := get_world_3d().direct_space_state
	var x := _rng.randf_range(area.position.x, area.end.x)
	var z := _rng.randf_range(area.position.z, area.end.z)
	var from := Vector3(x, area.position.y + 5.0, z)
	var hit := space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, Vector3(x, area.position.y - 5.0, z)))
	if hit.is_empty() or absf(hit.position.y - area.position.y) > 0.3:
		return null # off the floor, or on top of a wall
	var pos: Vector3 = hit.position
	for exit in get_exits():
		if Vector2(exit.global_position.x - pos.x, exit.global_position.z - pos.z).length() < entry_clear_radius:
			return null
	var probe := SphereShape3D.new()
	probe.radius = wall_clearance
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.transform = Transform3D(Basis(), pos + Vector3.UP * (wall_clearance + 0.3))
	if not space_state.intersect_shape(query, 1).is_empty():
		return null # against a wall
	return pos


func _compute_floor_bounds() -> AABB:
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in find_children("Floor*", "MeshInstance3D", true, false):
		var box := mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


func _get_spawn_points() -> Array[Node3D]:
	var points: Array[Node3D] = []
	var container := get_node_or_null("SpawnPoints")
	if container:
		for child in container.get_children():
			if child is Node3D:
				points.append(child)
	return points


func _on_enemy_removed(enemy: Node) -> void:
	if is_queued_for_deletion() or not is_inside_tree() or not enemy.get(&"_is_dead"):
		return # the room unloading or the game quitting doesn't count as a clear
	_alive_enemies.erase(enemy)
	print("enemy removed, remaining: ", _alive_enemies.size())
	if _alive_enemies.is_empty():
		print("all enemies defeated, unblocking exits")
		all_enemies_defeated.emit()
