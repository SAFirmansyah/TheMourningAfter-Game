class_name SaveIndicator
extends CanvasLayer
## "Saving..." note in the top-right corner, shown briefly whenever the game saves.

@export var show_time := 1.2 # TUNE: seconds the note stays fully visible
@export var fade_time := 0.25 # TUNE: note fade in/out (s)

@onready var label: Label = $Label

var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	label.modulate.a = 0.0


func flash() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(label, "modulate:a", 1.0, fade_time)
	_tween.tween_interval(show_time)
	_tween.tween_property(label, "modulate:a", 0.0, fade_time)
