@tool
class_name NarrativeBeat
extends Interactable
## Campfire spot for each night's narrative beat. Once the night's results (and any story event) are
## done, a bubble pops up over the fire; talking there plays the beat for the current Sanctuary Health
## band (95+, 90-95, 85-90, ...), and the next day starts when it ends.

@export var bubble_height := 4.6 # TUNE: height of the bubble's tip above the campfire (m)
@export var health_band := 5.0 # TUNE: width of each narrative beat's health range (%)
@export var pop_in_time := 0.35 # TUNE: bubble grow-in (s)

@onready var bubble: Control = $Bubble/View

var _manager: SanctuaryManager
var _shown := false


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	prompt_label = "Reflect"
	_manager = get_tree().get_first_node_in_group(&"sanctuary_manager")
	bubble.hide()
	interacted.connect(_on_interacted)
	finished.connect(_on_finished)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var waiting := _manager != null and _manager.day_cycle.awaiting_beat
	enabled = waiting
	if waiting != _shown:
		_shown = waiting
		bubble.visible = waiting
		if waiting:
			bubble.scale = Vector2.ZERO
			create_tween().tween_property(bubble, "scale", Vector2.ONE, pop_in_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var cam := get_viewport().get_camera_3d()
	var anchor := global_position + Vector3(0.0, bubble_height, 0.0)
	if _shown and cam and not cam.is_position_behind(anchor):
		bubble.position = cam.unproject_position(anchor) - bubble.pivot_offset


## Lower edge of the health band the beat belongs to (95 covers 95-100).
func band(health: float) -> int:
	return int(minf(floorf(health / health_band) * health_band, 100.0 - health_band))


func _on_interacted() -> void:
	var line := DialogueLine.new()
	line.speaker = DialogueLine.Speaker.PLAYER
	line.text = "Dummy narrative beat for %d%%" % roundi(_manager.health)
	conversation = [line]


func _on_finished() -> void:
	conversation = []
	_manager.day_cycle.start_day()
