@tool
class_name LootPickup
extends Node3D
## Floating pickup. Hovers with a slow bob; interacting pulls it into the player.
## Auto-collect pickups skip the prompt and fly in as soon as the player is close.

signal collected(loot_id: StringName)

@export var loot_data: LootData
@export var loot_id: StringName = &"dummy"
@export var auto_collect := false
@export var auto_collect_radius := 1.2 # TUNE: distance at which auto-collect pickups fly in (m)
@export var tint := Color.WHITE:
	set(value):
		tint = value
		if card:
			card.modulate = tint
@export var hover_height := 0.45 # TUNE: resting height above the floor (m)
@export var hover_amplitude := 0.12 # TUNE: bob height (m)
@export var hover_period := 2.0 # TUNE: seconds per bob
@export var collect_time := 0.35 # TUNE: time to fly into the player (s)
@export var collect_end_scale := 0.15 # TUNE: size when it reaches the player (fraction)
@export var collect_target_height := 0.9 # TUNE: point on the player it flies to (m above feet)

@onready var card: FacingCard = $Card
@onready var interactable: Interactable = $Interactable

var _time := 0.0
var _phase := 0.0
var _collecting := false
var _collect_t := 0.0
var _collect_from := Vector3.ZERO
var _player: Node3D


func _ready() -> void:
	card.modulate = tint
	_phase = fposmod(position.x * 1.7 + position.z * 2.3, TAU)
	if Engine.is_editor_hint():
		return
	add_to_group(&"loot_pickups")
	card.position.y = _hover_y()
	card.reset_physics_interpolation()
	interactable.prompt_label = "Collect"
	interactable.interacted.connect(_on_interacted)
	if auto_collect:
		interactable.enabled = false
		interactable.interact_radius = auto_collect_radius
		interactable.body_entered.connect(func(body: Node3D) -> void:
			if body is Player:
				_start_collect(body))


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_time += delta
		card.visual_offset = Vector3(0.0, _hover_y(), 0.0)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _collecting:
		_step_collect(delta)
		return
	_time += delta
	card.position.y = _hover_y()


func _hover_y() -> float:
	return hover_height + hover_amplitude * sin(_time * TAU / hover_period + _phase)


func _on_interacted() -> void:
	if interactable.player:
		_start_collect(interactable.player)


func _start_collect(player: Node3D) -> void:
	if _collecting:
		return
	_player = player
	interactable.enabled = false
	get_tree().call_group(&"world", &"mark_unsaved")
	_collecting = true
	_collect_from = card.global_position


func _step_collect(delta: float) -> void:
	_collect_t = minf(_collect_t + delta / collect_time, 1.0)
	var k := ease(_collect_t, 2.4)
	var target := _player.global_position + Vector3(0.0, collect_target_height, 0.0)
	card.global_position = _collect_from.lerp(target, k)
	card.scale = Vector3.ONE * lerpf(1.0, collect_end_scale, k)
	if _collect_t >= 1.0:
		if loot_data:
			RunInventory.collect(loot_data)
		collected.emit(loot_id)
		queue_free()
