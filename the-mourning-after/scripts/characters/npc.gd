class_name NPC
extends StaticBody3D
## Talkable character. Name, portrait and conversation are set here and passed to its Interactable.

@export var character_name := "Character"
@export var portrait: Texture2D # placeholder uses the card
@export var conversation: Array[DialogueLine] = []

@onready var card: Sprite3D = $Card
@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	interactable.prompt_label = "Talk"
	interactable.character_name = character_name
	interactable.character_portrait = portrait if portrait else card.texture
	interactable.character_portrait_tint = Color.WHITE if portrait else card.modulate
	interactable.conversation = conversation
