class_name TestTools
extends CanvasLayer
## Testing-only buttons in the top-right corner of Perrin's side: no health loss, ignore residue,
## reset run, reset save. The toggles are static so they survive room and scene changes.

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"

static var no_health_loss := false # Perrin takes no damage
static var ignore_residue := false # every Fate bargain is allowed and costs nothing
static var shown := false # testing buttons on screen (toggled from the pause menu); hidden by default

@export var world: World

@onready var health_button: Button = $Buttons/NoHealthLoss
@onready var residue_button: Button = $Buttons/IgnoreResidue
@onready var reset_run_button: Button = $Buttons/ResetRun
@onready var reset_save_button: Button = $Buttons/ResetSave


func _ready() -> void:
	health_button.button_pressed = no_health_loss
	residue_button.button_pressed = ignore_residue
	health_button.toggled.connect(func(on: bool) -> void: no_health_loss = on)
	residue_button.toggled.connect(func(on: bool) -> void:
		ignore_residue = on
		RunInventory.effects_changed.emit()) # bargain prompts re-check what they can afford
	reset_run_button.pressed.connect(func() -> void:
		if world:
			world.reset_run())
	reset_save_button.pressed.connect(func() -> void: reset_save(get_tree()))


## Back to a brand-new game: every save (both halves, and the Start from test save) is wiped
## and the title screen opens.
static func reset_save(tree: SceneTree) -> void:
	SaveSystem.delete_all()
	SaveSystem.clear_ended() # undoes the 'Destroy the spell' self-deletion too
	tree.paused = false
	tree.change_scene_to_file(TITLE_SCENE)


func _process(_delta: float) -> void:
	visible = shown
