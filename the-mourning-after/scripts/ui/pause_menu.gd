class_name PauseMenu
extends CanvasLayer
## Escape pauses everything: grayscale overlay, slide-out menu, quit confirmation, stats sheet.

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
@onready var stats_box: Control = $StatsBox
@onready var stats_rows: GridContainer = $StatsBox/Content/Rows
@onready var stats_close_button: Button = $StatsBox/Content/Close

@export var stats_heading_color := Color(0.95, 0.85, 0.6) # TUNE: section headings in the stats sheet
@export var stats_name_color := Color(0.7, 0.67, 0.6) # TUNE: stat names
@export var stats_value_color := Color(0.92, 0.9, 0.85) # TUNE: stat values

var is_open := false
var _tween: Tween
var _quit_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_amount(0.0)
	grayscale.hide()
	panel.hide()
	quit_box.hide()
	stats_box.hide()
	resume_button.pressed.connect(close)
	stats_button.pressed.connect(_open_stats_box)
	stats_close_button.pressed.connect(_close_stats_box)
	save_button.pressed.connect(world.save_game)
	quit_button.pressed.connect(_open_quit_box)
	save_quit_button.pressed.connect(_save_and_quit)
	quit_no_save_button.pressed.connect(get_tree().quit)
	cancel_button.pressed.connect(_close_quit_box)
	for button: Button in [resume_button, save_button, stats_button, quit_button, save_quit_button, quit_no_save_button, cancel_button, stats_close_button]:
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
	elif stats_box.visible:
		_close_stats_box()
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
	stats_box.hide()
	panel.position.x = -panel.size.x
	_restart_tween()
	_tween.tween_property(panel, "position:x", 0.0, slide_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_method(_set_amount, _get_amount(), 1.0, slide_time)
	resume_button.grab_focus()


func close() -> void:
	is_open = false
	world.set_menu_paused(false)
	_hide_quit_box_now()
	stats_box.hide()
	_restart_tween()
	_tween.tween_property(panel, "position:x", -panel.size.x, slide_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_method(_set_amount, _get_amount(), 0.0, slide_time)
	_tween.chain().tween_callback(func() -> void:
		panel.hide()
		grayscale.hide())
	get_viewport().gui_release_focus()


## Only asks about saving when something happened since the last save.
func _open_quit_box() -> void:
	stats_box.hide()
	if not world.has_unsaved_changes():
		get_tree().quit()
		return
	_set_enabled(save_quit_button, world.can_save())
	quit_box.show()
	quit_box.modulate.a = 0.0
	if _quit_tween:
		_quit_tween.kill()
	_quit_tween = create_tween().set_parallel()
	_quit_tween.tween_property(quit_box, "modulate:a", 1.0, slide_time)
	(save_quit_button if not save_quit_button.disabled else quit_no_save_button).grab_focus()


func _open_stats_box() -> void:
	_hide_quit_box_now()
	_fill_stats()
	stats_box.show()
	stats_box.modulate.a = 0.0
	if _quit_tween:
		_quit_tween.kill()
	_quit_tween = create_tween()
	_quit_tween.tween_property(stats_box, "modulate:a", 1.0, slide_time)
	stats_close_button.grab_focus()


func _close_stats_box() -> void:
	stats_box.hide()
	stats_button.grab_focus()


## Everything the HUD leaves out: loadout, weapon, buffs and the inventory.
func _fill_stats() -> void:
	for child in stats_rows.get_children():
		stats_rows.remove_child(child)
		child.queue_free()
	var player := RunInventory.get_player()
	if RunInventory.loadout_taken and player:
		_add_heading("Perrin")
		_add_row("Health", "%d / %d" % [player.stats.health, player.stats.current_max_health])
		_add_row("Move Speed", "%sx" % snappedf(player.move_speed_multiplier(), 0.01))
		_add_row("Dashes", str(player.max_dashes))
		_add_row("Damage Resist", "%s%%" % snappedf(player.damage_reduction * 100.0, 0.1))
		var weapon := player.weapon
		if weapon:
			_add_heading("Weapon")
			_add_row("Sword", weapon.weapon_name)
			_add_row("Damage", _with_bonus(str(roundi(weapon.damage)), roundi(player.bonus_weapon_damage), "+%d"))
			var swing := weapon.attack_cooldown * (1.0 - player.bonus_cooldown_reduction)
			_add_row("Time Between Swings", "%ss" % snappedf(swing, 0.001))
			_add_row("Attack Speed Bonus", "+%s%%" % snappedf(player.bonus_cooldown_reduction * 100.0, 0.1))
			var ready := "Ready" if player.is_ability_ready() else "%d%%" % roundi(player.charge_points / Player.MAX_CHARGE * 100.0)
			_add_row("Ability", "%s (%s)" % [_ability_name_for(weapon), ready])
	_add_heading("Inventory")
	_add_row("Residue", str(RunInventory.magic_residue))


func _with_bonus(base: String, bonus: int, format: String) -> String:
	return base if bonus == 0 else "%s (%s)" % [base, format % bonus]


func _add_heading(text: String) -> void:
	for column in 2:
		var label := Label.new()
		label.text = text if column == 0 else ""
		label.add_theme_font_size_override(&"font_size", 28)
		label.add_theme_color_override(&"font_color", stats_heading_color)
		stats_rows.add_child(label)


func _add_row(stat: String, value: String) -> void:
	var name_label := Label.new()
	name_label.text = stat
	name_label.add_theme_font_size_override(&"font_size", 24)
	name_label.add_theme_color_override(&"font_color", stats_name_color)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_rows.add_child(name_label)
	var value_label := Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override(&"font_size", 24)
	value_label.add_theme_color_override(&"font_color", stats_value_color)
	stats_rows.add_child(value_label)


func _ability_name_for(weapon: WeaponData) -> String:
	if weapon.charged_abilities.is_empty():
		return "None"
	var ability := weapon.charged_abilities[0]
	if ability is PoisonDamageAbility:
		return "Poison"
	elif ability is StunAbility:
		return "Stun"
	elif ability is CritHitAbility:
		return "Critical Hit"
	elif ability is SelfHealAbility:
		return "Heal"
	return "Ability"


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
