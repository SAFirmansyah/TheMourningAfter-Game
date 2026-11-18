class_name Villain
extends Player
## Constance's side of the final fight. Fixed loadout, plus two spells determined by which boss
## Perrin defeated this run, and a Q summon (one of each small mob type, 20s cooldown that only
## starts once the summoned pair is fully cleared).

enum SpellType { NONE, HEALING, ENSNARED, ADRENALINE }

@export var staff: WeaponData

@export_group("Spell 1 (Healing)")
@export var heal_fraction := 0.5 # TUNE: fraction of MISSING health restored
@export var heal_cooldown := 15.0

@export_group("Spell 2 (Adrenaline)")
@export var adrenaline_duration := 10.0
@export var adrenaline_speed_bonus := 0.5
@export var adrenaline_cooldown := 20.0

@export_group("Spell (Ensnared)")
const VINE_SCENE := preload("res://scenes/boss/vine_trap_gwen.tscn")
@export var ensnared_radius := 1.6
@export var ensnared_warning := 5.0
@export var ensnared_root_time := 5.0
@export var ensnared_damage := 5
@export var ensnared_cooldown := 10.0

@export_group("Summon")
@export var deformed_human_scene: PackedScene
@export var low_mutant_scene: PackedScene
@export var summon_cooldown := 20.0

var spell_1 := SpellType.NONE
var spell_2 := SpellType.NONE

var _spell_1_cd_left := 0.0
var _spell_2_cd_left := 0.0
var _adrenaline_left := 0.0
var _grab_pending := false

var _summon_cd_left := 0.0
var _active_summons: Array[Node] = []
var _summons_were_active := false


func _ready() -> void:
	super._ready()
	_apply_villain_loadout()
	_resolve_spells()


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


func _resolve_spells() -> void:
	var defeated := CampaignState.defeated_boss_name
	spell_1 = SpellType.ENSNARED if defeated == "Shuyi" else SpellType.HEALING
	spell_2 = SpellType.ENSNARED if defeated == "Rudrama" else SpellType.ADRENALINE


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	_spell_1_cd_left = maxf(0.0, _spell_1_cd_left - delta)
	_spell_2_cd_left = maxf(0.0, _spell_2_cd_left - delta)

	if _adrenaline_left > 0.0:
		_adrenaline_left -= delta
		is_invulnerable = true
		if _adrenaline_left <= 0.0:
			stats.move_speed_multiplier -= adrenaline_speed_bonus

	_active_summons = _active_summons.filter(func(n): return is_instance_valid(n))
	if _active_summons.is_empty() and _summons_were_active:
		_summons_were_active = false
		_summon_cd_left = summon_cooldown
	_summon_cd_left = maxf(0.0, _summon_cd_left - delta)

	if _grab_pending:
		_grab_pending = false
		var opponent := _find_opponent()
		if opponent and opponent.has_method("is_stunned") and opponent.is_stunned():
			_grab(opponent)


func _grab(opponent: Node3D) -> void:
	input_enabled = false
	var to := opponent.global_position - global_position
	if to.length() > attack_reach + weapon.hitbox_height / 2.0:
		global_position = opponent.global_position - Vector3(to.x, 0.0, to.z).normalized() * 1.0

	while opponent and is_instance_valid(opponent) and opponent.has_method("is_stunned") and opponent.is_stunned():
		_facing = Vector2(to.x, to.z).normalized()
		_try_attack()
		await get_tree().create_timer(weapon.attack_cooldown + weapon.active_delay).timeout
		to = opponent.global_position - global_position

	input_enabled = true


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if not input_enabled:
		return
	if event.is_action_pressed(&"constance_spell_1") and _spell_1_cd_left <= 0.0:
		_cast(spell_1)
		_spell_1_cd_left = _cooldown_for(spell_1)
	if event.is_action_pressed(&"constance_spell_2") and _spell_2_cd_left <= 0.0:
		_cast(spell_2)
		_spell_2_cd_left = _cooldown_for(spell_2)
	if event.is_action_pressed(&"constance_summon") and _active_summons.is_empty() and _summon_cd_left <= 0.0:
		_summon()


func _cooldown_for(spell: SpellType) -> float:
	match spell:
		SpellType.HEALING: return heal_cooldown
		SpellType.ADRENALINE: return adrenaline_cooldown
		SpellType.ENSNARED: return ensnared_cooldown
	return 0.0


func _cast(spell: SpellType) -> void:
	match spell:
		SpellType.HEALING:
			var missing := stats.current_max_health - stats.health
			stats.on_health_set(stats.health + int(missing * heal_fraction))
		SpellType.ADRENALINE:
			_adrenaline_left = adrenaline_duration
			stats.move_speed_multiplier += adrenaline_speed_bonus
		SpellType.ENSNARED:
			var opponent := _find_opponent()
			if opponent and VINE_SCENE:
				var vine := VINE_SCENE.instantiate()
				get_parent().add_child(vine)
				vine.global_position = opponent.global_position
				vine.configure(self, opponent, ensnared_radius, ensnared_warning, ensnared_root_time, ensnared_damage)


## Called by VineHazard if the opponent gets caught — same callback name Boss uses.
func on_player_ensnared() -> void:
	_grab_pending = true


func _summon() -> void:
	_summons_were_active = true
	var opponent := _find_opponent()
	var scenes: Array[PackedScene] = [deformed_human_scene, low_mutant_scene]
	for scene in scenes:
		if scene == null:
			continue
		var minion: Node = scene.instantiate()
		get_parent().add_child(minion)
		minion.global_position = global_position + Vector3(_facing.x, 0.0, _facing.y) * 2.0
		if "target" in minion:
			minion.target = opponent
		_active_summons.append(minion)


func _find_opponent() -> Node3D:
	return get_tree().get_first_node_in_group(&"boss")
