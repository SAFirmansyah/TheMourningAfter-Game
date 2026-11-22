class_name InteractionHUD
extends CanvasLayer
## Interact prompt, narration box and conversations for the nearest Interactable in range.
## The prompt can also be clicked instead of pressing E.
## Story mode (StoryPlayer): scripted lines with Constance's portrait always on the left and the
## latest other speaker on the right, choices inside the text box, and a small note under the prompt.

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

var _story := false
var _story_advance := false
var _right_key := ""
var _choice_box: VBoxContainer
var _choice_result := -1
var _note: PanelContainer
var _note_label: StreamedLabel
var _note_tween: Tween


func _ready() -> void:
	overlay.color = Color(0, 0, 0, overlay_alpha)
	for node: CanvasItem in [overlay, portraits, prompt, dialogue]:
		node.hide()
	_build_note()
	prompt.mouse_filter = Control.MOUSE_FILTER_STOP
	prompt.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	prompt.gui_input.connect(_on_prompt_input)


func _process(_delta: float) -> void:
	if _story:
		prompt.hide()
		return
	if _active:
		return
	_target = _find_target()
	prompt.visible = _target != null
	if _target:
		prompt_label.text = "E - %s" % _target.prompt_label


func _unhandled_input(event: InputEvent) -> void:
	if _story:
		if dialogue.visible and _choice_box == null and event.is_action_pressed(&"advance_dialogue"):
			get_viewport().set_input_as_handled()
			if dialogue_label.is_streaming():
				dialogue_label.skip()
			else:
				_story_advance = true
		return
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


## A real portrait only: no portrait art means nobody shown on that side.
func _set_portrait(rect: TextureRect, tex: Texture2D, _card: Sprite3D = null, _tint := Color.WHITE) -> void:
	rect.texture = tex
	rect.modulate = Color.WHITE
	rect.visible = tex != null


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


# --- Story mode (StoryPlayer) ----------------------------------------------------------------------

func story_begin() -> void:
	_story = true
	_right_key = ""
	prompt.hide()
	dialogue.hide()
	story_clear_portraits()


## The right-hand speaker has left the scene.
func story_clear_right(key: String) -> void:
	if key == _right_key:
		_right_key = ""
		character_portrait.texture = null
		character_portrait.hide()


## Nobody on either side until they speak (new scene, or a cut to another room).
func story_clear_portraits() -> void:
	_right_key = ""
	for rect: TextureRect in [player_portrait, character_portrait]:
		rect.texture = null
		rect.hide()


func story_end() -> void:
	story_hide_box()
	_story = false


## Shows one scripted line and starts streaming it. `left` is Constance; `show_portrait` false hides
## her portrait (off-screen). A side with no portrait art shows nobody.
func story_line(speaker_name: String, key: String, left: bool, tex: Texture2D, text: String, show_portrait := true) -> void:
	_story_advance = false
	if left:
		_set_portrait(player_portrait, tex if show_portrait else null)
	else:
		_right_key = key
		_set_portrait(character_portrait, tex)
	player_portrait.self_modulate = Color.WHITE if left else listener_dim
	character_portrait.self_modulate = listener_dim if left else Color.WHITE
	if not overlay.visible or overlay.modulate.a < 1.0:
		_fade_conversation(true)
	dialogue.show()
	name_tag.show()
	name_label.text = speaker_name
	_place_name_tag(left)
	dialogue_label.stream(text)


## True once the current line has been read and advanced past.
func story_line_done() -> bool:
	return _story_advance


func story_hide_box() -> void:
	if dialogue.visible or overlay.visible:
		dialogue.hide()
		_fade_conversation(false)


## Puts the options in the text box (Constance choosing); story_choice_result() is -1 until one is picked.
func story_choice(options: Array) -> void:
	_choice_result = -1
	dialogue.show()
	name_tag.show()
	name_label.text = "Constance"
	_place_name_tag(true)
	player_portrait.self_modulate = Color.WHITE
	character_portrait.self_modulate = listener_dim
	dialogue_label.hide()
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override(&"separation", 12)
	_choice_box.alignment = BoxContainer.ALIGNMENT_CENTER
	$Dialogue/Box.add_child(_choice_box)
	for i in options.size():
		var button := Button.new()
		button.text = "> " + String(options[i].text)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override(&"font_size", 30)
		button.mouse_entered.connect(button.grab_focus)
		button.pressed.connect(func() -> void: _choice_result = i)
		_choice_box.add_child(button)
	(_choice_box.get_child(0) as Button).grab_focus()


func story_choice_result() -> int:
	if _choice_result >= 0 and _choice_box:
		_choice_box.queue_free()
		_choice_box = null
		dialogue_label.show()
	return _choice_result


## Clicking the "E - ..." prompt does the same as pressing E (and doesn't also swing a sword).
func _on_prompt_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and _target and not _active and not _story:
		prompt.accept_event()
		_open(_target)


## Small caption box (the old cutscene caption style): fades in, types the text, holds, fades out.
func show_note(text: String, seconds: float) -> void:
	_note.modulate.a = 0.0
	_note.show()
	_note_label.stream(text)
	if _note_tween:
		_note_tween.kill()
	_note_tween = create_tween()
	_note_tween.tween_property(_note, "modulate:a", 1.0, 0.2)
	_note_tween.tween_interval(maxf(seconds - 0.4, 0.0))
	_note_tween.tween_property(_note, "modulate:a", 0.0, 0.2)
	_note_tween.tween_callback(_note.hide)


func _build_note() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.09, 0.85)
	style.border_color = Color(0.78, 0.66, 0.38, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	_note = PanelContainer.new()
	_note.add_theme_stylebox_override(&"panel", style)
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_note.offset_left = -120.0
	_note.offset_right = 120.0
	_note.offset_top = -236.0 # original caption size, raised above the prompt
	_note.offset_bottom = -180.0
	_note.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_note.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_note_label = StreamedLabel.new()
	_note_label.add_theme_font_size_override(&"font_size", 26)
	_note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note.add_child(_note_label)
	_note.hide()
	add_child(_note)


