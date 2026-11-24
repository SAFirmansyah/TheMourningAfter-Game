class_name PauseMenu
extends CanvasLayer
## Escape pauses everything: grayscale overlay and the slide-out scroll menu.
## Quit goes back to the title screen rather than closing the game. With unsaved progress, the first
## click turns Quit into "Save & Quit" and drops "Quit without saving" out just below it (nothing else
## moves); Escape folds it back up.

@export var world: World

const HAND_MENU := preload("res://textures/ui/Pause_Menu_3.png")
const HAND_TEXT := Color(0.24, 0.15, 0.09)
const HAND_TITLE := Color(0.45, 0.16, 0.1)
@export var slide_time := 0.25 # TUNE: menu slide in/out (s)
@export var cascade_time := 0.22 # TUNE: "Quit without saving" dropping out (s)
@export var cascade_drop := 14.0 # TUNE: how far it slides down into place (px)

@onready var grayscale: ColorRect = $Grayscale
@onready var panel: Control = $Panel
@onready var resume_button: Button = $Panel/Content/Resume
@onready var save_button: Button = $Panel/Content/Save
@onready var quit_button: Button = $Panel/Content/Quit

var is_open := false
var _tween: Tween
var _cascade_tween: Tween
var _quit_no_save: Button # sits just under Quit, outside the layout, so nothing shifts
var _asking := false # Quit has become "Save & Quit"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.theme = GameFonts.theme_with(GameFonts.TITLE)
	_build_quit_no_save()
	_apply_hand_drawn()
	_set_amount(0.0)
	grayscale.hide()
	panel.hide()
	resume_button.pressed.connect(close)
	save_button.pressed.connect(world.save_game)
	_add_testing_toggle()
	quit_button.pressed.connect(_on_quit)
	_quit_no_save.pressed.connect(_quit_to_title)
	for button: Button in [resume_button, save_button, quit_button, _quit_no_save]:
		button.mouse_entered.connect(func() -> void:
			if not button.disabled:
				button.grab_focus())


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	get_viewport().set_input_as_handled()
	if not is_open:
		open()
	elif _asking:
		_fold_quit()
		quit_button.grab_focus()
	else:
		close()


