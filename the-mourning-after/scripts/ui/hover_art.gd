class_name HoverArt
## Hand-drawn hover highlights: each time a button is hovered it gets a random brush stroke from the
## set (never the same one twice in a row), stretched behind its content.

const SELECTION: Array[Texture2D] = [
	preload("res://textures/ui/select hover/selection1.png"),
	preload("res://textures/ui/select hover/selection2.png"),
	preload("res://textures/ui/select hover/selection3.png"),
]
const ITEM_SELECTION: Array[Texture2D] = [
	preload("res://textures/ui/select hover/itemselection1.png"),
	preload("res://textures/ui/select hover/itemselection2.png"),
	preload("res://textures/ui/select hover/itemselection3.png"),
]


## Menu buttons (wide strokes) or item buttons (round blots); clears the flat normal/focus boxes.
static func apply(button: BaseButton, textures: Array[Texture2D] = SELECTION) -> void:
	var empty := StyleBoxEmpty.new()
	for state in [&"normal", &"focus", &"disabled"]:
		button.add_theme_stylebox_override(state, empty)
	_pick(button, textures)
	button.mouse_entered.connect(_pick.bind(button, textures))


static func _pick(button: BaseButton, textures: Array[Texture2D]) -> void:
	var last: int = button.get_meta(&"hover_art", -1)
	var index := randi() % textures.size()
	if textures.size() > 1 and index == last:
		index = (index + 1 + randi() % (textures.size() - 1)) % textures.size()
	button.set_meta(&"hover_art", index)
	var style := StyleBoxTexture.new()
	style.texture = textures[index]
	for state in [&"hover", &"pressed", &"hover_pressed"]:
		button.add_theme_stylebox_override(state, style)


## Icon buttons (the arrow, the checkmark): no brush; the icon grows a little on hover.
static func icon_button(button: Button, icon: Texture2D, size := Vector2(110, 58)) -> void:
	button.text = ""
	button.icon = icon
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = size
	var empty := StyleBoxEmpty.new()
	for state in [&"normal", &"focus", &"disabled", &"hover", &"pressed", &"hover_pressed"]:
		button.add_theme_stylebox_override(state, empty)
	button.mouse_entered.connect(_grow.bind(button, true))
	button.mouse_exited.connect(_grow.bind(button, false))


static func _grow(button: Button, over: bool) -> void:
	button.pivot_offset = button.size / 2.0
	button.create_tween().tween_property(button, "scale", Vector2.ONE * (1.2 if over and not button.disabled else 1.0), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT) # TUNE: hover size
