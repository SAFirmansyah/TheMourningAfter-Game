class_name SkipPrompt
extends CanvasLayer
## "Hold X - Skip" prompt shown during cutscenes. Holding fills the bar; a full bar requests a skip.

signal skip_requested

@export var hold_time := 2.0 # TUNE: seconds X must be held to skip
@export var drain_speed := 3.0 # TUNE: how fast the bar empties after release (times the fill speed)

@onready var prompt: Control = $Prompt
@onready var fill: Control = $Prompt/Fill

var frozen := false # set while the pause menu is open

var _active := false
var _progress := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	prompt.hide()
	_set_progress(0.0)


func begin() -> void:
	_active = true
	_set_progress(0.0)
	prompt.show()


func end() -> void:
	_active = false
	prompt.hide()


func _process(delta: float) -> void:
	if not _active or frozen:
		return
	if Input.is_action_pressed(&"skip_cutscene"):
		_set_progress(_progress + delta / hold_time)
	else:
		_set_progress(_progress - delta * drain_speed / hold_time)
	if _progress >= 1.0:
		_active = false
		skip_requested.emit()


func _set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	fill.anchor_right = _progress
	fill.visible = _progress > 0.0
