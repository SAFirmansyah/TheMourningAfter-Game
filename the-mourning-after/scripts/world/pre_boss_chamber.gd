class_name PreBossChamber
extends Room

@export var boss_exit_name: StringName = &"BossEntry" # match your actual exit node's name

@onready var boss_announce_label: Label = $CanvasLayer/NextBossLabel	

func _ready() -> void:
	super._ready()
	CampaignState.start_boss_selection()
	_configure_boss_exit()
	_update_announce_label()
	CampaignState.boss_changed.connect(_on_boss_changed)
	
func _on_boss_changed() -> void:
	_configure_boss_exit()
	_update_announce_label()


func _configure_boss_exit() -> void:
	var exit := get_exit(boss_exit_name)
	if exit == null:
		push_warning("PreBossChamber: exit '", boss_exit_name, "' not found")
		return
	exit.target_room = CampaignState.chosen_boss_path
	

func _update_announce_label() -> void:
	boss_announce_label.text = "BOSS CHAMBER — %s" % _boss_display_name(CampaignState.chosen_boss_path)


func _boss_display_name(path: String) -> String:
	if path.contains("boss_sandbox_2"):
		return "SHUYI" # TUNE: adjust mapping once actual boss scene names/paths are finalized
	elif path.contains("boss_sandbox"):
		return "GWENITH"
	else:
		return "RUDRAMA"
