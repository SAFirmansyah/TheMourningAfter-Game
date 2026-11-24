class_name HeroStory
extends Node
## Perrin's story: which scene plays when (the hero side's counterpart to Huyana's StoryDirector).
## New game: CUTSCENE Inciting Incident (black-screen text), then NARRATIVE BEAT Motivation in the base,
## ending at the sword stand where he takes up arms. Saves made before the story existed skip it, as
## does Start from: first boss.

const SCRIPT_PATH := "res://dialogue/hero/%s.txt"

@export var world: World

var intro_done := false
var busy := false

var _loaded := false
var _had_save := false
var _start_point := ""


func _enter_tree() -> void:
	add_to_group(&"save_state")


func _ready() -> void:
	_had_save = SaveSystem.has_save(world.save_slot) # before the world's own first save
	_start_point = World.pending_start
	_begin.call_deferred() # after the world has loaded the save


func _begin() -> void:
	if not world.is_hero_side() or intro_done:
		return
	if (_had_save and not _loaded) or _start_point == "first_boss":
		intro_done = true # an older save, or a test start past the beginning
		return
	busy = true
	world.hold_black()
	await world.story.play_file(SCRIPT_PATH % "inciting_incident")
	if not is_inside_tree(): return
	await world.story.play_file(SCRIPT_PATH % "motivation") # ends at the sword stand
	if not is_inside_tree(): return
	world.story.release()
	intro_done = true
	busy = false
	world.save_game(false)


func get_save_data() -> Dictionary:
	return {"intro_done": intro_done}


func load_save_data(data: Dictionary) -> void:
	_loaded = true
	intro_done = bool(data.get("intro_done", intro_done))
