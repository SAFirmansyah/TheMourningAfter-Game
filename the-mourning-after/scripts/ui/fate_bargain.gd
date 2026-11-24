class_name FateBargain
extends CanvasLayer
## Fate 3: on death, offers a paid revive. Bargain → countdown, then the fight resumes; Die → back to base.

signal revive_chosen
signal death_chosen
signal countdown_finished

@export var countdown_seconds := 3 # TUNE: pause before the fight resumes after a revive (s)
@export var fade_time := 0.25 # TUNE: grey overlay in/out (s)

const PARCHMENT := preload("res://textures/ui/Tutorial_Modal.png")
const INK := Color(0.24, 0.15, 0.09)
const INK_TITLE := Color(0.45, 0.16, 0.1)

@onready var grayscale: ColorRect = $Grayscale
@onready var box: Control = $Box
@onready var message: Label = $Box/Content/Message
@onready var residue_label: Label = $Box/Content/Residue
@onready var bargain_button: Button = $Box/Content/Bargain
@onready var die_button: Button = $Box/Content/Die
@onready var countdown_label: Label = $Countdown

var is_open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_amount(0.0)
	grayscale.hide()
	box.hide()
	countdown_label.hide()
	bargain_button.pressed.connect(_on_bargain)
	die_button.pressed.connect(_on_die)
	for button: Button in [bargain_button, die_button]:
		button.mouse_entered.connect(button.grab_focus)
	_style()


## On the same parchment, ink and brush hover as every other modal in the game.
func _style() -> void:
	var width := 900.0 # TUNE: on-screen width of the parchment (height follows its shape)
	var size := Vector2(width, width * PARCHMENT.get_height() / PARCHMENT.get_width())
	var style := StyleBoxTexture.new()
	style.texture = PARCHMENT
	style.content_margin_left = 0.08 * size.x
	style.content_margin_right = 0.08 * size.x
	style.content_margin_top = 0.12 * size.y
	style.content_margin_bottom = 0.11 * size.y
	box.add_theme_stylebox_override(&"panel", style)
	box.offset_left = -size.x / 2.0
	box.offset_right = size.x / 2.0
	box.offset_top = -size.y / 2.0
	box.offset_bottom = size.y / 2.0
	var heading := box.get_node(^"Content/Heading") as Label
	heading.add_theme_font_override(&"font", GameFonts.TITLE)
	heading.add_theme_color_override(&"font_color", INK_TITLE)
	for label: Label in [message, residue_label]:
		label.add_theme_color_override(&"font_color", INK)
	box.get_node(^"Content/Separator").hide() # dividers live in the pause menu only
	for button: Button in [bargain_button, die_button]:
		HoverArt.apply(button)
		button.add_theme_font_override(&"font", GameFonts.TITLE)
		for state: StringName in [&"font_color", &"font_focus_color"]:
			button.add_theme_color_override(state, INK)
		for state: StringName in [&"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color"]:
			button.add_theme_color_override(state, INK_TITLE)
	countdown_label.add_theme_font_override(&"font", GameFonts.TITLE)


## Swallows Escape so the pause menu can't open over the offer.
func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()


func open() -> void:
	is_open = true
	var cost := RunInventory.revive_cost()
	message.text = "Perrin has fallen. Offer %d residue to Fate to rise and fight on?" % cost
	residue_label.text = "Residue: %d" % RunInventory.magic_residue
	bargain_button.text = "Bargain (-%d)" % cost
	grayscale.show()
	box.show()
	box.pivot_offset = box.size / 2.0
	box.modulate.a = 0.0
	box.scale = Vector2.ONE * 0.94
	var pop := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pop.tween_property(box, "modulate:a", 1.0, 0.16)
	pop.tween_property(box, "scale", Vector2.ONE, 0.16)
	countdown_label.hide()
	create_tween().tween_method(_set_amount, 0.0, 1.0, fade_time)
	bargain_button.grab_focus()


func _on_bargain() -> void:
	box.hide()
	revive_chosen.emit()
	countdown_label.show()
	for n in range(countdown_seconds, 0, -1):
		countdown_label.text = str(n)
		await get_tree().create_timer(1.0, true).timeout
	countdown_label.hide()
	_close()
	countdown_finished.emit()


func _on_die() -> void:
	box.hide()
	_close()
	death_chosen.emit()


func _close() -> void:
	is_open = false
	_set_amount(0.0)
	grayscale.hide()


func _set_amount(value: float) -> void:
	(grayscale.material as ShaderMaterial).set_shader_parameter(&"amount", value)
