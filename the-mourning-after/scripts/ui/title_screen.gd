class_name TitleScreen
extends Control
## Title screen: New game / Resume game, Exit, and (testing only) Start from, which wipes and
## rebuilds a separate test save at a chosen point: Silvaluca (Perrin's base), the first boss
## fight (the room before it), Huyana (Constance's opening), a Huyana milestone (75/50/25/0%),
## which starts at that milestone's narrative beat, or a standalone Play as Constance test fight.

const WORLD_SCENE := "res://scenes/world/world.tscn"
const FINAL_FIGHT_SCENE := "res://scenes/rooms/constance_fight.tscn" # TUNE: adjust to the real path
const INK := Color(0.24, 0.15, 0.09)
const INK_HOVER := Color(0.45, 0.16, 0.1)
const INK_TEST := Color(0.3, 0.32, 0.42) # the testing-only option, set apart

@export var title_gap := 90 # TUNE: space between the title art and the buttons (px)

@onready var play_button: Button = $Center/Content/Play
@onready var start_from_button: Button = $Center/Content/StartFrom
@onready var exit_button: Button = $Center/Content/Exit
@onready var start_box: Control = $StartFrom
@onready var silvaluca_button: Button = $StartFrom/Content/Silvaluca
@onready var first_boss_button: Button = $StartFrom/Content/FirstBoss
@onready var huyana_button: Button = $StartFrom/Content/Huyana
@onready var milestone_buttons: Array[Button] = [$StartFrom/Content/Huyana75, $StartFrom/Content/Huyana50, $StartFrom/Content/Huyana25, $StartFrom/Content/Huyana0]
@onready var play_as_constance_button: Button = $StartFrom/Content/FinalBossFight
@onready var cancel_button: Button = $StartFrom/Content/Cancel

@onready var constance_box: Control = $ConstanceTestBox
@onready var gwenith_button: Button = $ConstanceTestBox/Content/GwenithDead
@onready var shuyi_button: Button = $ConstanceTestBox/Content/ShuyiDead
@onready var rudrama_button: Button = $ConstanceTestBox/Content/RudramaDead
@onready var constance_cancel_button: Button = $ConstanceTestBox/Content/Cancel


func _ready() -> void:
	get_tree().paused = false
	SaveSystem.profile = "" # the real save, whatever was played last
	World.pending_start = ""
	start_box.hide()
	constance_box.hide()
	play_button.text = "Resume game" if SaveSystem.has_save(SaveSystem.DEFAULT_SLOT) else "New game"
	if SaveSystem.is_ended(): # the game "deleted itself": only Exit and the testing option are left
		play_button.hide()
	play_button.pressed.connect(_on_play)
	start_from_button.pressed.connect(_open_start_box)
	exit_button.pressed.connect(get_tree().quit)
	silvaluca_button.pressed.connect(_start_from.bind("silvaluca"))
	first_boss_button.pressed.connect(_start_from.bind("first_boss"))
	play_as_constance_button.pressed.connect(_open_constance_box)
	huyana_button.pressed.connect(_start_from.bind("huyana"))
	for i in milestone_buttons.size():
		milestone_buttons[i].pressed.connect(_start_from.bind("huyana_%d" % i))
	cancel_button.pressed.connect(_close_start_box)
	gwenith_button.pressed.connect(_start_constance_fight.bind("Gwenith"))
	shuyi_button.pressed.connect(_start_constance_fight.bind("Shuyi"))
	rudrama_button.pressed.connect(_start_constance_fight.bind("Rudrama"))
	constance_cancel_button.pressed.connect(_close_constance_box)
	for button: Button in [play_button, start_from_button, exit_button, silvaluca_button, first_boss_button, play_as_constance_button, huyana_button, cancel_button, gwenith_button, shuyi_button, rudrama_button, constance_cancel_button] + milestone_buttons:
		button.mouse_entered.connect(button.grab_focus)
	_style_menu()
	(start_from_button if SaveSystem.is_ended() else play_button).grab_focus()


## Dark ink on the paper backdrop, the brush hover, and the title face (as in the pause menu).
func _style_menu() -> void:
	var gap := $Center/Content/Separator as HSeparator # no line (dividers live in the pause menu), just space
	gap.add_theme_stylebox_override(&"separator", StyleBoxEmpty.new())
	gap.add_theme_constant_override(&"separation", title_gap)
	for button: Button in [play_button, start_from_button, exit_button]:
		HoverArt.apply(button)
		button.add_theme_font_override(&"font", GameFonts.TITLE)
		var ink := INK_TEST if button == start_from_button else INK
		for state: StringName in [&"font_color", &"font_focus_color"]:
			button.add_theme_color_override(state, ink)
		for state: StringName in [&"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color"]:
			button.add_theme_color_override(state, INK_HOVER)


func _unhandled_input(event: InputEvent) -> void:
	if constance_box.visible and event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_close_constance_box()
		return
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


func _open_constance_box() -> void:
	start_box.hide()
	constance_box.show()
	gwenith_button.grab_focus()


func _close_constance_box() -> void:
	constance_box.hide()
	start_from_button.grab_focus()


## Testing: jumps straight into the final fight scene, skipping World.gd and RunInventory entirely,
## with a chosen "defeated boss" so Constance's two spells can be tested in every combination.
func _start_constance_fight(defeated_boss: String) -> void:
	TestFixture.pending_defeated_boss = defeated_boss
	get_tree().change_scene_to_file(FINAL_FIGHT_SCENE)
