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
		if card is not FacingCard: # swaying grass turns itself to the camera
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


## Blank rows under each texture's drawing (measured once per texture), so the blades themselves,
## not the image's empty bottom edge, touch the floor.
static var _bottom_gap := {}


func _sit_on_floor() -> void:
	if card and card.texture:
		var tex := card.texture
		if not _bottom_gap.has(tex):
			var img := tex.get_image()
			_bottom_gap[tex] = img.get_height() - img.get_used_rect().end.y if img else 0
		card.centered = true
		card.offset.y = tex.get_height() / 2.0 - _bottom_gap[tex] # the drawing's lowest pixel at this node's origin
		card.position.y = 0.0
