@tool
class_name Grass
extends Node3D
## Purely decorative environment sprite. No collision — spawned randomly by CombatRoom.

@export var card: Sprite3D

@export var random_scale_range := Vector2(0.85, 1.15) # TUNE: per-instance size variation
@export var random_y_rotation := true # face each blade a random direction


func _ready() -> void:
	if not Engine.is_editor_hint():
		_randomize_look()


func _randomize_look() -> void:
	var s := randf_range(random_scale_range.x, random_scale_range.y)
	scale = Vector3(s, s, s)
	if random_y_rotation:
		rotation.y = randf() * TAU


func set_texture(tex: Texture2D) -> void:
	if card:
		card.texture = tex
