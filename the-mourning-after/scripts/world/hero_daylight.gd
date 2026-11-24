class_name HeroDaylight
extends CanvasLayer
## Perrin's side day and night: the light drifts slowly from day through a golden dusk to a mild night
## and back, on a loop (no sudden switch). Shadows follow the sun outdoors; rooms with static shadows
## (the base) override them.

@export var cycle_length := 600.0 # TUNE: one full day and night (s)
@export_range(0.0, 1.0) var max_darkness := 0.55 # TUNE: how dark the night gets (1 = as dark as Huyana's)
@export var shadow_opacity := 0.35 # TUNE: shadow darkness at noon

@onready var shade: ColorRect = $Shade

var _time := 0.0


func _process(delta: float) -> void:
	_time = fmod(_time + delta, cycle_length)
	var p := _time / cycle_length # 0 = morning
	var night := 0.5 - 0.5 * cos(TAU * clampf((p - 0.35) / 0.65, 0.0, 1.0)) # day holds, then a long dusk-night-dawn
	var material := shade.material as ShaderMaterial
	material.set_shader_parameter("amount", night * max_darkness)
	material.set_shader_parameter("warmth", clampf(1.0 - absf(night - 0.3) / 0.3, 0.0, 1.0) * (1.0 if p < 0.7 else 0.5))
	var sun := lerpf(-0.9, 0.9, clampf(p / 0.6, 0.0, 1.0))
	RenderingServer.global_shader_parameter_set(&"sun_shadow_dir", Vector2(sun, -1.0).normalized())
	RenderingServer.global_shader_parameter_set(&"sun_shadow_alpha", shadow_opacity * (1.0 - night))
