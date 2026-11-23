class_name StreamedLabel
extends Label
## Label that types its text out character by character.

signal stream_finished

@export var chars_per_second := 28.0 # TUNE: typing speed (characters per second)

var _progress := 0.0
var _streaming := false


func stream(new_text: String) -> void:
	text = new_text
	visible_characters = 0
	_progress = 0.0
	_streaming = true
	if new_text.is_empty():
		_finish()


func skip() -> void:
	if _streaming:
		_finish()


func is_streaming() -> bool:
	return _streaming


func _process(delta: float) -> void:
	if not _streaming:
		return
	_progress += delta * chars_per_second
	visible_characters = int(_progress)
	if visible_characters >= get_total_character_count():
		_finish()


func _finish() -> void:
	visible_characters = -1
	_streaming = false
	stream_finished.emit()
