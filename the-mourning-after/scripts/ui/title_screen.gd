class_name TitleScreen
extends Control
## Title screen: New game / Resume game, Exit, and (testing only) Start from, which wipes and
## rebuilds a separate test save at a chosen point: Silvaluca (Perrin's base), the first boss
## fight (the room before it), Huyana (Constance's opening) or a Huyana milestone (75/50/25/0%),
## which starts at that milestone's narrative beat.

const WORLD_SCENE := "res://scenes/world/world.tscn"

@onready var play_button: Button = $Center/Content/Play
@onready var start_from_button: Button = $Center/Content/StartFrom
@onready var exit_button: Button = $Center/Content/Exit
@onready var start_box: Control = $StartFrom
@onready var silvaluca_button: Button = $StartFrom/Content/Silvaluca
@onready var first_boss_button: Button = $StartFrom/Content/FirstBoss
@onready var huyana_button: Button = $StartFrom/Content/Huyana
@onready var milestone_buttons: Array[Button] = [$StartFrom/Content/Huyana75, $StartFrom/Content/Huyana50, $StartFrom/Content/Huyana25, $StartFrom/Content/Huyana0]
@onready var cancel_button: Button = $StartFrom/Content/Cancel


func _ready() -> void:
	get_tree().paused = false
	SaveSystem.profile = "" # the real save, whatever was played last
	World.pending_start = ""
	start_box.hide()
	play_button.text = "Resume game" if SaveSystem.has_save(SaveSystem.DEFAULT_SLOT) else "New game"
	if SaveSystem.is_ended(): # the game "deleted itself": only the testing option is left
		play_button.hide()
		exit_button.hide()
	play_button.pressed.connect(_on_play)
	start_from_button.pressed.connect(_open_start_box)
	exit_button.pressed.connect(get_tree().quit)
	silvaluca_button.pressed.connect(_start_from.bind("silvaluca"))
	first_boss_button.pressed.connect(_start_from.bind("first_boss"))
	huyana_button.pressed.connect(_start_from.bind("huyana"))
	for i in milestone_buttons.size():
		milestone_buttons[i].pressed.connect(_start_from.bind("huyana_%d" % i))
	cancel_button.pressed.connect(_close_start_box)
	for button: Button in [play_button, start_from_button, exit_button, silvaluca_button, first_boss_button, huyana_button, cancel_button] + milestone_buttons:
		button.mouse_entered.connect(button.grab_focus)
	(start_from_button if SaveSystem.is_ended() else play_button).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if start_box.visible and event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_close_start_box()


func _on_play() -> void:
	if not SaveSystem.has_save(SaveSystem.DEFAULT_SLOT):
		SaveSystem.delete_profile("") # no leftover Act 2 save under a new game
	get_tree().change_scene_to_file(WORLD_SCENE)


## Testing: a fresh test save each time, set up at the chosen point.
func _start_from(point: String) -> void:
	SaveSystem.delete_profile(SaveSystem.TEST_PROFILE)
	SaveSystem.profile = SaveSystem.TEST_PROFILE
	World.pending_start = point
	get_tree().change_scene_to_file(WORLD_SCENE)


func _open_start_box() -> void:
	start_box.show()
	silvaluca_button.grab_focus()


func _close_start_box() -> void:
	start_box.hide()
	start_from_button.grab_focus()
