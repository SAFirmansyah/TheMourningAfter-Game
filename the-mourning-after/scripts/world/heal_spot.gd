@tool
class_name HealSpot
extends Interactable
## Non-combat room heal spot (pond, Huyana supplies): once per visit, restores part of the HP lost so far.

@export_range(0.0, 1.0) var restore_fraction := 0.5 # TUNE: share of missing HP restored
@export var action_label := "Rest" # prompt verb, e.g. "Drink" at the pond
@export var once_per_visit := false # on: usable once each time the room is entered (ponds); off: once per gauntlet

var always_usable := false # set by the story: usable even at full health (a Fate is waiting at this pond)

var _used_here := false


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	interacted.connect(_on_interacted)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var amount := _heal_amount()
	prompt_label = "%s (+%d HP)" % [action_label, amount] if amount > 0 else action_label
	enabled = not _is_used() and (amount > 0 or always_usable)


func _heal_amount() -> int:
	var player := RunInventory.get_player()
	if player == null or player.stats == null:
		return 0
	return ceili((player.stats.current_max_health - player.stats.health) * restore_fraction)


func _on_interacted() -> void:
	var amount := _heal_amount()
	if _is_used() or (amount <= 0 and not always_usable):
		return
	if once_per_visit:
		_used_here = true
	else:
		CombatRunState.use_rest()
	RunInventory.get_player().heal(amount)


func _is_used() -> bool:
	return _used_here if once_per_visit else CombatRunState.is_rest_used()
