class_name FinalBossRoom
extends Room

@export var villain_staff: WeaponData

@onready var constance_play: Player = $Constance
@onready var hero_opponent: PerrinAsEnemy = $PerrinEnemy
@onready var camera_rig: CameraRig = $CameraRig


func _ready() -> void:
	super._ready()
	
	camera_rig.follow_target = constance_play
	constance_play.camera_rig = camera_rig
	camera_rig.snap_to_target()

	if RunInventory.get_player() == null or not RunInventory.loadout_taken:
		_setup_test_fixtures()
	else:
		hero_opponent.stats = RunInventory.get_player().stats.duplicate()
		hero_opponent.weapon = RunInventory.get_player().weapon

	hero_opponent.get_node("HurtboxArea").refresh_layer()
	hero_opponent.target = constance_play
	hero_opponent.defeated.connect(func(): get_tree().change_scene_to_file("res://scenes/endings/victory_time_thief.tscn"))
	constance_play.died.connect(func(): get_tree().change_scene_to_file("res://scenes/endings/lost_cause.tscn"))



func _setup_test_fixtures() -> void:
	var test_stats := BossStats.new()
	test_stats.max_health = 150
	hero_opponent.stats = test_stats
	hero_opponent.weapon = load("res://scripts/weapons/sword_bronze.tres")
	hero_opponent.get_node("HurtboxArea").refresh_layer()

	var chosen: String = TestFixture.pending_defeated_boss
	CampaignState.defeated_boss_name = chosen if chosen != "" else "Gwenith"
	TestFixture.pending_defeated_boss = ""
