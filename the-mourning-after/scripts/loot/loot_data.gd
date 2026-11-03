# LootData.gd
class_name LootData
extends Resource

enum EffectType {
	WEAPON_DAMAGE_UP,
	WEAPON_ATKSPD_UP,      # faster attacks
	PLAYER_HEALTH_UP,
	PLAYER_MOVE_SPD_UP,
	DOUBLE_DASH,
	DMG_REDUCTION,
	MAGIC_RESIDUE,             # the one exception: a currency, not an instant effect
}

@export var loot_id: StringName = &""
@export var display_name := ""
@export var effect: EffectType = EffectType.WEAPON_DAMAGE_UP
@export var value := 0.0 # TUNE: meaning depends on effect: flat damage, % cooldown reduction, flat HP, etc.
@export var icon: Texture2D
