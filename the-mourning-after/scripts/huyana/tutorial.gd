class_name Tutorial
extends Node
## First-run tutorial. The Sanctuary sits idle (AT_ALTAR) until the StoryDirector's opening ends and
## calls begin_day_0():
## - Day 0: two instruction pages over the Sanctuary, then a shortened day that plays normally
##   but costs no Sanctuary Health.
## - Night 0: the night modal explains Sanctuary Health (DayCycle.first_night_note).
## The Skip tutorial test button jumps straight to a normal day.

# INTRO was Night 0's pages; GUIDE is no longer used (old saves in it carry on as FREE_DAY).
# New stages go last: saves store the number.
enum Stage { INTRO, GUIDE, FREE_DAY, DONE, AT_ALTAR }

const PAGES := [
	["Day 0", "Every day, the lost sisters of Huyana will require food and medicine. Their containments will also need repairs. Rudrama can be tasked with repairing containments, but she can only fix one at a time."],
	["Day 0", "Ask Gwenith to prepare the food each containment needs, and Shuyi to brew the right medicines. Medicines can only be prepared if the right ingredients are available, so make sure to order these from Gwenith!"],
]
const ARROW := preload("res://textures/ui/arrow.png")

@export var world: World
@export var manager: SanctuaryManager
@export var day_cycle: DayCycle
@export var player: Player
@export var skip_button: Button
@export var day_0_length := 180.0 # TUNE: length of Day 0 (s at 1x)

@onready var panel: Control = $Pages/Panel
@onready var page_title: Label = $Pages/Panel/Content/Title
@onready var page_body: Label = $Pages/Panel/Content/Body
@onready var page_number: Label = $Pages/Panel/Content/Buttons/Page
@onready var back_button: Button = $Pages/Panel/Content/Buttons/Back
@onready var next_button: Button = $Pages/Panel/Content/Buttons/Next

var stage := Stage.AT_ALTAR

var _page := 0
var _normal_day_length := 0.0


func _enter_tree() -> void:
	add_to_group(&"save_state")


func _ready() -> void:
	_normal_day_length = Demo.DAY_LENGTH if Demo.SIDE == "villain" else day_cycle.day_length
	panel.hide()
	for button: Button in [back_button, next_button]: # arrows grow on hover; "Begin" gets the brush
		for state in [&"normal", &"focus", &"disabled"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.mouse_entered.connect(_hover_arrow.bind(button, true))
		button.mouse_exited.connect(_hover_arrow.bind(button, false))
	var flipped := ARROW.get_image()
	flipped.flip_x()
	back_button.icon = ImageTexture.create_from_image(flipped) # back: the arrow pointing left
	_set_arrow_backing(back_button, false)
	back_button.text = ""
	back_button.pressed.connect(func() -> void: _show_page(_page - 1))
	next_button.pressed.connect(_on_next)
	skip_button.pressed.connect(_skip)
	day_cycle.night_started.connect(_on_night_started)
	_begin.call_deferred() # after the world has loaded the save


func _begin() -> void:
	# Saves from before the tutorial existed are already past it.
	if stage in [Stage.INTRO, Stage.AT_ALTAR] and (day_cycle.day > 1 or day_cycle.elapsed > 0.0 or day_cycle.phase == DayCycle.Phase.NIGHT):
		stage = Stage.DONE
	if stage == Stage.GUIDE:
		stage = Stage.FREE_DAY
	_apply_stage()


func _process(_delta: float) -> void:
	if stage == Stage.INTRO:
		player.input_enabled = false # the room change hands control back as it fades in


func _apply_stage() -> void:
	skip_button.visible = stage == Stage.INTRO # during Day 0 the Skip day button takes its place
	day_cycle.clock_layer.visible = stage != Stage.AT_ALTAR
	manager.frozen = stage in [Stage.INTRO, Stage.AT_ALTAR]
	manager.health_locked = stage == Stage.FREE_DAY
	day_cycle.clock_paused = stage in [Stage.INTRO, Stage.AT_ALTAR]
	day_cycle.day_length = _normal_day_length if stage == Stage.DONE else day_0_length
	panel.visible = stage == Stage.INTRO
	if stage == Stage.INTRO:
		player.input_enabled = false
		player.forced_input = Vector2.ZERO
		_show_page(0)


## The opening has played: Day 0's instruction pages.
func begin_day_0() -> void:
	if stage == Stage.AT_ALTAR:
		stage = Stage.INTRO
		day_cycle.set_darkness(0.0) # the opening ends at night; Day 0 dawns while the screen is black
		_apply_stage()


func _on_next() -> void:
	if _page < PAGES.size() - 1:
		_show_page(_page + 1)
		return
	stage = Stage.FREE_DAY
	player.input_enabled = true
	_apply_stage()
	get_tree().call_group(&"world", &"save_game")


func _show_page(index: int) -> void:
	_page = clampi(index, 0, PAGES.size() - 1)
	page_title.text = PAGES[_page][0]
	page_body.text = PAGES[_page][1]
	page_number.text = "%d / %d" % [_page + 1, PAGES.size()]
	back_button.disabled = _page == 0
	back_button.modulate.a = 0.4 if _page == 0 else 1.0
	var last := _page == PAGES.size() - 1
	next_button.text = "Begin" if last else "" # the arrow until the last page
	next_button.icon = null if last else ARROW
	_set_arrow_backing(next_button, last)
	if last:
		next_button.scale = Vector2.ONE
	next_button.grab_focus()


## Arrow buttons: grow a little on hover (no brush behind them).
func _hover_arrow(button: Button, over: bool) -> void:
	if over and button.icon == null:
		HoverArt._pick(button, HoverArt.SELECTION) # a fresh brush each time, like other menus
	if button.icon == null or button.disabled:
		over = false
	button.pivot_offset = button.size / 2.0
	button.create_tween().tween_property(button, "scale", Vector2.ONE * (1.2 if over else 1.0), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT) # TUNE: hover size


## The brush hover behind a word button; none behind an arrow.
func _set_arrow_backing(button: Button, backing: bool) -> void:
	if backing:
		HoverArt._pick(button, HoverArt.SELECTION)
	else:
		var empty := StyleBoxEmpty.new()
		for state in [&"hover", &"pressed", &"hover_pressed"]:
			button.add_theme_stylebox_override(state, empty)


func _on_night_started(_day: int) -> void:
	if stage != Stage.DONE:
		stage = Stage.DONE # the manager has already settled the day, so Day 0 cost no health
		_apply_stage()


## Already past the tutorial (Start from a milestone): no pages.
func mark_done() -> void:
	stage = Stage.DONE
	_apply_stage()


## Test button: straight to a normal day, wherever the tutorial is.
func _skip() -> void:
	stage = Stage.DONE
	_apply_stage()
	player.input_enabled = true
	get_tree().call_group(&"world", &"save_game")


func get_save_data() -> Dictionary:
	return {"stage": stage}


func load_save_data(data: Dictionary) -> void:
	stage = int(data.get("stage", stage)) as Stage
