class_name World
extends Node3D
## Holds the player and camera; swaps rooms when a path exit is entered; plays cutscenes.
## Starts from the save file if there is one, otherwise in whichever room is placed under Rooms.
## A new save starts on Perrin's side (world.tscn); once he has handed over, launching goes straight to Act 2.
## Autosaves on every room change, combat room clear and Fate bargain. Entering an uncleared combat
## room saves a wiped run instead (GDD: quitting mid-room loses the run); saving is off until it's cleared.
## Room changes (e.g. collected loot) only persist for the current room.
## Nodes in the "save_state" group add their own data via get_save_data() / load_save_data(data).
## The title screen's Start from (testing) sets pending_start before opening the world.

signal room_entered(room: Room)

const SAVE_VERSION := 2
const LOOT_PICKUP_SCENE := preload("res://scenes/loot/loot_pickup.tscn")
const BOSS_TEST_WEAPON := preload("res://scripts/weapons/sword_bronze.tres") # Start from: first boss fight
const BOSS_TEST_HEALTH := 100
const BOSS_TEST_SPEED := 1.5
const BASE_MAX_HEALTH := 50   # TUNE: max HP with zero residue (matches the old first-run value)
const MAX_HEALTH_CAP := 200   # TUNE: ceiling; residue beyond this stops adding HP

@export var fade_time := 0.35 # TUNE: fade to/from black per room change (s)
@export var load_save_on_start := true # off: always start fresh in the placed room
@export var base_room_path := "res://scenes/rooms/room_a.tscn"
@export var save_slot := "savegame" # save file name; one per game half
@export_file("*.tscn") var act_two_scene := "res://scenes/huyana/huyana.tscn"
@export_file("*.txt") var act_two_cutscene := "res://dialogue/hero/act_one_end.txt"
@export var act_two_slot := "huyana" # Act 2's save file; cleared when Perrin hands over
@export var villain_max_health := 100 # TUNE: Constance's HP
@export var villain_move_speed := 1.0 # TUNE: Constance's move speed multiplier

@onready var player: Player = $Player
@onready var player_hud: PlayerHUD = get_node_or_null(^"PlayerHUD") # hero side only
@onready var camera_rig: CameraRig = $CameraRig
@onready var rooms: Node3D = $Rooms
@onready var fade: ColorRect = $Transition/Fade
@onready var save_indicator: SaveIndicator = $SaveIndicator
@onready var hud: InteractionHUD = $InteractionHUD
@onready var fate_bargain: FateBargain = get_node_or_null(^"FateBargain") # hero side only

static var _arriving_in_black := false # the scene before this one ended on a black screen
static var pending_start := "" # Start from: "silvaluca", "first_boss", "huyana" or "huyana_0".."huyana_3" (milestones); used once

var current_room: Room
var _transitioning := false
var _in_cutscene := false
var story: StoryPlayer # runs cutscenes and scripted scenes (dialogue/*.txt)
var _fade_tween: Tween
var _menu_paused := false
var _tree_was_paused := false
var _room_changes := {}
var _unsaved := false


func _enter_tree() -> void:
	add_to_group(&"world")


