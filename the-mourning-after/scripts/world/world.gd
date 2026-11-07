class_name World
extends Node3D
## Holds the player and camera; swaps rooms when a path exit is entered; plays cutscenes.
## Starts from the save file if there is one, otherwise in whichever room is placed under Rooms.
## Autosaves on every room change, combat room clear and Fate bargain. Entering an uncleared combat
## room saves a wiped run instead (GDD: quitting mid-room loses the run); saving is off until it's cleared.
## Room changes (e.g. collected loot) only persist for the current room.

const SAVE_VERSION := 2
const LOOT_PICKUP_SCENE := preload("res://scenes/loot/loot_pickup.tscn")

@export var fade_time := 0.35 # TUNE: fade to/from black per room change (s)
@export var load_save_on_start := true # off: always start fresh in the placed room
@export var base_room_path := "res://scenes/rooms/room_a.tscn"

@onready var player: Player = $Player
@onready var player_hud: PlayerHUD = $PlayerHUD
@onready var camera_rig: CameraRig = $CameraRig
@onready var rooms: Node3D = $Rooms
@onready var fade: ColorRect = $Transition/Fade
@onready var save_indicator: SaveIndicator = $SaveIndicator
@onready var skip_prompt: SkipPrompt = $SkipPrompt

var current_room: Room
var _transitioning := false
var _in_cutscene := false
var _cutscene: Cutscene
var _fade_tween: Tween
var _menu_paused := false
var _tree_was_paused := false
var _room_changes := {}


func _ready() -> void:
	skip_prompt.skip_requested.connect(func() -> void:
		if _cutscene:
			_cutscene.skip())
	var placed: Room
	for child in rooms.get_children():
		if child is Room:
			placed = child
			break
			
	player.died.connect(_on_player_died)
	player_hud.bind_stats(player.stats)
	player_hud.bind_player(player)
	RunInventory.bind_player(player)
	CampaignState.reset_campaign()
	RunInventory.bargained.connect(func() -> void: save_game())

	var data := SaveSystem.load_data() if load_save_on_start else {}
	RunInventory.magic_residue = data.get("magic_residue", 0)
	RunInventory.has_completed_first_run = data.get("has_completed_first_run", false)
	RunInventory.has_reached_boss = data.get("has_reached_boss", false)
	RunInventory.final_snapshot = data.get("final_snapshot", {})
	var run: Dictionary = data.get("run", {}) if int(data.get("version", 0)) >= SAVE_VERSION else {}
	var saved_room: String = data.get("room", "")
	if saved_room != "" and run.is_empty():
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
		if pos is Array and pos.size() == 3 and not run.is_empty():
			player.teleport(Vector3(pos[0], pos[1], pos[2]))
			camera_rig.snap_to_target()
	elif placed:
		_enter_room(placed, &"")


## Plays a cutscene scene (a Cutscene root) over everything, pausing gameplay.
## Callable from any trigger: story beats, room changes, first launch, etc.
func play_cutscene(path: String, fade_back_in := true) -> void:
	if _in_cutscene:
		return
	_in_cutscene = true
	var cutscene: Cutscene = (load(path) as PackedScene).instantiate()
	cutscene.process_mode = Node.PROCESS_MODE_ALWAYS
	if fade.color.a < 1.0:
		await _fade_to(1.0)
	get_tree().paused = true
	_cutscene = cutscene
	add_child(cutscene)
	skip_prompt.begin()
	await _fade_to(0.0)
	await cutscene.play()
	skip_prompt.end()
	await _fade_to(1.0)
	_cutscene = null
	cutscene.queue_free()
	get_tree().paused = false
	_in_cutscene = false
	if fade_back_in:
		await _fade_to(0.0)


## Pause menu freeze: stops gameplay, any running cutscene and any fade in progress.
func set_menu_paused(on: bool) -> void:
	if on == _menu_paused:
		return
	_menu_paused = on
	if on:
		_tree_was_paused = get_tree().paused
		get_tree().paused = true
		skip_prompt.frozen = true
		if _cutscene:
			_cutscene.process_mode = Node.PROCESS_MODE_DISABLED
		if _fade_tween and _fade_tween.is_running():
			_fade_tween.pause()
	else:
		skip_prompt.frozen = false
		if _cutscene:
			_cutscene.process_mode = Node.PROCESS_MODE_ALWAYS
		if _fade_tween and _fade_tween.is_valid():
			_fade_tween.play()
		get_tree().paused = _tree_was_paused


func can_save() -> bool:
	return not _transitioning and not _in_cutscene and current_room != null and current_room.allows_saving()


func can_view_stats() -> bool:
	return not _in_cutscene # hero side only, once the villain half exists


## Writes the save. Inside an uncleared combat room this quietly writes a wiped run instead.
func save_game(show_indicator := true) -> void:
	if current_room and not current_room.allows_saving():
		SaveSystem.save_data(_meta_save_data(base_room_path))
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
	SaveSystem.save_data(data)
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
		pickup.auto_collect = true
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


func _on_player_died() -> void:
	_end_run_at_base() # Fate 3


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
	CampaignState.reset_campaign()
	player.stats.on_health_set(player.stats.current_max_health)
	_load_room(base_room_path, &"")
	save_game()

	await _fade_to(0.0)
	player.input_enabled = true
	_transitioning = false
