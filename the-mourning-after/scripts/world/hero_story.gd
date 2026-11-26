class_name HeroStory
extends Node
## Perrin's story: which scene plays when (the hero side's counterpart to Huyana's StoryDirector).
## - New game: CUTSCENE Inciting Incident, then NARRATIVE BEAT Motivation, ending at the sword stand.
## - First residue: once the room is cleared he walks up to it; the room stays shut until it's collected.
## - First pre-boss room (with residue): drinking at the pond flashes white and plays Doubt (first Fate
##   met) or Seira, which re-rolls the boss. The exit stays shut until then.
## - First fall (with residue): Life (first Fate met) or Kano, which revives him.
## - First return to base after dying: Again (no residue), or, on taking up arms at the sword stand,
##   Anxiety / Archi, which re-seeds his sword. The exit stays shut until then.
## - Gwenith's chamber: her first meeting, then three set encounters, then random short ones.
## - Flavour captions for returning to base and for every bargain taken the normal way.
## Older saves and Start from: first boss skip the opening.

const SCRIPT_PATH := "res://dialogue/hero/%s.txt"
const BOSS_ROLES := {"GWENITH": "farmer", "SHUYI": "medic", "RUDRAMA": "guard"}

const RETURN_LINES := [
	"Home again… I’ve got another go at this.",
	"The beings that keep helping me out… I wonder what they want from me?",
	"I can’t waste time here. I fell, but I have to get back up.",
	"Time to take up weapons again and keep going.",
	"Mother, you taught me better than to quit. So I won’t.",
	"Maybe this time I’ll make it through. Gods, please…",
	"Ah, I’m back. Again. I need to try harder, make sure I don’t lose all my work like this.",
	"Drat, back again. No matter. I’ll head out again soon.",
]
const WEAPON_LINES := [
	"%s will do better for me this time.",
	"I’m sure to do better with %s this day.",
	"Hmm. How about %s?",
	"%s is calling to me today.",
	"The powers that be have decided I ought to use %s.",
	"So be it, then. %s, here I go.",
]
const BOSS_LINES := [
	"I’d rather fight the %s, I think.",
	"Gods, let me prevail against this %s.",
	"Looks like my opponent today is to be the %s.",
	"Alright, %s, here I come.",
]
const REVIVE_LINES := [
	"Hrngh! Here I go again!", "Not just yet! I refuse to quit.", "I’ve got more fight in me.",
	"Now is not the time to lie down and die.", "Death, hold on a while longer!", "I need more time!",
	"I can do this, I can do this, I can do this…", "Ngh! No, I won’t stop here!",
	"Come on, Perrin, give it another go.", "Not here, not now! Hah!",
]

@export var world: World

var intro_done := false
var busy := false
var fates_met := false
var first_residue_done := false
var preboss_done := false
var first_death_done := false
var first_return_done := false
var gwenith_meetings := 0

var _loaded := false
var _had_save := false
var _start_point := ""
var _room: Room
var _died := false # the last trip back to base was a death
var _preboss_waiting := false # first pre-boss room with residue: drinking at the pond plays the Fate beat
var _demo_note_after_scene := false
var _base_waiting := false # first return with residue: taking up arms plays Anxiety / Archi


func _enter_tree() -> void:
	add_to_group(&"save_state")
	add_to_group(&"hero_story")


func _ready() -> void:
	_had_save = SaveSystem.has_save(world.save_slot) # before the world's own first save
	_start_point = World.pending_start
	_begin.call_deferred() # after the world has loaded the save


func _begin() -> void:
	if not world.is_hero_side():
		return
	world.story.cue.connect(_on_cue)
	if intro_done:
		return
	if (_had_save and not _loaded) or _start_point == "first_boss":
		intro_done = true # an older save, or a test start past the beginning
		return
	busy = true
	world.hold_black()
	await world.story.play_file_skippable(SCRIPT_PATH % "inciting_incident")
	if not is_inside_tree(): return
	await world.story.play_file(SCRIPT_PATH % "motivation") # ends at the sword stand
	if not is_inside_tree(): return
	world.story.release()
	intro_done = true
	busy = false
	world.save_game(false)


