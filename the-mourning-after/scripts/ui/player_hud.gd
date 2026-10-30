class_name PlayerHUD
extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthBar
@onready var health_label: Label = $HealthBar/HealthLabel

var _stats: HeroStats


func bind_stats(stats: HeroStats) -> void:
	if _stats:
		_stats.health_change.disconnect(_on_health_change)
	_stats = stats
	_stats.health_change.connect(_on_health_change)
	_on_health_change(_stats.health, _stats.current_max_health)


func _on_health_change(cur_health: int, max_health: int) -> void:
	health_bar.max_value = max_health
	health_bar.value = cur_health
	health_label.text = "%d / %d" % [cur_health, max_health]
