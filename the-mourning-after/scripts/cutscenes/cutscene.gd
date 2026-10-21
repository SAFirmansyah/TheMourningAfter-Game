class_name Cutscene
extends CanvasLayer
## Base for cutscenes. Plays its AnimationPlayer's animation and any CutsceneCaptions,
## then emits `finished` once both are done.
## Gameplay is paused while a cutscene plays; this node keeps running.

signal finished

@export var animation_name: StringName = &"play"

@onready var animation_player: AnimationPlayer = get_node_or_null(^"AnimationPlayer")


func play() -> void:
	var captions: Array[CutsceneCaption] = []
	for node in find_children("*", "", true, false):
		if node is CutsceneCaption:
			captions.append(node)
			node.start()
	if animation_player and animation_player.has_animation(animation_name):
		animation_player.play(animation_name)
		await animation_player.animation_finished
	for caption in captions:
		if caption.is_running():
			await caption.done
	finished.emit()
