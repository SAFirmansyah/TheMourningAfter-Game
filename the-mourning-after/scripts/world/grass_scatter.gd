class_name GrassScatter
extends Node3D
## Decorative grass, spread semi-evenly over every Floor mesh of its room (and the room end of its
## paths): a jittered grid, so it reaches right up to the edges with no bald patches, without any card
## hanging off a floor edge. Keeps off props; walls sit on the floor edge anyway.
## As a node: scatters over its parent room on load. CombatRoom calls scatter_room() directly.

@export var grass_scene: PackedScene = preload("res://scenes/world/grass.tscn")
@export var textures: Array[Texture2D] = []
@export var spacing := 0.75 # TUNE: average distance between grass cards (m); bigger = sparser

const JITTER := 0.45 # share of the spacing each card is nudged randomly, so the grid doesn't show
const SIDE_MARGIN := 0.4 # TUNE: how far a card reaches sideways past its spot (m), kept over floor
const DEPTH_MARGIN := 0.08 # the card stands upright, so front/back it barely needs any room
const PROP_CLEARANCE := 0.35 # TUNE: distance kept from props (m)
const PROP_LAYERS := 2 # environment props / obstacles (not walls, not mobs)

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if Engine.is_editor_hint() or textures.is_empty():
		return
	_rng.randomize()
	scatter_room.call_deferred(get_parent(), self, grass_scene, textures, _rng, spacing)


## Plants grass over all of `room`'s floor and the room end of its paths, under `parent`.
static func scatter_room(room: Node3D, parent: Node3D, scene: PackedScene, tex: Array[Texture2D],
		rng: RandomNumberGenerator, gap: float) -> void:
	var rects: Array[Rect2] = [] # floor pieces, top-down (x, z)
	var height := 0.0
	for floor_mesh: MeshInstance3D in room.find_children("Floor*", "MeshInstance3D", true, false):
		var box := floor_mesh.global_transform * floor_mesh.get_aabb()
		rects.append(Rect2(box.position.x, box.position.z, box.size.x, box.size.z))
		height = box.position.y
	var space := parent.get_world_3d().direct_space_state
	var done: Array[Rect2] = []
	for rect in rects:
		var x := rect.position.x + gap / 2.0
		while x < rect.end.x:
			var z := rect.position.y + gap / 2.0
			while z < rect.end.y:
				var spot := Vector2(x, z) + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * gap * JITTER
				z += gap
				if _covered(done, spot) or not _fits(rects, spot):
					continue # another floor piece already planted here, or the card would hang off
				var at := Vector3(spot.x, height, spot.y)
				if _clear(space, at):
					_plant(parent, scene, tex, rng, at)
			x += gap
		done.append(rect)
	if room is Room:
		_scatter_paths(room as Room, parent, scene, tex, rng, gap, space)


## The room end of each path (it fades out further along, so the grass thins and stops there).
static func _scatter_paths(room: Room, parent: Node3D, scene: PackedScene, tex: Array[Texture2D],
		rng: RandomNumberGenerator, gap: float, space: PhysicsDirectSpaceState3D) -> void:
	for exit in room.get_exits():
		var plane := exit.path_mesh.mesh as PlaneMesh
		if plane == null:
			continue
		var reach := plane.size.x * 0.5
		var half_width := plane.size.y / 2.0 - SIDE_MARGIN
		var along := 0.0
		while along < reach:
			var keep := 1.0 - along / reach # thins out toward the fade
			var across := -half_width
			while across <= half_width:
				if rng.randf() < keep:
					var local := Vector3(along - plane.size.x / 2.0, 0.0, across) + Vector3(rng.randf_range(-1, 1), 0.0, rng.randf_range(-1, 1)) * gap * JITTER
					local.z = clampf(local.z, -half_width, half_width)
					var at := exit.path_mesh.global_transform * local
					if _clear(space, at):
						_plant(parent, scene, tex, rng, at)
				across += gap
			along += gap


static func _covered(rects: Array[Rect2], spot: Vector2) -> bool:
	for r in rects:
		if r.has_point(spot):
			return true
	return false


## The card's footprint (its width sideways, a sliver front to back) lies over floor.
static func _fits(rects: Array[Rect2], spot: Vector2) -> bool:
	for offset: Vector2 in [Vector2(-SIDE_MARGIN, 0), Vector2(SIDE_MARGIN, 0), Vector2(0, -DEPTH_MARGIN), Vector2(0, DEPTH_MARGIN)]:
		if not _covered(rects, spot + offset):
			return false
	return true


static func _clear(space: PhysicsDirectSpaceState3D, at: Vector3) -> bool:
	var probe := SphereShape3D.new()
	probe.radius = PROP_CLEARANCE
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.collision_mask = PROP_LAYERS
	query.transform = Transform3D(Basis(), at + Vector3.UP * (PROP_CLEARANCE + 0.3))
	return space.intersect_shape(query, 1).is_empty()


static func _plant(parent: Node3D, scene: PackedScene, tex: Array[Texture2D], rng: RandomNumberGenerator, at: Vector3) -> void:
	var grass := scene.instantiate() as Grass
	parent.add_child(grass)
	grass.global_position = at
	grass.set_texture(tex[rng.randi() % tex.size()])
