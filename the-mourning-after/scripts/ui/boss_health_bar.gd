class_name BossHealthBar
extends CanvasLayer
## Boss name and health along the top of the screen; appears when the fight starts.

@onready var name_label: Label = $Panel/Content/Name
@onready var bar: ProgressBar = $Panel/Content/Bar

var _stats: Stats


func _ready() -> void:
	hide()


func bind(boss: Boss) -> void:
	_stats = boss.stats
	name_label.text = boss.display_name
	_stats.health_change.connect(func(_cur: int, _max: int) -> void: _refresh())
	_refresh()


func reveal() -> void:
	_refresh()
	show()


func _refresh() -> void:
	if _stats == null:
		return
	bar.max_value = maxi(_stats.current_max_health, 1)
	bar.value = _stats.health
