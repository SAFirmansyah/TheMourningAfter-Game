class_name WeaponData
extends Resource

@export var weapon_name := "Sword"
@export var damage := 1.0 # TUNE: base damage per hit
@export var attack_cooldown := 0.4 # TUNE: seconds between swings
@export var active_window := 0.15 # TUNE: how long the hitbox stays on
@export var active_delay := 0.05 # TUNE: windup before hitbox turns on
@export var abilities: Array[WeaponAbility] = [] # on-hit effects on a normal (uncharged) attack
@export var hitbox_radius := 1.0
@export var hitbox_height := 0.8

@export_group("Charge Ability")
@export var charge_per_attack := 20.0 # TUNE: charge gained per swing (charge fills to 100)
@export var charged_abilities: Array[WeaponAbility] = [] # effects triggered on the attack that consumes a full charge
@export var charge_instant_use := false # true = Q applies ability immediately (self-targeted, e.g. heal); false = Q arms it for the next attack
