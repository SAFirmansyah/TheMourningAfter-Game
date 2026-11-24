class_name GameFonts
## The game's typefaces (IM Fell, SIL Open Font License: fonts/OFL.txt).
## BODY is the project default (Project Settings > GUI > Theme > Custom Font).

const BODY := preload("res://fonts/IMFellDoublePica-Regular.ttf") # everything by default
const TITLE := preload("res://fonts/IMFellGreatPrimerSC-Regular.ttf") # titles, speaker names, the pause menu
const CUTSCENE := preload("res://fonts/IMFellDWPica-Regular.ttf") # black-screen cutscene text


## A theme whose default font is `font`, for a whole panel (e.g. the pause menu).
static func theme_with(font: Font) -> Theme:
	var theme := Theme.new()
	theme.default_font = font
	return theme
