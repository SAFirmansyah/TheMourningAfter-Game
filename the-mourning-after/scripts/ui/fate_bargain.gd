class_name FateBargain
extends CanvasLayer
## Fate 3: on death, offers a paid revive. Bargain → countdown, then the fight resumes; Die → back to base.

signal revive_chosen
signal death_chosen
signal countdown_finished

@export var countdown_seconds := 3 # TUNE: pause before the fight resumes after a revive (s)
@export var fade_time := 0.25 # TUNE: grey overlay in/out (s)

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
