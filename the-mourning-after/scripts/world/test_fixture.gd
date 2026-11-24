extends Node
## Testing-only bridge: carries the "defeated boss" choice from the title screen's
## Play as Constance sub-menu into FinalBossRoom, since that test jump skips World.gd entirely.

static var pending_defeated_boss := ""
