@tool
extends EditorPlugin
## Registers the .txt importer (see importer.gd).

var _importer: EditorImportPlugin


func _enter_tree() -> void:
	_importer = preload("res://addons/story_text_import/importer.gd").new()
	add_import_plugin(_importer)


func _exit_tree() -> void:
	remove_import_plugin(_importer)
	_importer = null
