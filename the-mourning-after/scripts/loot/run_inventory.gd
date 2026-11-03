# RunInventory.gd (autoload)
extends Node

signal effects_changed

var applied_effects: Array[LootData] = [] # kept only so we know what to undo on death

@export var first_run_residue_grant := 2 # TUNE: residue given on the very first ever run
@export var _wood_sword: WeaponData = preload("res://scripts/weapons/sword_wood.tres")
@export var _starting_weapon_pool: Array[WeaponData] = [
	preload("res://scripts/weapons/sword_wood.tres"),
	preload("res://scripts/weapons/sword_bone.tres"),
	preload("res://scripts/weapons/sword_bronze.tres"),
	preload("res://scripts/weapons/sword_iron.tres"),
]
var has_completed_first_run := false
var has_bargained_this_run := false # resets each new run; caps bargain to once per run
var magic_residue := 0

const MAX_RESIDUE_PER_RUN := 3

var _player: Player


func bind_player(player: Player) -> void:
	_player = player

func mark_first_run_if_needed() -> void:
	if not has_completed_first_run:
		magic_residue = first_run_residue_grant
		has_completed_first_run = true

func collect(loot: LootData) -> void:
	if loot.effect == LootData.EffectType.MAGIC_RESIDUE:
		if magic_residue < MAX_RESIDUE_PER_RUN:
			magic_residue += 1
			effects_changed.emit()
		return

	applied_effects.append(loot)
	_apply(loot)
	effects_changed.emit()
	
	
func roll_starting_loadout() -> void:
	print("roll_starting_loadout called, has_completed_first_run=", has_completed_first_run)
	if not has_completed_first_run:
		_player.stats.setup_first_run_stats()
		_player.weapon = _wood_sword
	else:
		_player.stats.setup_stats()
		_player.weapon = _starting_weapon_pool.pick_random()
		print("bargain rerolled weapon to: ", _player.weapon.weapon_name if _player.weapon else "null")


func can_drop_residue() -> bool:
	return magic_residue < MAX_RESIDUE_PER_RUN


func reset_on_death() -> void:
	applied_effects.clear()
	if _player:
		_player.reset_run_modifiers() # player rebuilds itself back to base values
	effects_changed.emit()

func start_new_run_loadout() -> void:
	mark_first_run_if_needed()
	has_bargained_this_run = false
	roll_starting_loadout()
	effects_changed.emit()

func _apply(loot: LootData) -> void:
	if _player == null:
		return
	match loot.effect:
		LootData.EffectType.WEAPON_DAMAGE_UP:
			_player.bonus_weapon_damage += loot.value
		LootData.EffectType.WEAPON_ATKSPD_UP:
			_player.bonus_cooldown_reduction += loot.value
		LootData.EffectType.PLAYER_HEALTH_UP:
			_player.stats.current_max_health += int(loot.value)
			_player.stats.health += int(loot.value)
			_player.stats.health_change.emit(_player.stats.health, _player.stats.current_max_health)
		LootData.EffectType.PLAYER_MOVE_SPD_UP:
			_player.base_move_speed += loot.value
		LootData.EffectType.DOUBLE_DASH:
			_player.max_dashes = 2
		LootData.EffectType.DMG_REDUCTION:
			_player.damage_reduction = clampf(_player.damage_reduction + loot.value, 0.0, 0.9) # TUNE: cap

func try_bargain() -> bool:
	if has_bargained_this_run or magic_residue <= 0:
		return false
	magic_residue -= 1
	has_bargained_this_run = true
	roll_starting_loadout()
	effects_changed.emit()
	return true
