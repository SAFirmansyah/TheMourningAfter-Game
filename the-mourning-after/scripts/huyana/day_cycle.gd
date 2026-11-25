class_name DayCycle
extends Node
## Sanctuary day/night loop. Days run on a timer and move the sun; nights darken the scene and show
## the night modal. After Proceed, Constance walks to the campfire, where the StoryDirector plays the
## night's scene (or milestone beat) and starts the next day.
## Testing: Skip day ends the day at once, costing some Sanctuary Health.

signal day_started(day: int)
signal night_started(day: int)

enum Phase { DAY, NIGHT }

@export var player: Player
@export var day_length := 360.0 # TUNE: real seconds per day at 1x
@export var night_fade_time := 1.5 # TUNE: seconds to darken at dusk / brighten at dawn
@export var sanctuary: SanctuaryManager
const CHECKMARK := preload("res://textures/ui/checkmark.png")

@export_multiline var first_night_note := "This is the current health of your lost sisters in the sanctuary. It decays each time a request is left unfulfilled after the timer runs out, and never comes back up." # shown on Night 0's modal
@export var night_0_spacing := 22 # TUNE: gap between heading, bar, note and OK on Night 0 (px)
@export var later_night_spacing := 30 # TUNE: gap between heading, bar and OK on nights after Night 0 (px)
@export var skip_day_health_loss := 4.0 # TUNE: Sanctuary Health the Skip day test button costs (%)

@export_group("Sun")
@export_range(0.0, 0.5) var golden_hour := 0.2 # TUNE: share of the day at each end lit golden (dusk full, dawn softer)
@export var shadow_angle_start := 170.0 # TUNE: shadow direction at dawn (degrees; 0 = right, 90 = away from camera, 180 = left)
@export var shadow_angle_end := 10.0 # TUNE: shadow direction at dusk
@export var shadow_length_long := 1.6 # TUNE: shadow length at dawn/dusk (times object height)
@export var shadow_length_short := 0.35 # TUNE: shadow length at midday (times object height)
@export var shadow_opacity := 0.5 # TUNE: shadow darkness in full sun
@export var shadow_fade := 0.06 # TUNE: share of the day over which shadows fade in at dawn / out at dusk

var day := 1
var phase := Phase.DAY
var speed := 1.0
var elapsed := 0.0
## Night after Proceed: waiting on the campfire's narrative beat before the next day.
var awaiting_beat := false
## Tutorial: the clock stands still (the Sanctuary keeps working).
var clock_paused := false

@onready var clock_layer: CanvasLayer = $Clock
@onready var clock: ClockFace = $Clock/Dial
@onready var speed_buttons: Container = $Clock/Speeds
@onready var reset_button: Button = $Clock/ResetSave
@onready var skip_day_button: Button = $Clock/SkipDay
@onready var night_shade: ColorRect = $NightOverlay/Shade
@onready var night_modal: Control = $NightModal/Panel
@onready var night_title: Label = $NightModal/Panel/Content/Title
@onready var health_label: Label = $NightModal/Panel/Content/HealthLabel
@onready var health_bar: TextureProgressBar = $NightModal/Panel/Content/HealthBar # the bar art over its background; shortens as health drops
@onready var health_percent: Label = $NightModal/Panel/Content/HealthBar/Percent
@onready var night_note: Label = $NightModal/Panel/Content/Note
@onready var proceed_button: Button = $NightModal/Panel/Content/Proceed

var _shade_tween: Tween


func _ready() -> void:
	if Demo.SIDE == "villain":
		day_length = Demo.DAY_LENGTH
	add_to_group(&"save_state")
	add_to_group(&"day_cycle")
	skip_day_button.pressed.connect(_skip_day)
	_set_night_amount(0.0)
	night_modal.hide()
	HoverArt.icon_button(proceed_button, CHECKMARK, Vector2(90, 70)) # OK
	proceed_button.pressed.connect(_on_proceed)
	reset_button.pressed.connect(_reset_save)
	for button: Button in speed_buttons.get_children():
		button.pressed.connect(set_speed.bind(float(button.text.trim_suffix("x"))))
	_update_sun()
	_update_clock()
	day_started.emit(day)


var _test_buttons: Control

## The testing buttons under the clock sit in one container so the pause menu toggle hides them all.
func _gather_test_buttons() -> void:
	_test_buttons = Control.new()
	_test_buttons.name = "TestButtons"
	_test_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_test_buttons.set_anchors_preset(Control.PRESET_FULL_RECT)
	clock_layer.add_child(_test_buttons)
	for path in [^"Clock/Speeds", ^"Clock/ResetSave", ^"Clock/SkipTutorial", ^"Clock/SkipDay"]:
		var node := get_node_or_null(path)
		if node:
			node.reparent(_test_buttons, false)


