class_name InteractionHUD
extends CanvasLayer
## Interact prompt, narration box and conversations for the nearest Interactable in range.
## The prompt can also be clicked instead of pressing E.
## hand_drawn (Constance's side): parchment text box with the name in its tab, the hand-drawn E prompt
## and caption, and an arrow when more lines follow; long captions continue across several boxes.
## The text box unfurls from the speaker's side when it opens or the speaker changes side.
## Story mode (StoryPlayer): scripted lines with Constance's portrait always on the left and the
## latest other speaker on the right, choices inside the text box, and a small note under the prompt.

@export var player: Player
@export var more_marker := " >" # appended to pages that have a next page
@export var overlay_alpha := 0.6 # TUNE: darkness of the scene behind conversations (0–1)
@export var overlay_fade_time := 0.25 # TUNE: overlay and portrait fade in/out (s)
@export var listener_dim := Color(0.45, 0.45, 0.45) # TUNE: tint of the portrait not speaking
@export var name_tag_inset := 48.0 # TUNE: name tag distance from the box's left/right edge (px)
@export var hand_drawn := false
@export var unfurl_time := 0.25 # TUNE: hand-drawn text box's unfurl from the speaker's side (s)

const HAND_TEXT := Color(0.24, 0.15, 0.09) # ink colour on the parchment
const HAND_TEXTBOX := preload("res://textures/ui/Textbox.png")
const HAND_ARROW := preload("res://textures/ui/arrow.png")
const HAND_PROMPT := preload("res://textures/ui/E_Prompt.png")
const HAND_CAPTION := preload("res://textures/ui/Caption.png")
# Where things sit on the art, as shares of its size (left, top, right, bottom).
const HAND_TEXTBOX_SIZE := Vector2(1180, 357) # TUNE: on-screen size of the text box art
const MAX_LINES := 2 # TUNE: lines per text box; longer lines carry on in the next box with "..."
const NAME_FONT_SIZE := 36 # TUNE: speaker name size in the tab (matches the text)
const NAME_MIN_FONT_SIZE := 22 # TUNE: smallest a long name shrinks to before wrapping
const HAND_TEXTBOX_NAME := Rect2(0.105, 0.045, 0.29, 0.255) # the upper tab, inside its drawn border (name centred in it)
const HAND_TEXTBOX_TEXT := Rect2(0.085, 0.3, 0.84, 0.5) # the main parchment (text centred in it)
const HAND_PROMPT_SIZE := Vector2(260, 80) # TUNE
const HAND_PROMPT_TEXT := Rect2(0.08, 0.2, 0.83, 0.56) # centred on the paper
const HAND_CAPTION_SIZE := Vector2(940, 106) # TUNE
const HAND_CAPTION_TEXT := Rect2(0.05, 0.18, 0.88, 0.6) # centred on the paper

@onready var overlay: ColorRect = $Overlay
@onready var portraits: Control = $Portraits
@onready var player_portrait: TextureRect = $Portraits/PlayerPortrait
@onready var character_portrait: TextureRect = $Portraits/CharacterPortrait
@onready var prompt: Control = $Prompt
@onready var prompt_label: Label = $Prompt/Label
@onready var dialogue: Control = $Dialogue
@onready var dialogue_label: StreamedLabel = $Dialogue/Box/Label
@onready var dialogue_box: PanelContainer = $Dialogue/Box
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
var _prompt_tween: Tween
var _arrow: TextureRect
var _line_parts := PackedStringArray() # the current story line, split into boxes of MAX_LINES
var _line_part := 0
var _arrow_x := 0.0 # where the arrow rests; it bobs to the right of this
var _hand_art: TextureRect
var _hand_text_style: StyleBoxEmpty
var _hand_left := true # which side the hand-drawn text box currently faces
var _box_closed := true # the text box has been hidden since it last unfurled
var _wipe: Control # clips the text box while it unfurls
var _wipe_holder: Control # keeps the box's contents still inside the moving clip
var _unfurl: Tween
var _has_more := false # the current line isn't the last of this stretch of dialogue
var _prompt_font_size := 26


func _ready() -> void:
	overlay.color = Color(0, 0, 0, overlay_alpha)
	name_label.add_theme_font_override(&"font", GameFonts.TITLE)
	for node: CanvasItem in [overlay, portraits, prompt, dialogue]:
		node.hide()
	_build_note()
	if hand_drawn:
		_apply_hand_drawn()
	prompt.mouse_filter = Control.MOUSE_FILTER_STOP
	prompt.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	prompt.gui_input.connect(_on_prompt_input)