# --- Room changes and exit triggers ----------------------------------------------------------------

func _process(_delta: float) -> void:
	if not world.is_hero_side() or busy or world.is_story_playing():
		return
	if world.current_room != _room:
		_room = world.current_room
		_on_room_entered.call_deferred(_room)
	if _room == null:
		return
	if _preboss_waiting and _room.scene_file_path == CampaignState.pre_boss_chamber_path:
		var pond := _room.get_node_or_null(^"Pond/HealSpot") as HealSpot
		if pond and pond._is_used(): # right after drinking at the pond
			_play_preboss_beat()
	elif _base_waiting and _room is BaseRoom and RunInventory.loadout_taken: # right as he takes up arms at the sword stand
		_play_base_beat()


func _on_room_entered(room: Room) -> void:
	if room == null or room != world.current_room:
		return
	if room is CombatRoom and not first_residue_done:
		(room as CombatRoom).all_enemies_defeated.connect(_on_room_cleared.bind(room), CONNECT_ONE_SHOT)
	if room.scene_file_path == CampaignState.pre_boss_chamber_path and not preboss_done:
		preboss_done = true # the first time only
		if RunInventory.magic_residue >= 1:
			_preboss_waiting = true
			_set_exit_blocked(&"EastExit", true)
			var pond := room.get_node_or_null(^"Pond/HealSpot") as HealSpot
			if pond:
				pond.always_usable = true # the Fate waits at the pond, even at full health
	if room is BaseRoom and _died:
		_died = false
		if not first_return_done:
			first_return_done = true
			if RunInventory.magic_residue <= 0:
				await _play(["again"])
			else:
				_base_waiting = true
				_set_exit_blocked(&"SouthExit", true)
		else:
			world.hud.show_note(RETURN_LINES.pick_random(), 3.5)
	if Demo.active() and room is BossRoom:
		(room as BossRoom).boss_defeated.connect(_play_demo_end, CONNECT_ONE_SHOT)
	if room.scene_file_path == CampaignState.boss_rooms.get("GWENITH", ""):
		var scene := "gwenith_first"
		match gwenith_meetings:
			0: scene = "gwenith_first"
			1: scene = "gwenith_2"
			2: scene = "gwenith_3"
			3: scene = "gwenith_4"
			_: scene = ["gwenith_v1", "gwenith_v2", "gwenith_v3"].pick_random()
		gwenith_meetings += 1
		await get_tree().create_timer(0.6).timeout
		await _play([scene])


func _set_exit_blocked(exit_name: StringName, blocked: bool) -> void:
	var exit := world.current_room.get_exit(exit_name) if world.current_room else null
	if exit:
		exit.set_blocked(blocked)


func _play_preboss_beat() -> void:
	_preboss_waiting = false
	await _play(["seira" if fates_met else "doubt"])
	fates_met = true
	if _demo_note_after_scene:
		_demo_note_after_scene = false
		world.hud.show_note(Demo.ONLY_BOSS_NOTE, 4.0)
	_set_exit_blocked(&"EastExit", false)
	if world.current_room.has_method(&"_configure_boss_exit"):
		world.current_room._configure_boss_exit() # now leads to the boss Seira swapped in


func _play_base_beat() -> void:
	_base_waiting = false
	await _play(["archi" if fates_met else "anxiety"])
	fates_met = true
	_set_exit_blocked(&"SouthExit", false)


## While a beat plays here the room's enemies hold still.
func _play(scenes: Array) -> void:
	busy = true
	var frozen: Array[Node] = []
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		if enemy.process_mode != Node.PROCESS_MODE_DISABLED:
			frozen.append(enemy)
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
	for scene: String in scenes:
		await world.story.play_file(SCRIPT_PATH % scene)
		if not is_inside_tree(): return
	world.story.release()
	for enemy in frozen:
		if is_instance_valid(enemy):
			enemy.process_mode = Node.PROCESS_MODE_INHERIT
	busy = false
	world.mark_unsaved()


# --- First residue ---------------------------------------------------------------------------------

