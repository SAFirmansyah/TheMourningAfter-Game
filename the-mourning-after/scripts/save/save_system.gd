extends Node
## Autoload "SaveSystem": reads and writes save files, one per slot.

const DEFAULT_SLOT := "savegame"


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
	return "user://%s.json" % slot
