extends Node3D
## Fate 2's bargain: residue re-rolls the boss chamber, once per run (forced on a fresh save's first visit).

@onready var interactable: Interactable = $Interactable


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
	interactable.enabled = CampaignState.can_bargain_boss()
