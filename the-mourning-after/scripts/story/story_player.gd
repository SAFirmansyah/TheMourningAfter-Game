class_name StoryPlayer
extends Node
## Runs scene scripts (see StoryScript) on a world: dialogue in the InteractionHUD, black-screen text,
## fades, room changes and staging. The world creates one; play_file() returns the choice id, if any.
## While a script plays, gameplay is held (no input, saving, Sanctuary or day clock). Staging stays in
## place when a script ends until release() (callers fade to black first, then release).
##
## Staging commands (marks are Marker3D nodes under the room's "Stage" node, or exit names):
##   @fade black | white | in           @room altar|sanctuary [mark or exit]
##   @walk WHO MARK  (waits)            @move WHO MARK  (doesn't wait)      @settle  (waits for moves)
##   @show WHO MARK                      @hide WHO...                         @exit WHO...  (walk out, vanish)
##   @pan MARK | back                    @night                               @wait SECONDS
## WHO is the protagonist (constance / perrin), gwenith, shuyi, rudrama, archi, seira or kano. Characters missing from the room
## appear as placeholder cards.

const TEXT_SCENE := preload("res://scenes/story/story_text.tscn")
const PLACEHOLDER_SCENE := preload("res://scenes/characters/npc.tscn")
const PORTRAIT_DIR := "res://textures/portraits/"
const ROOMS := {
	"altar": "res://scenes/huyana/altar.tscn",
	"sanctuary": "res://scenes/huyana/sanctuary.tscn",
	"base": "res://scenes/rooms/room_a.tscn",
}
const CAST_TINTS := { # placeholder card colours in the world until the character art exists
	"constance": Color(0.72, 0.5, 0.95),
	"gwenith": Color(0.6, 0.9, 0.5),
	"shuyi": Color(0.85, 0.85, 0.55),
	"rudrama": Color(0.55, 0.62, 0.85),
	"archi": Color(0.95, 0.6, 0.6),
	"seira": Color(0.6, 0.85, 0.95),
	"kano": Color(0.95, 0.78, 0.5),
	"perrin": Color(1.0, 0.62, 0.4),
}

@export var walk_speed := 3.5 # TUNE: staged walking pace (m/s)
@export var fade_time := 0.6 # TUNE: @fade duration (s)
@export var pan_smoothing := 2.5 # TUNE: camera follow tightness during @pan (lower = slower pan)
@export var pan_hold := 1.4 # TUNE: time given to a @pan before the next line (s)

signal scene_started(path: String)
signal cue(name: String) # @cue NAME: lets the game act mid-scene (e.g. a Fate bargain going through)

var world: World
var playing := false

static var _portrait_files := {} # lowercase "speaker variant" -> exact path

var _skipping := false
var _text: StoryText
var _spawned := {} # who -> placeholder card in the current room
var _scripted: Array[WorkerNPC] = []
var _hidden: Array[Node3D] = []
var _movers := 0
var _held := {}


## Plays a scene script; returns the id of the option picked at its @choice, or "".
func play_file(path: String) -> String:
	scene_started.emit(path)
	return await play_steps(StoryScript.load_steps(path))


## The same, with a Skip prompt (Esc, or click it) for the whole scene: the openings of both sides.
func play_file_skippable(path: String) -> String:
	world.hud.show_skip_prompt(skip)
	var result := await play_file(path)
	if is_inside_tree():
		world.hud.hide_skip_prompt()
	return result


func play_steps(steps: Array[Dictionary]) -> String:
	_begin()
	var result := ""
	for i in steps.size():
		if not is_inside_tree():
			return result # the scene was left mid-cutscene (e.g. quit to the title)
		var step := steps[i]
		match step.type:
			"line":
				await _line(step, i + 1 < steps.size() and steps[i + 1].type == "line")
			"text":
				await play_text(step.stanzas)
			"choice":
				result = await _choice(step.options)
			"cmd":
				await _command(step.name, step.args)
	_end()
	return result


## Black-screen text (also used on its own, e.g. "To be continued").
func play_text(stanzas: Array) -> void:
	world.hud.story_hide_box()
	world.fade.color = Color(0, 0, 0, 1)
	if _skipping:
		return
	_text = TEXT_SCENE.instantiate()
	world.add_child(_text)
	await _text.play(stanzas)
	_text.queue_free()
	_text = null


## Testing: rushes through the rest of the script (choices still wait for an answer).
func skip() -> void:
	if not playing:
		return
	_skipping = true
	if _text:
		_text.skip()


