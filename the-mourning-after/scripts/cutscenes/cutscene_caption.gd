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
var _run_id := 0


func _ready() -> void:
	if not Engine.is_editor_hint():
		hide()


func is_running() -> bool:
	return _running


func start() -> void:
	if lines.is_empty():
		return
	_running = true
	_run_id += 1
	var run := _run_id
	await _wait(start_delay)
	if run != _run_id:
		return
	modulate.a = 0.0
	show()
	label.stream(lines[0].text)
	_fade(1.0)
	for i in lines.size():
		if i > 0:
			label.stream(lines[i].text)
		if label.is_streaming():
			await label.stream_finished
		if run != _run_id:
			return
		await _wait(lines[i].hold_time)
		if run != _run_id:
			return
	await _fade(0.0)
	if run != _run_id:
		return
	hide()
	_running = false
	done.emit()


func stop() -> void:
	if not _running:
		return
	_run_id += 1
	label.skip()
	hide()
	_running = false
	done.emit()


func _wait(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await get_tree().process_frame
		if can_process():
			elapsed += get_process_delta_time()


func _fade(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", alpha, fade_time)
	await tween.finished
