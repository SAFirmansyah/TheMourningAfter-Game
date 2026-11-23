extends Node
## Autoload "SaveSystem": reads and writes save files, one per slot.
## Slots live in a profile: the real game (no prefix) or the title screen's Start from test save.

const DEFAULT_SLOT := "savegame"
const SLOTS: Array[String] = ["savegame", "huyana"] # every save file the game writes, per profile
const TEST_PROFILE := "startfrom_"

var profile := "" # file name prefix for every slot


## Wipes every slot in this profile.
func delete_profile(prefix: String) -> void:
	for slot in SLOTS:
		var path := "user://%s%s.json" % [prefix, slot]
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


const ENDED_FLAG := "user://ended.flag" # the 'Destroy the spell' ending's self-deletion; survives delete_all


func mark_ended() -> void:
	FileAccess.open(ENDED_FLAG, FileAccess.WRITE).store_string("There would be no mourning after.")


func is_ended() -> bool:
	return FileAccess.file_exists(ENDED_FLAG)


func clear_ended() -> void:
	if is_ended():
		DirAccess.remove_absolute(ENDED_FLAG)


## A brand-new game: the real saves and the test save are all gone.
func delete_all() -> void:
	delete_profile("")
	delete_profile(TEST_PROFILE)


func has_save(slot := DEFAULT_SLOT) -> bool:
	return FileAccess.file_exists(_path(slot))


func save_data(data: Dictionary, slot := DEFAULT_SLOT) -> bool:
	var temp := _path(slot) + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		push_error("Save failed: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return DirAccess.rename_absolute(temp, _path(slot)) == OK


func load_data(slot := DEFAULT_SLOT) -> Dictionary:
	if not has_save(slot):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path(slot)))
	return parsed if parsed is Dictionary else {}


func delete_save(slot := DEFAULT_SLOT) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(_path(slot))


func _path(slot: String) -> String:
	return "user://%s%s.json" % [profile, slot]
