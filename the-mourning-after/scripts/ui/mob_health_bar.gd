class_name MobHealthBar
extends Node3D
## Small floating bar over a mob; stays hidden until the mob first takes damage.

@onready var _fill: Sprite3D = $Fill

var _stats: Stats
var _full_width := 0.0


func watch(stats: Stats) -> void:
	_stats = stats
	_full_width = _fill.region_rect.size.x
	hide()
	stats.damaged.connect(func(_amount: int) -> void:
		show()
		_refresh())
	stats.health_change.connect(func(_cur: int, _max: int) -> void: _refresh())


func _refresh() -> void:
	if _stats == null or _stats.current_max_health <= 0:
		return
	var frac := clampf(float(_stats.health) / _stats.current_max_health, 0.0, 1.0)
	_fill.region_rect.size.x = _full_width * frac
