class_name Demo
## Exhibition build: which side this demo plays ("hero", "villain" or "" for the full game).
## The title offers only "Play Demo", every quit wipes the save for the next visitor, and the side's
## demo rules apply (hero: Gwenith is the only boss; beating her ends the demo).

const SIDE := "hero"
const ONLY_BOSS := "GWENITH"
const ONLY_BOSS_NOTE := "In this demo, only the Gwenith boss fight is available."
const THANKS := "Thank you for playing, and congratulations on beating the first boss!"


static func active() -> bool:
	return SIDE != ""


## A clean slate for the next player.
static func wipe() -> void:
	SaveSystem.delete_all()
	SaveSystem.clear_ended()
