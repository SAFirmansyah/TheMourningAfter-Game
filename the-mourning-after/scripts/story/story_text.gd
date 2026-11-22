class_name StoryText
extends CanvasLayer
## Black-screen text cutscene: each stanza's lines stream in one after another, as a left-aligned
## block in the middle of the screen. A click while streaming shows the whole stanza; once it's all
## there a hint shows and the next click moves on. Not skippable (the
## testing Skip button ends it through `skip()`).

@export var line_separation := 14 # TUNE: gap between lines (px)
@export var hint_delay := 0.4 # TUNE: pause after a stanza finishes before the hint appears (s)

@onready var lines_box: VBoxContainer = $Center/Lines
@onready var hint: Label = $Hint

var _advance := false
var _skipping := false
var _font: FontVariation


func _ready() -> void:
	hint.hide()
	lines_box.add_theme_constant_override(&"separation", line_separation)
	_font = FontVariation.new()
	_font.base_font = ThemeDB.fallback_font
	_font.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.2, 1.0), Vector2.ZERO) # italic


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"advance_dialogue") or event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		_advance = true


func skip() -> void:
	_skipping = true


func play(stanzas: Array) -> void:
	for stanza: PackedStringArray in stanzas:
		if _skipping:
			return
		for child in lines_box.get_children():
			child.queue_free()
		hint.hide()
		_advance = false
		var labels: Array[StreamedLabel] = []
		for text in stanza:
			var label := StreamedLabel.new()
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT # the block is centred; lines read from the left
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.custom_minimum_size = Vector2(1200, 0)
			label.add_theme_font_override(&"font", _font)
			label.add_theme_font_size_override(&"font_size", 34)
			label.add_theme_color_override(&"font_color", Color(0.92, 0.9, 0.85))
			label.text = text
			label.visible_characters = 0
			lines_box.add_child(label)
			labels.append(label)
		var hurry := false # advance pressed mid-stanza: show the rest of it at once
		for label in labels:
			if hurry:
				break
			label.stream(label.text)
			while label.is_streaming():
				if _skipping:
					return
				if _advance:
					_advance = false
					hurry = true
					break
				await get_tree().process_frame
		if hurry:
			for label in labels:
				label.skip()
				label.visible_characters = -1
		await _wait(hint_delay) # a click in here already counts as moving on
		hint.show()
		while not _advance and not _skipping:
			await get_tree().process_frame


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not _skipping and not _advance:
		await get_tree().process_frame
		if can_process():
			left -= get_process_delta_time()
