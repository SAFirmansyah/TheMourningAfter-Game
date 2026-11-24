class_name TestSkip
extends CanvasLayer
## Testing-only: a Skip button in the top-right corner while any cutscene or scripted scene plays.

@export var world: World

@onready var button: Button = $Skip


func _ready() -> void:
	button.pressed.connect(func() -> void:
		if world:
			world.story.skip())


func _process(_delta: float) -> void:
	button.visible = world != null and world.is_story_playing() and not get_tree().paused
