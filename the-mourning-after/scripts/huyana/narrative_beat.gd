@tool
class_name NarrativeBeat
extends Interactable
## Campfire spot for each night's scene. Once the night's results are done, Constance walks herself
## over to the fire; reflecting there (still the player's call) has the StoryDirector play the night's
## scene (or milestone beat), after which the next day starts.

@export var walk_offset := Vector3(0, 0, 2.5) # TUNE: where she stops, relative to the fire (m)
@export var walk_timeout := 8.0 # TUNE: longest she tries to walk before stepping straight there (s)

var _manager: SanctuaryManager
var _world: World
var _was_waiting := false
var _walking := false


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	prompt_label = "Reflect"
	_manager = get_tree().get_first_node_in_group(&"sanctuary_manager")
	_world = get_tree().get_first_node_in_group(&"world") as World
	interacted.connect(_on_interacted)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var director := get_tree().get_first_node_in_group(&"story_director") as StoryDirector
	var waiting := _manager != null and _manager.day_cycle.awaiting_beat and not (director and director.busy)
	enabled = waiting and not _walking
	if waiting and not _was_waiting and not player_in_range and not (_world and _world.is_story_playing()):
		_walk_to_fire()
	_was_waiting = waiting


## Steers her like normal movement (so she animates and collides); if something blocks her, she
## finishes the walk directly.
func _walk_to_fire() -> void:
	var player := _world.player if _world else null
	if player == null:
		return
	_walking = true
	player.input_enabled = false
	var target := global_position + walk_offset
	var time := 0.0
	var stuck := 0.0
	var last := player.global_position
	while is_inside_tree() and time < walk_timeout:
		var to := target - player.global_position
		to.y = 0.0
		if to.length() < 0.3:
			break
		player.forced_input = Vector2(to.x, to.z).normalized()
		await get_tree().physics_frame
		var step := get_physics_process_delta_time()
		time += step
		stuck = stuck + step if player.global_position.distance_to(last) < 0.01 else 0.0
		last = player.global_position
		if stuck > 0.4:
			var tween := player.create_tween()
			tween.tween_property(player, "global_position", Vector3(target.x, player.global_position.y, target.z), 0.4)
			await tween.finished
			break
	if not is_instance_valid(player):
		return
	player.forced_input = Vector2.ZERO
	if not (_world and _world.is_story_playing()):
		player.input_enabled = true
	_walking = false


func _on_interacted() -> void:
	var director := get_tree().get_first_node_in_group(&"story_director") as StoryDirector
	if director:
		director.play_night()
