class_name RequestCatalog
extends RefCounted
## Everything that can be requested or ordered: display name, placeholder icon, whose station supplies it,
## and Shuyi's recipes.

enum Kind { FOOD, MEDICINE, REPAIR, INGREDIENT }

const REPAIR := &"repair"
const FOODS: Array[StringName] = [&"infused_dew", &"willow_bark", &"graceroot"]
const MEDICINES: Array[StringName] = [&"capillanyx", &"haemoshear", &"nacrescorch"]
const INGREDIENTS: Array[StringName] = [&"bloodflower", &"obsidian_grass", &"pearls_of_night"]
const RECIPES := {
	&"haemoshear": [&"bloodflower", &"obsidian_grass"],
	&"nacrescorch": [&"obsidian_grass", &"pearls_of_night"],
	&"capillanyx": [&"pearls_of_night", &"bloodflower"],
}

const FARMER_COLOR := Color(0.3, 0.62, 0.3)
const MEDIC_COLOR := Color(0.28, 0.45, 0.8)
const REPAIR_COLOR := Color(0.48, 0.48, 0.52)

const ITEMS := {
	&"infused_dew": {"name": "Infused Dew", "initials": "ID", "kind": Kind.FOOD, "color": FARMER_COLOR, "source": "Gwenith (Farmer)"},
	&"willow_bark": {"name": "Willow Bark", "initials": "WB", "kind": Kind.FOOD, "color": FARMER_COLOR, "source": "Gwenith (Farmer)"},
	&"graceroot": {"name": "Graceroot", "initials": "GR", "kind": Kind.FOOD, "color": FARMER_COLOR, "source": "Gwenith (Farmer)"},
	&"bloodflower": {"name": "Bloodflower", "initials": "BF", "kind": Kind.INGREDIENT, "color": FARMER_COLOR, "source": "Gwenith (Farmer)"},
	&"obsidian_grass": {"name": "Obsidian Grass", "initials": "OG", "kind": Kind.INGREDIENT, "color": FARMER_COLOR, "source": "Gwenith (Farmer)"},
	&"pearls_of_night": {"name": "Pearls of Night", "initials": "PN", "kind": Kind.INGREDIENT, "color": FARMER_COLOR, "source": "Gwenith (Farmer)"},
	&"capillanyx": {"name": "Capillanyx", "initials": "CX", "kind": Kind.MEDICINE, "color": MEDIC_COLOR, "source": "Shuyi (Medic)"},
	&"haemoshear": {"name": "Haemoshear", "initials": "HS", "kind": Kind.MEDICINE, "color": MEDIC_COLOR, "source": "Shuyi (Medic)"},
	&"nacrescorch": {"name": "Nacrescorch", "initials": "NC", "kind": Kind.MEDICINE, "color": MEDIC_COLOR, "source": "Shuyi (Medic)"},
	&"repair": {"name": "Repair", "initials": "RP", "kind": Kind.REPAIR, "color": REPAIR_COLOR, "source": "Rudrama (Guard)"},
}


## Item art (textures/resources); repairs (no art) use a gear.
## Each picture sits in a large canvas; ICON_BOUNDS is the drawn part (as shares of the canvas).
const ICON_BOUNDS := {
	&"infused_dew": Rect2(0.236, 0.0, 0.528, 1.0),
	&"willow_bark": Rect2(0.055, 0.0, 0.891, 1.0),
	&"graceroot": Rect2(0.33, 0.0, 0.341, 1.0),
	&"bloodflower": Rect2(0.0, 0.08, 1.0, 0.84),
	&"obsidian_grass": Rect2(0.378, 0.0, 0.245, 1.0),
	&"pearls_of_night": Rect2(0.0, 0.052, 1.0, 0.897),
	&"haemoshear": Rect2(0.188, 0.0, 0.624, 1.0),
	&"nacrescorch": Rect2(0.188, 0.0, 0.624, 1.0),
	&"capillanyx": Rect2(0.188, 0.0, 0.624, 1.0),
}
const ICONS := {
	&"infused_dew": preload("res://textures/resources/resource_dew.png"),
	&"willow_bark": preload("res://textures/resources/resource_bark.png"),
	&"graceroot": preload("res://textures/resources/resource_mandrake.png"),
	&"bloodflower": preload("res://textures/resources/resource_bloodflower.png"),
	&"obsidian_grass": preload("res://textures/resources/resource_grassobsidian.png"),
	&"pearls_of_night": preload("res://textures/resources/resource_pearl.png"),
	&"haemoshear": preload("res://textures/resources/resource_haemoshear.png"),
	&"nacrescorch": preload("res://textures/resources/resource_nacrescorch.png"),
	&"capillanyx": preload("res://textures/resources/resource_capillanyx.png"),
}


static func info(item: StringName) -> Dictionary:
	return ITEMS.get(item, ITEMS[REPAIR])


## The item's art fitted inside a circle of `radius`; without art, its initials coloured by whose
## station it comes from (repairs are a gear).
static func draw_icon(canvas: CanvasItem, item: StringName, center: Vector2, radius: float) -> void:
	var icon: Texture2D = ICONS.get(item)
	if icon:
		var share: Rect2 = ICON_BOUNDS.get(item, Rect2(0, 0, 1, 1))
		var region := Rect2(share.position * icon.get_size(), share.size * icon.get_size())
		var fit := minf(radius * 2.0 / region.size.x, radius * 2.0 / region.size.y)
		var icon_size := region.size * fit
		canvas.draw_texture_rect_region(icon, Rect2(center - icon_size / 2.0, icon_size), region)
		return
	var data := info(item)
	if item == REPAIR:
		_draw_gear(canvas, center, radius, data.color)
		return
	var font: Font = GameFonts.BODY
	var font_size := int(radius * 1.25)
	var text: String = data.initials
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := center + Vector2(-text_size.x / 2.0, font.get_ascent(font_size) - text_size.y / 2.0)
	canvas.draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 2, data.color)
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, data.color)


static func _draw_gear(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	for i in 8:
		var a := TAU * i / 8.0
		var tooth := PackedVector2Array()
		for corner in 4:
			var c := a + PI / 4.0 + TAU * corner / 4.0
			tooth.append(center + Vector2(cos(a), sin(a)) * radius * 0.78 + Vector2(cos(c), sin(c)) * radius * 0.28)
		canvas.draw_colored_polygon(tooth, color)
	canvas.draw_circle(center, radius * 0.72, color)
	canvas.draw_circle(center, radius * 0.3, Color(0.94, 0.92, 0.87))
