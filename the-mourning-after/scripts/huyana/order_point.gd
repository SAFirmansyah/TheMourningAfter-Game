@tool
class_name OrderPoint
extends Interactable
## E-spot for ordering. Three kinds:
## - a station slot (slot >= 0): "Order" when empty, "Collect" when ready, nothing while in progress;
## - a worker herself (slot = -1): "Order" into any free slot, or a "busy" line when every slot is taken;
## - Rudrama or her anvil: the repair menu.
## Gwenith's and Shuyi's menus open over their station.

@export_enum("gwenith", "shuyi", "rudrama") var worker := "gwenith"
@export var slot := -1 # station slot this point serves; -1 = the worker herself
@export var station: WorkStation # menus open over this station
@export var pauses_worker := false # Rudrama herself: she stops walking while her menu is open
@export var menu_height := 2.4 # TUNE: height of the menu's tip above this point when there's no station (m)
@export_multiline var busy_line := "My hands are full right now. Come back once something's ready to collect."

var _manager: SanctuaryManager
var _busy_conversation: Array[DialogueLine] = []
var _no_conversation: Array[DialogueLine] = []


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	prompt_label = "Order"
	_manager = get_tree().get_first_node_in_group(&"sanctuary_manager")
	var npc := get_parent() as NPC
	if npc:
		var card := npc.get_node(^"Card") as Sprite3D
		character_name = npc.character_name
		var art: Texture2D = npc.portrait if npc.portrait else StoryPlayer.portrait(npc.character_name.to_lower(), "neutral")
		character_portrait = art if art else card.texture
		character_portrait_tint = Color.WHITE if art else npc.tint
	var line := DialogueLine.new()
	line.text = busy_line
	_busy_conversation.append(line)
	interacted.connect(_on_interacted)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _manager == null:
		return
	var is_day := _manager.day_cycle.phase == DayCycle.Phase.DAY
	if worker == "rudrama":
		enabled = is_day
		return
	var who := StringName(worker)
	if slot >= 0:
		var state := _manager.slot_state(who, slot)
		enabled = is_day and state != SanctuaryManager.SlotState.PREPARING
		prompt_label = "Collect" if state == SanctuaryManager.SlotState.READY else "Order"
	else:
		enabled = is_day
		var busy := not _manager.has_free_slot(who)
		prompt_label = "Talk" if busy else "Order"
		conversation = _busy_conversation if busy else _no_conversation


func menu_anchor() -> Vector3:
	return station.menu_anchor() if station else global_position + Vector3(0.0, menu_height, 0.0)


func _on_interacted() -> void:
	var menus := get_tree().get_first_node_in_group(&"order_menus") as OrderMenus
	if menus == null or _manager == null:
		return
	var who := StringName(worker)
	if worker != "rudrama":
		if slot >= 0 and _manager.slot_state(who, slot) == SanctuaryManager.SlotState.READY:
			_manager.collect(who, slot)
			return
		if is_conversation():
			return # busy line plays instead
	menus.open(who, self, pauses_worker, slot)
