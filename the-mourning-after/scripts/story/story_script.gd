class_name StoryScript
extends RefCounted
## Reads a scene script (res://dialogue/...txt) into steps the StoryPlayer runs. Format:
##   NAME (portrait variant): line          dialogue; NAME may be a group ("ARCHI, SEIRA, KANO")
##   @command args                          staging (see StoryPlayer)
##   @text ... @end                         black-screen text; blank lines split stanzas
##   @choice  then  > option text | id      a choice in Constance's text box
##   # comment

const LINE_PATTERN := "^([A-Z][A-Z ,]*?)\\s*\\(([^)]*)\\)\\s*:\\s*(.+)$"


static func load_steps(path: String) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	var source := _read(path)
	if source.is_empty():
		push_error("Story script not found: %s" % path)
		return steps
	var line_re := RegEx.create_from_string(LINE_PATTERN)
	var in_text := false
	var stanzas: Array = []
	var stanza := PackedStringArray()
	var choice: Dictionary = {}
	for raw in source.split("\n"):
		var line := raw.strip_edges()
		if in_text:
			if line == "@end":
				if not stanza.is_empty():
					stanzas.append(stanza)
				steps.append({"type": "text", "stanzas": stanzas})
				in_text = false
			elif line.is_empty():
				if not stanza.is_empty():
					stanzas.append(stanza)
				stanza = PackedStringArray()
			else:
				stanza.append(line)
			continue
		if line.is_empty() or line.begins_with("#"):
			continue
		if line == "@text":
			in_text = true
			stanzas = []
			stanza = PackedStringArray()
		elif line == "@choice":
			choice = {"type": "choice", "options": []}
			steps.append(choice)
		elif line.begins_with(">") and not choice.is_empty():
			var parts := line.substr(1).split("|")
			var id := parts[1].strip_edges() if parts.size() > 1 else str(choice.options.size())
			choice.options.append({"text": parts[0].strip_edges(), "id": id})
		elif line.begins_with("@"):
			var words := line.substr(1).split(" ", false)
			steps.append({"type": "cmd", "name": words[0], "args": Array(words.slice(1))})
		else:
			var found := line_re.search(line)
			if found:
				steps.append({
					"type": "line",
					"speaker": found.get_string(1).strip_edges().to_lower(),
					"variant": found.get_string(2).strip_edges().to_lower(),
					"text": found.get_string(3).strip_edges(),
				})
			else:
				push_warning("%s: can't read line: %s" % [path.get_file(), line])
	return steps


## The imported resource (packed into exports); the raw file as a fallback (not yet imported).
static func _read(path: String) -> String:
	if ResourceLoader.exists(path):
		var imported := load(path) as StoryTextFile
		if imported:
			return imported.text
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
