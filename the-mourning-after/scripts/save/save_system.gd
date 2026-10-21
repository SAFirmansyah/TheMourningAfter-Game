extends Node
## Autoload "SaveSystem": reads and writes the single save file.

const SAVE_PATH := "user://savegame.json"
const TEMP_PATH := "user://savegame.json.tmp"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_data(data: Dictionary) -> bool:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Save failed: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH) == OK


func load_data() -> Dictionary:
	if not has_save():
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	return parsed if parsed is Dictionary else {}


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
