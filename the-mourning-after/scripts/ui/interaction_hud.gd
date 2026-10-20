class_name InteractionHUD
extends CanvasLayer
## Interact prompt and dialogue box for the nearest Interactable in range.

@export var player: Player
@export var more_marker := " >" # appended to pages that have a next page

@onready var prompt: Control = $Prompt
@onready var prompt_label: Label = $Prompt/Label
@onready var dialogue: Control = $Dialogue
@onready var dialogue_label: Label = $Dialogue/Label

var _target: Interactable
var _active: Interactable
var _page := 0


func _ready() -> void:
	prompt.hide()
	dialogue.hide()


func _process(_delta: float) -> void:
	if _active:
		return
	_target = _find_target()
	prompt.visible = _target != null
	if _target:
		prompt_label.text = "E - %s" % _target.prompt_label


func _unhandled_input(event: InputEvent) -> void:
	if _active:
		if event.is_action_pressed(&"advance_dialogue"):
			get_viewport().set_input_as_handled()
			_advance()
	elif _target and event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		_open(_target)


func is_open() -> bool:
	return _active != null


func _find_target() -> Interactable:
	if player == null or not player.input_enabled:
		return null
	var best: Interactable
	var best_dist := INF
	for node in get_tree().get_nodes_in_group(&"interactable"):
		var it := node as Interactable
		if it == null or not it.player_in_range or it.lines.is_empty():
			continue
		var dist := it.global_position.distance_squared_to(player.global_position)
		if dist < best_dist:
			best = it
			best_dist = dist
	return best


func _open(it: Interactable) -> void:
	_active = it
	_page = 0
	player.input_enabled = false
	player.forced_input = Vector2.ZERO
	prompt.hide()
	dialogue.show()
	_show_page()
	it.interacted.emit()


func _advance() -> void:
	_page += 1
	if _page >= _active.lines.size():
		_close()
	else:
		_show_page()


func _show_page() -> void:
	var text := _active.lines[_page]
	if _page < _active.lines.size() - 1:
		text += more_marker
	dialogue_label.text = text


func _close() -> void:
	var it := _active
	_active = null
	dialogue.hide()
	player.input_enabled = true
	it.finished.emit()
