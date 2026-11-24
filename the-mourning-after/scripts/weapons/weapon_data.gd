class_name WeaponData
extends Resource

@export var weapon_name := "Sword"
@export var damage := 1.0 # TUNE: base damage per hit
@export var attack_cooldown := 0.4 # TUNE: seconds between swings
@export var active_window := 0.3 # TUNE: how long the hitbox stays on
@export var active_delay := 0.1 # TUNE: windup before hitbox turns on
@export var hitbox_radius := 0.4 # TUNE: sword reach around each hit point (m)
@export var hitbox_height := 1.6 # TUNE: vertical coverage of the swing (m); never less than 2x radius

@export_group("Ability")
@export var hits_to_charge := 5 # TUNE: successful base hits (LMB) needed before the ability can be used
@export var charged_abilities: Array[WeaponAbility] = [] # the sword's ability (heal/poison/stun/crit), used with RMB/Q once charged
@export var charge_instant_use := false # true = RMB/Q applies the ability to the wielder at once (heal); false = RMB/Q swings an attack that applies it