func _process(delta: float) -> void:
	if _test_buttons == null:
		_gather_test_buttons()
	_test_buttons.visible = TestTools.shown
	var world := get_parent() as World
	skip_day_button.visible = phase == Phase.DAY and not clock_paused and not (world and world.is_story_playing())
	if phase != Phase.DAY or clock_paused:
		return
	elapsed = minf(elapsed + delta * speed, day_length)
	_update_sun()
	_update_clock()
	if elapsed >= day_length:
		_start_night()


func progress() -> float:
	return clampf(elapsed / day_length, 0.0, 1.0)


## Test fast-forward: scales only the day clock, not gameplay.
func set_speed(multiplier: float) -> void:
	speed = multiplier


## Testing: straight to tonight, as if the day had passed with some Sanctuary Health lost.
func _skip_day() -> void:
	sanctuary.skip_day(skip_day_health_loss)
	elapsed = day_length


## Testing: back to a brand-new game (every save wiped, title screen).
func _reset_save() -> void:
	TestTools.reset_save(get_tree())


func _start_night() -> void:
	phase = Phase.NIGHT
	player.input_enabled = false
	player.forced_input = Vector2.ZERO
	_update_clock()
	night_started.emit(day)
	await _fade_shade(1.0)
	_show_night_modal()


func _on_proceed() -> void:
	night_modal.hide()
	var world := get_parent() as World
	awaiting_beat = true
	player.input_enabled = true
	if world:
		world.save_game()


## Called once the night's narrative beat has played.
func start_day() -> void:
	awaiting_beat = false
	day += 1
	elapsed = 0.0
	phase = Phase.DAY
	_update_sun()
	_update_clock()
	player.input_enabled = true
	_fade_shade(0.0)
	day_started.emit(day)
	var world := get_parent() as World
	if world:
		world.save_game()


func _show_night_modal() -> void:
	var first := day == 1 # the night after Day 0
	night_title.text = "Night %d" % (day - 1) if first else "Night %d - Sanctuary Health" % (day - 1)
	health_bar.value = sanctuary.health
	health_percent.text = "%d%%" % roundi(sanctuary.health)
	night_note.text = first_night_note
	night_note.visible = first and first_night_note != ""
	health_label.hide() # the heading names the bar on later nights; Night 0's note explains it
	night_modal.get_node(^"Content").add_theme_constant_override(&"separation", night_0_spacing if first else later_night_spacing)
	night_modal.show()
	proceed_button.grab_focus()


func get_save_data() -> Dictionary:
	return {"day": day, "phase": phase, "elapsed": elapsed, "awaiting_beat": awaiting_beat}


func load_save_data(data: Dictionary) -> void:
	day = int(data.get("day", day))
	elapsed = float(data.get("elapsed", elapsed))
	phase = int(data.get("phase", phase)) as Phase
	awaiting_beat = phase == Phase.NIGHT and bool(data.get("awaiting_beat", false))
	_update_sun()
	_update_clock()
	if phase == Phase.NIGHT:
		_set_night_amount(1.0)
		player.input_enabled = awaiting_beat
		if not awaiting_beat:
			_show_night_modal()


func _update_sun() -> void:
	var p := progress()
	var angle := deg_to_rad(lerpf(shadow_angle_start, shadow_angle_end, p))
	var fade := smoothstep(0.0, shadow_fade, p) * (1.0 - smoothstep(1.0 - shadow_fade, 1.0, p))
	RenderingServer.global_shader_parameter_set(&"sun_shadow_dir", Vector2(cos(angle), -sin(angle)))
	RenderingServer.global_shader_parameter_set(&"sun_shadow_length", lerpf(shadow_length_long, shadow_length_short, sin(PI * p)))
	RenderingServer.global_shader_parameter_set(&"sun_shadow_alpha", shadow_opacity * fade)
	var golden := maxf(0.6 * (1.0 - smoothstep(0.0, golden_hour, p)), smoothstep(1.0 - golden_hour, 1.0, p)) # dawn softer than dusk
	(night_shade.material as ShaderMaterial).set_shader_parameter("warmth", golden if phase == Phase.DAY else 0.0)


func _update_clock() -> void:
	clock.set_time(phase == Phase.NIGHT, progress())


## Night darkness outside the normal cycle (e.g. staged scenes).
func set_darkness(value: float, fade := false) -> void:
	if fade:
		_fade_shade(value)
	else:
		if _shade_tween:
			_shade_tween.kill()
		_set_night_amount(value)


func _fade_shade(target: float) -> void:
	if _shade_tween:
		_shade_tween.kill()
	_shade_tween = create_tween()
	_shade_tween.tween_method(_set_night_amount, _get_night_amount(), target, night_fade_time)
	await _shade_tween.finished


func _set_night_amount(value: float) -> void:
	(night_shade.material as ShaderMaterial).set_shader_parameter("amount", value)


## Current night darkness, 0 (day) to 1 (full night).
func night_amount() -> float:
	return _get_night_amount()


func _get_night_amount() -> float:
	return (night_shade.material as ShaderMaterial).get_shader_parameter("amount")
