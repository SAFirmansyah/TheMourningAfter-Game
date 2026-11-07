@tool
class_name HealSpot
extends Interactable
## Non-combat room heal spot (pond, Huyana supplies): once per visit, restores part of the HP lost so far.

@export_range(0.0, 1.0) var restore_fraction := 0.5 # TUNE: share of missing HP restored
@export var action_label := "Rest" # prompt verb, e.g. "Drink" at the pond


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	interacted.connect(_on_interacted)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var amount := _heal_amount()
	prompt_label = "%s (+%d HP)" % [action_label, amount]
	enabled = not CombatRunState.is_rest_used() and amount > 0


func _heal_amount() -> int:
	var player := RunInventory.get_player()
	if player == null or player.stats == null:
		return 0
	return ceili((player.stats.current_max_health - player.stats.health) * restore_fraction)


func _on_interacted() -> void:
	var amount := _heal_amount()
	if CombatRunState.is_rest_used() or amount <= 0:
		return
	CombatRunState.use_rest()
	RunInventory.get_player().heal(amount)
