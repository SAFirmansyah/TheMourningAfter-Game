@tool
class_name Grass
extends Node3D
## Purely decorative environment sprite. No collision — spawned randomly by CombatRoom / GrassScatter.
## The card stands on its spot (its bottom edge at the floor, never below it) and turns to face the
## camera, so it's never seen edge-on or poking out under the floor.

@export var card: Sprite3D

@export var random_scale_range := Vector2(0.85, 1.15) # TUNE: per-instance size variation


func _ready() -> void:
	if card:
		card.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		card.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		card.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		_sit_on_floor()
	if not Engine.is_editor_hint():
		var s := randf_range(random_scale_range.x, random_scale_range.y)
		scale = Vector3(s, s, s)


func set_texture(tex: Texture2D) -> void:
	if card:
		card.texture = tex
		_sit_on_floor()


## Half the card's width on screen, at the largest random scale (how far it reaches sideways).
func half_width() -> float:
	if card == null or card.texture == null:
		return 0.5
	return card.texture.get_width() * card.pixel_size * card.scale.x * random_scale_range.y / 2.0


func _sit_on_floor() -> void:
	if card and card.texture:
		card.centered = true
		card.offset.y = card.texture.get_height() / 2.0 # bottom edge at this node's origin
		card.position.y = 0.0
