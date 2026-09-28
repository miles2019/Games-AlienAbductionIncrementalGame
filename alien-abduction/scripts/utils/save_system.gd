class_name SaveSystem
extends RefCounted
## JSON-Speichersystem mit Backup-Datei.

const SAVE_PATH := "user://abduct_o_matic_save.json"
const BACKUP_PATH := "user://abduct_o_matic_save.bak.json"
const VERSION := 2


static func save(data: Dictionary) -> bool:
	data["version"] = VERSION
	data["saved_at"] = Time.get_unix_time_from_system()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(BACKUP_PATH))
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Speichern fehlgeschlagen: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


static func load_save() -> Dictionary:
	var result := _read(SAVE_PATH)
	if result.is_empty():
		result = _read(BACKUP_PATH)
	return result


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func delete_save() -> void:
	for path in [SAVE_PATH, BACKUP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Spielstand %s ist beschädigt." % path)
		return {}
	return parsed


## Hilfsfunktionen zum sicheren Auslesen
static func get_float(d: Dictionary, key: String, default: float = 0.0) -> float:
	var v: Variant = d.get(key, default)
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		return float(v)
	return default


static func get_int(d: Dictionary, key: String, default: int = 0) -> int:
	return int(get_float(d, key, default))


static func get_dict(d: Dictionary, key: String) -> Dictionary:
	var v: Variant = d.get(key, {})
	if typeof(v) == TYPE_DICTIONARY:
		return v
	return {}
