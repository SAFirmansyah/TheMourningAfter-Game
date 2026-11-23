# RunInventory.gd (autoload)
extends Node

signal effects_changed
signal bargained # any Fate bargain went through; the world autosaves

var applied_effects: Array[LootData] = [] # kept only so we know what to undo on death

@export var first_run_residue_grant := 2 # TUNE: residue given on the very first ever run
@export var reseed_cost := 1 # TUNE: Fate 1 re-seed of starting stats (no limit per run)
@export var revive_costs: Array[int] = [2, 3] # TUNE: Fate 3 cost of each revive in a run; its length is the revive limit
@export var _wood_sword: WeaponData = preload("res://scripts/weapons/sword_wood.tres")
@export var _bone_sword: WeaponData = preload("res://scripts/weapons/sword_bone.tres") # first run's Fate 1 bargain
@export var _starting_weapon_pool: Array[WeaponData] = [
	preload("res://scripts/weapons/sword_wood.tres"),
	preload("res://scripts/weapons/sword_bone.tres"),
	preload("res://scripts/weapons/sword_bronze.tres"),
	preload("res://scripts/weapons/sword_iron.tres"),
]
var has_completed_first_run := false # set once the first run has begun; saved
var has_reached_boss := false # the forced Fate 2 bargain has happened; saved
var final_snapshot := {} # GDD: Perrin's loadout and the boss killed on the run that reached the Sanctuary; saved
var loadout_taken := false # this run's starting stats + weapon have been handed out (starting room)
var _first_run_active := false
var revives_used := 0 # Fate 3 revives bought this run; saved with the run
var has_bargained_this_run := false # resets each new run; set by the first Fate 1 bargain
var magic_residue := 0
var residue_gained_this_run := 0

const MAX_RESIDUE_PER_RUN := 5 # TUNE: residue that can drop in one run

var _player: Player


func bind_player(player: Player) -> void:
	_player = player


## A world is starting (launch, or back from the title screen): drop anything left from an earlier
## session before the save is read.
func reset_session() -> void:
	applied_effects.clear()
	loadout_taken = false
	_first_run_active = false
	revives_used = 0
	has_bargained_this_run = false
	residue_gained_this_run = 0
	magic_residue = 0
	has_completed_first_run = false
	has_reached_boss = false
	final_snapshot = {}


## Every Fate bargain checks and pays through these (the Ignore residue test button skips both).
func can_afford(cost: int) -> bool:
	return TestTools.ignore_residue or magic_residue >= cost


func spend(cost: int) -> void:
	if not TestTools.ignore_residue:
		magic_residue = maxi(magic_residue - cost, 0)

func get_player() -> Player:
	return _player


func clear_weapon() -> void:
	if _player:
		_player.weapon = null


func mark_first_run_if_needed() -> void:
	_first_run_active = not has_completed_first_run
	if not has_completed_first_run:
		magic_residue = first_run_residue_grant
		has_completed_first_run = true

func collect(loot: LootData) -> void:
	if loot.effect == LootData.EffectType.MAGIC_RESIDUE:
		if can_drop_residue():
			magic_residue += 1
			residue_gained_this_run += 1
			effects_changed.emit()
		return

	applied_effects.append(loot)
	_apply(loot)
	effects_changed.emit()
	
	
func roll_starting_loadout() -> void:
	print("roll_starting_loadout called, has_completed_first_run=", has_completed_first_run)
	if _first_run_active and not has_bargained_this_run:
		_player.stats.setup_first_run_stats()
		_player.weapon = _wood_sword
	else:
		_player.stats.setup_stats()
		_player.weapon = _starting_weapon_pool.pick_random()
		print("bargain rerolled weapon to: ", _player.weapon.weapon_name if _player.weapon else "null")


func can_drop_residue() -> bool:
	return residue_gained_this_run < MAX_RESIDUE_PER_RUN


func reset_on_death() -> void:
	applied_effects.clear()
	loadout_taken = false
	if _player:
		_player.reset_run_modifiers() # player rebuilds itself back to base values
	effects_changed.emit()

## Starting room: rolls this run's stats + weapon and starts the run's room sequence.
func take_loadout() -> bool:
	if loadout_taken or _player == null:
		return false
	start_new_run_loadout()
	loadout_taken = true
	CombatRunState.start_new_run()
	CampaignState.reset_campaign()
	effects_changed.emit()
	return true


## Fate 3: residue the next revive costs.
func revive_cost() -> int:
	return revive_costs[revives_used] if revives_used < revive_costs.size() else 0


func can_revive() -> bool:
	return loadout_taken and revives_used < revive_costs.size() and can_afford(revive_cost())