## Puts staged characters back under the game's control and removes placeholders.
func release() -> void:
	for worker in _scripted:
		if is_instance_valid(worker):
			worker.scripted = false
			worker.visible = true
	_scripted.clear()
	for node in _hidden:
		if is_instance_valid(node):
			node.visible = true
	_hidden.clear()
	for card: Node3D in _spawned.values():
		if is_instance_valid(card):
			card.queue_free()
	_spawned.clear()


# --- Running -------------------------------------------------------------------------------------

func _begin() -> void:
	if not is_inside_tree():
		return
	playing = true
	_skipping = false
	var player := world.player
	# A room transition switches input off only until its fade ends: that isn't the state to come back to.
	_held = {"input": player.input_enabled or world.is_transitioning()}
	player.input_enabled = false
	player.forced_input = Vector2.ZERO
	world.set_story_active(true)
	var manager := get_tree().get_first_node_in_group(&"sanctuary_manager") as SanctuaryManager
	if manager:
		_held.frozen = manager.frozen
		_held.clock = manager.day_cycle.clock_paused
		manager.frozen = true
		manager.day_cycle.clock_paused = true
	world.hud.story_begin()


func _end() -> void:
	if _dark:
		_dark.hide()
	if not is_inside_tree():
		return # the world is being torn down
	world.hud.story_end()
	world.camera_rig.follow_target = world.player
	world.camera_rig.follow_smoothing = _held.get("smoothing", world.camera_rig.follow_smoothing)
	world.player.input_enabled = _held.input and not world.is_transitioning() # mid-transition, its end gives input back
	var manager := get_tree().get_first_node_in_group(&"sanctuary_manager") as SanctuaryManager
	if manager:
		manager.frozen = _held.frozen
		manager.day_cycle.clock_paused = _held.clock
	world.set_story_active(false)
	if world.fade.color.r > 0.5: # ended on a fade to white: keep the alpha, back to black
		world.fade.color = Color(0, 0, 0, world.fade.color.a)
	playing = false
	_skipping = false


## has_more: another line follows straight on (the text box shows its arrow).
func _line(step: Dictionary, has_more := false) -> void:
	var key: String = step.speaker.replace(",", "")
	var off_screen: bool = step.variant.begins_with("out of sight")
	var left := key == protagonist() # the side being played sits on the left
	world.hud.story_line(_speaker_label(step), key, left, portrait(key, step.variant), step.text, not off_screen, has_more)
	while is_inside_tree() and not world.hud.story_line_done() and not _skipping:
		await get_tree().process_frame


func _choice(options: Array) -> String:
	world.hud.story_choice(options)
	var picked := world.hud.story_choice_result()
	while picked < 0 and is_inside_tree():
		await get_tree().process_frame
		picked = world.hud.story_choice_result()
	return String(options[picked].id) if picked >= 0 else ""


func _command(name: String, args: Array) -> void:
	match name:
		"fade":
			world.hud.story_hide_box()
			await _fade(args[0] if not args.is_empty() else "black")
		"room":
			world.hud.story_hide_box()
			_room(args[0], args[1] if args.size() > 1 else "")
		"walk":
			world.hud.story_hide_box()
			await _walk(args[0], args[1])
		"move":
			world.hud.story_hide_box()
			_move(args[0], args[1])
		"settle":
			while _movers > 0 and not _skipping and is_inside_tree():
				await get_tree().process_frame
		"show":
			var actor := _actor(args[0])
			var mark := _mark(args[1])
			if actor and mark:
				actor.global_position = mark.global_position
				actor.visible = true
				_hidden.erase(actor)
		"hide":
			for who: String in args:
				_hide(who)
				world.hud.story_clear_right(who)
		"exit":
			world.hud.story_hide_box()
			for who: String in args:
				_move(who, "Exit", true)
				world.hud.story_clear_right(who) # her portrait leaves with her
			while _movers > 0 and not _skipping and is_inside_tree():
				await get_tree().process_frame
		"pan":
			world.hud.story_hide_box()
			await _pan(args[0])
		"night":
			var day_cycle := get_tree().get_first_node_in_group(&"day_cycle") as DayCycle
			if day_cycle:
				day_cycle.set_darkness(1.0, not _skipping)
				await _wait(day_cycle.night_fade_time)
		"wait":
			await _wait(float(args[0]))
		"dark": # @dark on|off: black behind the dialogue (portraits, box and health bar stay visible)
			_set_dark(args.is_empty() or args[0] != "off")
		"flash": # a quick white flash
			if not _skipping:
				var was := world.fade.color
				world.fade.color = Color(1, 1, 1, 0)
				var tween := world.create_tween()
				tween.tween_property(world.fade, "color:a", 0.9, 0.08)
				tween.tween_property(world.fade, "color:a", 0.0, 0.35)
				await tween.finished
				world.fade.color = Color(0, 0, 0, was.a)
		"cue":
			cue.emit(args[0])
		_:
			push_warning("Unknown story command @%s" % name)


