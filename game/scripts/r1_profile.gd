extends RefCounted
## Local profile and resumable run are committed together in one checked file.

const LegacyTreasure := preload("res://scripts/treasure_collection.gd")
const ITEMS := {
	"H01": {"name": "斷線貓鬚", "slot": "habit", "core": "a", "desc": "穿影二級提早取得寬影成形"},
	"H03": {"name": "回身鈴鐺", "slot": "habit", "core": "b", "desc": "游走二級提早取得回身追咬"},
	"H05": {"name": "牙印石", "slot": "habit", "core": "c", "desc": "獵痕二級提早取得緊咬成形"},
	"U01": {"name": "柔布領巾", "slot": "charm", "core": "", "desc": "每戰首次受傷減少 8，至少受 1"},
	"U02": {"name": "羽毛繩", "slot": "charm", "core": "", "desc": "移動速度 +5%"},
	"U03": {"name": "小布袋", "slot": "charm", "core": "", "desc": "經驗吸附範圍增加"},
}

var path: String
var legacy_path: String
var data: Dictionary = {}
var load_failed := false
var last_error := ""


func _init(save_path: String = "user://nana-r1.save", old_path: String = "user://treasure-collection.json") -> void:
	path = save_path
	legacy_path = old_path
	load_profile()


func default_data() -> Dictionary:
	return {"version": 2, "owned": ["U01", "U02"], "habit": "", "charm": "", "target": "",
		"assist": false, "active": {}, "history": [], "finished_first": false}


func _digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _valid_data(value) -> bool:
	if not value is Dictionary or value.get("version", 0) != 2: return false
	if not value.get("owned") is Array or not value.get("active") is Dictionary: return false
	if not value.get("history") is Array or not value.get("assist") is bool or not value.get("finished_first") is bool: return false
	for key: String in ["habit", "charm", "target"]:
		if not value.get(key) is String: return false
	var seen := {}
	for id in value.owned:
		if not id is String or not ITEMS.has(id) or seen.has(id): return false
		seen[id] = true
	for starter: String in ["U01", "U02"]:
		if starter not in seen: return false
	for slot: String in ["habit", "charm"]:
		var selected: String = value[slot]
		if not selected.is_empty() and (not ITEMS.has(selected) or selected not in seen or ITEMS[selected].slot != slot): return false
	var target: String = value.target
	if not target.is_empty() and (not ITEMS.has(target) or target in seen or target in ["U01", "U02"]): return false
	return true


func _read_file(filename: String) -> Dictionary:
	if not FileAccess.file_exists(filename): return {}
	var file := FileAccess.open(filename, FileAccess.READ)
	if file == null: return {}
	var envelope = file.get_var(false)
	file.close()
	if not envelope is Dictionary or not envelope.has("payload") or not envelope.payload is PackedByteArray:
		return {}
	var bytes: PackedByteArray = envelope.payload
	if envelope.get("hash", "") != _digest(bytes): return {}
	var value = bytes_to_var(bytes)
	if not _valid_data(value): return {}
	return value


func load_profile() -> bool:
	load_failed = false
	last_error = ""
	if FileAccess.file_exists(path):
		data = _read_file(path)
		if not data.is_empty(): return true
		var backup := _read_file(path + ".bak")
		if not backup.is_empty():
			data = backup
			last_error = "已從前一份有效存檔復原"
			return true
		load_failed = true
		last_error = "存檔無法讀取，原始資料已保留"
		return false
	data = default_data()
	if FileAccess.file_exists(legacy_path):
		var legacy := LegacyTreasure.new(legacy_path)
		if legacy.load_failed:
			load_failed = true
			last_error = "舊收藏無法讀取，原始資料已保留"
			return false
		if legacy.owned:
			data.owned.append("H03")
			if legacy.equipped: data.habit = "H03"
	return true


func commit(next: Dictionary) -> bool:
	if load_failed: return false
	if not _valid_data(next):
		last_error = "存檔內容不完整，舊紀錄仍在"
		return false
	var payload := var_to_bytes(next)
	var temp := path + ".tmp"
	var f := FileAccess.open(temp, FileAccess.WRITE)
	if f == null:
		last_error = "無法建立暫存檔"
		return false
	f.store_var({"payload": payload, "hash": _digest(payload)}, false)
	f.flush()
	var error := f.get_error()
	f.close()
	if error != OK or _read_file(temp) != next:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
		last_error = "存檔驗證失敗，舊紀錄仍在"
		return false
	if FileAccess.file_exists(path) and not _read_file(path).is_empty():
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
		if error != OK or _read_file(backup_temp).is_empty():
			last_error = "備份驗證失敗，舊紀錄仍在"
			return false
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(backup_temp), ProjectSettings.globalize_path(path + ".bak"))
		if error != OK:
			last_error = "備份替換失敗，舊紀錄仍在"
			return false
	elif FileAccess.file_exists(path) and _read_file(path + ".bak").is_empty():
		last_error = "原存檔與備份均無法驗證，已保留原資料"
		return false
	error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(path))
	if error != OK:
		last_error = "存檔替換失敗，舊紀錄仍在"
		return false
	data = next.duplicate(true)
	last_error = ""
	return true


func acquire(id: String, active: Dictionary) -> bool:
	if not ITEMS.has(id): return false
	var next := data.duplicate(true)
	if id not in next.owned: next.owned.append(id)
	if next.target == id: next.target = ""
	next.active = active.duplicate(true)
	return commit(next)


func select_item(slot: String, id: String) -> bool:
	if slot not in ["habit", "charm"]: return false
	if not id.is_empty() and (id not in data.owned or ITEMS[id].slot != slot): return false
	var next := data.duplicate(true)
	next[slot] = id
	return commit(next)


func set_target(id: String) -> bool:
	if not id.is_empty() and (not ITEMS.has(id) or id in data.owned or id in ["U01", "U02"]): return false
	var next := data.duplicate(true)
	next.target = id
	return commit(next)


func save_active(snapshot: Dictionary) -> bool:
	var next := data.duplicate(true)
	next.active = snapshot.duplicate(true)
	return commit(next)


func finish(summary: Dictionary) -> bool:
	var next := data.duplicate(true)
	next.active = {}
	next.history.append(summary.duplicate(true))
	while next.history.size() > 20: next.history.pop_front()
	if summary.get("won", false): next.finished_first = true
	return commit(next)
