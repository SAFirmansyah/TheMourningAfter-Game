class_name Cutscene
extends CanvasLayer
## Base for cutscenes. Plays its AnimationPlayer's animation and any CutsceneCaptions,
## then emits `finished` once both are done, or as soon as `skip()` is called.
## Gameplay is paused while a cutscene plays; this node keeps running.

signal finished

@export var animation_name: StringName = &"play"

@onready var animation_player: AnimationPlayer = get_node_or_null(^"AnimationPlayer")

var _skipped := false
var _captions: Array[CutsceneCaption] = []


func play() -> void:
	for node in find_children("*", "", true, false):
		if node is CutsceneCaption:
			_captions.append(node)
			node.start()
	var animated := animation_player != null and animation_player.has_animation(animation_name)
	if animated:
		animation_player.play(animation_name)
	while not _skipped and (_is_animating(animated) or _captions.any(func(c: CutsceneCaption) -> bool: return c.is_running())):
		await get_tree().process_frame
	finished.emit()


func skip() -> void:
	_skipped = true
	if animation_player:
		animation_player.pause()
	for caption in _captions:
		caption.stop()


func _is_animating(animated: bool) -> bool:
	return animated and animation_player.is_playing()