var _dark: CanvasLayer

func _set_dark(on: bool) -> void:
	if _dark == null:
		_dark = CanvasLayer.new()
		_dark.layer = 2 # over the room and its atmosphere; under the HUD, portraits and box
		var rect := ColorRect.new()
		rect.color = Color.BLACK
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_dark.add_child(rect)
		add_child(_dark)
	if _skipping:
		_dark.visible = on
		return
	var rect := _dark.get_child(0) as ColorRect
	if on:
		_dark.visible = true
		rect.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(rect, "modulate:a", 1.0 if on else 0.0, 0.4)
	if not on:
		tween.tween_callback(_dark.hide)


func _fade(mode: String) -> void:
	var fade := world.fade
	match mode:
		"white":
			fade.color = Color(1, 1, 1, fade.color.a if fade.color.r > 0.5 else 0.0)
			await _tween_fade(1.0)
		"in":
			await _tween_fade(0.0)
			fade.color = Color(0, 0, 0, 0)
		_:
			fade.color = Color(0, 0, 0, fade.color.a) # from white, this cuts straight to black
			await _tween_fade(1.0)


func _tween_fade(alpha: float) -> void:
	if _skipping:
		world.fade.color.a = alpha
		return
	var tween := world.create_tween()
	tween.tween_property(world.fade, "color:a", alpha, fade_time)
	await tween.finished


func _room(room: String, mark: String) -> void:
	var path: String = ROOMS.get(room, "")
	if path.is_empty():
		push_warning("Unknown story room '%s'" % room)
		return
	_spawned.clear() # placeholders live in the room being left
	_scripted.clear()
	world.hud.story_clear_portraits() # whoever was talking stays behind
	var entry := StringName(mark)
	world.load_room(path, &"")
	var target := _mark(mark) if not mark.is_empty() else null
	if target == null and not mark.is_empty() and world.current_room.get_exit(entry):
		target = world.current_room.get_exit(entry).spawn_point
	if target:
		world.player.teleport(target.global_position)
	world.player.forced_input = Vector2.ZERO
	world.camera_rig.snap_to_target()


func _walk(who: String, mark_name: String, vanish := false) -> void:
	var actor := _actor(who)
	var mark := _mark(mark_name)
	if actor == null or mark == null:
		return
	var target := Vector3(mark.global_position.x, actor.global_position.y, mark.global_position.z)
	var distance := actor.global_position.distance_to(target)
	_face(actor, target - actor.global_position)
	if _skipping or distance < 0.05:
		actor.global_position = target
	else:
		_animate(actor, &"walk")
		var tween := actor.create_tween()
		tween.tween_property(actor, "global_position", target, distance / walk_speed)
		while tween.is_running() and not _skipping and is_inside_tree():
			await get_tree().process_frame
		if _skipping:
			tween.kill()
			actor.global_position = target
		if is_instance_valid(actor):
			_animate(actor, &"idle")
	if vanish:
		_hide(who)


func _move(who: String, mark_name: String, vanish := false) -> void:
	_movers += 1
	await _walk(who, mark_name, vanish)
	_movers -= 1


func _pan(target_name: String) -> void:
	var rig := world.camera_rig
	if not _held.has("smoothing"):
		_held.smoothing = rig.follow_smoothing
	if target_name == "back":
		rig.follow_target = world.player
	else:
		var mark := _mark(target_name)
		if mark == null:
			return
		rig.follow_target = mark
	rig.follow_smoothing = pan_smoothing
	if _skipping:
		rig.snap_to_target()
	await _wait(pan_hold)


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not _skipping and is_inside_tree():
		await get_tree().process_frame
		if can_process():
			left -= get_process_delta_time()


# --- Cast and marks ------------------------------------------------------------------------------

## Whoever is being played: Perrin on the hero side, Constance on the villain side. Their lines
## sit on the left and their name moves the player.
func protagonist() -> String:
	return "perrin" if world and world.is_hero_side() else "constance"


