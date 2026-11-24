@tool
class_name WorkerNPC
extends NPC
## Rudrama, Gwenith or Shuyi: follows the position the Sanctuary manager walks her along
## (Rudrama: anvil <-> containments; Gwenith and Shuyi: station <-> campfire).

@export_enum("rudrama", "gwenith", "shuyi") var worker := "rudrama"

@export_group("Animation")
@export var idle_frames: Array[Texture2D] = [] # set for characters with art (Rudrama); others keep the placeholder card
@export var walk_frames: Array[Texture2D] = []
@export var idle_fps := 7.0 # TUNE (Perrin: 7)
@export var walk_fps := 14.0 # TUNE (Perrin: 18, at a faster stride)
@export var art_pixel_size := 0.00156 # TUNE: card size for the art (m per pixel)
@export var art_faces_left := true # the art's natural facing (flip_h follows travel either way)

var scripted := false # a story scene is moving her; the manager's position is ignored

var _anim_time := 0.0
var _last_position := Vector3.ZERO
var _moving := false
var _still_for := 1.0

var _manager: SanctuaryManager


func _ready() -> void:
	super()
	if not idle_frames.is_empty():
		card.modulate = Color.WHITE
		card.pixel_size = art_pixel_size
		card.texture = idle_frames[0]
	if Engine.is_editor_hint():
		return
	_last_position = global_position
	_manager = get_tree().get_first_node_in_group(&"sanctuary_manager")
	if _manager:
		global_position = _manager.worker_position(StringName(worker))
		reset_physics_interpolation()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or _manager == null or scripted:
		return
	var at := _manager.worker_position(StringName(worker))
	if not _on_floor(at):
		_manager.send_home(StringName(worker))
		at = _manager.worker_position(StringName(worker))
	global_position = at


var _floor_rects: Array[Rect2] = []

## Over one of the room's floor pieces (top-down).
func _on_floor(at: Vector3) -> bool:
	if _floor_rects.is_empty():
		var room := get_parent()
		while room and room is not Room:
			room = room.get_parent()
		if room == null:
			return true
		for mesh: MeshInstance3D in room.find_children("Floor*", "MeshInstance3D", true, false):
			var box := mesh.global_transform * mesh.get_aabb()
			_floor_rects.append(Rect2(box.position.x, box.position.z, box.size.x, box.size.z))
	for rect in _floor_rects:
		if rect.grow(0.3).has_point(Vector2(at.x, at.z)):
			return true
	return false


## Plays idle or walk like Perrin's AnimatedSprite3D: frames advance on a steady clock, walk while
## she's been moved recently (whoever moves her: the manager or a story scene), facing her way.
func _process(delta: float) -> void:
	if Engine.is_editor_hint() or idle_frames.is_empty():
		return
	var step := global_position - _last_position
	_last_position = global_position
	if Vector2(step.x, step.z).length() > 0.0005:
		_still_for = 0.0
		if absf(step.x) > 0.0005:
			card.flip_h = (step.x > 0.0) == art_faces_left
	else:
		_still_for += delta
	var moving := _still_for < 0.12 # physics steps don't land every frame: don't flicker to idle between them
	if moving != _moving:
		_moving = moving
		_anim_time = 0.0
	var frames := walk_frames if moving and not walk_frames.is_empty() else idle_frames
	_anim_time += delta
	var frame: Texture2D = frames[int(_anim_time * (walk_fps if frames == walk_frames else idle_fps)) % frames.size()]
	if card.texture != frame:
		card.texture = frame
