class_name FinalBossRoom
extends Room

@export var villain_staff: WeaponData

@onready var constance_play: Player = $Constance
@onready var hero_opponent: PerrinAsEnemy = $PerrinEnemy
@onready var constance_hud: PlayerHUD = $PlayerHUD
@onready var camera_rig: CameraRig = $CameraRig


func _ready() -> void:
	super._ready()
	
	camera_rig.follow_target = constance_play
	constance_play.camera_rig = camera_rig
	camera_rig.snap_to_target()

	if RunInventory.get_player() == null or not RunInventory.loadout_taken:
		_setup_test_fixtures()
	else:
		hero_opponent.set_stats(RunInventory.get_player().stats.duplicate())
		hero_opponent.weapon = RunInventory.get_player().weapon

	constance_play._resolve_spells()
	hero_opponent.target = constance_play
	hero_opponent.defeated.connect(func(): get_tree().change_scene_to_file("res://scenes/endings/victory_time_thief.tscn"))
	constance_play.died.connect(func(): get_tree().change_scene_to_file("res://scenes/endings/lost_cause.tscn"))

	constance_hud.bind_stats(constance_play.stats)
	constance_hud.bind_player(constance_play)

func _setup_test_fixtures() -> void:
	var test_stats := BossStats.new()
	test_stats.max_health = 150
	hero_opponent.set_stats(test_stats)
	hero_opponent.weapon = load("res://scripts/weapons/sword_bronze.tres")

	var chosen: String = TestFixture.pending_defeated_boss
	CampaignState.defeated_boss_name = chosen if chosen != "" else "Gwenith"
	TestFixture.pending_defeated_boss = ""
