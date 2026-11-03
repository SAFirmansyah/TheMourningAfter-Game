class_name PlayerHUD
extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthBar
@onready var health_label: Label = $HealthBar/HealthLabel
@onready var charge_bar: ProgressBar = $AbilityChargeBar
@onready var residue_label: Label = $ResidueLabel
@onready var weapon_label: Label = $WeaponLabel
@onready var ability_label: Label = $AbilityLabel

var _stats: HeroStats
var _player: Player


func _ready() -> void:
	RunInventory.effects_changed.connect(_on_effects_changed)
	_on_effects_changed() # sync immediately on load

func bind_stats(stats: HeroStats) -> void:
	if _stats:
		_stats.health_change.disconnect(_on_health_change)
	_stats = stats
	_stats.health_change.connect(_on_health_change)
	_on_health_change(_stats.health, _stats.current_max_health)
	
func bind_player(player: Player) -> void:
	_player = player
	charge_bar.max_value = Player.MAX_CHARGE
	player.weapon_changed.connect(_on_weapon_changed)
	_on_weapon_changed(player.weapon) # sync immediately on bind


func _on_health_change(cur_health: int, max_health: int) -> void:
	health_bar.max_value = max_health
	health_bar.value = cur_health
	health_label.text = "%d / %d" % [cur_health, max_health]
	
func _on_effects_changed() -> void:
	residue_label.text = "Residue: %d / %d" % [RunInventory.magic_residue, RunInventory.MAX_RESIDUE_PER_RUN]
	
func _process(_delta: float) -> void:
	if _player:
		charge_bar.value = _player.charge_points
		_update_ability_ready_label()
		
func _on_weapon_changed(weapon: WeaponData) -> void:
	weapon_label.text = weapon.weapon_name if weapon else "No Weapon"
	
func _update_ability_ready_label() -> void:
	if _player.weapon == null:
		ability_label.visible = false
		return

	var name := _ability_name_for(_player.weapon)

	if _player._ability_armed:
		ability_label.visible = true
		ability_label.text = "%s Ready! (%.1fs)" % [name, _player._ability_armed_time_left]
	elif _player.charge_points >= Player.MAX_CHARGE:
		ability_label.visible = true
		ability_label.text = "%s Available" % name
	else:
		ability_label.visible = false

func _ability_name_for(weapon: WeaponData) -> String:
	if weapon.charged_abilities.is_empty():
		return "Ability"
	var ability := weapon.charged_abilities[0]
	if ability is PoisonDamageAbility:
		return "Poison"
	elif ability is StunAbility:
		return "Stun"
	elif ability is CritHitAbility:
		return "Critical Hit"
	elif ability is SelfHealAbility:
		return "Heal"
	return "Ability"
