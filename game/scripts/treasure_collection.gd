extends RefCounted
## Persistent collection. Write a complete temporary file before replacing the old one.
var path := "user://treasure-collection.json"
var owned := false
var equipped := false
var load_failed := false

func _init(file_path: String = "user://treasure-collection.json") -> void:
	path = file_path
	load_state()

func load_state() -> bool:
	owned = false
	equipped = false
	load_failed = false
	if not FileAccess.file_exists(path): return true
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		load_failed = true
		return false
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or data.get("version") != 1 or not data.get("owned") is bool or not data.get("equipped") is bool or (data.equipped and not data.owned):
		load_failed = true
		return false
	owned = data.owned
	equipped = data.equipped
	return true

func save_state(new_owned: bool, new_equipped: bool) -> bool:
	if load_failed or (new_equipped and not new_owned): return false
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"version": 1, "owned": new_owned, "equipped": new_equipped}))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
		return false
	error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(path))
	if error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
		return false
	owned = new_owned
	equipped = new_equipped
	return true

func acquire() -> bool:
	return owned or save_state(true, false)

func set_equipped(value: bool) -> bool:
	return save_state(owned, value)