## Portraits drift gently against the cursor (and breathe a touch); the one speaking moves more.
@export var portrait_drift := 6.0 # TUNE: listener's drift at the screen edge (px)
@export var portrait_drift_speaking := 16.0 # TUNE: speaker's drift (px)
var _portrait_home := {}
var _portrait_shift := {}


func _drift_portraits(delta: float) -> void:
	var view := get_viewport().get_visible_rect().size
	if view.x <= 0.0:
		return
	var cursor := (get_viewport().get_mouse_position() - view / 2.0) / (view / 2.0)
	cursor = cursor.clamp(-Vector2.ONE, Vector2.ONE)
	for rect: TextureRect in [player_portrait, character_portrait]:
		if not _portrait_home.has(rect) or not rect.visible:
			_portrait_home[rect] = Vector2(rect.offset_left, rect.offset_top)
			_portrait_shift[rect] = Vector2.ZERO
			continue
		var speaking := rect.self_modulate.is_equal_approx(Color.WHITE)
		var breath := Vector2(0.0, sin(Time.get_ticks_msec() / 900.0 + (0.0 if rect == player_portrait else 1.7)) * (3.0 if speaking else 1.0))
		var target := -cursor * (portrait_drift_speaking if speaking else portrait_drift) + breath
		_portrait_shift[rect] = (_portrait_shift[rect] as Vector2).lerp(target, 1.0 - exp(-5.0 * delta))
		var home: Vector2 = _portrait_home[rect]
		var size := Vector2(rect.offset_right - rect.offset_left, rect.offset_bottom - rect.offset_top)
		rect.offset_left = home.x + _portrait_shift[rect].x
		rect.offset_top = home.y + _portrait_shift[rect].y
		rect.offset_right = rect.offset_left + size.x
		rect.offset_bottom = rect.offset_top + size.y


func _process(_delta: float) -> void:
	_drift_portraits(_delta)
	if _arrow:
		var more := _has_more or (_story and _line_part + 1 < _line_parts.size())
		_arrow.visible = dialogue.visible and more and not dialogue_label.is_streaming() and _choice_box == null
		_arrow.position.x = _arrow_x + 3.0 + 3.0 * sin(Time.get_ticks_msec() / 1000.0 * TAU / 0.9)
	if _story:
		prompt.hide()
		return
	if _active:
		return
	_target = _find_target()
	if hand_drawn and _target != null and not prompt.visible:
		_pop_prompt()
	prompt.visible = _target != null
	if _target:
		prompt_label.text = "E - %s" % _target.prompt_label
		if hand_drawn:
			_fit_font(prompt_label, _prompt_font_size, HAND_PROMPT_SIZE.x * HAND_PROMPT_TEXT.size.x)


## Hand-drawn prompt: fades in with a slight grow (it hides instantly, so it never lingers clickable).
func _pop_prompt() -> void:
	prompt.pivot_offset = Vector2(prompt.size.x / 2.0, prompt.size.y)
	prompt.modulate.a = 0.0
	prompt.scale = Vector2.ONE * 0.94
	if _prompt_tween:
		_prompt_tween.kill()
	_prompt_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_prompt_tween.tween_property(prompt, "modulate:a", 1.0, 0.14)
	_prompt_tween.tween_property(prompt, "scale", Vector2.ONE, 0.14)


func _unhandled_input(event: InputEvent) -> void:
	if _story:
		if dialogue.visible and _choice_box == null and event.is_action_pressed(&"advance_dialogue"):
			get_viewport().set_input_as_handled()
			if dialogue_label.is_streaming():
				dialogue_label.skip()
			elif _line_part + 1 < _line_parts.size():
				_line_part += 1 # the rest of a long line
				dialogue_label.stream(_line_parts[_line_part])
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
		_set_name(player.display_name if by_player else _active.character_name)
		_place_name_tag(by_player)
		player_portrait.self_modulate = Color.WHITE if by_player else listener_dim
		character_portrait.self_modulate = listener_dim if by_player else Color.WHITE
	else:
		text = _active.lines[_page]
	_has_more = _page < _active.page_count() - 1
	if _has_more and not hand_drawn:
		text += more_marker
	dialogue_label.stream(text)


func _close() -> void:
	var it := _active
	_active = null
	dialogue.hide()
	_box_closed = true
	if it.is_conversation():
		_fade_conversation(false)
	player.input_enabled = true
	it.finished.emit()


