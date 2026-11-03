extends Node3D

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	_refresh_prompt()
	RunInventory.effects_changed.connect(_refresh_prompt)
	CampaignState.boss_changed.connect(_refresh_prompt)


func _on_interacted() -> void:
	CampaignState.bargain_boss()
	_refresh_prompt()


func _refresh_prompt() -> void:
	interactable.enabled = RunInventory.magic_residue > 0 and not CampaignState.has_boss_bargained