func _on_room_cleared(room: CombatRoom) -> void:
	if first_residue_done or room != world.current_room:
		return
	await get_tree().create_timer(0.4).timeout # its loot lands
	var residue: LootPickup = null
	for pickup: LootPickup in get_tree().get_nodes_in_group(&"loot_pickups"):
		if pickup.loot_data and pickup.loot_data.effect == LootData.EffectType.MAGIC_RESIDUE and room.is_ancestor_of(pickup):
			residue = pickup
	if residue == null:
		return # no residue dropped here: the next combat room tries again
	first_residue_done = true
	busy = true
	for exit in room.get_exits():
		exit.set_blocked(true) # just this once: not leaving without it
	var player := world.player
	player.input_enabled = false
	var target := residue.global_position + (player.global_position - residue.global_position).normalized() * 0.9
	target.y = player.global_position.y
	var tween := player.create_tween()
	tween.tween_property(player, "global_position", target, player.global_position.distance_to(target) / 3.5)
	await tween.finished
	await world.story.play_file(SCRIPT_PATH % "first_residue_a")
	world.story.release()
	player.input_enabled = true # free to walk up and press E (the exits stay shut)
	busy = false
	await residue.collected # the player presses E
	await get_tree().create_timer(0.5).timeout
	await _play(["first_residue_b"])
	for exit in room.get_exits():
		exit.set_blocked(false)


# --- Death ------------------------------------------------------------------------------------------

## The world asks first: true if the story handles this fall (the first one, with residue to spend).
func handle_death() -> bool:
	if first_death_done or RunInventory.magic_residue < 1 or not RunInventory.can_revive():
		return false
	first_death_done = true
	_play_first_fall()
	return true


func _play_first_fall() -> void:
	await _play(["kano" if fates_met else "life"])
	fates_met = true


## The world is sending Perrin home after a fall.
func on_died_to_base() -> void:
	first_death_done = true
	_died = true


# --- Cues: the bargains the Fates make mid-scene ----------------------------------------------------

func _on_cue(cue_name: String) -> void:
	match cue_name:
		"boss_bargain":
			CampaignState.bargain_boss()
			if Demo.active():
				_demo_note_after_scene = true
		"revive":
			RunInventory.buy_revive()
			world.player.clear_stun()
			world.player.stats.on_health_set(world.player.stats.current_max_health)
		"weapon_bargain":
			RunInventory.try_bargain() # the new sword goes straight into his hand


# --- Flavour captions for bargains taken the normal way --------------------------------------------

func say_weapon_bargain() -> void:
	var weapon := world.player.weapon
	if weapon:
		world.hud.show_note(WEAPON_LINES.pick_random() % weapon.weapon_name, 3.5)


func say_boss_bargain() -> void:
	if Demo.active():
		world.hud.show_note(Demo.ONLY_BOSS_NOTE, 4.0)
		return
	world.hud.show_note(BOSS_LINES.pick_random() % BOSS_ROLES.get(CampaignState.chosen_boss, "witch"), 3.5)


func say_revive() -> void:
	world.hud.show_note(REVIVE_LINES.pick_random(), 3.0)


func get_save_data() -> Dictionary:
	return {"intro_done": intro_done, "fates_met": fates_met, "first_residue_done": first_residue_done,
		"preboss_done": preboss_done, "first_death_done": first_death_done,
		"first_return_done": first_return_done, "gwenith_meetings": gwenith_meetings}


func load_save_data(data: Dictionary) -> void:
	_loaded = true
	intro_done = bool(data.get("intro_done", intro_done))
	fates_met = bool(data.get("fates_met", fates_met))
	first_residue_done = bool(data.get("first_residue_done", first_residue_done))
	preboss_done = bool(data.get("preboss_done", preboss_done))
	first_death_done = bool(data.get("first_death_done", first_death_done))
	first_return_done = bool(data.get("first_return_done", first_return_done))
	gwenith_meetings = int(data.get("gwenith_meetings", gwenith_meetings))


## Demo: beating the boss ends the demo: Perrin's lines, a thank-you, then the title (which wipes the save).
func _play_demo_end() -> void:
	await get_tree().create_timer(1.2).timeout
	await _play(["demo_end"])
	if not is_inside_tree(): return
	get_tree().change_scene_to_file(TestTools.TITLE_SCENE)
