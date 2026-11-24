class_name PlayerHUD
extends CanvasLayer
## Top-left run HUD (the villain side's clock sits top-right): the residue ring with the residue held
## underneath, and Perrin's health bar coming out of it (the bar art over its background, shortening
## as he's hurt), with the ability charge under it. Hidden until the starting loadout is taken.
## In the starting room the loadout's rolled stats show as text under the bar.
## Bars glide to new values; a hit flashes the bar; the residue count pops when it changes.

@onready var panel: Control = $Panel
@onready var health_bar: TextureProgressBar = $Panel/HealthBar
@onready var health_label: Label = $Panel/HealthBar/HealthLabel
@onready var charge_bar: ProgressBar = $Panel/ChargeBar
@onready var residue_icon: TextureRect = $Panel/Ring/Icon
@onready var residue_count: Label = $Panel/Ring/ResidueCount # inside the ring, under the icon
@onready var info_label: Label = $Panel/InfoLabel

@export var charge_color := Color(0.78, 0.66, 0.38) # TUNE: charge bar fill while charging
@export var charge_ready_color := Color(1.0, 0.9, 0.45) # TUNE: charge bar fill when the ability is ready
@export var bar_glide := 8.0 # TUNE: how quickly the bars catch up (higher = snappier)
@export var hit_flash := Color(1.0, 0.55, 0.5) # TUNE: the bar's tint for a moment when hurt
@export var fade_time := 0.25 # TUNE: HUD fade in/out (s)

var in_base_room := false # set by the world on every room change

var _stats: HeroStats
var _player: Player
var _info_text := ""
var _shown_health := -1.0
var _target_health := 0.0
var _shown_residue := -1
var _alpha := 0.0


func _ready() -> void:
	RunInventory.effects_changed.connect(_refresh)
	panel.modulate.a = 0.0
	_refresh()


func bind_stats(stats: HeroStats) -> void:
	if _stats:
		_stats.health_change.disconnect(_on_health_change)
	_stats = stats
	_stats.health_change.connect(_on_health_change)
	_on_health_change(_stats.health, _stats.current_max_health)


func bind_player(player: Player) -> void:
	_player = player
	charge_bar.max_value = Player.MAX_CHARGE
	_refresh()


func _on_health_change(cur_health: int, max_health: int) -> void:
	if _shown_health >= 0.0 and cur_health < _target_health:
		health_bar.modulate = hit_flash
		create_tween().tween_property(health_bar, "modulate", Color.WHITE, 0.3)
	health_bar.max_value = max_health
	_target_health = cur_health
	if _shown_health < 0.0:
		_shown_health = cur_health
	health_label.text = "%d / %d" % [cur_health, max_health]


func _process(delta: float) -> void:
	_refresh()
	var weight := 1.0 - exp(-bar_glide * delta)
	if _shown_health >= 0.0:
		_shown_health = lerpf(_shown_health, _target_health, weight)
		health_bar.value = _shown_health
	if _player and charge_bar.visible:
		charge_bar.value = lerpf(charge_bar.value, _player.charge_points, weight)
	_alpha = move_toward(_alpha, 1.0 if _wanted() else 0.0, delta / fade_time)
	panel.modulate.a = _alpha
	panel.visible = _alpha > 0.0


func _wanted() -> bool:
	return RunInventory.loadout_taken and _player != null


func _refresh() -> void:
	if not _wanted():
		return
	if RunInventory.magic_residue != _shown_residue:
		if _shown_residue >= 0:
			residue_count.scale = Vector2.ONE * 1.3
			create_tween().tween_property(residue_count, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_shown_residue = RunInventory.magic_residue
		residue_count.text = str(_shown_residue)
	var text := ""
	if in_base_room and not _near_bargain_spot():
		text = "Max HP: %d\nMove Speed: %sx" % [_player.stats.current_max_health, snappedf(_player.move_speed_multiplier(), 0.01)]
	info_label.visible = text != ""
	charge_bar.visible = text == ""
	if charge_bar.visible:
		var fill := charge_bar.get_theme_stylebox(&"fill") as StyleBoxFlat
		fill.bg_color = charge_ready_color if _player.is_ability_ready() else charge_color
	if text != _info_text:
		_info_text = text
		info_label.text = text


func _near_bargain_spot() -> bool:
	return get_tree().get_nodes_in_group(&"bargain_spots").any(func(spot: Node) -> bool: return spot.is_player_near())
