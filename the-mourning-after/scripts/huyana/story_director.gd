class_name StoryDirector
extends Node
## Constance's story: which scene plays when.
## Opening (new save): The Plague -> Huyana's Altar -> Huyana's Sanctuary -> the tutorial's Night 0.
## Nights (at the campfire): a milestone night plays that sister's narrative beat; the first night after
## each milestone plays that stretch's fixed scene (1, 3, 5, 7); later nights pick an unplayed variant
## (2, 4, 6) at random, and once those run out a short note shows instead. A sister whose variant was
## missed in an earlier stretch (the milestone came first) has hers picked first in the next stretch. A short fade to black leads
## into the next day. The Fates' beat (0%) leads straight into The Choice:
## cast -> "To be continued" and the title (the save stays at The Choice);
## destroy -> Back to Burhana, then the game "deletes itself" (every save erased, title stripped bare).

const SCRIPT_PATH := "res://dialogue/huyana/%s.txt"
const FIXED_SCENES: Array[String] = ["night_1", "night_3", "night_5", "night_7"] # first night after each milestone (0 = start)
const VARIANT_SCENES := [ # later nights in each stretch, random, never repeated
	["night_2_v1", "night_2_v2", "night_2_v3"],
	["night_4_v1", "night_4_v2", "night_4_v3"],
	["night_6_v1", "night_6_v2", "night_6_v3"],
	[],
]
const MILESTONE_BEATS := {&"gwenith": "beat_gwenith", &"shuyi": "beat_shuyi", &"rudrama": "beat_rudrama", &"fates": "beat_fates"}

enum Opening { PLAGUE, ALTAR, SANCTUARY, DONE }

@export var world: World
@export var manager: SanctuaryManager
@export var day_cycle: DayCycle
@export var tutorial: Tutorial
@export_file("*.tscn") var altar_room := "res://scenes/huyana/altar.tscn"
@export_file("*.tscn") var sanctuary_room := "res://scenes/huyana/sanctuary.tscn"
@export var no_scene_note := "And we live to see another night..."
@export var no_scene_note_time := 3.0 # TUNE: how long the note stays before the next day (s)
@export var day_fade_time := 0.8 # TUNE: fade to/from black between a night's scene and the next day (s)
@export var decision_fade_time := 2.5 # TUNE: slow fade to black after The Choice, before the ending text (s)
@export var to_be_continued := "To be continued..."

var opening := Opening.PLAGUE
var fixed_done: Array[int] = []
var variants_used: Array[String] = []
var at_choice := false
var busy := false

var _loaded := false
var _start_point := "" # Start from (testing): "huyana_0".."huyana_3" = the 75/50/25/0% milestone beat
var _variant_sisters := {} # variant id -> the sister it's with (read from its script)


func _enter_tree() -> void:
	add_to_group(&"save_state")
	add_to_group(&"story_director")


func _ready() -> void:
	_start_point = World.pending_start # read before the world clears it
	_begin.call_deferred() # after the world has loaded the save


func _begin() -> void:
	if _start_point.begins_with("huyana_"):
		_start_at_milestone(int(_start_point.trim_prefix("huyana_")))
		return
	if not _loaded and SaveSystem.has_save(world.save_slot):
		opening = Opening.DONE # a save from before the story existed
	if at_choice:
		_play_choice()
	elif opening != Opening.DONE:
		_play_opening()
	elif tutorial.stage == Tutorial.Stage.AT_ALTAR:
		tutorial.begin_night_0()


## Start from (testing): the night a milestone is reached, as if everything before it had played,
## standing at the campfire; its narrative beat starts straight away.
func _start_at_milestone(index: int) -> void:
	opening = Opening.DONE
	tutorial.mark_done()
	fixed_done.clear()
	variants_used.clear()
	for stretch in index + 1:
		fixed_done.append(stretch)
		for id: String in VARIANT_SCENES[stretch]:
			variants_used.append(id)
	manager.story_events_reached = index + 1
	manager.set_health(SanctuaryManager.MILESTONES[index])
	manager.pending_story_event = SanctuaryManager.STORY_EVENTS[index]
	_ensure_room(sanctuary_room)
	var spot := world.current_room.get_node_or_null(^"Stage/Campfire") as Node3D
	if spot:
		world.player.teleport(spot.global_position)
	world.camera_rig.snap_to_target()
	day_cycle.load_save_data({"day": 2 + index * 6, "phase": DayCycle.Phase.NIGHT, "elapsed": day_cycle.day_length, "awaiting_beat": true})
	world.hold_black()
	await _fade(0.0)
	play_night()


# --- Opening -------------------------------------------------------------------------------------