## Spends the residue for a Fate 3 revive.
func buy_revive() -> bool:
	if not can_revive():
		return false
	spend(revive_cost())
	revives_used += 1
	effects_changed.emit()
	bargained.emit()
	return true


## Interact prompt for any Fate bargain.
func bargain_prompt(cost: int) -> String:
	return "Bargain (free)" if cost <= 0 else "Bargain (-%d)" % cost


func can_bargain() -> bool:
	return loadout_taken and can_afford(reseed_cost)


## Fresh save only: the first run can't leave the starting room until Fate 1 is bargained with.
func fate1_forced_pending() -> bool:
	return _first_run_active and loadout_taken and not has_bargained_this_run


func start_new_run_loadout() -> void:
	mark_first_run_if_needed()
	has_bargained_this_run = false
	residue_gained_this_run = 0
	revives_used = 0
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
			_player.show_heal_effect()
		LootData.EffectType.PLAYER_MOVE_SPD_UP:
			_player.bonus_move_speed += loot.value
		LootData.EffectType.DOUBLE_DASH:
			_player.max_dashes = 2
		LootData.EffectType.DMG_REDUCTION:
			_player.damage_reduction = clampf(_player.damage_reduction + loot.value, 0.0, 0.9) # TUNE: cap

## Fate 1: 1 residue re-seeds the starting stats + weapon, once per run.
## On the very first run it always grants 100 HP, 1x speed and the bone sword (GDD).
func try_bargain() -> bool:
	if not can_bargain():
		return false
	spend(reseed_cost)
	var forced := fate1_forced_pending()
	has_bargained_this_run = true
	if forced:
		_player.stats.setup_fixed_stats(100, 1.0)
		_player.weapon = _bone_sword
	else:
		roll_starting_loadout()
	effects_changed.emit()
	bargained.emit()
	return true


## Reaching the Sanctuary: keep this run's Perrin for the montage and final boss fight.
func take_final_snapshot() -> void:
	final_snapshot = save_run()
	final_snapshot["boss_killed"] = CampaignState.chosen_boss


## This run's state for the save file.
func save_run() -> Dictionary:
	if not loadout_taken or _player == null:
		return {}
	var p := _player
	return {
		"first_run_active": _first_run_active,
		"has_bargained": has_bargained_this_run,
		"residue_gained": residue_gained_this_run,
		"revives_used": revives_used,
		"effects": applied_effects.map(func(l: LootData) -> String: return l.resource_path),
		"weapon": p.weapon.resource_path if p.weapon else "",
		"charge": p.charge_points,
		"max_health": p.stats.current_max_health,
		"health": p.stats.health,
		"move_speed": p.stats.move_speed_multiplier,
		"bonus_damage": p.bonus_weapon_damage,
		"bonus_attack_speed": p.bonus_cooldown_reduction,
		"damage_reduction": p.damage_reduction,
		"bonus_move_speed": p.bonus_move_speed,
		"max_dashes": p.max_dashes,
	}


## Puts a saved run back on the player (stats wait a frame so HeroStats' own setup can't overwrite them).
func load_run(run: Dictionary) -> void:
	if run.is_empty() or _player == null:
		return
	var p := _player
	loadout_taken = true
	_first_run_active = run.get("first_run_active", false)
	has_bargained_this_run = run.get("has_bargained", false)
	residue_gained_this_run = run.get("residue_gained", 0)
	revives_used = int(run.get("revives_used", 0))
	applied_effects.clear()
	for path: String in run.get("effects", []):
		if ResourceLoader.exists(path):
			applied_effects.append(load(path))
	var weapon_path: String = run.get("weapon", "")
	p.weapon = load(weapon_path) if ResourceLoader.exists(weapon_path) else _wood_sword
	p.charge_points = run.get("charge", 0.0)
	p.bonus_weapon_damage = run.get("bonus_damage", 0.0)
	p.bonus_cooldown_reduction = run.get("bonus_attack_speed", 0.0)
	p.damage_reduction = run.get("damage_reduction", 0.0)
	p.bonus_move_speed = run.get("bonus_move_speed", 0.0)
	p.max_dashes = run.get("max_dashes", 1)
	p.dashes_available = p.max_dashes
	_restore_stats.call_deferred(int(run.get("max_health", 100)), int(run.get("health", 100)), float(run.get("move_speed", 1.0)))
	effects_changed.emit()


func _restore_stats(max_health: int, health: int, move_speed: float) -> void:
	_player.stats.setup_fixed_stats(max_health, move_speed)
	_player.stats.on_health_set(health)
	effects_changed.emit()
