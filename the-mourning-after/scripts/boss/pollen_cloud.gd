class_name PollenCloud
extends Node3D
## A puff of pollen that swells and fades (Gwenith vanishing or reappearing).

@export var lifetime := 1.2 # TUNE (s)

@onready var cloud: MeshInstance3D = $Cloud
@onready var sprite: AnimatedSprite3D = $Sprite

var _age := 0.0

func _ready() -> void:
	sprite.play("cloud")

func _physics_process(delta: float) -> void:
	_age += delta
	var t := clampf(_age / lifetime, 0.0, 1.0)
	cloud.scale = Vector3.ONE * lerpf(0.6, 1.4, t)
	cloud.transparency = lerpf(0.2, 1.0, t)
	if t >= 1.0:
		queue_free()