func _ready() -> void:
	story = StoryPlayer.new()
	story.name = "StoryPlayer"
	story.world = self
	add_child(story)
	var placed: Room
	for child in rooms.get_children():
		if child is Room:
			placed = child
			break

	var data := SaveSystem.load_data(save_slot) if load_save_on_start else {}
	var run: Dictionary = {}
	if is_hero_side():
		RunInventory.reset_session()
		if pending_start.begins_with("huyana"): # Perrin's part counts as done
			data = _meta_save_data(base_room_path)
			data.act_two = true
			SaveSystem.save_data(data, save_slot)
	elif pending_start.begins_with("huyana"): # the test save starts empty (StoryDirector reads milestones)
		pending_start = ""
	if is_hero_side() and data.get("act_two", false):
		_go_to_act_two()
		return
	if is_hero_side():
		player.died.connect(_on_player_died)
		fate_bargain.revive_chosen.connect(_on_revive_chosen)
		fate_bargain.death_chosen.connect(_on_death_chosen)
		player_hud.bind_stats(player.stats)
		player_hud.bind_player(player)
		RunInventory.bind_player(player)
		CampaignState.reset_campaign()
		RunInventory.bargained.connect(func() -> void: save_game())
		RunInventory.magic_residue = data.get("magic_residue", 0)
		RunInventory.has_completed_first_run = data.get("has_completed_first_run", false)
		RunInventory.has_reached_boss = data.get("has_reached_boss", false)
		RunInventory.final_snapshot = data.get("final_snapshot", {})
		if int(data.get("version", 0)) >= SAVE_VERSION:
			run = data.get("run", {})
	else:
		player.stats.setup_fixed_stats(villain_max_health, villain_move_speed)
	var saved_room: String = data.get("room", "")
	if is_hero_side() and saved_room != "" and run.is_empty():
		saved_room = base_room_path # no run in progress (or an old save): start at base
	if saved_room != "" and ResourceLoader.exists(saved_room):
		if placed:
			rooms.remove_child(placed)
			placed.queue_free()
		if not run.is_empty():
			RunInventory.load_run(run.get("inventory", {}))
			CombatRunState.load_state(run.get("combat", {}))
			CampaignState.load_state(run.get("campaign", {}))
		_load_room(saved_room, &"", data.get("room_changes", {}), true)
		_restore_room_state(data)
		var pos: Variant = data.get("player_position")
		if pos is Array and pos.size() == 3 and (not run.is_empty() or not is_hero_side()):
			player.teleport(Vector3(pos[0], pos[1], pos[2]))
			camera_rig.snap_to_target()
	elif placed:
		_enter_room(placed, &"")
	var states: Dictionary = data.get("state", {})
	for node in get_tree().get_nodes_in_group(&"save_state"):
		if states.has(String(node.name)):
			node.load_save_data(states[String(node.name)])
	if is_hero_side() and pending_start == "first_boss":
		_start_at_first_boss()
	elif is_hero_side() and pending_start == "silvaluca":
		save_game(false) # Start from: the test save exists from the first moment
	pending_start = ""
	if _arriving_in_black:
		_arriving_in_black = false
		fade.color.a = 1.0
		_fade_to(0.0)


## Start from: first boss fight. A normal (not first) run with both forest gauntlets done, standing
## in the room before the boss: no forced bargains, a fixed loadout, and free unlimited boss re-rolls
## so any of the three bosses can be picked.
func _start_at_first_boss() -> void:
	RunInventory.has_completed_first_run = true # no forced Fate 1
	RunInventory.has_reached_boss = true # no forced Fate 2
	RunInventory.take_loadout()
	player.weapon = BOSS_TEST_WEAPON
	player.stats.setup_fixed_stats(BOSS_TEST_HEALTH, BOSS_TEST_SPEED)
	CampaignState.free_boss_bargains = true
	CombatRunState.start_next_gauntlet() # past the pond
	CampaignState.gauntlet_count = 2
	_load_room(CampaignState.pre_boss_chamber_path, &"")
	save_game(false)


## Plays a scene script (dialogue/*.txt): black-screen text and/or a scripted scene. Not skippable
## (only the testing Skip button). Fades to black first; fade_back_in reveals the room afterwards.
func play_cutscene(path: String, fade_back_in := true) -> void:
	if _in_cutscene:
		return
	if fade.color.a < 1.0:
		await _fade_to(1.0)
	await story.play_file(path)
	story.release()
	if fade_back_in:
		await _fade_to(0.0)


## A scripted scene is playing: no saving, exits or stats sheet.
func set_story_active(on: bool) -> void:
	_in_cutscene = on


func is_story_playing() -> bool:
	return story != null and story.playing


## Room change without the walk-out, fade or save (scripted scenes, Start from).
func load_room(path: String, entry: StringName) -> void:
	_load_room(path, entry)


## Straight to black and stay there (e.g. an opening cutscene right after arriving).
func hold_black() -> void:
	if _fade_tween:
		_fade_tween.kill()
	fade.color = Color(0, 0, 0, 1)


## Pause menu freeze: stops gameplay, any running cutscene and any fade in progress.
func set_menu_paused(on: bool) -> void:
	if on == _menu_paused:
		return
	_menu_paused = on
	if on:
		_tree_was_paused = get_tree().paused
		get_tree().paused = true
		if _fade_tween and _fade_tween.is_running():
			_fade_tween.pause()
	else:
		if _fade_tween and _fade_tween.is_valid():
			_fade_tween.play()
		get_tree().paused = _tree_was_paused