func _actor(who: String) -> Node3D:
	if who == protagonist():
		return world.player
	if _spawned.has(who) and is_instance_valid(_spawned[who]):
		return _spawned[who]
	var room := world.current_room
	if room == null:
		return null
	for worker: WorkerNPC in room.find_children("*", "WorkerNPC", true, false):
		if worker.worker == who:
			worker.scripted = true
			if not _scripted.has(worker):
				_scripted.append(worker)
			return worker
	var card := PLACEHOLDER_SCENE.instantiate() as NPC
	card.character_name = who.capitalize()
	card.tint = _tint(who)
	card.collision_layer = 0
	room.add_child(card)
	card.global_position = room.get_start_position()
	_spawned[who] = card
	return card


func _hide(who: String) -> void:
	var actor := _actor(who)
	if actor == null:
		return
	if _spawned.get(who) == actor:
		actor.queue_free()
		_spawned.erase(who)
	else:
		actor.visible = false
		if not _hidden.has(actor):
			_hidden.append(actor)


func _mark(mark_name: String) -> Node3D:
	var room := world.current_room
	if room == null:
		return null
	var mark := room.get_node_or_null(NodePath("Stage/" + mark_name)) as Node3D
	if mark == null and room.get_exit(StringName(mark_name)):
		mark = room.get_exit(StringName(mark_name)).spawn_point
	if mark == null:
		push_warning("Story mark '%s' not found in %s" % [mark_name, room.name])
	return mark


## Animated cards (Constance) walk while a scene moves them; plain cards just slide.
func _animate(actor: Node3D, animation: StringName) -> void:
	var card := actor.get_node_or_null(^"Card") as AnimatedSprite3D
	if card and card.sprite_frames and card.sprite_frames.has_animation(animation):
		card.play(animation)
	if actor is Player:
		(actor as Player).animation_held = animation != &"idle"


func _face(actor: Node3D, direction: Vector3) -> void:
	var card := actor.get_node_or_null(^"Card") as SpriteBase3D # Sprite3D cards and Constance's animated one
	if card and absf(direction.x) > 0.05:
		card.flip_h = direction.x < 0.0


# --- Portraits -----------------------------------------------------------------------------------

## textures/portraits/<speaker> <variant>.png (e.g. "constance lost in thought.png"); null if missing.
## Matched case-insensitively against the real file names, so .PNG/.png both work once exported.
static func portrait(key: String, variant: String) -> Texture2D:
	if _portrait_files.is_empty():
		for file in DirAccess.get_files_at(PORTRAIT_DIR):
			var name := file.trim_suffix(".import").trim_suffix(".remap")
			if name.get_extension().to_lower() == "png":
				_portrait_files[name.get_basename().to_lower()] = PORTRAIT_DIR + name
	for v in [variant, variant.replace(" ", "-"), variant.replace("-", " ")]:
		var path: String = _portrait_files.get("%s %s" % [key, v], "")
		if not path.is_empty():
			return _framed(load(path)) if variant.begins_with("silhouette") else load(path)
	return null


const FRAME_TOP := 0.175 # share of the portrait above a character's head (Perrin's art), so everyone stands as tall
static var _framed_cache := {}

## Silhouettes come on tighter canvases than the character art: crop them to the drawing and pad the
## top like Perrin's, so in the same portrait frame they stand the same height as him.
static func _framed(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	if _framed_cache.has(tex):
		return _framed_cache[tex]
	var img := tex.get_image()
	var used := img.get_used_rect()
	var pad := used.size.y * FRAME_TOP / (1.0 - FRAME_TOP)
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	var top := float(used.position.y) - pad
	atlas.region = Rect2(0, maxf(top, 0.0), img.get_width(), used.end.y - maxf(top, 0.0))
	atlas.margin = Rect2(0, maxf(-top, 0.0), 0, maxf(-top, 0.0))
	_framed_cache[tex] = atlas
	return atlas


## Unknown speakers (the Fates as silhouettes): "???" for the three together, "?" for one.
func _speaker_label(step: Dictionary) -> String:
	if String(step.variant).begins_with("silhouette"):
		return "???" if String(step.speaker).to_lower() == "the fates" else "?"
	return _display_name(step.speaker)


func _display_name(speaker: String) -> String:
	var names := PackedStringArray()
	for part in speaker.split(","):
		names.append(part.strip_edges().capitalize())
	return ", ".join(names)


func _tint(key: String) -> Color:
	if CAST_TINTS.has(key):
		return CAST_TINTS[key]
	var tint := Color(0, 0, 0, 0)
	var count := 0
	for name in CAST_TINTS: # groups: blend their colours
		if key.contains(name):
			tint += CAST_TINTS[name]
			count += 1
	return tint / count if count > 0 else Color(0.8, 0.8, 0.8)
