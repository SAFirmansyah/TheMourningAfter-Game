class_name HeroTutorial
extends CanvasLayer
## Perrin's one-page tutorial, on the same parchment as Huyana's: shown the first time he takes up
## arms (once per save). Player control waits until it's dismissed.

@export var world: World
@export var pop_time := 0.16 # TUNE: pop-open time (s)

@onready var panel: Control = $Panel
@onready var ok_button: Button = $Panel/Content/Begin

var seen := false


func _enter_tree() -> void:
	add_to_group(&"save_state")
	add_to_group(&"hero_tutorial")


func _ready() -> void:
	panel.hide()
	HoverArt.apply(ok_button)
	ok_button.pressed.connect(_close)


## Called when Perrin takes up arms; only the first time does anything.
func show_once() -> void:
	if seen:
		return
	seen = true
	world.player.input_enabled = false
	world.player.forced_input = Vector2.ZERO
	panel.show()
	panel.pivot_offset = panel.size / 2.0
	panel.modulate.a = 0.0
	panel.scale = Vector2.ONE * 0.94
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, pop_time)
	tween.tween_property(panel, "scale", Vector2.ONE, pop_time)
	ok_button.grab_focus()


func _close() -> void:
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, pop_time * 0.6)
	tween.tween_callback(panel.hide)
	world.player.input_enabled = true
	world.mark_unsaved()


func get_save_data() -> Dictionary:
	return {"seen": seen}


func load_save_data(data: Dictionary) -> void:
	seen = bool(data.get("seen", seen))