func can_save() -> bool:
	return not _transitioning and not _in_cutscene and current_room != null and current_room.allows_saving()


func is_hero_side() -> bool:
	return fate_bargain != null


## Something worth saving happened since the last save (interaction, pickup, dialogue, order...).
func mark_unsaved() -> void:
	_unsaved = true


func has_unsaved_changes() -> bool:
	return _unsaved


## Writes the save. Inside an uncleared combat room this quietly writes a wiped run instead.
func save_game(show_indicator := true) -> void:
	_unsaved = false
	if current_room and not current_room.allows_saving():
		SaveSystem.save_data(_meta_save_data(base_room_path), save_slot)
		return
	var data := _meta_save_data(current_room.scene_file_path)
	var pos := player.global_position
	data.player_position = [pos.x, pos.y, pos.z]
	data.room_changes = _room_changes
	data.exits = {}
	for exit in current_room.get_exits():
		data.exits[String(exit.name)] = exit.target_room
	data.drops = []
	for pickup: LootPickup in get_tree().get_nodes_in_group(&"loot_pickups"):
		if pickup.has_meta(&"dropped") and pickup.loot_data and current_room.is_ancestor_of(pickup):
			var p := pickup.global_position
			data.drops.append({"loot": pickup.loot_data.resource_path, "pos": [p.x, p.y, p.z]})
	if RunInventory.loadout_taken:
		data.run = {
			"inventory": RunInventory.save_run(),
			"combat": CombatRunState.save_state(),
			"campaign": CampaignState.save_state(),
		}
	var states := {}
	for node in get_tree().get_nodes_in_group(&"save_state"):
		states[String(node.name)] = node.get_save_data()
	data.state = states
	SaveSystem.save_data(data, save_slot)
	if show_indicator:
		save_indicator.flash()


## What survives between runs: residue and the fresh-save flags.
func _meta_save_data(room_path: String) -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"room": room_path,
		"magic_residue": RunInventory.magic_residue,
		"has_completed_first_run": RunInventory.has_completed_first_run,
		"has_reached_boss": RunInventory.has_reached_boss,
		"final_snapshot": RunInventory.final_snapshot,
	}


## Saved exit targets and uncollected mob drops go back into the room just loaded.
func _restore_room_state(data: Dictionary) -> void:
	var exits: Dictionary = data.get("exits", {})
	for exit in current_room.get_exits():
		if exits.has(String(exit.name)):
			exit.target_room = exits[String(exit.name)]
	for drop: Dictionary in data.get("drops", []):
		var path: String = drop.get("loot", "")
		var pos: Array = drop.get("pos", [])
		if not ResourceLoader.exists(path) or pos.size() != 3:
			continue
		var pickup := LOOT_PICKUP_SCENE.instantiate() as LootPickup
		pickup.loot_data = load(path)
		pickup.loot_id = pickup.loot_data.loot_id
		pickup.tint = pickup.loot_data.tint
		pickup.auto_collect = pickup.loot_data == null or pickup.loot_data.effect != LootData.EffectType.MAGIC_RESIDUE
		pickup.set_meta(&"dropped", true)
		current_room.add_child(pickup)
		pickup.global_position = Vector3(pos[0], pos[1], pos[2])


func _on_exit_requested(target_room: String, target_entry: StringName, exit_direction: Vector3, cutscene: String) -> void:
	if _transitioning or _in_cutscene:
		return
	_transitioning = true
	player.input_enabled = false
	player.forced_input = Vector2(exit_direction.x, exit_direction.z)
	await _fade_to(1.0)
	_load_room(target_room, target_entry)
	save_game()
	if cutscene != "":
		await play_cutscene(cutscene, false)
	await _fade_to(0.0)
	player.forced_input = Vector2.ZERO
	player.input_enabled = true
	_transitioning = false


func _load_room(path: String, entry: StringName, changes := {}, restoring := false) -> void:
	if current_room:
		rooms.remove_child(current_room)
		current_room.queue_free()
	var room: Room = (load(path) as PackedScene).instantiate()
	room.restoring = restoring

	rooms.add_child(room)
	_enter_room(room, entry, changes)


