class_name PlayerHUD
extends CanvasLayer
## Top-left run panel; hidden until the starting loadout is taken.
## Starting room: the rolled loadout as text. Once combat starts: health and ability charge bars.
## Next to a Fate 2 bargain spot: just the residue held. Everything else lives in the pause menu's stats.

@onready var panel: PanelContainer = $Panel
@onready var health_bar: ProgressBar = $Panel/Content/HealthBar
@onready var health_label: Label = $Panel/Content/HealthBar/HealthLabel
@onready var charge_bar: ProgressBar = $Panel/Content/ChargeBar
@onready var info_label: Label = $Panel/Content/InfoLabel

@export var charge_color := Color(0.78, 0.66, 0.38) # TUNE: charge bar fill while charging
@export var charge_ready_color := Color(1.0, 0.9, 0.45) # TUNE: charge bar fill when the ability is ready

var in_base_room := false # set by the world on every room change

var _stats: HeroStats
var _player: Player
var _info_text := ""


func _ready() -> void:
	RunInventory.effects_changed.connect(_refresh)
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
	health_bar.max_value = max_health
	health_bar.value = cur_health
	health_label.text = "%d / %d" % [cur_health, max_health]


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	panel.visible = RunInventory.loadout_taken and _player != null
	if not panel.visible:
		return
	var text := ""
	if _near_bargain_spot():
		text = "Residue: %d" % RunInventory.magic_residue
	elif in_base_room:
		text = "Max HP: %d\nMove Speed: %sx\nResidue: %d" % [
			_player.stats.current_max_health, snappedf(_player.move_speed_multiplier(), 0.01), RunInventory.magic_residue]
	var bars := text == ""
	health_bar.visible = bars
	charge_bar.visible = bars
	info_label.visible = not bars
	if bars:
		charge_bar.value = _player.charge_points
		var fill := charge_bar.get_theme_stylebox(&"fill") as StyleBoxFlat
		fill.bg_color = charge_ready_color if _player.is_ability_ready() else charge_color
	if text != _info_text:
		_info_text = text
		info_label.text = text
		panel.reset_size()


func _near_bargain_spot() -> bool:
	return get_tree().get_nodes_in_group(&"bargain_spots").any(func(spot: Node) -> bool: return spot.is_player_near())
