extends Node3D
## Fate 2's bargain: residue re-rolls the boss chamber, once per run (forced on a fresh save's first visit).

@onready var interactable: Interactable = $Interactable

## When set (the pre-boss pond), the bargain is only offered once that spot's heal has been taken
## (or there was nothing to heal): drink first, then bargain.
@export var after_heal: HealSpot


func _ready() -> void:
	add_to_group(&"bargain_spots")
	interactable.interacted.connect(_on_interacted)
	_refresh_prompt()
	RunInventory.effects_changed.connect(_refresh_prompt)
	CampaignState.boss_changed.connect(_refresh_prompt)


func is_player_near() -> bool:
	return interactable.player_in_range


func _on_interacted() -> void:
	CampaignState.bargain_boss()
	_refresh_prompt()


func _refresh_prompt() -> void:
	interactable.prompt_label = RunInventory.bargain_prompt(0 if CampaignState.free_boss_bargains else CampaignState.boss_bargain_cost)
	interactable.enabled = CampaignState.can_bargain_boss() and _heal_done()


func _process(_delta: float) -> void:
	if after_heal:
		_refresh_prompt() # opens up once the pond has been drunk from


func _heal_done() -> bool:
	return after_heal == null or after_heal._is_used() or after_heal._heal_amount() <= 0
