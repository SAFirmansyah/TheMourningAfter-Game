class_name InteractionHUD
extends CanvasLayer
## Interact prompt, narration box and conversations for the nearest Interactable in range.

@export var player: Player
@export var more_marker := " >" # appended to pages that have a next page
@export var overlay_alpha := 0.6 # TUNE: darkness of the scene behind conversations (0–1)
@export var overlay_fade_time := 0.25 # TUNE: overlay and portrait fade in/out (s)
@export var listener_dim := Color(0.45, 0.45, 0.45) # TUNE: tint of the portrait not speaking
@export var name_tag_inset := 48.0 # TUNE: name tag distance from the box's left/right edge (px)

@onready var overlay: ColorRect = $Overlay
@onready var portraits: Control = $Portraits
@onready var player_portrait: TextureRect = $Portraits/PlayerPortrait
@onready var character_portrait: TextureRect = $Portraits/CharacterPortrait
@onready var prompt: Control = $Prompt
@onready var prompt_label: Label = $Prompt/Label
@onready var dialogue: Control = $Dialogue
@onready var dialogue_label: StreamedLabel = $Dialogue/Box/Label
@onready var name_tag: Control = $Dialogue/NameTag
@onready var name_label: Label = $Dialogue/NameTag/Label

var _target: Interactable
var _active: Interactable
var _page := 0
var _fade: Tween


func _ready() -> void:
	overlay.color = Color(0, 0, 0, overlay_alpha)
	for node: CanvasItem in [overlay, portraits, prompt, dialogue]:
		node.hide()


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
		if it == null or not it.enabled or not it.player_in_range:
			continue
		var dist := it.global_position.distance_squared_to(player.global_position)
		if dist < best_dist:
			best = it
			best_dist = dist
	return best


func _open(it: Interactable) -> void:
	get_tree().call_group(&"world", &"mark_unsaved")
	it.interacted.emit()
	if it.page_count() == 0:
		return
	_active = it
	_page = 0
	player.input_enabled = false
	player.forced_input = Vector2.ZERO
	prompt.hide()
	dialogue.show()
	name_tag.visible = it.is_conversation()
	if it.is_conversation():
		_set_portrait(player_portrait, player.portrait, player.card)
		_set_portrait(character_portrait, it.character_portrait, null, it.character_portrait_tint)
		_fade_conversation(true)
	_show_page()


func _advance() -> void:
	if dialogue_label.is_streaming():
		dialogue_label.skip()
		return
	_page += 1
	if _page >= _active.page_count():
		_close()
	else:
		_show_page()


func _show_page() -> void:
	var text: String
	if _active.is_conversation():
		var line := _active.conversation[_page]
		text = line.text
		var by_player := line.speaker == DialogueLine.Speaker.PLAYER
		name_label.text = player.display_name if by_player else _active.character_name
		_place_name_tag(by_player)
		player_portrait.self_modulate = Color.WHITE if by_player else listener_dim
		character_portrait.self_modulate = listener_dim if by_player else Color.WHITE
	else:
		text = _active.lines[_page]
	if _page < _active.page_count() - 1:
		text += more_marker
	dialogue_label.stream(text)


func _close() -> void:
	var it := _active
	_active = null
	dialogue.hide()
	if it.is_conversation():
		_fade_conversation(false)
	player.input_enabled = true
	it.finished.emit()


func _place_name_tag(left: bool) -> void:
	var anchor := 0.0 if left else 1.0
	var x := name_tag_inset if left else -name_tag_inset
	name_tag.anchor_left = anchor
	name_tag.anchor_right = anchor
	name_tag.offset_left = x
	name_tag.offset_right = x
	name_tag.grow_horizontal = Control.GROW_DIRECTION_END if left else Control.GROW_DIRECTION_BEGIN


func _set_portrait(rect: TextureRect, tex: Texture2D, card: Sprite3D, tint := Color.WHITE) -> void:
	if tex == null and card:
		tex = card.texture
		tint = card.modulate
	rect.texture = tex
	rect.modulate = tint


func _fade_conversation(fade_in: bool) -> void:
	if _fade:
		_fade.kill()
	if fade_in and not overlay.visible:
		overlay.modulate.a = 0.0
		portraits.modulate.a = 0.0
	if fade_in:
		overlay.show()
		portraits.show()
	_fade = create_tween().set_parallel()
	var alpha := 1.0 if fade_in else 0.0
	_fade.tween_property(overlay, "modulate:a", alpha, overlay_fade_time)
	_fade.tween_property(portraits, "modulate:a", alpha, overlay_fade_time)
	if not fade_in:
		_fade.chain().tween_callback(func() -> void:
			overlay.hide()
			portraits.hide())