func open() -> void:
	is_open = true
	world.set_menu_paused(true)
	_set_enabled(save_button, world.can_save())
	_fold_quit(true)
	grayscale.show()
	panel.show()
	_fit_menu_art() # now that the menu's text has been laid out
	panel.position.x = -panel.size.x
	_restart_tween()
	_tween.tween_property(panel, "position:x", 0.0, slide_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_method(_set_amount, _get_amount(), 1.0, slide_time)
	resume_button.grab_focus()


func close() -> void:
	is_open = false
	world.set_menu_paused(false)
	_restart_tween()
	_tween.tween_property(panel, "position:x", -panel.size.x, slide_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_method(_set_amount, _get_amount(), 0.0, slide_time)
	_tween.chain().tween_callback(func() -> void:
		_fold_quit(true)
		panel.hide()
		grayscale.hide())
	get_viewport().gui_release_focus()


## First click: straight out if nothing's unsaved, else offer Save & Quit / Quit without saving.
## Second click (as "Save & Quit"): save and go.
func _on_quit() -> void:
	if _asking:
		_save_and_quit()
	elif not world.has_unsaved_changes():
		_quit_to_title()
	else:
		_unfold_quit()


func _unfold_quit() -> void:
	_asking = true
	quit_button.text = "Save & Quit"
	_set_enabled(quit_button, world.can_save())
	_place_quit_no_save()
	var rest := _quit_no_save.position.y
	_quit_no_save.position.y = rest - cascade_drop
	_quit_no_save.modulate.a = 0.0
	_quit_no_save.show()
	if _cascade_tween:
		_cascade_tween.kill()
	_cascade_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cascade_tween.tween_property(_quit_no_save, "position:y", rest, cascade_time)
	_cascade_tween.tween_property(_quit_no_save, "modulate:a", 1.0, cascade_time)
	(quit_button if not quit_button.disabled else _quit_no_save).grab_focus()


## Back to plain Quit (instantly when the menu opens or closes).
func _fold_quit(instant := false) -> void:
	if not _asking and not _quit_no_save.visible:
		return
	_asking = false
	quit_button.text = "Quit"
	_set_enabled(quit_button, true)
	if _cascade_tween:
		_cascade_tween.kill()
	if instant:
		_quit_no_save.hide()
		return
	_cascade_tween = create_tween().set_parallel()
	_cascade_tween.tween_property(_quit_no_save, "modulate:a", 0.0, cascade_time * 0.6)
	_cascade_tween.chain().tween_callback(_quit_no_save.hide)


func _build_quit_no_save() -> void:
	_quit_no_save = Button.new()
	_quit_no_save.name = &"QuitWithoutSaving"
	_quit_no_save.text = "Quit without saving"
	_quit_no_save.hide()
	quit_button.add_child(_quit_no_save) # a child, not a row: the column keeps its spacing


## Centred just below Quit, at Quit's text size.
func _place_quit_no_save() -> void:
	_quit_no_save.reset_size()
	_quit_no_save.position = Vector2((quit_button.size.x - _quit_no_save.size.x) / 2.0, quit_button.size.y + 4.0)


func _save_and_quit() -> void:
	world.save_game()
	_quit_to_title()


func _quit_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TestTools.TITLE_SCENE)


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


func _apply_hand_drawn() -> void:
	_fit_menu_art()
	get_viewport().size_changed.connect(_fit_menu_art)
	for divider: Control in [panel.get_node(^"Content/Separator1"), panel.get_node(^"Content/Separator2")]:
		divider.custom_minimum_size.x = 220.0 # TUNE: width of the scroll's dividers
		divider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_quit_no_save.add_theme_font_size_override(&"font_size", 28) # TUNE: a step smaller than the menu items
	for button: Button in [resume_button, save_button, quit_button, _quit_no_save]:
		HoverArt.apply(button)
		button.add_theme_color_override(&"font_color", HAND_TEXT)
		button.add_theme_color_override(&"font_focus_color", HAND_TEXT)
		button.add_theme_color_override(&"font_hover_color", HAND_TITLE)
		button.add_theme_color_override(&"font_pressed_color", HAND_TITLE)


## The scroll fills the screen's height; its width follows so the art keeps its proportions.
func _fit_menu_art() -> void:
	var height := get_viewport().get_visible_rect().size.y
	var width := height * HAND_MENU.get_width() / HAND_MENU.get_height()
	panel.add_theme_stylebox_override(&"panel", _art_style(HAND_MENU, Vector2(width, height), Vector4(0.22, 0.11, 0.2, 0.17)))
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: # sized by hand, so nothing stretches it
		panel.set_anchor(side, 0.0)
	panel.size = Vector2(width, height)
	panel.set_deferred(&"size", Vector2(width, height)) # again once the wrapped title has settled its height
	panel.position = Vector2(0.0 if is_open else -width, 0.0)


## Art stretched over the panel, content kept inside its border (margins as shares: left, top, right, bottom).
func _art_style(texture: Texture2D, art_size: Vector2, margins: Vector4) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.content_margin_left = margins.x * art_size.x
	style.content_margin_top = margins.y * art_size.y
	style.content_margin_right = margins.z * art_size.x
	style.content_margin_bottom = margins.w * art_size.y
	return style


## "Testing tools: shown / hidden" under Save: toggles the testing buttons (top right, Skip scene).
func _add_testing_toggle() -> void:
	var toggle := Button.new()
	toggle.name = "TestingTools"
	toggle.flat = true
	toggle.focus_mode = Control.FOCUS_ALL
	toggle.add_theme_font_size_override(&"font_size", 26)
	toggle.add_theme_color_override(&"font_color", Color(0.3, 0.32, 0.42))
	toggle.add_theme_color_override(&"font_hover_color", HAND_TITLE)
	HoverArt.apply(toggle)
	var refresh := func() -> void: toggle.text = "Testing tools: %s" % ("shown" if TestTools.shown else "hidden")
	refresh.call()
	toggle.pressed.connect(func() -> void:
		TestTools.shown = not TestTools.shown
		refresh.call())
	save_button.get_parent().add_child(toggle)
	save_button.get_parent().move_child(toggle, save_button.get_index() + 1)
