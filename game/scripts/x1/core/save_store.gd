extends RefCounted
## Checked, atomic save of one Dictionary with a verified backup.
## The file holds {payload, hash}; writes go to .tmp, are read back, then replace the main file.

var path := ""
var validator: Callable
var last_error := ""


func _init(save_path: String, check: Callable) -> void:
	path = save_path
	validator = check


static func digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func read_file(filename: String) -> Dictionary:
	if not FileAccess.file_exists(filename): return {}
	var file := FileAccess.open(filename, FileAccess.READ)
	if file == null: return {}
	var envelope = file.get_var(false)
	file.close()
	if not envelope is Dictionary or not envelope.has("payload") or not envelope.payload is PackedByteArray: return {}
	var bytes: PackedByteArray = envelope.payload
	if envelope.get("hash", "") != digest(bytes): return {}
	var value = bytes_to_var(bytes)
	if not value is Dictionary or not validator.call(value): return {}
	return value


## Returns {"data": Dictionary, "status": "missing" | "ok" | "recovered" | "failed"}
func read() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"data": {}, "status": "missing"}
	var main := read_file(path)
	if not main.is_empty(): return {"data": main, "status": "ok"}
	var backup := read_file(path + ".bak")
	if not backup.is_empty(): return {"data": backup, "status": "recovered"}
	return {"data": {}, "status": "failed"}


func write(next: Dictionary) -> bool:
	if not validator.call(next):
		last_error = "存檔內容不完整，舊紀錄仍在"
		return false
	var payload := var_to_bytes(next)
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		last_error = "無法建立暫存檔"
		return false
	file.store_var({"payload": payload, "hash": digest(payload)}, false)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or read_file(temp).is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
		last_error = "存檔驗證失敗，舊紀錄仍在"
		return false
	if FileAccess.file_exists(path) and not read_file(path).is_empty():
		var old_bytes := FileAccess.get_file_as_bytes(path)
		var backup_temp := path + ".bak.tmp"
		var back := FileAccess.open(backup_temp, FileAccess.WRITE)
		if back == null:
			last_error = "無法保留前一份存檔"
			return false
		back.store_buffer(old_bytes)
		back.flush()
		error = back.get_error()
		back.close()
		if error != OK or read_file(backup_temp).is_empty():
			last_error = "備份驗證失敗，舊紀錄仍在"
			return false
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(backup_temp), ProjectSettings.globalize_path(path + ".bak")) != OK:
			last_error = "備份替換失敗，舊紀錄仍在"
			return false
	elif FileAccess.file_exists(path) and read_file(path + ".bak").is_empty():
		last_error = "原存檔與備份都無法驗證，已保留原資料"
		return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(path)) != OK:
		last_error = "存檔替換失敗，舊紀錄仍在"
		return false
	last_error = ""
	return true