func _enter_room(room: Room, entry: StringName, changes := {}) -> void:
	current_room = room
	current_room.exit_requested.connect(_on_exit_requested)
	if player_hud:
		player_hud.in_base_room = room is BaseRoom
	if room is CombatRoom and not room.is_cleared:
		room.all_enemies_defeated.connect(func() -> void: save_game())
	if room is BossRoom:
		room.boss_defeated.connect(func() -> void: save_game())
	_apply_room_changes(changes)

	var exit := current_room.get_exit(entry)
	if exit:
		player.teleport(exit.spawn_point.global_position)
		var inward := -exit.outward_direction()
		player.forced_input = Vector2(inward.x, inward.z)
	else:
		player.teleport(current_room.get_start_position())
	camera_rig.snap_to_target()
	room_entered.emit(room)


func _apply_room_changes(changes: Dictionary) -> void:
	_room_changes = {"collected": []}
	var collected: Array = changes.get("collected", [])
	for path: String in collected:
		var node := current_room.get_node_or_null(NodePath(path))
		if node:
			node.queue_free()
			_room_changes.collected.append(path)
	for node in current_room.find_children("*", "", true, false):
		if node is LootPickup and not node.is_queued_for_deletion():
			var path := String(current_room.get_path_to(node))
			node.collected.connect(func(_id: StringName) -> void:
				_room_changes.collected.append(path))


func _fade_to(alpha: float) -> void:
	_fade_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.tween_property(fade, "color:a", alpha, fade_time)
	await _fade_tween.finished


## Fate 3: pause and offer a paid revive if Perrin can afford one; otherwise straight back to base.
func _on_player_died() -> void:
	var story_node := get_tree().get_first_node_in_group(&"hero_story") as HeroStory
	if _transitioning or fate_bargain.is_open or player.stats.health > 0:
		return
	if is_story_playing() or (story_node and story_node.busy):
		return # already being handled (e.g. a second hit the same moment, while the first-fall Fate scene plays)
	if story_node and story_node.handle_death():
		return # the first fall: a Fate steps in
	if not RunInventory.can_revive():
		_end_run_at_base()
		return
	set_menu_paused(true)
	fate_bargain.open()


## Bargain taken: full health now, the fight resumes once the countdown ends.
func _on_revive_chosen() -> void:
	RunInventory.buy_revive()
	get_tree().call_group(&"hero_story", &"say_revive")
	player.clear_stun()
	player.stats.on_health_set(player.stats.current_max_health)
	await fate_bargain.countdown_finished
	set_menu_paused(false)


func _on_death_chosen() -> void:
	set_menu_paused(false)
	_end_run_at_base()


## Perrin's story ends here for good: plays the cutscene, marks the save and moves on to Constance.
func begin_act_two() -> void:
	if _transitioning or _in_cutscene:
		return
	_transitioning = true
	player.input_enabled = false
	player.forced_input = Vector2.ZERO
	await play_cutscene(act_two_cutscene, false)
	SaveSystem.delete_save(act_two_slot) # Act 2 always starts fresh from here
	var data := _meta_save_data(base_room_path)
	data.act_two = true
	SaveSystem.save_data(data, save_slot)
	_go_to_act_two()


func _go_to_act_two() -> void:
	_arriving_in_black = true
	get_tree().change_scene_to_file.call_deferred(act_two_scene)


## Test button: the run ends (no death, no bargain) and starts over at the base.
func reset_run() -> void:
	_end_run_at_base()


## Sanctuary stand-in: the run ends and Perrin heads home, progress saved.
func return_to_base() -> void:
	_end_run_at_base()


## Back to the starting room; the next run starts at the sword stand. Residue and flags are kept.
func _end_run_at_base() -> void:
	if _transitioning or _in_cutscene:
		return
	_transitioning = true
	player.input_enabled = false

	await _fade_to(1.0)

	RunInventory.reset_on_death()
	get_tree().call_group(&"hero_story", &"on_died_to_base")
	player.clear_stun()
	CampaignState.reset_campaign()
	player.stats.on_health_set(player.stats.current_max_health)
	_load_room(base_room_path, &"")
	save_game()

	await _fade_to(0.0)
	player.input_enabled = true
	_transitioning = false
	
	
