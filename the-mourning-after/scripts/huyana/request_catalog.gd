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


static func info(item: StringName) -> Dictionary:
	return ITEMS.get(item, ITEMS[REPAIR])


## Placeholder icon: the item's initials, coloured by whose station it comes from; repairs are a gear.
static func draw_icon(canvas: CanvasItem, item: StringName, center: Vector2, radius: float) -> void:
	var data := info(item)
	if item == REPAIR:
		_draw_gear(canvas, center, radius, data.color)
		return
	var font := ThemeDB.fallback_font
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
