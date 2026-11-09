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

var _card: Sprite3D
var _base_modulate := Color.WHITE
var _tween: Tween
var _white_tween: Tween
var _material: ShaderMaterial


func watch(stats: Stats, card: Sprite3D) -> void:
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
	_material.set_shader_parameter(&"card_texture", _card.texture)
	_card.material_override = _material


func flash() -> void:
	if _card == null:
		return
	if _tween:
		_tween.kill()
	_card.modulate = _base_modulate * flash_color
	_tween = create_tween()
	_tween.tween_property(_card, "modulate", _base_modulate, flash_time)


func flash_white() -> void:
	if _material == null:
		return
	if _white_tween:
		_white_tween.kill()
	_material.set_shader_parameter(&"flash_color", white_flash_color)
	_white_tween = create_tween()
	_white_tween.tween_method(func(v: float) -> void: _material.set_shader_parameter(&"flash_amount", v),
		white_flash_strength, 0.0, white_flash_time)


func set_greyed(on: bool) -> void:
	if _material:
		_material.set_shader_parameter(&"grey_amount", 1.0 if on else 0.0)
