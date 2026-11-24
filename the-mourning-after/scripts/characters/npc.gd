@tool
class_name NPC
extends StaticBody3D
## Talkable character. Name, portrait, tint and conversation are set here and passed to its Interactable.

@export var character_name := "Character"
@export var portrait: Texture2D # placeholder uses the card
@export var tint := Color(1, 0.62, 0.4, 1): # placeholder card colour
	set(value):
		tint = value
		if card:
			card.modulate = tint
@export var conversation: Array[DialogueLine] = []

@onready var card: Sprite3D = $Card
@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	add_to_group(&"parallax_character")
	card.modulate = tint
	if Engine.is_editor_hint():
		return
	interactable.prompt_label = "Talk"
	interactable.enabled = not conversation.is_empty()
	interactable.character_name = character_name
	interactable.character_portrait = portrait if portrait else card.texture
	interactable.character_portrait_tint = Color.WHITE if portrait else card.modulate
	interactable.conversation = conversation
