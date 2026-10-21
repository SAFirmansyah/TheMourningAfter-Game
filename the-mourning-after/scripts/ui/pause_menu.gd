class_name PauseMenu
extends CanvasLayer
## Escape pauses everything: grayscale overlay, slide-out menu, quit confirmation.

@export var world: World
@export var slide_time := 0.25 # TUNE: menu and quit box slide in/out (s)

@onready var grayscale: ColorRect = $Grayscale
@onready var panel: Control = $Panel
@onready var resume_button: Button = $Panel/Content/Resume
@onready var save_button: Button = $Panel/Content/Save
@onready var stats_button: Button = $Panel/Content/ViewStats
@onready var quit_button: Button = $Panel/Content/Quit
@onready var quit_box: Control = $QuitBox
@onready var save_quit_button: Button = $QuitBox/Content/SaveAndQuit
@onready var quit_no_save_button: Button = $QuitBox/Content/QuitWithoutSaving
@onready var cancel_button: Button = $QuitBox/Content/Cancel

var is_open := false
var _tween: Tween
var _quit_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_amount(0.0)
	grayscale.hide()
	panel.hide()
	quit_box.hide()
	resume_button.pressed.connect(close)
	save_button.pressed.connect(world.save_game)
	quit_button.pressed.connect(_open_quit_box)
	save_quit_button.pressed.connect(_save_and_quit)
	quit_no_save_button.pressed.connect(get_tree().quit)
	cancel_button.pressed.connect(_close_quit_box)
	for button: Button in [resume_button, save_button, stats_button, quit_button, save_quit_button, quit_no_save_button, cancel_button]:
		button.mouse_entered.connect(func() -> void:
			if not button.disabled:
				button.grab_focus())


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	get_viewport().set_input_as_handled()
	if not is_open:
		open()
	elif quit_box.visible:
		_close_quit_box()
	else:
		close()


func open() -> void:
	is_open = true
	world.set_menu_paused(true)
	_set_enabled(save_button, world.can_save())
	_set_enabled(stats_button, world.can_view_stats())
	grayscale.show()
	panel.show()
	quit_box.hide()
	panel.position.x = -panel.size.x
	_restart_tween()
	_tween.tween_property(panel, "position:x", 0.0, slide_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_method(_set_amount, _get_amount(), 1.0, slide_time)
	resume_button.grab_focus()


func close() -> void:
	is_open = false
	world.set_menu_paused(false)
	_hide_quit_box_now()
	_restart_tween()
	_tween.tween_property(panel, "position:x", -panel.size.x, slide_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_method(_set_amount, _get_amount(), 0.0, slide_time)
	_tween.chain().tween_callback(func() -> void:
		panel.hide()
		grayscale.hide())
	get_viewport().gui_release_focus()


func _open_quit_box() -> void:
	_set_enabled(save_quit_button, world.can_save())
	quit_box.show()
	quit_box.modulate.a = 0.0
	if _quit_tween:
		_quit_tween.kill()
	_quit_tween = create_tween().set_parallel()
	_quit_tween.tween_property(quit_box, "modulate:a", 1.0, slide_time)
	(save_quit_button if not save_quit_button.disabled else quit_no_save_button).grab_focus()


func _close_quit_box() -> void:
	_hide_quit_box_now()
	quit_button.grab_focus()


func _hide_quit_box_now() -> void:
	if _quit_tween:
		_quit_tween.kill()
	quit_box.hide()


func _save_and_quit() -> void:
	world.save_game()
	get_tree().quit()


func _restart_tween() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()


func _set_enabled(button: Button, enabled: bool) -> void:
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


func _set_amount(value: float) -> void:
	(grayscale.material as ShaderMaterial).set_shader_parameter("amount", value)


func _get_amount() -> float:
	return (grayscale.material as ShaderMaterial).get_shader_parameter("amount")
