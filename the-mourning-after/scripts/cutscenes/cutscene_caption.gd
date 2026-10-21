class_name CutsceneCaption
extends PanelContainer
## Small caption box for cutscenes. Waits `start_delay`, types each line, holds it, then hides.
## Started automatically by the Cutscene it sits in.

signal done

@export var start_delay := 1.0 # TUNE: seconds after the cutscene starts before the box appears
@export var fade_time := 0.2 # TUNE: box fade in/out (s)
@export var lines: Array[CaptionLine] = []

@onready var label: StreamedLabel = $Label

var _running := false


func _ready() -> void:
	if not Engine.is_editor_hint():
		hide()


func is_running() -> bool:
	return _running


func start() -> void:
	if lines.is_empty():
		return
	_running = true
	await _wait(start_delay)
	modulate.a = 0.0
	show()
	label.stream(lines[0].text)
	_fade(1.0)
	for i in lines.size():
		if i > 0:
			label.stream(lines[i].text)
		if label.is_streaming():
			await label.stream_finished
		await _wait(lines[i].hold_time)
	await _fade(0.0)
	hide()
	_running = false
	done.emit()


func _wait(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds, true).timeout


func _fade(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", alpha, fade_time)
	await tween.finished
