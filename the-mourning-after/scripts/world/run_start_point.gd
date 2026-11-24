@tool
class_name RunStartPoint
extends Interactable
## Starting-room spots: the sword stand hands out this run's starting stats and weapon; the prayer
## spot is Fate 1's bargain (residue, any number of times) that re-seeds them. Results show on the HUD.
## On a fresh save the first run's loadout is fixed and the bargain is forced.

enum Kind { LOADOUT, RESEED }

@export var kind := Kind.LOADOUT


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	interacted.connect(_on_interacted)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	match kind:
		Kind.LOADOUT:
			prompt_label = "Take up arms"
			enabled = not RunInventory.loadout_taken
		Kind.RESEED:
			prompt_label = RunInventory.bargain_prompt(RunInventory.reseed_cost)
			enabled = RunInventory.can_bargain()


func _on_interacted() -> void:
	if kind == Kind.LOADOUT:
		RunInventory.take_loadout()
		get_tree().call_group(&"hero_tutorial", &"show_once") # the mission, the first time only
	else:
		RunInventory.try_bargain()
