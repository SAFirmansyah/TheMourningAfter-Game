@tool
class_name WorkerNPC
extends NPC
## Rudrama, Gwenith or Shuyi: follows the position the Sanctuary manager walks her along
## (Rudrama: anvil <-> containments; Gwenith and Shuyi: station <-> campfire).

@export_enum("rudrama", "gwenith", "shuyi") var worker := "rudrama"

@export_group("Animation")
@export var idle_frames: Array[Texture2D] = [] # set for characters with art (Rudrama); others keep the placeholder card
@export var walk_frames: Array[Texture2D] = []
@export var idle_fps := 6.0 # TUNE
@export var walk_fps := 12.0 # TUNE
@export var art_pixel_size := 0.00156 # TUNE: card size for the art (m per pixel)
@export var art_faces_left := false # the art's natural facing (flip_h follows travel either way)

var scripted := false # a story scene is moving her; the manager's position is ignored

var _anim_time := 0.0
var _last_position := Vector3.ZERO
var _moving := false

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
	global_position = _manager.worker_position(StringName(worker))


## Plays idle or walk (whoever is moving her: the manager or a story scene) and faces her way.
func _process(delta: float) -> void:
	if Engine.is_editor_hint() or idle_frames.is_empty():
		return
	var step := global_position - _last_position
	_last_position = global_position
	var moving := Vector2(step.x, step.z).length() > 0.2 * delta # at least a slow walk
	if moving != _moving:
		_moving = moving
		_anim_time = 0.0
	if moving and absf(step.x) > 0.001:
		card.flip_h = (step.x > 0.0) == art_faces_left
	var frames := walk_frames if moving and not walk_frames.is_empty() else idle_frames
	_anim_time += delta
	var frame: Texture2D = frames[int(_anim_time * (walk_fps if frames == walk_frames else idle_fps)) % frames.size()]
	if card.texture != frame:
		card.texture = frame
