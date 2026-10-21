class_name DialogueLine
extends Resource
## One line of a conversation.

enum Speaker { CHARACTER, PLAYER }

@export var speaker := Speaker.CHARACTER
@export_multiline var text := ""
