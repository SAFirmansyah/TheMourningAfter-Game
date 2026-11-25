class_name Demo
## Exhibition build: which side this demo plays ("hero", "villain" or "" for the full game).
## The title offers only "Play Demo", every quit wipes the save for the next visitor, and the side's
## demo rules apply (hero: Gwenith is the only boss; beating her ends the demo).

const SIDE := "villain"
const ONLY_BOSS := "GWENITH"
const ONLY_BOSS_NOTE := "In this demo, only the Gwenith boss fight is available."
const THANKS := "Thank you for playing, and congratulations on beating the first boss!"

# Villain demo: shorter days, a penalty that grows every night, and it ends after night scene 7.
const DAY_LENGTH := 240.0 # TUNE: a demo day (s at 1x)
const PENALTY_START := 0.4 # TUNE: sanctuary health lost per expired request on the first day (%)
const PENALTY_PER_NIGHT := 0.25 # TUNE: added to that after every night (%)
const VILLAIN_THANKS := "Thank you for playing. If you're wondering what's next for Constance and her people, stay tuned for the game's release!"


static func active() -> bool:
	return SIDE != ""


## A clean slate for the next player.
static func wipe() -> void:
	SaveSystem.delete_all()
	SaveSystem.clear_ended()
