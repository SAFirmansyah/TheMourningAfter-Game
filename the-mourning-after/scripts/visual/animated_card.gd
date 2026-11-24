@tool
class_name AnimatedCard
extends FacingCard
## Facing card that loops through a list of frame textures (frames share one canvas, so they line up).
## The editor shows the first frame.

@export var frames: Array[Texture2D] = []
@export var fps := 8.0 # TUNE: animation speed (frames per second)

var _time := 0.0


func _ready() -> void:
	if not frames.is_empty() and texture == null:
		texture = frames[0]
	super()


func _process(delta: float) -> void:
	super(delta)
	if Engine.is_editor_hint() or frames.is_empty():
		return
	_time += delta
	var frame: Texture2D = frames[int(_time * fps) % frames.size()]
	if texture != frame:
		texture = frame
