@tool
class_name RunStartPoint
extends Interactable
## Starting-room spots: the sword stand hands out this run's starting stats and weapon; the prayer
## spot is Fate 1's bargain (residue, any number of times) that re-seeds them. Results show on the HUD.
## On a fresh save the first run's loadout is fixed and the bargain is forced.

enum Kind { LOADOUT, RESEED }

@export var kind := Kind.LOADOUT
@export var card: Sprite3D # the stand's visual; swapped to its empty look once the weapon's taken
@export var empty_texture: Texture2D # TUNE: the sword-stand art with no sword in it


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	interacted.connect(_on_interacted)
	_refresh_card()


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
		_refresh_card()
		get_tree().call_group(&"hero_tutorial", &"show_once") # the mission, the first time only
	elif RunInventory.try_bargain():
		get_tree().call_group(&"hero_story", &"say_weapon_bargain")


func _refresh_card() -> void:
	if kind == Kind.LOADOUT and card and empty_texture and RunInventory.loadout_taken:
		card.texture = empty_texture