## Hand-drawn: names too wide for the tab shrink, then wrap onto two lines (breaking after commas
## first, e.g. "Archi, Seira, Kano").
func _set_name(speaker: String) -> void:
	name_label.text = speaker
	if not hand_drawn:
		return
	var font := name_label.get_theme_font(&"font")
	var width := HAND_TEXTBOX_NAME.size.x * HAND_TEXTBOX_SIZE.x - 24.0
	var height := HAND_TEXTBOX_NAME.size.y * HAND_TEXTBOX_SIZE.y
	var size := NAME_FONT_SIZE
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	while size > NAME_MIN_FONT_SIZE and font.get_string_size(speaker, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 2
	if font.get_string_size(speaker, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		# two lines: break after the comma nearest the middle, else let it word-wrap
		var cut := -1
		var commas := []
		for i in speaker.length():
			if speaker[i] == ",":
				commas.append(i)
		for i: int in commas:
			if cut < 0 or absi(i - speaker.length() / 2) < absi(cut - speaker.length() / 2):
				cut = i
		size = NAME_FONT_SIZE
		var text := speaker.substr(0, cut + 1) + "\n" + speaker.substr(cut + 1).strip_edges() if cut >= 0 else speaker
		while size > NAME_MIN_FONT_SIZE and (_widest_line(text, font, size) > width or font.get_height(size) * 2.0 > height):
			size -= 2
		name_label.text = text
		if cut < 0:
			name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override(&"font_size", size)


func _widest_line(text: String, font: Font, size: int) -> float:
	var widest := 0.0
	for line in text.split("\n"):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	return widest


func _place_name_tag(left: bool) -> void:
	if hand_drawn:
		_set_hand_side(left)
		return
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
func story_line(speaker_name: String, key: String, left: bool, tex: Texture2D, text: String, show_portrait := true, has_more := false) -> void:
	_story_advance = false
	_has_more = has_more
	_line_parts = _fit_lines(text, dialogue_label, _line_width(), MAX_LINES) if hand_drawn else PackedStringArray([text])
	_line_part = 0
	_set_hand_side(left)
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
	_set_name(speaker_name)
	_place_name_tag(left)
	dialogue_label.stream(_line_parts[0])


## True once the current line has been read and advanced past.
func story_line_done() -> bool:
	return _story_advance


func story_hide_box() -> void:
	_box_closed = true
	if dialogue.visible or overlay.visible:
		dialogue.hide()
		_fade_conversation(false)


## Puts the options in the text box (Constance choosing); story_choice_result() is -1 until one is picked.
func story_choice(options: Array) -> void:
	_choice_result = -1
	_set_hand_side(true)
	dialogue.show()
	name_tag.show()
	_set_name("Constance")
	_place_name_tag(true)
	player_portrait.self_modulate = Color.WHITE
	character_portrait.self_modulate = listener_dim
	dialogue_label.hide()
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override(&"separation", 12)
	_choice_box.alignment = BoxContainer.ALIGNMENT_CENTER
	dialogue_box.add_child(_choice_box)
	for i in options.size():
		var button := Button.new()
		button.text = "> " + String(options[i].text)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override(&"font_size", 34)
		if hand_drawn:
			HoverArt.apply(button)
			for state: StringName in [&"font_color", &"font_focus_color", &"font_pressed_color"]:
				button.add_theme_color_override(state, HAND_TEXT)
			button.add_theme_color_override(&"font_hover_color", Color(0.6, 0.2, 0.1))
			button.add_theme_color_override(&"font_focus_color", Color(0.6, 0.2, 0.1))
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


## Small caption box: fades in, types the text, holds, fades out. With the hand-drawn caption (which
## can't grow), text too long for it is cut with "..." and carries on in the next box.
func show_note(text: String, seconds: float) -> void:
	var parts := PackedStringArray([text])
	if hand_drawn:
		parts = _fit_parts(text, _note_label, HAND_CAPTION_SIZE.x * HAND_CAPTION_TEXT.size.x)
	_note.modulate.a = 0.0
	_note.show()
	if _note_tween:
		_note_tween.kill()
	_note_tween = create_tween()
	_note_tween.tween_property(_note, "modulate:a", 1.0, 0.2)
	for part in parts:
		_note_tween.tween_callback(_note_label.stream.bind(part))
		_note_tween.tween_interval(maxf(seconds - 0.4, 0.6))
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
	_note_label.add_theme_font_size_override(&"font_size", 30)
	_note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note.add_child(_note_label)
	_note.hide()
	add_child(_note)


# --- Hand-drawn UI (Constance's side) --------------------------------------------------------------

func _apply_hand_drawn() -> void:
	# Text box: parchment art behind everything, name in the tab, line in the main parchment.
	dialogue.offset_left = -HAND_TEXTBOX_SIZE.x / 2.0
	dialogue.offset_right = HAND_TEXTBOX_SIZE.x / 2.0
	dialogue.offset_bottom = -100.0
	dialogue.offset_top = dialogue.offset_bottom - HAND_TEXTBOX_SIZE.y
	var art := TextureRect.new()
	art.name = "Art"
	art.texture = HAND_TEXTBOX
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialogue.add_child(art)
	dialogue.move_child(art, 0)
	_hand_art = art
	var text_box := StyleBoxEmpty.new()
	_hand_text_style = text_box
	var t := HAND_TEXTBOX_TEXT
	text_box.content_margin_left = t.position.x * HAND_TEXTBOX_SIZE.x
	text_box.content_margin_top = t.position.y * HAND_TEXTBOX_SIZE.y
	text_box.content_margin_right = (1.0 - t.end.x) * HAND_TEXTBOX_SIZE.x
	text_box.content_margin_bottom = (1.0 - t.end.y) * HAND_TEXTBOX_SIZE.y
	dialogue_box.add_theme_stylebox_override(&"panel", text_box)
	dialogue_label.add_theme_color_override(&"font_color", HAND_TEXT)
	dialogue_label.add_theme_font_size_override(&"font_size", 36)
	dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT # streams from the left edge
	var n := HAND_TEXTBOX_NAME
	name_tag.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	name_tag.anchor_left = 0.0
	name_tag.anchor_right = 0.0
	name_tag.offset_left = n.position.x * HAND_TEXTBOX_SIZE.x
	name_tag.offset_right = n.end.x * HAND_TEXTBOX_SIZE.x
	name_tag.offset_top = n.position.y * HAND_TEXTBOX_SIZE.y
	name_tag.offset_bottom = n.end.y * HAND_TEXTBOX_SIZE.y
	name_label.add_theme_color_override(&"font_color", HAND_TEXT)
	name_label.add_theme_font_size_override(&"font_size", NAME_FONT_SIZE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Arrow at the bottom-right of the parchment, bobbing, while more lines follow.
	_arrow = TextureRect.new()
	_arrow.texture = HAND_ARROW
	_arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.size = Vector2(64, 49) # TUNE: arrow size
	_arrow.position.y = t.end.y * HAND_TEXTBOX_SIZE.y - 42.0 # TUNE: arrow height
	_arrow.hide()
	dialogue.add_child(_arrow)
	# Everything goes in a clip that grows from the speaker's side as the box unfurls.
	_wipe = Control.new()
	_wipe.name = "Unfurl"
	_wipe.clip_contents = true
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wipe.size = HAND_TEXTBOX_SIZE
	dialogue.add_child(_wipe)
	_wipe_holder = Control.new()
	_wipe_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wipe_holder.size = HAND_TEXTBOX_SIZE
	_wipe.add_child(_wipe_holder)
	for part: Control in [art, dialogue_box, name_tag, _arrow]:
		part.reparent(_wipe_holder, false)
	_set_hand_side(true)
	_set_wipe(1.0)
	_box_closed = true
	# E prompt on its tag (fixed size; the text shrinks to fit).
	prompt.add_theme_stylebox_override(&"panel", _art_style(HAND_PROMPT, HAND_PROMPT_SIZE, HAND_PROMPT_TEXT))
	prompt.custom_minimum_size = HAND_PROMPT_SIZE
	prompt.offset_left = -HAND_PROMPT_SIZE.x / 2.0
	prompt.offset_right = HAND_PROMPT_SIZE.x / 2.0
	prompt.offset_bottom = -84.0
	prompt.offset_top = prompt.offset_bottom - HAND_PROMPT_SIZE.y
	prompt_label.clip_text = true
	prompt_label.add_theme_color_override(&"font_color", HAND_TEXT)
	_prompt_font_size = 28
	# Caption on its strip (fixed size).
	_note.add_theme_stylebox_override(&"panel", _art_style(HAND_CAPTION, HAND_CAPTION_SIZE, HAND_CAPTION_TEXT))
	_note.custom_minimum_size = HAND_CAPTION_SIZE
	_note.offset_left = -HAND_CAPTION_SIZE.x / 2.0
	_note.offset_right = HAND_CAPTION_SIZE.x / 2.0
	_note.offset_bottom = prompt.offset_top - 6.0
	_note.offset_top = _note.offset_bottom - HAND_CAPTION_SIZE.y
	_note_label.clip_text = true
	_note_label.add_theme_color_override(&"font_color", HAND_TEXT)


## The speaker's side: on the right, the text box art is mirrored and its tab and text area follow.
func _set_hand_side(left: bool) -> void:
	if not hand_drawn or _hand_art == null:
		return
	var unfurl := _box_closed or left != _hand_left
	_hand_left = left
	_box_closed = false
	_hand_art.flip_h = not left
	var width := HAND_TEXTBOX_SIZE.x
	var n := HAND_TEXTBOX_NAME
	var name_left := n.position.x if left else 1.0 - n.end.x
	name_tag.offset_left = name_left * width
	name_tag.offset_right = (name_left + n.size.x) * width
	var t := HAND_TEXTBOX_TEXT
	var text_left := t.position.x if left else 1.0 - t.end.x
	_hand_text_style.content_margin_left = text_left * width
	_hand_text_style.content_margin_right = (1.0 - text_left - t.size.x) * width
	_arrow_x = (text_left + t.size.x) * width - 44.0
	if unfurl:
		if _unfurl:
			_unfurl.kill()
		_set_wipe(0.0)
		_unfurl = create_tween()
		_unfurl.tween_method(_set_wipe, 0.0, 1.0, unfurl_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## How much of the text box shows (0-1), unrolled from the speaker's side.
func _set_wipe(amount: float) -> void:
	var width := HAND_TEXTBOX_SIZE.x * amount
	_wipe.size = Vector2(width, HAND_TEXTBOX_SIZE.y)
	_wipe.position.x = 0.0 if _hand_left else HAND_TEXTBOX_SIZE.x - width
	_wipe_holder.position.x = -_wipe.position.x


## A fixed-size art panel whose content area is `text` (shares of the art's size).
func _art_style(texture: Texture2D, art_size: Vector2, text: Rect2) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.content_margin_left = text.position.x * art_size.x
	style.content_margin_top = text.position.y * art_size.y
	style.content_margin_right = (1.0 - text.end.x) * art_size.x
	style.content_margin_bottom = (1.0 - text.end.y) * art_size.y
	return style


## Shrinks a label's font until its one line fits the width.
func _fit_font(label: Label, largest: int, width: float) -> void:
	var font := label.get_theme_font(&"font")
	var font_size := largest
	while font_size > 12 and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		font_size -= 1
	label.add_theme_font_size_override(&"font_size", font_size)


## Splits text into one-line parts that fit the width, each but the last ending in "...".
func _line_width() -> float:
	return HAND_TEXTBOX_TEXT.size.x * HAND_TEXTBOX_SIZE.x


## Word-wraps `text` at `width` and groups the lines `max_lines` to a box; every box but the last ends
## with "..." (counted in its width).
func _fit_lines(text: String, label: Label, width: float, max_lines: int) -> PackedStringArray:
	var font := label.get_theme_font(&"font")
	var font_size := label.get_theme_font_size(&"font_size")
	var fits := func(line: String) -> bool: return font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width
	var boxes := PackedStringArray()
	var lines := PackedStringArray()
	var line := ""
	var words := text.split(" ", false)
	for i in words.size():
		var candidate: String = words[i] if line.is_empty() else line + " " + words[i]
		var last_line_of_box := lines.size() == max_lines - 1
		var needed: String = candidate + "..." if last_line_of_box and i < words.size() - 1 else candidate
		if not line.is_empty() and not fits.call(needed):
			lines.append(line)
			line = words[i]
			if lines.size() == max_lines:
				boxes.append(" ".join(lines) + "...")
				lines.clear()
		else:
			line = candidate
	if not line.is_empty():
		lines.append(line)
	if not lines.is_empty():
		boxes.append(" ".join(lines))
	return boxes


func _fit_parts(text: String, label: Label, width: float) -> PackedStringArray:
	var font := label.get_theme_font(&"font")
	var font_size := label.get_theme_font_size(&"font_size")
	var fits := func(line: String) -> bool: return font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width
	var parts := PackedStringArray()
	var line := ""
	for word in text.split(" ", false):
		var candidate := word if line.is_empty() else line + " " + word
		if not line.is_empty() and not fits.call(candidate + "..."):
			parts.append(line + "...")
			line = word
		else:
			line = candidate
	if not line.is_empty():
		parts.append(line)
	return parts