func _play_opening() -> void:
	busy = true
	world.hold_black()
	if opening == Opening.PLAGUE:
		await world.story.play_file(SCRIPT_PATH % "the_plague")
		opening = Opening.ALTAR
	if opening == Opening.ALTAR:
		_ensure_room(altar_room)
		await world.story.play_file(SCRIPT_PATH % "huyanas_altar") # ends walking out into the Sanctuary
		world.story.release()
		opening = Opening.SANCTUARY
		world.save_game(false)
	if opening == Opening.SANCTUARY:
		_ensure_room(sanctuary_room, &"East")
		if world.fade.color.a > 0.0: # resuming here
			await _fade(0.0)
		await world.story.play_file(SCRIPT_PATH % "huyanas_sanctuary")
		await _fade(1.0)
		world.story.release()
		opening = Opening.DONE
		tutorial.begin_night_0()
		world.save_game(false)
		await _fade(0.0)
	busy = false


## Loads the room if Constance isn't already in it; true if it had to.
func _ensure_room(path: String, entry := &"") -> bool:
	if world.current_room and world.current_room.scene_file_path == path:
		return false
	world.load_room(path, entry)
	world.player.forced_input = Vector2.ZERO
	return true


# --- Nights --------------------------------------------------------------------------------------

## Reflecting at the campfire: tonight's scene, then the next day.
func play_night() -> void:
	if busy:
		return
	busy = true
	var event := manager.pending_story_event
	if event != &"":
		manager.pending_story_event = &""
		await world.story.play_file(SCRIPT_PATH % MILESTONE_BEATS[event])
		if event == &"fates":
			at_choice = true
			world.save_game(false) # resuming from here replays The Choice
			busy = false
			_play_choice()
			return
	else:
		var stretch := clampi(manager.story_events_reached, 0, FIXED_SCENES.size() - 1)
		if not fixed_done.has(stretch):
			fixed_done.append(stretch)
			await world.story.play_file(SCRIPT_PATH % FIXED_SCENES[stretch])
		else:
			var left: Array = VARIANT_SCENES[stretch].filter(func(id: String) -> bool: return not variants_used.has(id))
			if left.is_empty():
				world.player.input_enabled = false
				world.hud.show_note(no_scene_note, no_scene_note_time)
				await _wait(no_scene_note_time)
			else:
				var owed := _owed_sisters(stretch)
				var first: Array = left.filter(func(id: String) -> bool: return owed.has(_variant_sister(id)))
				var pick: String = (first if not first.is_empty() else left).pick_random()
				variants_used.append(pick)
				await world.story.play_file(SCRIPT_PATH % pick)
	await _next_day()
	busy = false


## Short fade to black, back to the campfire if the scene ended elsewhere, and the next day.
func _next_day() -> void:
	await _fade(1.0)
	world.story.release()
	if _ensure_room(sanctuary_room):
		var spot := world.current_room.get_node_or_null(^"Stage/Campfire") as Node3D
		if spot:
			world.player.teleport(spot.global_position)
		world.camera_rig.snap_to_target()
	day_cycle.start_day() # saves
	await _fade(0.0)


## Sisters whose variant was missed in an earlier stretch and hasn't been made up for since.
func _owed_sisters(stretch: int) -> Dictionary:
	var owed := {}
	for s in stretch + 1:
		for id: String in VARIANT_SCENES[s]:
			var sister := _variant_sister(id)
			if variants_used.has(id):
				owed.erase(sister)
			elif s < stretch:
				owed[sister] = true
	return owed


## The sister a variant is with: whoever speaks in it besides Constance.
func _variant_sister(id: String) -> String:
	if not _variant_sisters.has(id):
		_variant_sisters[id] = ""
		for step in StoryScript.load_steps(SCRIPT_PATH % id):
			if step.type == "line" and step.speaker != "constance":
				_variant_sisters[id] = step.speaker
				break
	return _variant_sisters[id]


# --- The Choice ----------------------------------------------------------------------------------

func _play_choice() -> void:
	busy = true
	world.hold_black()
	var choice := await world.story.play_file(SCRIPT_PATH % "beat_choice")
	await _fade(1.0, decision_fade_time)
	if choice == "cast":
		# The cast-the-spell route isn't built yet: the save stays at The Choice.
		await world.story.play_steps([{"type": "text", "stanzas": [PackedStringArray([to_be_continued])]}])
	else:
		await world.story.play_file(SCRIPT_PATH % "back_to_burhana")
		SaveSystem.delete_all()
		SaveSystem.mark_ended()
	get_tree().change_scene_to_file(TestTools.TITLE_SCENE)


# --- Helpers -------------------------------------------------------------------------------------

func _fade(alpha: float, seconds := -1.0) -> void:
	var tween := create_tween()
	tween.tween_property(world.fade, "color:a", alpha, day_fade_time if seconds < 0.0 else seconds)
	await tween.finished


func _wait(seconds: float) -> void:
	var timer := get_tree().create_timer(seconds, false)
	await timer.timeout


func get_save_data() -> Dictionary:
	return {"opening": opening, "fixed_done": fixed_done, "variants_used": variants_used, "at_choice": at_choice}


func load_save_data(data: Dictionary) -> void:
	_loaded = true
	opening = int(data.get("opening", Opening.DONE)) as Opening
	fixed_done.assign(data.get("fixed_done", []).map(func(n: float) -> int: return int(n)))
	variants_used.assign(data.get("variants_used", []))
	at_choice = bool(data.get("at_choice", false))
