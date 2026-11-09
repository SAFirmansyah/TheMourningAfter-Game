@tool
class_name BossClearPoint
extends Interactable
## Boss-room stand-in until boss fights exist: counts as defeating this run's boss.


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	interacted.connect(_on_interacted)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	prompt_label = "Defeat %s (stand-in)" % CampaignState.chosen_boss.capitalize()
	enabled = not CampaignState.boss_cleared


func _on_interacted() -> void:
	var room := owner as BossRoom
	if room:
		room.clear_boss()
