@tool
class_name NarrativeBeat
extends Interactable
## Campfire spot for each night's scene. Once the night's results are done, a bubble pops up over the
## fire; reflecting there has the StoryDirector play the night's scene (or milestone beat), after which
## the next day starts.

@export var bubble_height := 4.6 # TUNE: height of the bubble's tip above the campfire (m)
@export var pop_in_time := 0.35 # TUNE: bubble grow-in (s)

@onready var bubble: Control = $Bubble/View

var _manager: SanctuaryManager
var _shown := false


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	prompt_label = "Reflect"
	_manager = get_tree().get_first_node_in_group(&"sanctuary_manager")
	bubble.hide()
	interacted.connect(_on_interacted)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var director := get_tree().get_first_node_in_group(&"story_director") as StoryDirector
	var waiting := _manager != null and _manager.day_cycle.awaiting_beat and not (director and director.busy)
	enabled = waiting
	if waiting != _shown:
		_shown = waiting
		bubble.visible = waiting
		if waiting:
			bubble.scale = Vector2.ZERO
			create_tween().tween_property(bubble, "scale", Vector2.ONE, pop_in_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var cam := get_viewport().get_camera_3d()
	var anchor := global_position + Vector3(0.0, bubble_height, 0.0)
	if _shown and cam and not cam.is_position_behind(anchor):
		bubble.position = cam.unproject_position(anchor) - bubble.pivot_offset


func _on_interacted() -> void:
	var director := get_tree().get_first_node_in_group(&"story_director") as StoryDirector
	if director:
		director.play_night()
