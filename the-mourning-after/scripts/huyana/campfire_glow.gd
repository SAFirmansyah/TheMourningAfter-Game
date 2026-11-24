@tool
class_name CampfireGlow
extends Node3D
## The campfire's flames burn only at night, and light a flickering warm pool around the fire through
## the night overlay (the scene's cards are unshaded, so the light lives in that screen shader).

@export var fire: Sprite3D # the animated flame layer
@export var light_radius := 5.0 # TUNE: reach of the firelight on the ground (m)
@export var light_strength := 1.0 # TUNE: brightness of the firelight (0-1)
@export var flicker := 0.18 # TUNE: how much the light wavers
@export var flicker_speed := 7.0 # TUNE: how fast it wavers
@export var lit_from := 0.15 # TUNE: night darkness (0-1) at which the fire lights

var _manager: SanctuaryManager
var _time := 0.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		_manager = get_tree().get_first_node_in_group(&"sanctuary_manager")


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		_set_light(Vector2.ZERO, 0.0, 0.0)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _manager == null:
		return
	_time += delta
	var night := _manager.day_cycle.night_amount()
	var lit := night >= lit_from
	if fire:
		fire.visible = lit
	var cam := get_viewport().get_camera_3d()
	if not lit or cam == null or cam.is_position_behind(global_position):
		_set_light(Vector2.ZERO, 0.0, 0.0)
		return
	var screen := get_viewport().get_visible_rect().size
	var centre := cam.unproject_position(global_position)
	var edge := cam.unproject_position(global_position + cam.global_basis.x * light_radius)
	var waver := 1.0 - flicker * (0.5 + 0.5 * sin(_time * flicker_speed) * sin(_time * flicker_speed * 1.7 + 1.3))
	var fade := clampf((night - lit_from) / (1.0 - lit_from), 0.0, 1.0)
	_set_light(centre / screen, centre.distance_to(edge) / screen.y, light_strength * waver * fade)


func _set_light(uv: Vector2, radius: float, strength: float) -> void:
	var material := _manager.day_cycle.night_shade.material as ShaderMaterial if _manager else null
	if material == null:
		return
	material.set_shader_parameter("light_uv", uv)
	material.set_shader_parameter("light_radius", radius)
	material.set_shader_parameter("light_strength", strength)
