class_name Villain
extends Player
## The player-controlled side of the final fight: Perrin's own moveset (dash, attack, weapon
## abilities) with a fixed starting loadout, plus the three boss-borrowed tools — self-heal,
## shield, pesticide throw — minus whichever one Hero already defeated this run.
## Spellcasting and summoning are stubbed below — their mechanics aren't speced yet.

@export var staff: WeaponData # duplicate of sword_iron.tres, reskinned as a staff

@export_group("Borrowed Abilities")
@export var has_self_heal := true    # stripped if Shuyi was the one defeated
@export var has_shield := true       # stripped if Rudrama was the one defeated
@export var has_pesticide := true    # stripped if Gwenith was the one defeated

@export_group("Heal Potion (borrowed from Shuyi)")
@export var heal_cooldown := 15.0
@export var heal_amount := 50 # TUNE — Shuyi's version is "50% of lost HP"; needs your own number or a % calc here

@export_group("Shield (borrowed from Rudrama)")
@export var block_damage_reduction := 0.3
@export var block_duration := 5.0
@export var block_cooldown := 5.0

@export_group("Pesticide (borrowed from Gwenith)")
const PESTICIDE_SCENE := preload("res://scenes/boss/pesticide_gwen.tscn")
@export var pesticide_cooldown := 8.0
@export var pesticide_radius := 2.0
@export var pesticide_dps := 5
@export var pesticide_duration := 3.0

@export_group("Summoning")
@export var deformed_human_scene: PackedScene
@export var low_mutant_scene: PackedScene
@export var summon_cooldown := 10.0
@export var max_active_summons := 2

var _heal_cd_left := 0.0
var _shield_cd_left := 0.0
var _pesticide_cd_left := 0.0
var _summon_cd_left := 0.0
var _is_blocking := false
var _block_absorbed := 0
var _active_summons: Array[Node] = []


func _ready() -> void:
	super._ready()
	_apply_villain_loadout()
	has_self_heal = CampaignState.defeated_boss_name != "Shuyi"
	has_shield = CampaignState.defeated_boss_name != "Rudrama"
	has_pesticide = CampaignState.defeated_boss_name != "Gwenith"


func _apply_villain_loadout() -> void:
	stats = HeroStats.new()
	stats.current_max_health = 100
	stats.health = 100
	stats.move_speed_multiplier = 1.0
	stats.health_change.emit(100, 100)
	max_dashes = 1
	dashes_available = 1
	weapon = staff
	bonus_weapon_damage = 0.0
	bonus_cooldown_reduction = 0.0
	damage_reduction = 0.0


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_heal_cd_left = maxf(0.0, _heal_cd_left - delta)
	_shield_cd_left = maxf(0.0, _shield_cd_left - delta)
	_pesticide_cd_left = maxf(0.0, _pesticide_cd_left - delta)
	_summon_cd_left = maxf(0.0, _summon_cd_left - delta)


func receive_hit(amount: int) -> void:
	var incoming := amount
	if _is_blocking:
		incoming = int(incoming * (1.0 - block_damage_reduction))
		_block_absorbed += incoming
	stats.take_damage(incoming)


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if not input_enabled:
		return
	if has_self_heal and event.is_action_pressed(&"villain_heal") and _heal_cd_left <= 0.0:
		_use_heal()
	if has_shield and event.is_action_pressed(&"villain_shield") and _shield_cd_left <= 0.0 and not _is_blocking:
		_use_shield()
	if has_pesticide and event.is_action_pressed(&"villain_pesticide") and _pesticide_cd_left <= 0.0:
		_use_pesticide()
	if event.is_action_pressed(&"villain_summon") and _summon_cd_left <= 0.0:
		_try_summon()
	if event.is_action_pressed(&"villain_spell"):
		_try_cast_spell()


func _use_heal() -> void:
	_heal_cd_left = heal_cooldown
	stats.on_health_set(stats.health + heal_amount)


func _use_shield() -> void:
	_is_blocking = true
	_block_absorbed = 0
	_shield_cd_left = block_cooldown
	await get_tree().create_timer(block_duration).timeout
	_is_blocking = false


func _use_pesticide() -> void:
	_pesticide_cd_left = pesticide_cooldown
	var hazard := PESTICIDE_SCENE.instantiate()
	get_parent().add_child(hazard)
	hazard.global_position = global_position + Vector3(_facing.x, 0.0, _facing.y) * 3.0
	if hazard.has_method("configure"):
		hazard.configure(_find_opponent(), pesticide_radius, pesticide_dps, pesticide_duration)


func _try_summon() -> void:
	_active_summons = _active_summons.filter(func(n): return is_instance_valid(n))
	if _active_summons.size() >= max_active_summons:
		return
	_summon_cd_left = summon_cooldown
	var scene := deformed_human_scene if randf() < 0.5 else low_mutant_scene
	if scene == null:
		return
	var minion := scene.instantiate()
	get_parent().add_child(minion)
	minion.global_position = global_position + Vector3(_facing.x, 0.0, _facing.y) * 2.0
	if "target" in minion:
		minion.target = _find_opponent()
	_active_summons.append(minion)


func _find_opponent() -> Node3D:
	return get_tree().get_first_node_in_group(&"boss") # FinalHeroOpponent — still in this group via Boss.add_to_group


func _try_cast_spell() -> void:
	push_warning("Villain spellcasting not yet designed — no-op")
