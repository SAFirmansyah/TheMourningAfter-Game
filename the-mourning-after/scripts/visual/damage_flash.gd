class_name DamageFlash
extends Node
## Tints a card red whenever its owner takes damage, then fades back.
## With effects enabled (mobs) it can also grey the card out and flash it white.

const MOB_CARD_SHADER := preload("res://shaders/mob_card.gdshader")

@export var flash_color := Color(1.0, 0.25, 0.25) # TUNE: tint at the moment of the hit
@export var flash_time := 1.0 # TUNE: fade back to normal (s)
@export var white_flash_color := Color(1.0, 1.0, 1.0) # TUNE: crit flash colour
@export var white_flash_strength := 0.9 # TUNE: how solid the crit flash starts (0–1)
@export var white_flash_time := 0.35 # TUNE: crit flash fade (s)
@export var grey_tint := Color(0.55, 0.55, 0.6) # TUNE: stunned tint for cards without the mob shader (Perrin)

var _card: SpriteBase3D
var _base_modulate := Color.WHITE
var _tween: Tween
var _white_tween: Tween
var _material: ShaderMaterial
var _greyed := false


func watch(stats: Stats, card: SpriteBase3D) -> void:
	if card == null:
		return
	_card = card
	_base_modulate = card.modulate
	stats.damaged.connect(func(_amount: int) -> void: flash())


## Swaps the card onto the mob card shader so it can grey out and flash white.
func enable_effects() -> void:
	if _card == null or _material:
		return
	_material = ShaderMaterial.new()
	_material.shader = MOB_CARD_SHADER
	_update_card_texture()
	if _card is AnimatedSprite3D:
		(_card as AnimatedSprite3D).frame_changed.connect(_update_card_texture)
	_card.material_override = _material
	
func _update_card_texture() -> void:
	if _material == null:
		return
	if _card is AnimatedSprite3D:
		var anim := _card as AnimatedSprite3D
		if anim.sprite_frames and anim.sprite_frames.has_animation(anim.animation):
			_material.set_shader_parameter(&"card_texture", anim.sprite_frames.get_frame_texture(anim.animation, anim.frame))
	elif _card is Sprite3D:
		_material.set_shader_parameter(&"card_texture", (_card as Sprite3D).texture)


func flash() -> void:
	if _card == null:
		return
	if _tween:
		_tween.kill()
	_card.modulate = _resting_modulate() * flash_color
	_tween = create_tween()
	_tween.tween_property(_card, "modulate", _resting_modulate(), flash_time)


func flash_white() -> void:
	flash_tint(white_flash_color, white_flash_strength, white_flash_time)


## Solid colour over the card that fades out (crits, boss move wind-ups). Needs the mob shader.
func flash_tint(color: Color, strength: float, time: float) -> void:
	if _material == null:
		return
	if _white_tween:
		_white_tween.kill()
	_material.set_shader_parameter(&"flash_color", color)
	_white_tween = create_tween()
	_white_tween.tween_method(func(v: float) -> void: _material.set_shader_parameter(&"flash_amount", v),
		strength, 0.0, time)


func set_greyed(on: bool) -> void:
	if _material:
		_material.set_shader_parameter(&"grey_amount", 1.0 if on else 0.0)
		return
	_greyed = on
	if _card and not (_tween and _tween.is_running()):
		_card.modulate = _resting_modulate()


func _resting_modulate() -> Color:
	return _base_modulate * grey_tint if _greyed else _base_modulate
